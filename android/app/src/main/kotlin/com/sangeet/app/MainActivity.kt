package com.sangeet.app

import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: AudioServiceActivity() {
    private var clerkBridge: ClerkBridge? = null

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
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        clerkBridge?.destroy()
        clerkBridge = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
