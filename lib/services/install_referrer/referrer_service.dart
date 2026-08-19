import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sangeet/provider/auth/clerk_auth_provider.dart';
import 'package:sangeet/services/audio_player/audio_player.dart';
import 'package:sangeet/services/dio/dio.dart';
import 'package:sangeet/services/kv_store/kv_store.dart';
import 'package:sangeet/services/superwall_service.dart';

/// Google Play Install Referrer channel name (must match MainActivity).
const kInstallReferrerChannel = 'com.soulfulbhakti.app/install_referrer';

/// Key under which the affiliate referrer code is stored once read.
const kReferrerCodeKey = 'affiliateReferrerCode';

/// Key tracking whether the referrer code has already been bound to a user.
const kReferrerBoundKey = 'affiliateReferrerBound';

/// Key tracking whether this user is QR-affiliate-attributed (server-confirmed).
/// Persisted so the Superwall discount attribute survives app restarts.
const kIsQRAttributedKey = 'isQRAttributed';

/// Google Play Install Referrer -> affiliate attribution.
///
/// The affiliate QR deep link encodes `utm_source=<REFERRER_CODE>`. On a fresh
/// install the native [kInstallReferrerChannel] returns that code once. This
/// service:
///  1. Reads the code (first launch), stores it locally, and marks it "read".
///  2. Provides [bindToSignedInUser] which, when a user signs in and a code is
///     pending, calls the local server route that invokes the Supabase
///     `bind_affiliate_referral` RPC. Binding is immutable (once per user).
///
/// Attribution is attribution-only (no price change) and fully Google Play
/// compliant, mirroring the coupon program.
class ReferrerService {
  ReferrerService._();

  static final ReferrerService instance = ReferrerService._();

  static const _channel = MethodChannel(kInstallReferrerChannel);

  bool _readAttempted = false;

  /// Reads the install referrer (once, on first launch). If a `utm_source`
  /// affiliate code is present it is persisted so it can be bound after the
  /// user signs in. Safe to call multiple times; the native read happens once.
  Future<String?> readReferrer() async {
    if (_readAttempted) return _loadCode();
    _readAttempted = true;
    // The referrer is only available once shortly after install; never read it
    // again once we have already stored a code (immutable per install).
    final existing = _loadCode();
    if (existing != null) return existing;
    try {
      final code = await _channel.invokeMethod<String>('getReferrerCode');
      if (code != null && code.isNotEmpty) {
        await KVStoreService.sharedPreferences.setString(kReferrerCodeKey, code);
        return code;
      }
    } catch (_) {
      // Native channel unavailable (non-Android, or bridge not ready). Ignore.
    }
    return null;
  }

  String? _loadCode() {
    final raw =
        KVStoreService.sharedPreferences.getString(kReferrerCodeKey) ?? '';
    return raw.isEmpty ? null : raw;
  }

  bool get hasPendingCode =>
      _loadCode() != null &&
      !(KVStoreService.sharedPreferences.getBool(kReferrerBoundKey) ?? false);

  /// Binds the stored referrer code to the signed-in [userId] (called after
  /// sign-in). One-time per install: after a successful (or already-bound)
  /// response we mark it bound so it is never re-sent. Failures are silent so
  /// they never disrupt the user.
  Future<void> bindToSignedInUser(String userId) async {
    if (!hasPendingCode) return;
    final code = _loadCode();
    if (code == null) return;
    try {
      await SangeetMedia.ensurePortReady();
      final port = SangeetMedia.serverPort;
      final response = await globalDio.post(
        'http://127.0.0.1:$port/supabase/referrers/bind',
        data: {'referrer_code': code, 'user_id': userId},
        options: Options(
          validateStatus: (status) => status != null && status < 500,
          headers: {'content-type': 'application/json'},
        ),
      );
      if (response.statusCode == 200) {
        final status =
            (response.data as Map<String, dynamic>?)?['status'] as String?;
        // A user is QR-attributed when the server confirms a binding: `bound`
        // (fresh) or `already_bound` (from a prior session). Only `invalid`
        // means no affiliate attribution.
        final attributed =
            status == 'bound' || status == 'already_bound';
        await KVStoreService.sharedPreferences.setBool(
            kReferrerBoundKey, true);
        if (attributed) {
          await _markQRAttributed();
        }
      }
    } catch (_) {
      // Never disrupt sign-in over a best-effort referral attribution.
    }
  }

  /// Persists the QR-attribution flag and tells Superwall the user is
  /// affiliate-attributed so its dashboard audience can present the discounted
  /// yearly offer. Best-effort; never throws.
  Future<void> _markQRAttributed() async {
    await KVStoreService.sharedPreferences.setBool(kIsQRAttributedKey, true);
    try {
      await SuperwallService.instance
          .setUserAttributes({'has_affiliate_discount': true});
    } catch (_) {
      // Ignore: Superwall may not be configured yet (e.g. key absent).
    }
  }

  /// True when this user has a server-confirmed QR-affiliate attribution.
  bool get isQRAttributed =>
      KVStoreService.sharedPreferences.getBool(kIsQRAttributedKey) ?? false;

  /// Re-syncs the Superwall discount attribute for a user who was QR-attributed
  /// in a prior session (e.g. after re-login / app restart). Best-effort.
  Future<void> syncAffiliateAttribute() async {
    if (!isQRAttributed) return;
    try {
      await SuperwallService.instance
          .setUserAttributes({'has_affiliate_discount': true});
    } catch (_) {
      // Ignore: Superwall not configured.
    }
  }

  /// Convenience for Riverpod consumers: reads + binds if signed in.
  Future<void> init(Ref ref) async {
    await readReferrer();
    final auth = ref.read(clerkAuthProvider).valueOrNull;
    if (auth != null && auth.signedIn && auth.userId != null) {
      await bindToSignedInUser(auth.userId!);
    }
    // Restore the Superwall discount attribute for users attributed in a
    // prior session (e.g. after re-login or app restart).
    await syncAffiliateAttribute();
  }
}

final referrerProvider = Provider<ReferrerService>((ref) {
  final service = ReferrerService.instance;
  // Kick off read + bind-on-sign-in.
  service.init(ref);
  return service;
});
