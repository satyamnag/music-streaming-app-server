import 'dart:io';
import 'dart:math';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shelf/shelf_io.dart';
import 'package:sangeet/provider/server/pipeline.dart';
import 'package:sangeet/provider/server/router.dart';
import 'package:sangeet/provider/user_preferences/user_preferences_provider.dart';
import 'package:sangeet/services/audio_player/audio_player.dart';
import 'package:sangeet/services/logger/logger.dart';

final serverProvider = FutureProvider(
  (ref) async {
    final enabledRemoteConnect = ref.watch(
      userPreferencesProvider.select((value) => value.enableConnect),
    );
    final connectPort = ref.watch(
      userPreferencesProvider.select((value) => value.connectPort),
    );
    final pipeline = ref.watch(pipelineProvider);
    final router = ref.watch(serverRouterProvider);

    // When connect port is -1, we need to generate a random port
    // but we shouldn't reset it if it's already been set (caused by a state change)
    if (connectPort == -1) {
      if (SangeetMedia.serverPort == 0) {
        final port = Random().nextInt(17500) + 5000;
        SangeetMedia.setPort(port);
      }
    } else {
      SangeetMedia.setPort(connectPort);
    }

    final server = await serve(
      pipeline.addHandler(router.call),
      enabledRemoteConnect
          ? InternetAddress.anyIPv4
          : InternetAddress.loopbackIPv4,
      SangeetMedia.serverPort,
    );

    AppLogger.log.t(
      'Playback server at http://${server.address.host}:${server.port}',
    );

    ref.onDispose(() {
      server.close();
    });

    return (
      server: server,
      port: SangeetMedia.serverPort,
    );
  },
);
