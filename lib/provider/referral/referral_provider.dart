import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sangeet/provider/auth/clerk_auth_provider.dart';
import 'package:sangeet/services/audio_player/audio_player.dart';
import 'package:sangeet/services/dio/dio.dart';
import 'package:sangeet/services/kv_store/kv_store.dart';

/// Referral / affiliate program state for the signed-in user.
///
///  - [code]: the user's un-guessable referral code (created server-side).
///  - [referralCount]: number of people who signed up via the user's code.
///  - [pendingAmount] / [creditedAmount] / [totalAmount]: tracked commission
///    (₹). Payout rails are intentionally not implemented yet — amounts are
///    recorded server-side only, from verified Superwall webhooks.
class ReferralState {
  final String? code;
  final int referralCount;
  final double pendingAmount;
  final double creditedAmount;
  final double totalAmount;

  const ReferralState({
    this.code,
    this.referralCount = 0,
    this.pendingAmount = 0,
    this.creditedAmount = 0,
    this.totalAmount = 0,
  });

  factory ReferralState.fromJson(Map<String, dynamic> json) {
    return ReferralState(
      code: (json['code'] as String?)?.isNotEmpty == true
          ? json['code'] as String
          : null,
      referralCount: (json['referralCount'] as num?)?.toInt() ?? 0,
      pendingAmount: (json['pendingAmount'] as num?)?.toDouble() ?? 0,
      creditedAmount: (json['creditedAmount'] as num?)?.toDouble() ?? 0,
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Key under which a pending referral code (from an opened deep link) is
/// stored until the user signs in.
const kPendingReferralCodeKey = 'pendingReferralCode';

class ReferralNotifier extends AsyncNotifier<ReferralState> {
  static const _methodBase = '/supabase/referrals';

  @override
  Future<ReferralState> build() async {
    // Only signed-in users have a referral code.
    final auth = ref.watch(clerkAuthProvider).valueOrNull;
    final userId = (auth != null && auth.signedIn) ? auth.userId : null;
    if (userId == null) {
      return const ReferralState();
    }

    // Attribute the user to a referrer on their FIRST sign-in with a code
    // opened from a shared link (e.g. on a fresh install).
    await _attributePendingReferral(userId);

    final summary = await _fetchSummary(userId);
    ref.keepAlive();
    return summary;
  }

  /// If a referral code was captured from a deep link and not yet applied,
  /// record the attribution server-side and clear the pending value.
  Future<void> _attributePendingReferral(String userId) async {
    final code =
        KVStoreService.sharedPreferences.getString(kPendingReferralCodeKey);
    if (code == null || code.isEmpty) return;

    final alreadyAttributed =
        KVStoreService.sharedPreferences.getBool('referralAttributed_$userId');
    if (alreadyAttributed == true) return;

    await SangeetMedia.ensurePortReady();
    final port = SangeetMedia.serverPort;
    await globalDio.post(
      'http://127.0.0.1:$port$_methodBase/attribute',
      data: {'code': code, 'referred_user_id': userId},
      options: Options(
        validateStatus: (status) => status != null && status < 500,
        headers: {'content-type': 'application/json'},
      ),
    );

    // Mark attributed so we never re-attribute this user, then clear the
    // pending code. Server enforces single-attribution regardless.
    await KVStoreService.sharedPreferences
        .setBool('referralAttributed_$userId', true);
    await KVStoreService.sharedPreferences.remove(kPendingReferralCodeKey);
  }

  Future<ReferralState> _fetchSummary(String userId) async {
    try {
      await SangeetMedia.ensurePortReady();
      final port = SangeetMedia.serverPort;
      final response = await globalDio.get(
        'http://127.0.0.1:$port$_methodBase/$userId/summary',
        options: Options(
          validateStatus: (status) => status != null && status < 500,
          headers: {'accept': 'application/json'},
        ),
      );
      if (response.statusCode != 200) return const ReferralState();
      final data = response.data as Map<String, dynamic>;
      return ReferralState.fromJson(data);
    } catch (_) {
      return const ReferralState();
    }
  }

  /// Re-reads the earnings summary (call after a purchase or on refresh).
  Future<void> refresh() async {
    final auth = ref.read(clerkAuthProvider).valueOrNull;
    final userId = (auth != null && auth.signedIn) ? auth.userId : null;
    if (userId == null) {
      state = const AsyncData(ReferralState());
      return;
    }
    state = const AsyncLoading();
    state = AsyncData(await _fetchSummary(userId));
  }

  /// Explicitly stores a referral code captured from a shared deep link. The
  /// code is applied the next time a signed-in user's state is built.
  static Future<void> storePendingReferralCode(String code) {
    return KVStoreService.sharedPreferences
        .setString(kPendingReferralCodeKey, code);
  }

  static String? get pendingReferralCode =>
      KVStoreService.sharedPreferences.getString(kPendingReferralCodeKey);
}

final referralProvider = AsyncNotifierProvider<ReferralNotifier, ReferralState>(
  ReferralNotifier.new,
);

/// Returns a shareable deep link for the given referral code. Uses the app's
/// custom scheme (`sangeet://`), which the Android manifest declares for the
/// main activity, so opening the link launches the app.
String referralShareLink(String code) {
  return 'sangeet://referral?code=$code';
}

/// Parses a referral code out of an incoming URI (deep link) if present.
/// Accepts `sangeet://referral?code=XXX` and `https://...?ref=XXX`.
String? parseReferralCode(Uri uri) {
  if (uri.host == 'referral' || uri.scheme == 'sangeet') {
    final code = uri.queryParameters['code'];
    if (code != null && code.isNotEmpty) return code;
  }
  final ref = uri.queryParameters['ref'];
  if (ref != null && ref.isNotEmpty) return ref;
  return null;
}
