package com.sangeet.app

import android.util.Log
import com.clerk.api.Clerk
import io.flutter.app.FlutterApplication

/**
 * Application entry point.
 *
 * Extends [FlutterApplication] so the Flutter engine initializes normally.
 * The Clerk Android SDK (Native API) is initialized here with the Publishable
 * Key supplied via BuildConfig, following the official Clerk Android pattern:
 * initialize once in Application.onCreate() with an Application context.
 *
 * The SDK stores the context internally as a WeakReference to the
 * applicationContext, so Application context is the officially recommended
 * (and memory-safe) choice — see clerk/clerk-android quickstart.
 */
class SoulfulBhaktiApp : FlutterApplication() {
    private var clerkInitialized = false

    override fun onCreate() {
        super.onCreate()
        val key = BuildConfig.CLERK_PUBLISHABLE_KEY
        if (key.isNotBlank()) {
            clerkInitialized = true
            Clerk.initialize(this, publishableKey = key)
            Log.i("SoulfulBhaktiApp", "Clerk initialized in Application.onCreate()")
        } else {
            Log.w("SoulfulBhaktiApp", "CLERK_PUBLISHABLE_KEY is blank — Clerk not initialized")
        }
    }

    /**
     * Called from ClerkBridge when Flutter sends the publishable key.
     * Safe to call multiple times: only the first non-blank call actually
     * initializes (but since onCreate already did it, this is normally a no-op).
     */
    @Synchronized
    fun ensureClerkInitialized(publishableKey: String) {
        if (clerkInitialized || publishableKey.isBlank()) return
        clerkInitialized = true
        Clerk.initialize(this, publishableKey = publishableKey)
    }
}
