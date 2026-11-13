package com.sangeet.app

import android.os.Bundle
import androidx.core.view.WindowCompat
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: AudioServiceActivity() {
    private var clerkBridge: ClerkBridge? = null

    /**
     * Edge-to-edge, without the APIs Android 15 deprecates.
     *
     * Play's first advisory asked for `enableEdgeToEdge()`; its second reports
     * that this very helper calls `Window#setStatusBarColor`,
     * `Window#setNavigationBarColor` and `LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES`
     * — all deprecated for apps targeting 35+
     * (https://developer.android.com/about/versions/15/behavior-changes-15#edge-to-edge).
     * So the helper is replaced by the one call it makes that is NOT flagged and
     * is still meaningful before Android 15:
     *
     *   - `WindowCompat.setDecorFitsSystemWindows(window, false)` — the app owns
     *     the insets, i.e. edge-to-edge, on every API level;
     *   - no `setStatusBarColor` / `setNavigationBarColor`: on Android 15+ the
     *     platform makes both bars transparent and the setters are no-ops, and
     *     below 15 the theme's window background shows through, which is what the
     *     app looked like before — nothing to set;
     *   - no cutout-mode juggling here: the theme declares
     *     `windowLayoutInDisplayCutoutMode=always` in the res/values styles
     *     (and its night / v31 variants), the mode Android 15 requires for
     *     non-floating windows, instead of the deprecated `shortEdges`.
     *
     * The Flutter side applies the insets: `lib/pages/root/root_app.dart` wraps
     * the app in a `SafeArea(top: true, bottom: true)`.
     */
    override fun onCreate(savedInstanceState: Bundle?) {
        WindowCompat.setDecorFitsSystemWindows(window, false)
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
