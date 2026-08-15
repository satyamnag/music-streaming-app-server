import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sangeet/provider/metadata_plugin/metadata_plugin_provider.dart';
import 'package:sangeet/provider/server/server.dart';

/// Guards the splash screen lifecycle.
///
/// Resolves once the app's core services have settled (the metadata plugin and
/// the local playback server), with two guarantees:
///
///  - **Never flashes**: the splash stays visible for at least
///    [minSplashDuration], so even on a fast device the branding moment is not
///    a sub-frame blink.
///  - **Never hangs**: the wait is capped at [maxSplashDuration]. A hung or
///    failing provider never strands the user on a spinner forever — the app
///    proceeds and the home screen renders its own loading/error states.
///
/// The provider itself never throws: failures inside the awaited providers are
/// swallowed here because the app surfaces them with proper UI downstream.
final splashGateProvider = FutureProvider<void>((ref) async {
  final stopwatch = Stopwatch()..start();

  final pluginFuture = ref.read(metadataPluginProvider.future);
  final serverFuture = ref.read(serverProvider.future);

  try {
    await Future.wait([pluginFuture, serverFuture]).timeout(maxSplashDuration);
  } catch (_) {
    // A provider failed or timed out — never block on it. The home screen
    // shows the relevant error/retry UI itself.
  }

  final remaining = minSplashDuration - stopwatch.elapsed;
  if (remaining > Duration.zero) {
    await Future<void>.delayed(remaining);
  }
});

/// Minimum time the splash stays on screen (prevents a jarring flash).
const minSplashDuration = Duration(milliseconds: 1200);

/// Hard cap for how long the splash waits for core services.
const maxSplashDuration = Duration(seconds: 8);
