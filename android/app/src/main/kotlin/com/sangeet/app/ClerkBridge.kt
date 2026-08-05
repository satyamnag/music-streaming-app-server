package com.sangeet.app

import com.clerk.api.Clerk
import com.clerk.api.auth.types.VerificationType
import com.clerk.api.emailaddress.EmailAddress
import com.clerk.api.emailaddress.sendCode
import com.clerk.api.emailaddress.verifyCode
import com.clerk.api.network.model.factor.Factor
import com.clerk.api.network.model.verification.Verification
import com.clerk.api.network.serialization.errorMessage
import com.clerk.api.network.serialization.onFailure
import com.clerk.api.network.serialization.onSuccess
import com.clerk.api.signin.SignIn
import com.clerk.api.signin.prepareFirstFactor
import com.clerk.api.signin.verifyCode
import com.clerk.api.signup.SignUp
import com.clerk.api.signup.sendCode
import com.clerk.api.signup.verifyCode
import com.clerk.api.user.User
import com.clerk.api.user.createEmailAddress
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.launch

/**
 * Bridges the Clerk Android SDK (Native API) to the Flutter side.
 *
 * Implements a passwordless **email OTP only** auth flow, following Clerk's
 * official custom-flow guide:
 *  - sign up (new users): `Clerk.auth.signUp { email = X }` -> sendCode ->
 *    verifyCode(code, VerificationType.EMAIL). When the sign-up status becomes
 *    COMPLETE the user is created AND the session is set active.
 *  - sign in (existing users): falls back to `Clerk.auth.signIn { email = X }`
 *    -> sendCode -> verifyCode(code). When COMPLETE the session is active.
 *
 * Phone OTP is intentionally not supported. Auth state (initialized + user) is
 * streamed to Dart over an EventChannel.
 */
class ClerkBridge(
    engine: io.flutter.embedding.engine.FlutterEngine,
    private val app: SoulfulBhaktiApp,
) {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    private val methodChannel =
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL_METHODS)
    private val eventChannel =
        EventChannel(engine.dartExecutor.binaryMessenger, CHANNEL_EVENTS)

    private var eventSink: EventChannel.EventSink? = null

    init {
        methodChannel.setMethodCallHandler(::onMethodCall)
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
                emitState()
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })

        combine(Clerk.isInitialized, Clerk.userFlow) { initialized, user ->
            emitState(
                initialized = initialized,
                signedIn = user != null,
                userId = user?.id,
                email = user?.primaryEmailAddress?.emailAddress,
                username = user?.username,
                imageUrl = user?.imageUrl,
            )
        }.onEach {
            // state already emitted above
        }.launchIn(scope)
    }

    private fun emitState(
        initialized: Boolean = Clerk.isInitialized.value,
        signedIn: Boolean = Clerk.userFlow.value != null,
        userId: String? = Clerk.userFlow.value?.id,
        email: String? = Clerk.userFlow.value?.primaryEmailAddress?.emailAddress,
        username: String? = Clerk.userFlow.value?.username,
        imageUrl: String? = Clerk.userFlow.value?.imageUrl,
    ) {
        val state = mapOf(
            "initialized" to initialized,
            "signedIn" to signedIn,
            "userId" to (userId ?: ""),
            "email" to (email ?: ""),
            "username" to (username ?: ""),
            "imageUrl" to (imageUrl ?: ""),
        )
        eventSink?.success(state)
    }

    private fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            // Receives the Clerk publishable key from Flutter (sourced from the
            // project .env) and initializes the Clerk SDK if not yet done.
            "setPublishableKey" -> {
                val key = call.argument<String>("publishableKey") ?: ""
                app.ensureClerkInitialized(key)
                result.success(mapOf("status" to "success"))
            }

            "getState" -> {
                emitState()
                result.success(
                    mapOf(
                        "initialized" to Clerk.isInitialized.value,
                        "signedIn" to (Clerk.userFlow.value != null),
                        "userId" to (Clerk.userFlow.value?.id ?: ""),
                        "email" to (Clerk.userFlow.value?.primaryEmailAddress?.emailAddress ?: ""),
                        "username" to (Clerk.userFlow.value?.username ?: ""),
                        "imageUrl" to (Clerk.userFlow.value?.imageUrl ?: ""),
                    ),
                )
            }

            // Reports whether the signed-in user's email is verified.
            "getVerificationStatus" -> {
                val user = Clerk.userFlow.value
                if (user == null) {
                    result.success(mapOf("status" to "error", "error" to "Not signed in"))
                    return
                }
                val emailAddresses = user.emailAddresses
                val email = emailAddresses?.firstOrNull()?.emailAddress ?: ""
                result.success(
                    mapOf(
                        "status" to "success",
                        "email" to email,
                        "emailVerified" to
                            (emailAddresses?.firstOrNull()?.verification?.status ==
                                Verification.Status.VERIFIED),
                    ),
                )
            }

            // Sends a one-time code to the signed-in user's email, creating the
            // email contact if it does not exist yet.
            "sendContactOtp" -> {
                val identifier = call.argument<String>("identifier") ?: ""
                val user = Clerk.userFlow.value
                if (user == null) {
                    result.success(mapOf("status" to "error", "error" to "Not signed in"))
                    return
                }
                scope.launch {
                    createEmailAndSendCode(user, identifier, result)
                }
            }

            // Verifies the one-time code for the signed-in user's email.
            "verifyContactOtp" -> {
                val code = call.argument<String>("code") ?: ""
                val user = Clerk.userFlow.value
                if (user == null) {
                    result.success(mapOf("status" to "error", "error" to "Not signed in"))
                    return
                }
                scope.launch {
                    verifyEmailCode(user, code, result)
                }
            }

            // First step: send a one-time code to the given email address.
            // New users are signed up; existing users fall back to a proper
            // sign-in flow (create sign-in without a strategy, then prepare the
            // email_code first factor) so they can log back in any number of
            // times. A single-shot signInWithOtp fails on many instances with
            // "email_code does not match one of the allowed values for
            // parameter strategy".
            "sendOtp" -> {
                val identifier = call.argument<String>("identifier") ?: ""
                if (identifier.isBlank()) {
                    result.success(mapOf("status" to "error", "error" to "Empty identifier"))
                    return
                }
                scope.launch {
                    Clerk.auth
                        .signUp {
                            email = identifier
                        }
                        .onSuccess { signUp ->
                            signUp.sendCode {
                                email = identifier
                            }
                                .onSuccess {
                                    result.success(mapOf("status" to "sent"))
                                }
                                .onFailure {
                                    result.success(
                                        mapOf("status" to "error", "error" to it.errorMessage),
                                    )
                                }
                        }
                        .onFailure { signUpError ->
                            // Sign-up rejected (e.g. "email already taken") —
                            // the account already exists. Use the two-step
                            // sign-in flow: create the SignIn by identifier,
                            // then prepare the email_code first factor to send
                            // the OTP.
                            Clerk.auth
                                .signIn {
                                    email = identifier
                                }
                                .onSuccess { signIn ->
                                    prepareEmailCode(signIn, identifier, result)
                                }
                                .onFailure { signInError ->
                                    android.util.Log.i("ClerkBridge", "sendOtp signIn failure: ${signInError.errorMessage}")
                                    result.success(
                                        mapOf(
                                            "status" to "error",
                                            "error" to "${signUpError.errorMessage}. ${signInError.errorMessage}",
                                        ),
                                    )
                                }
                        }
                }
            }

            // Second step: verify the code the user received. Handles both the
            // sign-up flow (new users) and the sign-in flow (existing users).
            "verifyOtp" -> {
                val code = call.argument<String>("code") ?: ""
                val inProgressSignIn = Clerk.auth.currentSignIn
                val inProgressSignUp = Clerk.auth.currentSignUp
                if (inProgressSignIn == null && inProgressSignUp == null) {
                    result.success(mapOf("status" to "error", "error" to "No sign in/up in progress"))
                    return
                }
                scope.launch {
                    if (inProgressSignIn != null) {
                        inProgressSignIn
                            .verifyCode(code)
                            .onSuccess { signIn ->
                                android.util.Log.i("ClerkBridge", "verifyOtp sign-in status=${signIn.status}")
                                if (signIn.status == SignIn.Status.COMPLETE) {
                                    result.success(mapOf("status" to "complete"))
                                } else {
                                    result.success(
                                        mapOf("status" to "error", "error" to "Sign-in not complete"),
                                    )
                                }
                            }
                            .onFailure {
                                android.util.Log.i("ClerkBridge", "verifyOtp sign-in failure: ${it.errorMessage}")
                                result.success(mapOf("status" to "error", "error" to it.errorMessage))
                            }
                        return@launch
                    }
                    val signUp = inProgressSignUp ?: run {
                        result.success(mapOf("status" to "error", "error" to "No sign up in progress"))
                        return@launch
                    }
                    signUp
                        .verifyCode(
                            code,
                            VerificationType.EMAIL,
                        )
                        .onSuccess { signUp ->
                            android.util.Log.i("ClerkBridge", "verifyOtp success status=${signUp.status} missing=${signUp.missingFields} required=${signUp.requiredFields}")
                            if (signUp.status == SignUp.Status.COMPLETE) {
                                result.success(mapOf("status" to "complete"))
                            } else {
                                result.success(
                                    mapOf(
                                        "status" to "error",
                                        "error" to "Sign-up not complete. Missing: ${signUp.missingFields.joinToString()}",
                                    ),
                                )
                            }
                        }
                        .onFailure {
                            android.util.Log.i("ClerkBridge", "verifyOtp failure: ${it.errorMessage}")
                            result.success(mapOf("status" to "error", "error" to it.errorMessage))
                        }
                }
            }

            "signOut" -> {
                scope.launch {
                    Clerk.auth.signOut()
                        .onSuccess { result.success(mapOf("status" to "success")) }
                        .onFailure {
                            result.success(mapOf("status" to "error", "error" to it.errorMessage))
                        }
                }
            }

            else -> result.notImplemented()
        }
    }

    private suspend fun createEmailAndSendCode(
        user: User,
        identifier: String,
        result: Result,
    ) {
        val existing = user.emailAddresses?.firstOrNull()
        if (existing != null) {
            existing.sendCode()
                .onSuccess { result.success(mapOf("status" to "sent")) }
                .onFailure {
                    result.success(mapOf("status" to "error", "error" to it.errorMessage))
                }
            return
        }
        user.createEmailAddress(identifier)
            .onSuccess { email ->
                email.sendCode()
                    .onSuccess { result.success(mapOf("status" to "sent")) }
                    .onFailure {
                        result.success(mapOf("status" to "error", "error" to it.errorMessage))
                    }
            }
            .onFailure {
                result.success(mapOf("status" to "error", "error" to it.errorMessage))
            }
    }

    private suspend fun verifyEmailCode(user: User, code: String, result: Result) {
        val email = user.emailAddresses?.firstOrNull()
        if (email == null) {
            result.success(mapOf("status" to "error", "error" to "No email address to verify"))
            return
        }
        email.verifyCode(code)
            .onSuccess {
                if (it.verification?.status == Verification.Status.VERIFIED) {
                    result.success(mapOf("status" to "complete"))
                } else {
                    result.success(mapOf("status" to "error", "error" to "Email not verified"))
                }
            }
            .onFailure {
                result.success(mapOf("status" to "error", "error" to it.errorMessage))
            }
    }

    /**
     * Sends an email OTP for an existing account using the two-step sign-in
     * flow: pick the first supported `email_code` factor and prepare it. This
     * is the officially supported way to send an OTP to an existing user; a
     * single-shot `signInWithOtp` fails on instances that only allow strategy
     * selection at factor-prepare time.
     */
    private suspend fun prepareEmailCode(
        signIn: SignIn,
        identifier: String,
        result: Result,
    ) {
        val emailCodeFactor = signIn.supportedFirstFactors
            ?.firstOrNull { it.strategy == "email_code" }
        if (emailCodeFactor == null) {
            result.success(
                mapOf(
                    "status" to "error",
                    "error" to "Email code sign-in is not available for this account",
                ),
            )
            return
        }
        signIn
            .prepareFirstFactor(
                SignIn.PrepareFirstFactorParams.EmailCode(
                    emailAddressId = emailCodeFactor.emailAddressId ?: "",
                ),
            )
            .onSuccess {
                android.util.Log.i("ClerkBridge", "prepareEmailCode success id=${signIn.id}")
                result.success(mapOf("status" to "sent"))
            }
            .onFailure {
                android.util.Log.i("ClerkBridge", "prepareEmailCode failure: ${it.errorMessage}")
                result.success(mapOf("status" to "error", "error" to it.errorMessage))
            }
    }

    fun destroy() {
        scope.cancel()
        methodChannel.setMethodCallHandler(null)
    }

    companion object {
        const val CHANNEL_METHODS = "com.soulfulbhakti.app/clerk"
        const val CHANNEL_EVENTS = "com.soulfulbhakti.app/clerk/events"
    }
}
