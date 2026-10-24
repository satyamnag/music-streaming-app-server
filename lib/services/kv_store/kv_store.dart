import 'dart:convert';

import 'package:encrypt/encrypt.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sangeet/models/database/database.dart';
import 'package:sangeet/services/wm_tools/wm_tools.dart';
import 'package:uuid/uuid.dart';

abstract class KVStoreService {
  static SharedPreferences? _sharedPreferences;
  static SharedPreferences get sharedPreferences => _sharedPreferences!;

  static Future<void> initialize() async {
    _sharedPreferences = await SharedPreferences.getInstance();
  }

  static bool get askedForBatteryOptimization =>
      sharedPreferences.getBool('askedForBatteryOptimization') ?? false;
  static Future<void> setAskedForBatteryOptimization(bool value) async =>
      await sharedPreferences.setBool('askedForBatteryOptimization', value);

  /// Whether the user has opted in to product analytics (PostHog).
  ///
  /// Defaults to **false**: consent is opt-in, so a fresh install - and every
  /// install that has never seen the Settings toggle - collects nothing. Read
  /// once at startup by PostHogService.initialize, before the SDK is set up,
  /// so there is no window in which events are captured without consent.
  ///
  /// Stored in SharedPreferences rather than the Drift preferences table on
  /// purpose: it must be readable before the database is opened, and adding a
  /// column to preferences_table would need a schema migration for a single
  /// boolean.
  static bool get analyticsConsent =>
      sharedPreferences.getBool('analyticsConsent') ?? false;
  static Future<void> setAnalyticsConsent(bool value) async =>
      await sharedPreferences.setBool('analyticsConsent', value);

  static List<String> get recentSearches =>
      sharedPreferences.getStringList('recentSearches') ?? [];

  static Future<void> setRecentSearches(List<String> value) async =>
      await sharedPreferences.setStringList('recentSearches', value);

  static WindowSize? get windowSize {
    final raw = sharedPreferences.getString('windowSize');

    if (raw == null) {
      return null;
    }
    return WindowSize.fromJson(jsonDecode(raw));
  }

  static Future<void> setWindowSize(WindowSize value) async =>
      await sharedPreferences.setString(
        'windowSize',
        jsonEncode(
          value.toJson(),
        ),
      );

  static String get encryptionKey {
    final value = sharedPreferences.getString('encryption');

    final key = const Uuid().v4();
    if (value == null) {
      setEncryptionKey(key);
      return key;
    }

    return value;
  }

  static Future<void> setEncryptionKey(String key) async {
    await sharedPreferences.setString('encryption', key);
  }

  static IV get ivKey {
    final iv = sharedPreferences.getString('iv');
    final value = IV.fromSecureRandom(8);

    if (iv == null) {
      setIVKey(value);

      return value;
    }

    return IV.fromBase64(iv);
  }

  static Future<void> setIVKey(IV iv) async {
    await sharedPreferences.setString('iv', iv.base64);
  }

  static double get volume => sharedPreferences.getDouble('volume') ?? 1.0;
  static Future<void> setVolume(double value) async =>
      await sharedPreferences.setDouble('volume', value);

  static bool get hasMigratedToDrift =>
      sharedPreferences.getBool('hasMigratedToDrift') ?? false;
  static Future<void> setHasMigratedToDrift(bool value) async =>
      await sharedPreferences.setBool('hasMigratedToDrift', value);

  static Map<String, dynamic>? get _youtubeEnginePaths {
    final jsonRaw = sharedPreferences.getString('ytDlpPath');

    if (jsonRaw == null) {
      return null;
    }

    return jsonDecode(jsonRaw);
  }

  static String? getYoutubeEnginePath(YoutubeClientEngine engine) {
    return _youtubeEnginePaths?[engine.name];
  }

  static Future<void> setYoutubeEnginePath(
    YoutubeClientEngine engine,
    String path,
  ) async {
    await sharedPreferences.setString(
      'ytDlpPath',
      jsonEncode({
        ...?_youtubeEnginePaths,
        engine.name: path,
      }),
    );
  }
}
