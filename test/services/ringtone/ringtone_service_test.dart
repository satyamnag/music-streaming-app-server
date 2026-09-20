import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sangeet/services/ringtone/ringtone_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.soulfulbhakti.app/ringtone');

  setUp(() {
    // The test runner is not Android, so default every test to the Android
    // path unless it explicitly opts out. Production behaviour is unchanged.
    RingtoneService.isSupportedOverride = () => true;
  });

  tearDown(() {
    RingtoneService.isSupportedOverride = () => false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('setFromStoragePath forwards the R2 url and the sound type', () async {
    MethodCall? captured;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      captured = call;
      return true;
    });

    final ok = await RingtoneService.instance.setFromStoragePath(
      'song-ringtone.mp3',
      RingtoneType.notification,
    );

    expect(ok, isTrue);
    expect(captured, isNotNull);
    expect(captured!.method, 'setRingtone');
    expect(captured!.arguments['url'], endsWith('/song-ringtone.mp3'));
    expect(captured!.arguments['type'], 'notification');
  });

  test('setFromStoragePath maps each RingtoneType to its wire name', () async {
    final seen = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      seen.add(call.arguments['type'] as String);
      return true;
    });

    for (final t in RingtoneType.values) {
      await RingtoneService.instance.setFromStoragePath('clip.mp3', t);
    }
    expect(seen, ['ringtone', 'notification', 'alarm']);
  });

  test('setFromStoragePath refuses an empty path without calling native', () async {
    var called = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      called = true;
      return true;
    });

    final ok = await RingtoneService.instance.setFromStoragePath('', RingtoneType.ringtone);
    expect(ok, isFalse);
    expect(called, isFalse, reason: 'must not call native with an empty path');
  });

  test('setFromStoragePath refuses when the R2 CDN base is unconfigured', () async {
    var called = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      called = true;
      return true;
    });

    final ok = await RingtoneService.instance.setFromStoragePath(
      'song-ringtone.mp3',
      RingtoneType.ringtone,
    );

    // Only assert the no-call branch when the build really has no CDN base.
    if (!r2ConfiguredForTest) {
      expect(ok, isFalse);
      expect(called, isFalse, reason: 'must not call native without a URL');
    }
  });

  test('canWrite reflects the native result', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => true);
    expect(await RingtoneService.instance.canWrite(), isTrue);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => false);
    expect(await RingtoneService.instance.canWrite(), isFalse);
  });

  test('canWrite returns false when the channel throws', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'boom');
    });
    expect(await RingtoneService.instance.canWrite(), isFalse);
  });

  test('setFromStoragePath returns false when the channel throws', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'boom');
    });
    final ok = await RingtoneService.instance.setFromStoragePath(
      'song-ringtone.mp3',
      RingtoneType.alarm,
    );
    expect(ok, isFalse, reason: 'errors must never propagate to the player');
  });

  test('every method is a no-op on non-Android platforms', () async {
    RingtoneService.isSupportedOverride = () => false;
    var called = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      called = true;
      return true;
    });

    expect(await RingtoneService.instance.canWrite(), isFalse);
    expect(
      await RingtoneService.instance.setFromStoragePath('clip.mp3', RingtoneType.ringtone),
      isFalse,
    );
    await RingtoneService.instance.requestWrite();
    expect(called, isFalse, reason: 'no native calls on unsupported platforms');
  });
}
