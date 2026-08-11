package com.sangeet.app

import android.app.Activity
import android.app.Application
import android.os.Bundle
import com.clerk.api.Clerk
import com.clerk.api.network.model.verification.Verification
import com.clerk.api.network.serialization.errorMessage
import com.clerk.api.network.serialization.onFailure
import com.clerk.api.network.serialization.onSuccess
import com.clerk.api.sso.OAuthProvider
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.async
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.launch
import kotlinx.coroutines.selects.select

/**
 * Bridges the Clerk Android SDK (Native API) to the Flutter side.
 *
 * Implements a **Google-only** sign-in flow. The user picks an account in the
 * Google account chooser (rendered in a Chrome Custom Tab by the Clerk SDK);
 * new users are signed up automatically (Clerk's internal sign-in -> sign-up
 * transfer), existing users are signed in. Phone/email OTP is intentionally
 * not supported. Auth state (initialized + user + emailVerified) is streamed
 * to Dart over an EventChannel.
 *
 * ### OAuth cancellation
 * When the user dismisses the browser flow (pressing BACK, or closing the
 * Custom Tab), the Clerk SDK's `SSOManagerActivity` finishes, but the OAuth
 * call resolves with an opaque proxy error ("There is no account to
 * transfer") rather than a clean cancellation signal. This bridge therefore
 * treats any OAuth failure that occurs *after* the browser flow was started
 * (i.e. `SSOManagerActivity` was created) as a user cancellation, and reports
 * a distinguishable `cancelled` status so the UI can close cleanly. Failures
 * that happen before the browser launches (e.g. network errors creating the
 * sign-in) are surfaced as real errors.
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

    /** Completes when the Clerk OAuth browser activity goes away (null = no auth in flight). */
    private var ssoDestroyed: CompletableDeferred<Unit>? = null

    /** Whether the Clerk OAuth browser activity was seen during this attempt. */
    private var ssoActivitySeen = false

    private val activityLifecycleCallbacks =
        object : Application.ActivityLifecycleCallbacks {
            override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) {
                if (activity.javaClass.name == SSO_MANAGER_ACTIVITY_CLASS) {
                    ssoActivitySeen = true
                }
            }

            override fun onActivityDestroyed(activity: Activity) {
                if (activity.javaClass.name == SSO_MANAGER_ACTIVITY_CLASS) {
                    android.util.Log.i("ClerkBridge", "SSOManagerActivity destroyed")
                    ssoDestroyed?.complete(Unit)
                }
            }

            override fun onActivityStarted(activity: Activity) = Unit
            override fun onActivityResumed(activity: Activity) = Unit
            override fun onActivityPaused(activity: Activity) = Unit
            override fun onActivityStopped(activity: Activity) = Unit
            override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) = Unit
        }

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

        app.registerActivityLifecycleCallbacks(activityLifecycleCallbacks)

        combine(Clerk.isInitialized, Clerk.userFlow) { initialized, user ->
            emitState(
                initialized = initialized,
                signedIn = user != null,
                userId = user?.id,
                email = user?.primaryEmailAddress?.emailAddress,
                username = user?.username,
                imageUrl = user?.imageUrl,
                emailVerified =
                    user?.primaryEmailAddress?.verification?.status == Verification.Status.VERIFIED,
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
        emailVerified: Boolean =
            Clerk.userFlow.value?.primaryEmailAddress?.verification?.status ==
                Verification.Status.VERIFIED,
    ) {
        val state = mapOf(
            "initialized" to initialized,
            "signedIn" to signedIn,
            "userId" to (userId ?: ""),
            "email" to (email ?: ""),
            "username" to (username ?: ""),
            "imageUrl" to (imageUrl ?: ""),
            "emailVerified" to emailVerified,
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
                        "emailVerified" to
                            (Clerk.userFlow.value?.primaryEmailAddress?.verification?.status ==
                                Verification.Status.VERIFIED),
                    ),
                )
            }

            // Sign in with Google via the redirect-based OAuth flow. The Clerk
            // SDK opens a Chrome Custom Tab with Google's account chooser, waits
            // for the user to pick an account and complete the flow, then returns
            // here. New users are signed up automatically (Clerk's internal
            // sign-in -> sign-up transfer), existing users are signed in — either
            // way the active session is set by the SDK and the user state is
            // streamed back to Flutter over the EventChannel.
            //
            // When the user cancels (BACK / closing the Custom Tab), the SDK's
            // SSO flow resolves with a generic failure ("There is no account to
            // transfer") rather than a clean cancellation. We therefore treat
            // any failure that occurs *after* the browser flow started
            // (SSOManagerActivity was created) as a user cancellation and report
            // a distinct `cancelled` status, so the UI can close cleanly.
            "signInWithGoogle" -> {
                scope.launch {
                    // Fresh signal for this attempt. It completes when the Clerk
                    // OAuth browser activity (SSOManagerActivity) is destroyed.
                    val destroyed = CompletableDeferred<Unit>()
                    ssoDestroyed = destroyed
                    ssoActivitySeen = false
                    val authDeferred = async {
                        Clerk.auth.signInWithOAuth(OAuthProvider.GOOGLE)
                    }
                    val first =
                        select<OAuthOutcome> {
                            authDeferred.onAwait { result ->
                                when (result) {
                                    is com.clerk.api.network.serialization.ClerkResult.Success ->
                                        OAuthOutcome.Success
                                    is com.clerk.api.network.serialization.ClerkResult.Failure ->
                                        OAuthOutcome.Failure(result.errorMessage)
                                }
                            }
                            destroyed.onAwait { OAuthOutcome.Cancelled }
                        }
                    ssoDestroyed = null
                    when (first) {
                        is OAuthOutcome.Success -> {
                            android.util.Log.i("ClerkBridge", "signInWithGoogle success")
                            result.success(mapOf("status" to "success"))
                        }
                        is OAuthOutcome.Cancelled -> {
                            android.util.Log.i("ClerkBridge", "signInWithGoogle cancelled")
                            // The SDK's SSO deferred never completes on this path;
                            // stop the awaiting coroutine so it does not leak.
                            authDeferred.cancel()
                            result.success(mapOf("status" to "cancelled"))
                        }
                        is OAuthOutcome.Failure -> {
                            // A failure is ambiguous:
                            //  - The browser flow started (SSOManagerActivity was
                            //    created) and the user backed out / closed the
                            //    Custom Tab. The SDK then resolves with its opaque
                            //    "There is no account to transfer" proxy error.
                            //    Report it as a user cancellation.
                            //  - The failure happened before the browser launched
                            //    (no SSOManagerActivity was ever created), e.g. a
                            //    network error while creating the sign-in. Surface
                            //    the real error.
                            if (ssoActivitySeen) {
                                android.util.Log.i("ClerkBridge", "signInWithGoogle cancelled")
                                authDeferred.cancel()
                                result.success(mapOf("status" to "cancelled"))
                            } else {
                                android.util.Log.i("ClerkBridge", "signInWithGoogle failure: ${first.error}")
                                result.success(mapOf("status" to "error", "error" to first.error))
                            }
                        }
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

    /** Distinguishes the OAuth flow outcomes reported back to Flutter. */
    private sealed interface OAuthOutcome {
        data object Success : OAuthOutcome

        data class Failure(val error: String) : OAuthOutcome

        data object Cancelled : OAuthOutcome
    }

    fun destroy() {
        app.unregisterActivityLifecycleCallbacks(activityLifecycleCallbacks)
        scope.cancel()
        methodChannel.setMethodCallHandler(null)
    }

    companion object {
        const val CHANNEL_METHODS = "com.soulfulbhakti.app/clerk"
        const val CHANNEL_EVENTS = "com.soulfulbhakti.app/clerk/events"

        /** Clerk SDK's OAuth browser activity, observed for cancellation. */
        private const val SSO_MANAGER_ACTIVITY_CLASS = "com.clerk.api.sso.SSOManagerActivity"
    }
}
