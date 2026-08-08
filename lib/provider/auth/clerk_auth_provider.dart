import 'dart:async';

import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sangeet/collections/env.dart';
import 'package:sangeet/services/superwall_service.dart';

/// Flutter-side bridge to the Clerk Android SDK (Native API).
///
/// Mirrors the native auth state by listening to the EventChannel emitted from
/// [ClerkBridge] (Kotlin), and exposes the passwordless **email OTP** flow plus
/// in-account email verification via the MethodChannel.
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

  /// True when the email is present and verified (or the user has no email).
  bool get allContactsVerified {
    if (!signedIn) return true;
    if (email == null) return true;
    return emailVerified;
  }

  ClerkAuthState copyWith({
    bool? initialized,
    bool? signedIn,
    String? userId,
    String? email,
    String? username,
    String? imageUrl,
    bool? emailVerified,
  }) {
    return ClerkAuthState(
      initialized: initialized ?? this.initialized,
      signedIn: signedIn ?? this.signedIn,
      userId: userId ?? this.userId,
      email: email ?? this.email,
      username: username ?? this.username,
      imageUrl: imageUrl ?? this.imageUrl,
      emailVerified: emailVerified ?? this.emailVerified,
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
      _syncSuperwallIdentity(newState);
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
    _syncSuperwallIdentity(initialState);
    return initialState;
  }

  /// Syncs the Clerk identity to Superwall: identifies the user on sign-in
  /// (using the stable Clerk user id) and resets on sign-out. Also records a
  /// few user attributes for audience targeting.
  void _syncSuperwallIdentity(ClerkAuthState authState) {
    final sw = SuperwallService.instance;
    if (authState.signedIn && authState.userId != null) {
      sw.identify(authState.userId!);
      sw.setUserAttributes({
        'email': authState.email ?? '',
        'username': authState.username ?? '',
      });
    } else if (!authState.signedIn) {
      sw.reset();
    }
  }

  /// Refreshes the email verification status of the signed-in user.
  Future<ClerkAuthState?> refreshVerificationStatus() async {
    final result =
        await _methodChannel.invokeMethod<Map<Object?, Object?>>(
      'getVerificationStatus',
    );
    if (result?['status'] == 'error') return null;
    final current = state.value ?? const ClerkAuthState();
    final rawEmail = result?['email'] as String?;
    final updated = current.copyWith(
      email: (rawEmail?.isNotEmpty ?? false) ? rawEmail : null,
      emailVerified: result?['emailVerified'] == true,
    );
    state = AsyncData(updated);
    return updated;
  }

  /// Sends a one-time code to the signed-in user's email.
  Future<String?> sendContactOtp({required String identifier}) async {
    final result = await _methodChannel.invokeMethod<Map<Object?, Object?>>(
      'sendContactOtp',
      {'identifier': identifier},
    );
    final status = result?['status'] as String?;
    if (status == 'error') return result?['error'] as String?;
    return null;
  }

  /// Verifies the one-time code for the signed-in user's email.
  Future<String?> verifyContactOtp({required String code}) async {
    final result = await _methodChannel.invokeMethod<Map<Object?, Object?>>(
      'verifyContactOtp',
      {'code': code},
    );
    final status = result?['status'] as String?;
    if (status == 'error') return result?['error'] as String?;
    return null;
  }

  /// Sends a one-time code to the given email address.
  Future<String?> sendOtp({
    required String identifier,
    String? firstName,
    String? lastName,
  }) async {
    final result = await _methodChannel.invokeMethod<Map<Object?, Object?>>(
      'sendOtp',
      {
        'identifier': identifier,
        if (firstName != null && firstName.isNotEmpty) 'firstName': firstName,
        if (lastName != null && lastName.isNotEmpty) 'lastName': lastName,
      },
    );
    final status = result?['status'] as String?;
    if (status == 'error') return result?['error'] as String?;
    return null;
  }

  /// Verifies the one-time [code] received on the email address.
  Future<String?> verifyOtp({required String code}) async {
    final result = await _methodChannel.invokeMethod<Map<Object?, Object?>>(
      'verifyOtp',
      {'code': code},
    );
    final status = result?['status'] as String?;
    if (status == 'error') return result?['error'] as String?;
    return null;
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

final clerkAuthProvider =
    AsyncNotifierProvider<ClerkAuthNotifier, ClerkAuthState>(
  ClerkAuthNotifier.new,
);
