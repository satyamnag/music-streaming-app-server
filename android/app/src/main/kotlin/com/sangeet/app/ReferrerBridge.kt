package com.sangeet.app

import android.content.Context
import android.os.RemoteException
import com.android.installreferrer.api.InstallReferrerClient
import com.android.installreferrer.api.InstallReferrerStateListener
import io.flutter.plugin.common.MethodChannel

/**
 * Reads the Google Play Install Referrer once on first launch and hands the
 * parsed affiliate referrer code to Flutter.
 *
 * The affiliate QR deep link encodes:
 *   https://play.google.com/store/apps/details?id=com.soulfulbhakti.app
 *       &referrer=utm_source=<REFERRER_CODE>
 *
 * On a fresh install the Play Store returns the referrer string via the
 * official Install Referrer API (https://developer.android.com/google/play/installreferrer).
 * We parse the `utm_source` value (the affiliate's referrer code) and expose
 * it to Flutter so it can bind the user to the affiliate at first sign-in.
 *
 * The referrer is only available for a limited window after install (90 days
 * per Google) and is read exactly once on first launch.
 */
class ReferrerBridge(private val context: Context) {

    /**
     * Queries the install referrer and calls [onResult] with the parsed
     * `utm_source` value, or null if there is no affiliate referrer (or the
     * API is unavailable, e.g. no Play Store).
     */
    fun readReferrer(onResult: (String?) -> Unit) {
        val client = InstallReferrerClient.newBuilder(context).build()
        val listener = object : InstallReferrerStateListener {
            override fun onInstallReferrerSetupFinished(responseCode: Int) {
                when (responseCode) {
                    InstallReferrerClient.InstallReferrerResponse.OK -> {
                        try {
                            val details = client.installReferrer
                            val referrer = details?.installReferrer.orEmpty()
                            client.endConnection()
                            onResult(parseUtmSource(referrer))
                        } catch (e: RemoteException) {
                            try { client.endConnection() } catch (_: Exception) {}
                            onResult(null)
                        }
                    }
                    else -> {
                        // Not available: no Play Store, referrer not set, or
                        // the 90-day window has elapsed. Not an error.
                        try { client.endConnection() } catch (_: Exception) {}
                        onResult(null)
                    }
                }
            }

            override fun onInstallReferrerServiceDisconnected() {
                onResult(null)
            }
        }
        client.startConnection(listener)
    }

    /**
     * Extracts the `utm_source` parameter from an install-referrer string.
     * Handles both URL-encoded and raw forms, e.g.:
     *   "utm_source=YT-CHANNEL1"      -> "YT-CHANNEL1"
     *   "utm_source=YT-CHANNEL1&utm_campaign=x"
     */
    private fun parseUtmSource(referrer: String): String? {
        if (referrer.isEmpty()) return null
        val decoded = android.net.Uri.decode(referrer)
        // Split on & (the referrer is form-encoded query-ish text, not a full URL)
        for (pair in decoded.split('&')) {
            val parts = pair.split('=', limit = 2)
            if (parts.size == 2 && parts[0].trim() == "utm_source") {
                val value = parts[1].trim()
                return if (value.isEmpty()) null else value
            }
        }
        return null
    }

    companion object {
        const val CHANNEL_REFERRER = "com.soulfulbhakti.app/install_referrer"

        /** Registers the method channel handler on [channel]. */
        fun register(channel: MethodChannel, context: Context) {
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "getReferrerCode" -> {
                        val bridge = ReferrerBridge(context)
                        bridge.readReferrer { code ->
                            result.success(code)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }
}
