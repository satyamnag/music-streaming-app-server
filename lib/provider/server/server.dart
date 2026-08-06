import 'dart:io';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shelf/shelf_io.dart';
import 'package:sangeet/provider/server/pipeline.dart';
import 'package:sangeet/provider/server/router.dart';
import 'package:sangeet/provider/user_preferences/user_preferences_provider.dart';
import 'package:sangeet/services/audio_player/audio_player.dart';

const _portAttempts = 20;

// Singleton guard: the server must bind exactly once even if serverProvider is
// read from multiple places (main.dart ref.listen + ref.read, bonsoir, glance).
HttpServer? _serverInstance;
int _serverPort = 0;

final serverProvider = FutureProvider(
  (ref) async {
    if (_serverInstance != null) {
      return (server: _serverInstance!, port: _serverPort);
    }
    print('[SANGEET] server startup begin');
    try {
      // Wait for the persisted preferences to finish loading before reading
      // "Enable Connect". Without this, the provider reads the synchronous
      // default (Connect off) and the server binds to loopback even when the
      // user has enabled remote connect. Awaited once; the server still binds
      // exactly one time (see the _serverInstance singleton guard below).
      await ref.read(userPreferencesProvider.notifier).loaded;
      // Read preferences once (not watch) so the provider does NOT re-run and
      // kill the live server when the database finishes loading (connectPort
      // default -1 -> stored value).
      final preferences = ref.read(userPreferencesProvider);
      final enabledRemoteConnect = preferences.enableConnect;
      final connectPort = preferences.connectPort;
      print('[SANGEET] server startup connectPort=$connectPort');
      final pipeline = ref.read(pipelineProvider);
      final router = ref.read(serverRouterProvider);

      // Unique base port for this app (com.soulfulbhakti.app). The legacy
      // com.sangeet.app uses 9876, so a different port avoids any conflict
      // when both apps coexist on the same device.
      final basePort = connectPort == -1 ? 19876 : connectPort;
      SangeetMedia.setPort(basePort);

      final address = enabledRemoteConnect
          ? InternetAddress.anyIPv4
          : InternetAddress.loopbackIPv4;

      // Bind with a fallback port range so a lingering socket (or a previous
      // app instance holding the port) never crashes the server.
      HttpServer? server;
      for (var attempt = 0; attempt < _portAttempts; attempt++) {
        final port = basePort + attempt;
        try {
          server = await HttpServer.bind(address, port, shared: true);
          SangeetMedia.setPort(port);
          break;
        } on SocketException catch (e) {
          // EADDRINUSE: 98 on Linux, 48 on macOS.
          if (e.osError?.errorCode != 98 && e.osError?.errorCode != 48) rethrow;
          print('[SANGEET] port $port in use, trying next');
        }
      }

      if (server == null) {
        throw const SocketException(
          'Could not bind any port in the fallback range',
        );
      }

      _serverInstance = server;
      _serverPort = server.port;

      print(
        '[SANGEET] Playback server at http://${server.address.host}:${server.port}',
      );

      serveRequests(server, pipeline.addHandler(router.call));

      ref.onDispose(() {
        server!.close();
        _serverInstance = null;
      });

      return (
        server: server,
        port: server.port,
      );
    } catch (e) {
      print('[SANGEET] server startup FAILED: $e');
      rethrow;
    }
  },
);
