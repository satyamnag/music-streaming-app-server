package com.sangeet.app

import android.app.Activity
import android.content.ContentValues
import android.content.Intent
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.provider.Settings
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.net.HttpURLConnection
import java.net.URL

/**
 * Sets a downloaded MP3 as the device ringtone, notification sound or alarm.
 *
 * Two Android constraints shape this bridge:
 *
 *  1. `WRITE_SETTINGS` is a **special** permission. Apps targeting API 23+ must
 *     have the user grant it through the system screen
 *     (`Settings.ACTION_MANAGE_WRITE_SETTINGS`); it is not a runtime prompt.
 *     We check `Settings.System.canWrite()` first and only launch the screen
 *     when it is genuinely needed.
 *
 *  2. The sound must be reachable as a `content://` URI, so the MP3 is copied
 *     into the shared MediaStore (Ringtones collection) before being set.
 *     `RingtoneManager` cannot reference an app-private file path.
 *
 * Ringtones are MP3 only: Android's `RingtoneManager` does not accept `.opus`,
 * which is why a track carries a separate ringtone file.
 */
class RingtoneBridge(
    private val activity: Activity,
    private val scope: CoroutineScope = CoroutineScope(Dispatchers.Main),
) {
    companion object {
        const val CHANNEL = "com.soulfulbhakti.app/ringtone"
    }

    fun register(channel: MethodChannel) {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "canWrite" -> result.success(Settings.System.canWrite(activity))

                "requestWrite" -> {
                    try {
                        val intent = Intent(
                            Settings.ACTION_MANAGE_WRITE_SETTINGS,
                            Uri.parse("package:" + activity.packageName),
                        )
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        activity.startActivity(intent)
                        result.success(true)
                    } catch (t: Throwable) {
                        // Some OEM builds do not expose this screen; report the
                        // failure instead of crashing the player.
                        result.error("no_settings_screen", t.message, null)
                    }
                }

                "setRingtone" -> {
                    val url = call.argument<String>("url")
                    val type = call.argument<String>("type") ?: "ringtone"
                    if (url.isNullOrBlank()) {
                        result.error("bad_args", "url is required", null)
                        return@setMethodCallHandler
                    }
                    // Network + disk work must not block the platform thread.
                    scope.launch {
                        val ok = withContext(Dispatchers.IO) { applyRingtone(url, type) }
                        result.success(ok)
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    /** Returns true only when the sound was actually set. */
    private fun applyRingtone(url: String, type: String): Boolean {
        if (!Settings.System.canWrite(activity)) return false
        return try {
            val contentUri = downloadToMediaStore(url) ?: return false
            val ringtoneType = when (type) {
                "notification" -> RingtoneManager.TYPE_NOTIFICATION
                "alarm" -> RingtoneManager.TYPE_ALARM
                else -> RingtoneManager.TYPE_RINGTONE
            }
            RingtoneManager.setActualDefaultRingtoneUri(activity, ringtoneType, contentUri)
            true
        } catch (t: Throwable) {
            false
        }
    }

    /** Downloads [url] into the shared MediaStore and returns its content URI. */
    private fun downloadToMediaStore(url: String): Uri? {
        val connection = (URL(url).openConnection() as HttpURLConnection).apply {
            connectTimeout = 15_000
            readTimeout = 30_000
            instanceFollowRedirects = true
        }
        connection.connect()
        if (connection.responseCode !in 200..299) {
            connection.disconnect()
            return null
        }

        val displayName = "soulfulbhakti-ringtone-${System.currentTimeMillis()}.mp3"
        val values = ContentValues().apply {
            put(MediaStore.Audio.Media.DISPLAY_NAME, displayName)
            put(MediaStore.Audio.Media.MIME_TYPE, "audio/mpeg")
            put(MediaStore.Audio.Media.IS_RINGTONE, true)
            put(MediaStore.Audio.Media.IS_NOTIFICATION, true)
            put(MediaStore.Audio.Media.IS_ALARM, true)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                put(MediaStore.Audio.Media.RELATIVE_PATH, Environment.DIRECTORY_RINGTONES)
            }
        }

        val resolver = activity.contentResolver
        val collection = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            MediaStore.Audio.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        } else {
            MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
        }

        val uri = resolver.insert(collection, values)
        if (uri == null) {
            connection.disconnect()
            return null
        }

        try {
            val out = resolver.openOutputStream(uri)
            if (out == null) {
                resolver.delete(uri, null, null)
                connection.disconnect()
                return null
            }
            out.use { sink -> connection.inputStream.use { it.copyTo(sink) } }
        } catch (t: Throwable) {
            // A partial file would be unusable as a ringtone; remove it.
            resolver.delete(uri, null, null)
            connection.disconnect()
            return null
        }
        connection.disconnect()
        return uri
    }
}
