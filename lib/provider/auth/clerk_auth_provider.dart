import 'dart:async';

import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sangeet/collections/env.dart';
import 'package:sangeet/provider/database/database.dart';
import 'package:sangeet/services/install_referrer/referrer_service.dart';
import 'package:sangeet/services/kv_store/kv_store.dart';
import 'package:sangeet/services/onesignal_service.dart';
import 'package:sangeet/services/superwall_service.dart';

/// Flutter-side bridge to the Clerk Android SDK (Native API).
///
/// Mirrors the native auth state by listening to the EventChannel emitted from
/// [ClerkBridge] (Kotlin). Auth is Google-only: sign-in delegates to the native
/// Clerk OAuth flow, and on success the updated state (including the signed-in
/// email and its verification status) is streamed back here.
class ClerkAuthState {
  final bool initialized;
  final bool signedIn;
  final String? userId;

  final String? email;
  final String? username;
  final String? imageUrl;
  final bool emailVerified;

  const ClerkAuthState({
    this.initialized = false,
    this.signedIn = false,
    this.userId,
    this.email,
    this.username,
    this.imageUrl,
    this.emailVerified = false,
  });

  factory ClerkAuthState.fromMap(Map<Object?, Object?> map) {
    return ClerkAuthState(
      initialized: map['initialized'] == true,
      signedIn: map['signedIn'] == true,
      userId: (map['userId'] as String?)?.isNotEmpty == true
          ? map['userId'] as String
          : null,
      email: (map['email'] as String?)?.isNotEmpty == true
          ? map['email'] as String
          : null,
      username: (map['username'] as String?)?.isNotEmpty == true
          ? map['username'] as String
          : null,
      imageUrl: (map['imageUrl'] as String?)?.isNotEmpty == true
          ? map['imageUrl'] as String
          : null,
      emailVerified: map['emailVerified'] == true,
    );
  }
}

class ClerkAuthNotifier extends AsyncNotifier<ClerkAuthState> {
  static const _methodChannel = MethodChannel('com.soulfulbhakti.app/clerk');
  static const _eventChannel =
      EventChannel('com.soulfulbhakti.app/clerk/events');

  StreamSubscription<Object?>? _subscription;

  @override
  Future<ClerkAuthState> build() async {
    _subscription = _eventChannel
        .receiveBroadcastStream()
        .map((event) => ClerkAuthState.fromMap(event as Map))
        .listen((newState) {
      state = AsyncData(newState);
      _syncThirdPartyIdentity(newState);
    });

    ref.onDispose(() => _subscription?.cancel());

    // Hand the publishable key (from .env) to the native Clerk SDK before
    // querying state, so initialization uses the configured key.
    await _methodChannel.invokeMethod<Map<Object?, Object?>>(
      'setPublishableKey',
      {'publishableKey': Env.clerkPublishableKey},
    );

    final current =
        await _methodChannel.invokeMethod<Map<Object?, Object?>>('getState');
    final initialState = ClerkAuthState.fromMap(current ?? const {});
    _syncThirdPartyIdentity(initialState);
    return initialState;
  }

  /// Syncs the Clerk identity to third-party services:
  ///
  ///  - **Superwall**: `identify` on sign-in (stable Clerk user id), `reset` on
  ///    sign-out, plus a few user attributes for audience targeting.
  ///  - **OneSignal**: `login` on sign-in (transfers the device's push
  ///    subscription to the identified user, per the official guide),
  ///    `logout` on sign-out (reverts to a device-scoped user). The signed-in
  ///    email is attached to the identified user via `addEmail` **after**
  ///    `login`, so it lands on the identified user (per the guide, operations
  ///    done under the device-scoped user are lost on login).
  void _syncThirdPartyIdentity(ClerkAuthState authState) {
    final sw = SuperwallService.instance;
    final os = OneSignalService.instance;
    if (authState.signedIn && authState.userId != null) {
      sw.identify(authState.userId!);
      sw.setUserAttributes({
        'email': authState.email ?? '',
        'username': authState.username ?? '',
      });
      os.login(authState.userId!);
      final email = authState.email;
      if (email != null && email.isNotEmpty) {
        os.setEmail(email);
      }
      // Best-effort: bind the QR install-referrer code to this user (once).
      // Never blocks or disrupts sign-in.
      ReferrerService.instance.bindToSignedInUser(authState.userId!);
    } else if (!authState.signedIn) {
      sw.reset();
      os.logout();
    }
  }

  /// Signs in (or signs up) with Google.
  ///
  /// Delegates to the native Clerk SDK's redirect-based OAuth flow: Google's
  /// account chooser is presented, the user picks an account, and on success
  /// the session is set active natively. The updated auth state is streamed
  /// back through the EventChannel, so callers should invalidate
  /// [clerkAuthProvider] afterwards to reflect the new session.
  ///
  /// Returns an [AuthResult]:
  ///  - `success` — the user is signed in.
  ///  - `cancelled` — the user dismissed the Google flow (BACK / closed the
  ///    Custom Tab); no error to show, the dialog should just close.
  ///  - `failure(message)` — a real error occurred; surface `message`.
  Future<AuthResult> signInWithGoogle() async {
    final result = await _methodChannel.invokeMethod<Map<Object?, Object?>>(
      'signInWithGoogle',
    );
    final status = result?['status'] as String?;
    if (status == 'cancelled') return const AuthResult.cancelled();
    if (status == 'error') {
      return AuthResult.failure(result?['error'] as String? ?? 'Unknown error');
    }
    return const AuthResult.success();
  }

  Future<String?> signOut() async {
    final result = await _methodChannel.invokeMethod<Map<Object?, Object?>>(
      'signOut',
    );
    final status = result?['status'] as String?;
    if (status == 'error') return result?['error'] as String?;
    return null;
  }

  /// Permanently deletes the signed-in user's account (Clerk) and clears the
  /// user data associated with it, as required by the Google Play User Data
  /// policy (in-app account deletion).
  ///
  /// On success:
  ///  - the Clerk account is deleted natively (backend `DELETE /users/{id}`);
  ///  - local user data (playlists, playlist songs, liked songs, history) is
  ///    removed from the device database;
  ///  - device-scoped affiliate/referral keys are cleared;
  ///  - third-party identity (Superwall, OneSignal) is reset.
  ///
  /// Returns an error message on failure, or `null` on success.
  Future<String?> deleteAccount() async {
    final result = await _methodChannel.invokeMethod<Map<Object?, Object?>>(
      'deleteAccount',
    );
    final status = result?['status'] as String?;
    if (status == 'error') return result?['error'] as String?;

    // Best-effort cleanup: never block the successful deletion report on
    // local cleanup that might fail (e.g. a locked database).
    try {
      final db = ref.read(databaseProvider);
      await db.delete(db.localPlaylistsTable).go();
      await db.delete(db.localPlaylistSongsTable).go();
      await db.delete(db.localLikedSongsTable).go();
      await db.delete(db.historyTable).go();
    } catch (_) {
      // Local cleanup failure is non-fatal for account deletion.
    }

    // Clear device-scoped affiliate/referral attribution keys.
    try {
      final prefs = KVStoreService.sharedPreferences;
      await prefs.remove('affiliateReferrerCode');
      await prefs.remove('affiliateReferrerBound');
      await prefs.remove('isQRAttributed');
    } catch (_) {
      // Best-effort; ignore.
    }

    // Reset third-party identity and reflect the signed-out state.
    SuperwallService.instance.reset();
    OneSignalService.instance.logout();
    ref.invalidateSelf();

    return null;
  }
}

/// Outcome of a native Google sign-in attempt.
///
/// `cancelled` is distinct from a real failure: it means the user dismissed
/// the Google flow themselves, so no error message should be shown.
sealed class AuthResult {
  const AuthResult();

  const factory AuthResult.success() = AuthResultSuccess;

  const factory AuthResult.cancelled() = AuthResultCancelled;

  const factory AuthResult.failure(String message) = AuthResultFailure;
}

final class AuthResultSuccess extends AuthResult {
  const AuthResultSuccess();
}

final class AuthResultCancelled extends AuthResult {
  const AuthResultCancelled();
}

final class AuthResultFailure extends AuthResult {
  const AuthResultFailure(this.message);

  final String message;
}

final clerkAuthProvider =
    AsyncNotifierProvider<ClerkAuthNotifier, ClerkAuthState>(
  ClerkAuthNotifier.new,
);
