import 'dart:async';

import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sangeet/collections/env.dart';
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
