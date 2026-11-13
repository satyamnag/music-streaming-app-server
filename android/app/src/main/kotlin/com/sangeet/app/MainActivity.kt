package com.sangeet.app

import android.os.Build
import android.os.Bundle
import androidx.core.view.WindowCompat
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: AudioServiceActivity() {
    private var clerkBridge: ClerkBridge? = null

    /**
     * Edge-to-edge, version-guarded so the deprecated window APIs are only ever
     * reached on Android versions where they are NOT deprecated.
     *
     * The two Play advisories pull against each other:
     *
     *   1. "Edge-to-edge may not display for all users … call enableEdgeToEdge()";
     *   2. "deprecated APIs … Window.setStatusBarColor, setNavigationBarColor,
     *      LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES".
     *
     * `enableEdgeToEdge()` IS made of the APIs (2) reports, but those APIs were
     * deprecated *in Android 15 / API 35* — below 35 they are still the only way
     * to make the system bars transparent. So:
     *
     *   - API < 35: call the helper. It is the documented path (advisory 1) and
     *     the calls it makes are not deprecated here;
     *   - API >= 35: call NOTHING. The platform enforces edge-to-edge itself and
     *     the setters are disabled no-ops, so anything we called would be dead
     *     code.
     *
     * Supplying no bar colours from Flutter (`SystemChrome.setSystemUIOverlayStyle`
     * in `lib/pages/root/root_app.dart` sends only the icon brightness) keeps the
     * transparent bars the helper set, and the root `SafeArea(top: true,
     * bottom: true)` consumes both insets.
     *
     * The display-cutout mode is the theme's job:
     * `windowLayoutInDisplayCutoutMode=always` in res/values styles (and the
     * night / v31 variants) — what Android 15 requires of non-floating windows,
     * instead of the deprecated `shortEdges`.
     */
    override fun onCreate(savedInstanceState: Bundle?) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.VANILLA_ICE_CREAM) {
            WindowCompat.enableEdgeToEdge(window)
        }
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
