import 'package:flutter_test/flutter_test.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
// The public entry point does not export the platform interface. Importing the
// src path is the documented way to fake a plugin's platform channel, and it is
// confined to this test: analysis_options.yaml excludes test/**/*.dart.
import 'package:posthog_flutter/src/posthog_flutter_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sangeet/services/analytics/posthog_service.dart';
import 'package:sangeet/services/kv_store/kv_store.dart';

/// Records every call the service makes into the SDK.
///
/// This is what makes the wiring provable without a device, a project token, or
/// a network: the service talks to the SDK through
/// [PosthogFlutterPlatformInterface], so replacing that instance lets a test
/// assert the exact calls that would have crossed the platform channel.
class _RecordingPlatform extends PosthogFlutterPlatformInterface {
  final List<String> calls = [];
  PostHogConfig? setupConfig;
  String? capturedEvent;
  Map<String, Object>? capturedProperties;
  String? identifiedUserId;
  Map<String, Object>? identifiedUserProperties;
  Map<String, Object>? identifiedUserPropertiesSetOnce;
  String? screenName;
  Object? capturedError;
  bool throwOnEveryCall = false;

  void clear() {
    calls.clear();
    setupConfig = null;
    capturedEvent = null;
    capturedProperties = null;
    identifiedUserId = null;
    identifiedUserProperties = null;
    identifiedUserPropertiesSetOnce = null;
    screenName = null;
    capturedError = null;
  }

  @override
  Future<void> setup(PostHogConfig config) async {
    calls.add('setup');
    if (throwOnEveryCall) throw StateError('native setup failed');
    setupConfig = config;
  }

  @override
  Future<void> identify({
    required String userId,
    Map<String, Object>? userProperties,
    Map<String, Object>? userPropertiesSetOnce,
  }) async {
    calls.add('identify');
    if (throwOnEveryCall) throw StateError('native identify failed');
    identifiedUserId = userId;
    identifiedUserProperties = userProperties;
    identifiedUserPropertiesSetOnce = userPropertiesSetOnce;
  }

  @override
  Future<void> capture({
    required String eventName,
    Map<String, Object>? properties,
    Map<String, Object>? userProperties,
    Map<String, Object>? userPropertiesSetOnce,
  }) async {
    calls.add('capture');
    if (throwOnEveryCall) throw StateError('native capture failed');
    capturedEvent = eventName;
    capturedProperties = properties;
  }

  @override
  Future<void> screen({
    required String screenName,
    Map<String, Object>? properties,
  }) async {
    calls.add('screen');
    if (throwOnEveryCall) throw StateError('native screen failed');
    this.screenName = screenName;
  }

  @override
  Future<void> reset() async {
    calls.add('reset');
    if (throwOnEveryCall) throw StateError('native reset failed');
  }

  @override
  Future<void> disable() async {
    calls.add('disable');
    if (throwOnEveryCall) throw StateError('native disable failed');
  }

  @override
  Future<void> enable() async {
    calls.add('enable');
    if (throwOnEveryCall) throw StateError('native enable failed');
  }

  @override
  Future<void> flush() async {
    calls.add('flush');
    if (throwOnEveryCall) throw StateError('native flush failed');
  }

  @override
  Future<void> captureException({
    required Object error,
    StackTrace? stackTrace,
    Map<String, Object>? properties,
  }) async {
    calls.add('captureException');
    if (throwOnEveryCall) throw StateError('native captureException failed');
    capturedError = error;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _RecordingPlatform platform;
  final service = PostHogService.instance;

  const token = 'phc_test_project_token';

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await KVStoreService.initialize();
    platform = _RecordingPlatform();
    PosthogFlutterPlatformInterface.instance = platform;
    service.resetForTesting();
    // The host running these tests is Windows or Linux, where kIsMobile is
    // false and the real guard would skip setup entirely. The guard itself is
    // asserted separately in "does not set up on an unsupported platform".
    service.isSupportedPlatform = () => true;
  });

  tearDown(() => service.resetForTesting());

  group('consent gate (opt-in, default OFF)', () {
    test('a fresh install is not configured, not consented, not capturing', () {
      expect(service.isConfigured, isFalse);
      expect(service.hasConsent, isFalse);
      expect(service.isCapturing, isFalse);
    });

    test('initialize with a token but no consent never sets the SDK up', () async {
      await service.initialize(projectToken: token, host: 'https://us.i.posthog.com');

      expect(service.hasConsent, isFalse);
      expect(service.isConfigured, isFalse);
      expect(
        platform.calls,
        isEmpty,
        reason: 'without consent the SDK must not be started at all - no setup, '
            'no distinct id, no queued lifecycle event',
      );
    });

    test('no event method sends anything before consent', () async {
      await service.initialize(projectToken: token, host: 'https://us.i.posthog.com');

      await service.capture('app opened');
      await service.screen('Home');
      await service.identify('user_123');
      await service.captureException(StateError('boom'));
      await service.flush();
      await service.reset();

      expect(platform.calls, isEmpty);
    });

    test('a consented install sets the SDK up during initialize', () async {
      SharedPreferences.setMockInitialValues({'analyticsConsent': true});
      await KVStoreService.initialize();

      await service.initialize(projectToken: token, host: 'https://eu.i.posthog.com');

      expect(service.hasConsent, isTrue);
      expect(service.isConfigured, isTrue);
      expect(platform.calls, ['setup']);
      expect(platform.setupConfig?.projectToken, token);
      expect(platform.setupConfig?.host, 'https://eu.i.posthog.com');
    });

    test('setConsent(true) records the decision and opts the SDK in', () async {
      await service.initialize(projectToken: token, host: '');

      await service.setConsent(true);

      expect(service.isCapturing, isTrue);
      expect(KVStoreService.analyticsConsent, isTrue,
          reason: 'the decision must survive a restart');
      expect(platform.calls, containsAllInOrder(['setup', 'enable']));
    });

    test('setConsent(false) stops sending and clears the analytics identity',
        () async {
      SharedPreferences.setMockInitialValues({'analyticsConsent': true});
      await KVStoreService.initialize();
      await service.initialize(projectToken: token, host: '');

      await service.setConsent(false);

      expect(service.hasConsent, isFalse);
      expect(service.isCapturing, isFalse);
      expect(KVStoreService.analyticsConsent, isFalse);
      expect(
        platform.calls,
        containsAllInOrder(['disable', 'reset']),
        reason: 'disable first, then reset: resetting while still opted in '
            'would let a final event carry the identity being dropped',
      );
    });

    test('opting back in after opting out starts a new SDK session', () async {
      await service.initialize(projectToken: token, host: '');
      await service.setConsent(true);
      await service.setConsent(false);
      platform.clear();

      await service.setConsent(true);

      expect(service.isCapturing, isTrue);
      expect(platform.calls, ['enable'],
          reason: 'the SDK is already set up, so opting back in only has to '
              'reverse the opt-out');
    });

    test('consent recorded before initialize cannot set up yet', () async {
      // The toggle is only reachable after main() has run initialize(), but the
      // ordering matters: without the token, consent is recorded and nothing
      // else happens - which is the safe outcome, not a silent failure.
      await service.setConsent(true);

      expect(KVStoreService.analyticsConsent, isTrue);
      expect(service.isConfigured, isFalse);
      expect(platform.calls, isEmpty);
    });
  });

  group('configuration actually applied to the SDK', () {
    setUp(() async {
      await service.initialize(projectToken: token, host: '');
      await service.setConsent(true);
    });

    test('the safety-relevant defaults are all overridden', () {
      final config = platform.setupConfig!;

      expect(config.enableWindowsAndLinux, isFalse,
          reason: 'desktop capture is experimental and out of scope');
      expect(config.sessionReplay, isFalse,
          reason: 'replay records the screen; it needs its own consent');
      expect(config.surveys, isFalse);
      expect(config.preloadFeatureFlags, isFalse);
      expect(config.capturePushNotificationSubscriptions, isFalse,
          reason: 'push identity belongs to OneSignal; a second device '
              'identifier must not be sent to a second vendor');
      expect(config.capturePushNotificationOpened, isFalse);
      expect(config.rageClickConfig.enabled, isFalse);
      expect(config.beforeSend, isNotEmpty,
          reason: 'redaction must be installed on the SDK config');
      // Error tracking stays with Crashlytics: one crash reporter, not two.
      expect(config.errorTrackingConfig.captureFlutterErrors, isFalse);
      expect(config.errorTrackingConfig.capturePlatformDispatcherErrors, isFalse);
      expect(config.errorTrackingConfig.captureNativeExceptions, isFalse);
      expect(config.errorTrackingConfig.captureNativeCrashes, isFalse);
      expect(config.errorTrackingConfig.captureIsolateErrors, isFalse);
    });

    test('a blank host falls back to the SDK default, never an empty string', () {
      expect(platform.setupConfig?.host, 'https://us.i.posthog.com');
    });

    test('an empty token leaves the service unconfigured and logs nothing fatal',
        () async {
      service.resetForTesting();
      platform.clear();

      await service.initialize(projectToken: '', host: '');
      await service.setConsent(true);

      expect(service.isConfigured, isFalse);
      expect(platform.setupConfig, isNull);
    });

    test('does not set up on an unsupported platform (desktop / web)', () async {
      service.resetForTesting();
      platform.clear();
      service.isSupportedPlatform = () => false;

      await service.initialize(projectToken: token, host: '');
      await service.setConsent(true);

      expect(service.isConfigured, isFalse);
      expect(platform.calls, isEmpty);
    });

    test('the redaction callback is what gets installed', () {
      final config = platform.setupConfig!;
      final event = PostHogEvent(
        event: 'track played',
        properties: {'email': 'listener@example.com', 'screen_name': 'Home'},
      );

      // beforeSend callbacks may be async, so the declared return type is
      // FutureOr<PostHogEvent?>; ours is synchronous, so this cast is exact.
      final result = config.beforeSend.single(event) as PostHogEvent?;

      expect(result, isNotNull);
      expect(result!.properties, {'screen_name': 'Home'});
    });
  });

  group('identify', () {
    setUp(() async {
      await service.initialize(projectToken: token, host: '');
      await service.setConsent(true);
      platform.clear();
    });

    test('sends the Clerk user id and no person properties', () async {
      await service.identify('user_2abc');

      expect(platform.calls, ['identify']);
      expect(platform.identifiedUserId, 'user_2abc');
      expect(
        platform.identifiedUserProperties,
        isNull,
        reason: 'identify() emits a native \$set event that beforeSend cannot '
            'redact, so no PII may be passed here',
      );
      expect(platform.identifiedUserPropertiesSetOnce, isNull);
    });

    test('ignores a blank user id', () async {
      await service.identify('   ');

      expect(platform.calls, isEmpty);
    });

    test('reset reaches the SDK once configured', () async {
      await service.reset();

      expect(platform.calls, ['reset']);
    });
  });

  group('capture paths', () {
    setUp(() async {
      await service.initialize(projectToken: token, host: '');
      await service.setConsent(true);
      platform.clear();
    });

    test('capture forwards the event name and properties', () async {
      await service.capture('playlist created', properties: {'tracks': 3});

      expect(platform.capturedEvent, 'playlist created');
      expect(platform.capturedProperties, {'tracks': 3});
    });

    test('capture ignores a blank event name', () async {
      await service.capture('  ');

      expect(platform.calls, isEmpty);
    });

    test('screen forwards the screen name', () async {
      await service.screen('Now Playing');

      expect(platform.screenName, 'Now Playing');
    });

    test('captureException forwards the error', () async {
      final error = StateError('playback failed');
      await service.captureException(error);

      expect(platform.capturedError, same(error));
    });

    test('flush reaches the SDK', () async {
      await service.flush();

      expect(platform.calls, ['flush']);
    });
  });

  group('PII redaction', () {
    test('strips whole-key identifiers', () {
      final event = PostHogEvent(
        event: 'signup',
        properties: {
          'email': 'a@b.com',
          'phone': '+91 90000 00000',
          'full_name': 'Arjun Sharma',
          'username': 'arjun',
          'password': 'hunter2',
          'access_token': 'abc',
          'aadhaar': '1234 5678 9012',
          'gstin': '22AAAAA0000A1Z5',
          'search_query': 'bhajan',
        },
      );

      PostHogService.redact(event);

      expect(event.properties, isEmpty);
    });

    test('strips identifying fragments anywhere in the key', () {
      expect(PostHogService.isSensitiveKey('user_email'), isTrue);
      expect(PostHogService.isSensitiveKey('contact_phone_number'), isTrue);
      expect(PostHogService.isSensitiveKey('Account_Password'), isTrue);
      expect(PostHogService.isSensitiveKey('aadhaar_last4'), isTrue);
    });

    test('keeps the analytics properties the app actually needs', () {
      // The reason `name` is an exact-key match and not a fragment: as a
      // fragment it would strip every one of these.
      expect(PostHogService.isSensitiveKey('screen_name'), isFalse);
      expect(PostHogService.isSensitiveKey('track_name'), isFalse);
      expect(PostHogService.isSensitiveKey('artist_name'), isFalse);
      expect(PostHogService.isSensitiveKey('playlist_name'), isFalse);
      expect(PostHogService.isSensitiveKey('track_id'), isFalse);
      expect(PostHogService.isSensitiveKey('duration_ms'), isFalse);
    });

    test('redacts person properties as well as event properties', () {
      final event = PostHogEvent(
        event: 'identify',
        properties: {'email': 'a@b.com', 'track_id': 't1'},
        userProperties: {'phone': '123', 'plan': 'premium'},
        userPropertiesSetOnce: {'first_name': 'A', 'signup_source': 'qr'},
      );

      PostHogService.redact(event);

      expect(event.properties, {'track_id': 't1'});
      expect(event.userProperties, {'plan': 'premium'});
      expect(event.userPropertiesSetOnce, {'signup_source': 'qr'});
    });

    test('keeps an event rather than dropping it', () {
      final event = PostHogEvent(event: 'playback failed', properties: null);

      expect(PostHogService.redact(event), isNotNull,
          reason: 'dropping whole events would distort funnels; only the '
              'identifying keys are removed');
    });

    test('handles null and empty property maps', () {
      final event = PostHogEvent(event: 'app opened');

      expect(() => PostHogService.redact(event), returnsNormally);
      expect(PostHogService.redact(event)!.properties, isNull);
    });
  });

  group('failure containment', () {
    test('a throwing SDK never propagates out of the service', () async {
      await service.initialize(projectToken: token, host: '');
      await service.setConsent(true);
      platform.throwOnEveryCall = true;

      await expectLater(service.capture('x'), completes);
      await expectLater(service.screen('Home'), completes);
      await expectLater(service.identify('user_1'), completes);
      await expectLater(service.captureException(StateError('x')), completes);
      await expectLater(service.flush(), completes);
      await expectLater(service.reset(), completes);
      await expectLater(service.setConsent(false), completes);
      await expectLater(service.setConsent(true), completes);
    });

    test('a failing setup leaves the service safely unconfigured', () async {
      platform.throwOnEveryCall = true;

      await service.initialize(projectToken: token, host: '');
      await service.setConsent(true);

      expect(service.isConfigured, isFalse);
      expect(service.isCapturing, isFalse);
      // And every later call is still a safe no-op.
      await expectLater(service.capture('x'), completes);
    });
  });

  group('installation-verification harness', () {
    // The harness exists so CI can prove the pipeline against a real PostHog
    // project. These tests pin its two gates: it must be impossible to reach
    // from any normal build.
    setUp(() {
      service.isVerificationDefineSet = () => false;
      service.isDebugBuild = () => true;
    });

    tearDown(() {
      service.isVerificationDefineSet =
          () => const bool.fromEnvironment('POSTHOG_VERIFY_OPTIN');
      service.isDebugBuild = () => true;
    });

    test('a normal build never requests it', () {
      expect(service.isVerificationOptInRequested(), isFalse);
      expect(service.hasConsent, isFalse);
    });

    test('a release build refuses it even if the define were set', () {
      service.isVerificationDefineSet = () => true;
      service.isDebugBuild = () => false;

      expect(
        service.isVerificationOptInRequested(),
        isFalse,
        reason: 'a mistaken define in a release pipeline must not be enough to '
            'grant consent on every user device',
      );
    });

    test('without the define, verifyOptInIfRequested changes nothing', () async {
      final granted = await service.verifyOptInIfRequested();

      expect(granted, isFalse);
      expect(service.hasConsent, isFalse);
      expect(platform.calls, isEmpty);
      expect(KVStoreService.analyticsConsent, isFalse);
    });

    test('with both gates open it grants consent through the normal path',
        () async {
      service.isVerificationDefineSet = () => true;
      await service.initialize(projectToken: token, host: '');

      final granted = await service.verifyOptInIfRequested();

      expect(granted, isTrue);
      expect(service.hasConsent, isTrue);
      expect(service.isCapturing, isTrue);
      expect(KVStoreService.analyticsConsent, isTrue,
          reason: 'it must persist exactly what the Settings toggle persists');
      expect(
        platform.calls,
        containsAllInOrder(['setup', 'enable']),
        reason: 'and apply it exactly the same way',
      );
      expect(
        platform.setupConfig?.debug,
        isTrue,
        reason: 'a verification build turns on the SDK logs, so a missing event '
            'is diagnosable from logcat instead of guesswork',
      );
    });

    test('a normal build never turns on the SDK debug logs', () async {
      await service.initialize(projectToken: token, host: '');
      await service.setConsent(true);

      expect(
        platform.setupConfig?.debug,
        isFalse,
        reason: 'verbose SDK logging must not reach users',
      );
    });

    test('release build with the define still refuses to grant', () async {
      service.isVerificationDefineSet = () => true;
      service.isDebugBuild = () => false;
      await service.initialize(projectToken: token, host: '');

      final granted = await service.verifyOptInIfRequested();

      expect(granted, isFalse);
      expect(service.hasConsent, isFalse);
      expect(service.isCapturing, isFalse);
      expect(KVStoreService.analyticsConsent, isFalse);
      expect(platform.calls, isEmpty);
    });
  });
}
