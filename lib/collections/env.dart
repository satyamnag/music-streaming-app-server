import 'package:envied/envied.dart';
import 'package:sangeet/utils/platform.dart';

part 'env.g.dart';

enum ReleaseChannel {
  nightly,
  stable,
}

@Envied(obfuscate: true, requireEnvFile: true, path: ".env")
abstract class Env {
  @EnviedField(varName: 'HIDE_DONATIONS', defaultValue: "0")
  static final int _hideDonations = _Env._hideDonations;

  static bool get hideDonations => _hideDonations == 1;

  @EnviedField(varName: 'ENABLE_UPDATE_CHECK', defaultValue: "1")
  static final String _enableUpdateChecker = _Env._enableUpdateChecker;

  @EnviedField(varName: "RELEASE_CHANNEL", defaultValue: "nightly")
  static final String _releaseChannel = _Env._releaseChannel;

  static ReleaseChannel get releaseChannel => _releaseChannel == "stable"
      ? ReleaseChannel.stable
      : ReleaseChannel.nightly;

  @EnviedField(varName: 'SUPABASE_URL')
  static final String supabaseUrl = _Env.supabaseUrl;

  @EnviedField(varName: 'SUPABASE_ANON_KEY')
  static final String supabaseAnonKey = _Env.supabaseAnonKey;

  @EnviedField(varName: 'CLERK_PUBLISHABLE_KEY')
  static final String clerkPublishableKey = _Env.clerkPublishableKey;

  /// Superwall publishable API key (paywall/monetization). Public by design.
  @EnviedField(varName: 'SUPERWALL_API_KEY', defaultValue: "")
  static final String superwallApiKey = _Env.superwallApiKey;

  /// OneSignal App ID (push notifications & in-app messages). Public by design.
  @EnviedField(varName: 'ONESIGNAL_APP_ID', defaultValue: "")
  static final String oneSignalAppId = _Env.oneSignalAppId;

  static bool get enableUpdateChecker =>
      kIsFlatpak || _enableUpdateChecker == "1";

  static String discordAppId = "1176718791388975124";
}
