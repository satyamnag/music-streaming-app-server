import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:sangeet/collections/env.dart';
import 'package:sangeet/services/logger/logger.dart';
import 'package:sangeet/utils/platform.dart';

/// Pure freshness rule for a server entitlement answer.
///
/// Split out of [EntitlementSignal.isActive] so it can be unit-tested without a
/// clock or a network (see test/modules/monetization/entitlement_signal_test.dart).
///
/// Every rejection here is a fail-closed rule:
///  - not entitled                     -> false
///  - never verified (`checkedAt == null`) -> false, so writing `active` alone
///    cannot unlock premium;
///  - older than [maxAge]              -> false, so a revoked subscription stops
///    working even if the app never re-polls;
///  - paid period already over         -> false, even before the server is asked.
bool entitlementIsActive({
  required bool active,
  required DateTime? checkedAt,
  required DateTime? currentEnd,
  required DateTime now,
  Duration maxAge = EntitlementSignal.maxAge,
}) {
  if (!active) return false;
  if (checkedAt == null) return false;
  if (now.difference(checkedAt) > maxAge) return false;
  if (currentEnd != null && currentEnd.isBefore(now)) return false;
  return true;
}

/// The fields the app uses from `/api/razorpay/entitlement`.
class EntitlementSnapshot {
  const EntitlementSnapshot({
    required this.active,
    this.plan,
    this.currentEnd,
  });

  final bool active;
  final String? plan;
  final DateTime? currentEnd;
}

/// Parses the entitlement response body. Returns null for anything that is not
/// a JSON object, so a proxy/error page can never be mistaken for an answer.
///
/// Only the fields that grant access are read, and `active` must be the literal
/// `true` — a string "true" or a non-empty value is NOT accepted.
EntitlementSnapshot? entitlementFromJson(Object? decoded) {
  if (decoded is! Map) return null;
  final plan = decoded['plan'];
  final end = decoded['current_end'];
  return EntitlementSnapshot(
    active: decoded['active'] == true,
    plan: plan is String && plan.isNotEmpty ? plan : null,
    currentEnd: end is String ? DateTime.tryParse(end) : null,
  );
}

/// Latest SERVER-VERIFIED entitlement for the Razorpay (web) payment rail.
///
/// Why this exists: the Play-distributed app may not sell its digital
/// subscription through Razorpay (Google requires Play Billing, or Play's India
/// alternative-billing programme — see docs/RAZORPAY-SUBSCRIPTIONS.md §2). So
/// Razorpay subscriptions are sold OUTSIDE the app, and the app's only job is
/// to honour one: it asks the Node API "is this Clerk user entitled?" and
/// trusts only that answer.
///
/// Mirrors the pattern of `ClerkAuthSignal`: a synchronous, always-safe static
/// read for gates that cannot await (the stream server, the player notifier).
///
/// ## Fail-closed, but not fail-stupid
/// - A stale answer EXPIRES ([maxAge]) instead of staying true forever.
/// - `_checkedAt == null` (never verified) is NOT trusted, so merely flipping
///   a field cannot unlock premium.
/// - A [currentEnd] in the past stops access even if the server has not been
///   re-polled yet.
/// - Nothing here is persisted: the app already needs the network to stream,
///   so "offline premium" would buy nothing but a stale claim to defend.
class EntitlementSignal {
  EntitlementSignal._();

  /// How long a verified answer is trusted before it must be re-checked.
  static const Duration maxAge = Duration(minutes: 30);

  static bool _active = false;
  static String? _plan;
  static DateTime? _currentEnd;
  static DateTime? _checkedAt;

  /// Raw last answer (no freshness applied). Prefer [isActive].
  static bool get active => _active;

  /// Plan slug reported by the server ('monthly' / 'yearly'), if any.
  static String? get plan => _plan;

  /// End of the paid period reported by the server, if any.
  static DateTime? get currentEnd => _currentEnd;

  /// When the last successful server answer was received.
  static DateTime? get checkedAt => _checkedAt;

  /// Whether the user may currently be treated as a Razorpay subscriber.
  static bool get isActive => entitlementIsActive(
    active: _active,
    checkedAt: _checkedAt,
    currentEnd: _currentEnd,
    now: DateTime.now(),
  );

  /// Records a verified server answer.
  static void update({
    required bool active,
    String? plan,
    DateTime? currentEnd,
  }) {
    _active = active;
    _plan = plan;
    _currentEnd = currentEnd;
    _checkedAt = DateTime.now();
  }

  /// Forgets everything (sign-out, account deletion, or a failed check that
  /// proves the session is no longer valid). Also called on startup so a
  /// previous process's answer can never leak into this one.
  static void reset() {
    _active = false;
    _plan = null;
    _currentEnd = null;
    _checkedAt = null;
  }
}

/// Outcome of a refresh attempt, for callers that want to react (mostly
/// diagnostics/logging). The gate itself only reads [EntitlementSignal].
enum EntitlementRefreshResult {
  /// The server answered and [EntitlementSignal] was updated.
  updated,

  /// No API base URL configured: this build has no web rail.
  notConfigured,

  /// Not applicable on this platform (no Clerk bridge, e.g. desktop/iOS).
  unsupported,

  /// Not signed in, or the session was rejected.
  unauthenticated,

  /// A request was already in flight; this call was coalesced.
  skipped,

  /// Network error, timeout, or a non-200 answer. The previous answer is
  /// left to expire on its own.
  failed,
}

/// Fetches the entitlement for the signed-in user from the Node API.
///
/// Never throws: a monetisation check must not be able to break sign-in or
/// startup. Failures leave the current signal to expire naturally.
class EntitlementService {
  EntitlementService._(this._tokenProvider);

  static EntitlementService? _instance;

  /// The one instance, configured once at startup with a Clerk token getter.
  ///
  /// Kept non-final so tests can inject a fake token provider; production calls
  /// [configure] exactly once from `main()`.
  static EntitlementService get instance {
    final existing = _instance;
    if (existing != null) return existing;
    throw StateError(
      'EntitlementService.configure() must be called before use '
      '(expected in main.dart).',
    );
  }

  static EntitlementService configure(Future<String?> Function() tokenProvider) {
    final service = EntitlementService._(tokenProvider);
    _instance = service;
    return service;
  }

  /// Fire-and-forget refresh for lifecycle hooks and other call sites that
  /// cannot fail: does nothing when [configure] was never called.
  static Future<void> refreshIfConfigured({bool force = false}) async {
    final service = _instance;
    if (service == null) return;
    await service.refresh(force: force);
  }

  /// Test seam: forget the configured instance.
  static void resetForTest() => _instance = null;

  final Future<String?> Function() _tokenProvider;

  static const Duration _requestTimeout = Duration(seconds: 10);

  /// A single refresh is enough of an answer for a few seconds; this stops
  /// sign-in + resume + startup from each firing a request.
  static const Duration _minInterval = Duration(seconds: 30);

  bool _inFlight = false;
  DateTime? _lastAttempt;

  /// Whether [switches] are wired at all. False when [Env.apiBaseUrl] is empty,
  /// which is the default, so the feature is inert until configured.
  static bool get isConfigured => Env.apiBaseUrl.trim().isNotEmpty;

  /// Re-reads the entitlement for the current session.
  ///
  /// [force] bypasses the debounce (used right after a purchase completes on
  /// the web and the user returns to the app).
  Future<EntitlementRefreshResult> refresh({
    bool force = false,
    Future<String?> Function()? tokenProvider,
  }) async {
    // The Clerk bridge is Android-only; on other platforms there is no token
    // to send, so this is simply not applicable rather than an error.
    if (!kIsAndroid) return EntitlementRefreshResult.unsupported;
    if (!isConfigured) return EntitlementRefreshResult.notConfigured;

    if (_inFlight) return EntitlementRefreshResult.skipped;
    final last = _lastAttempt;
    if (!force &&
        last != null &&
        DateTime.now().difference(last) < _minInterval) {
      return EntitlementRefreshResult.skipped;
    }

    _inFlight = true;
    _lastAttempt = DateTime.now();
    try {
      final token = await (tokenProvider ?? _tokenProvider)();
      if (token == null || token.isEmpty) {
        // Signed out (or the token could not be minted): the claim is void.
        EntitlementSignal.reset();
        return EntitlementRefreshResult.unauthenticated;
      }

      final base = Env.apiBaseUrl.trim().replaceAll(RegExp(r'/+$'), '');
      final response = await http
          .get(
            Uri.parse('$base/api/razorpay/entitlement'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(_requestTimeout);

      if (response.statusCode == 401) {
        EntitlementSignal.reset();
        return EntitlementRefreshResult.unauthenticated;
      }
      if (response.statusCode != 200) {
        AppLogger.log.w(
          'Entitlement check returned ${response.statusCode}; keeping the '
          'previous answer until it expires.',
        );
        return EntitlementRefreshResult.failed;
      }

      final snapshot = entitlementFromJson(jsonDecode(response.body));
      if (snapshot == null) return EntitlementRefreshResult.failed;

      EntitlementSignal.update(
        active: snapshot.active,
        plan: snapshot.plan,
        currentEnd: snapshot.currentEnd,
      );
      return EntitlementRefreshResult.updated;
    } catch (e, stack) {
      // Network down, DNS, timeout, malformed JSON: not an error worth
      // surfacing, and never a reason to grant access.
      AppLogger.log.w('Entitlement check failed: $e');
      AppLogger.reportError(e, stack);
      return EntitlementRefreshResult.failed;
    } finally {
      _inFlight = false;
    }
  }
}
