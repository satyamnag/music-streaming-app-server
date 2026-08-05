package com.sangeet.app

import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity: AudioServiceActivity() {
    private var clerkBridge: ClerkBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        clerkBridge = ClerkBridge(flutterEngine, application as SoulfulBhaktiApp)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        clerkBridge?.destroy()
        clerkBridge = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
