import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sangeet/provider/auth/clerk_auth_provider.dart';
import 'package:sangeet/services/audio_player/audio_player.dart';
import 'package:sangeet/services/dio/dio.dart';
import 'package:sangeet/services/kv_store/kv_store.dart';

/// Affiliate coupon redemption state for the signed-in user.
///
/// Coupons are attribution-only codes issued to external affiliates. A
/// signed-in user enters a code once in the app; the server records the
/// attribution and the affiliate earns a commission on the user's later paid
/// subscription (credited from verified Superwall webhooks, never from the
/// client). Redemption is immutable: one code per user, applied at most once.
class CouponState {
  final String? code;
  final String? affiliateName;
  final bool redeemed;
  final bool loading;

  const CouponState({
    this.code,
    this.affiliateName,
    this.redeemed = false,
    this.loading = false,
  });

  factory CouponState.fromJson(Map<String, dynamic> json) {
    return CouponState(
      code: (json['code'] as String?)?.isNotEmpty == true
          ? json['code'] as String
          : null,
      affiliateName: (json['affiliateName'] as String?)?.isNotEmpty == true
          ? json['affiliateName'] as String
          : null,
      redeemed: json['redeemed'] == true,
    );
  }
}

/// Key under which the redeemed coupon is stored once applied.
const kRedeemedCouponKey = 'redeemedCoupon';

class CouponNotifier extends AsyncNotifier<CouponState> {
  static const _methodBase = '/supabase/coupons';

  @override
  Future<CouponState> build() async {
    // Only signed-in users can redeem a coupon.
    final auth = ref.watch(clerkAuthProvider).valueOrNull;
    final userId = (auth != null && auth.signedIn) ? auth.userId : null;
    if (userId == null) {
      return const CouponState();
    }

    // Restore a previously redeemed coupon from local storage.
    final saved = _loadSavedCoupon();
    if (saved != null) {
      ref.keepAlive();
      return saved;
    }
    return const CouponState();
  }

  /// Validates a coupon code without redeeming it. Returns the affiliate
  /// display name on success, or throws with a friendly message.
  Future<String?> validate(String code) async {
    await SangeetMedia.ensurePortReady();
    final port = SangeetMedia.serverPort;
    final response = await globalDio.post(
      'http://127.0.0.1:$port$_methodBase/validate',
      data: {'code': code},
      options: Options(
        validateStatus: (status) => status != null && status < 500,
        headers: {'content-type': 'application/json'},
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Could not validate the coupon. Try again in a moment.');
    }
    final data = response.data as Map<String, dynamic>;
    if (data['valid'] != true) {
      throw Exception('That coupon code is not valid.');
    }
    return data['affiliateName'] as String?;
  }

  /// Redeems a coupon code for the signed-in user. Returns a human-readable
  /// message describing the outcome.
  Future<String> redeem(String code) async {
    final auth = ref.read(clerkAuthProvider).valueOrNull;
    final userId = (auth != null && auth.signedIn) ? auth.userId : null;
    if (userId == null) {
      throw Exception('Please sign in before applying a coupon.');
    }

    final affiliateName = await validate(code);
    state = const AsyncData(
      CouponState(loading: true),
    );

    await SangeetMedia.ensurePortReady();
    final port = SangeetMedia.serverPort;
    final response = await globalDio.post(
      'http://127.0.0.1:$port$_methodBase/redeem',
      data: {'code': code, 'user_id': userId},
      options: Options(
        validateStatus: (status) => status != null && status < 500,
        headers: {'content-type': 'application/json'},
      ),
    );
    if (response.statusCode != 200) {
      state = const AsyncData(CouponState());
      throw Exception('Could not apply the coupon. Try again in a moment.');
    }
    final status = (response.data as Map<String, dynamic>)['status'] as String?;

    switch (status) {
      case 'redeemed':
        final applied = CouponState(
          code: code,
          affiliateName: affiliateName,
          redeemed: true,
        );
        _saveCoupon(applied);
        state = AsyncData(applied);
        return affiliateName != null
            ? 'Coupon applied — you are now supporting $affiliateName.'
            : 'Coupon applied.';
      case 'already_redeemed':
        final saved = _loadSavedCoupon();
        state = AsyncData(saved ?? const CouponState());
        return 'You have already applied a coupon.';
      default:
        state = const AsyncData(CouponState());
        return 'That coupon could not be applied.';
    }
  }

  CouponState? _loadSavedCoupon() {
    final raw = KVStoreService.sharedPreferences.getString(kRedeemedCouponKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return CouponState.fromJson(
        Map<String, dynamic>.from(
          (raw as Object?) is Map ? raw as Map : const {},
        ),
      );
    } catch (_) {
      return null;
    }
  }

  void _saveCoupon(CouponState coupon) {
    KVStoreService.sharedPreferences.setString(
      kRedeemedCouponKey,
      _couponToJson(coupon),
    );
  }

  String _couponToJson(CouponState coupon) {
    final map = <String, dynamic>{
      'code': coupon.code,
      'affiliateName': coupon.affiliateName,
      'redeemed': coupon.redeemed,
    };
    return const JsonEncoder().convert(map);
  }
}

final couponProvider = AsyncNotifierProvider<CouponNotifier, CouponState>(
  CouponNotifier.new,
);
