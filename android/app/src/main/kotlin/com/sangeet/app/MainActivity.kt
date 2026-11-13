package com.sangeet.app

import android.os.Bundle
import androidx.core.view.WindowCompat
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: AudioServiceActivity() {
    private var clerkBridge: ClerkBridge? = null

    /**
     * Edge-to-edge, per Google's Play Console recommendation for apps targeting
     * SDK 35+ ("call enableEdgeToEdge() … for backward compatibility").
     *
     * `WindowCompat.enableEdgeToEdge(window)` is the current API: the older
     * `ComponentActivity.enableEdgeToEdge()` is deprecated in androidx.main and
     * is only available to ComponentActivity subclasses — this Activity extends
     * audio_service's `AudioServiceActivity`, which is a `FlutterActivity`, so
     * the Window-level call is the correct one here. It does exactly what the
     * platform does from Android 15 onwards:
     *
     *   - `setDecorFitsSystemWindows(window, false)` — the app owns the insets;
     *   - transparent status and navigation bars;
     *   - display-cutout mode ALWAYS (API 30+) / SHORT_EDGES (API 28-29);
     *   - system contrast enforcement off (API 29+).
     *
     * Called BEFORE `super.onCreate`, the order the AndroidX KDoc specifies: the
     * call forces the decor view to exist first so Flutter's later window setup
     * cannot overwrite these attributes.
     *
     * The Flutter side must therefore apply the insets itself, which it already
     * does: `lib/pages/root/root_app.dart` insets the whole app (SafeArea) and
     * every page keeps its own SafeArea for scrolling content.
     */
    override fun onCreate(savedInstanceState: Bundle?) {
        WindowCompat.enableEdgeToEdge(window)
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        clerkBridge = ClerkBridge(flutterEngine, application as SoulfulBhaktiApp)
        // Register the Google Play Install Referrer channel for affiliate QR
        // attribution. The referrer code read here is bound to the user at
        // first sign-in so the affiliate earns a commission on a later purchase.
        ReferrerBridge.register(
            MethodChannel(
                flutterEngine.dartExecutor.binaryMessenger,
                ReferrerBridge.CHANNEL_REFERRER,
            ),
            applicationContext,
        )
        // Ringtone channel: sets a downloaded MP3 as the device's ringtone,
        // notification sound or alarm. Requires the user to grant WRITE_SETTINGS.
        RingtoneBridge(this).register(
            MethodChannel(
                flutterEngine.dartExecutor.binaryMessenger,
                RingtoneBridge.CHANNEL,
            )
        )
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        clerkBridge?.destroy()
        clerkBridge = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
