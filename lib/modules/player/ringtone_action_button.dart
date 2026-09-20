import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:sangeet/collections/spotube_icons.dart';
import 'package:sangeet/extensions/context.dart';
import 'package:sangeet/provider/audio_player/audio_player.dart';
import 'package:sangeet/services/ringtone/ringtone_service.dart';

/// "Set as ringtone" action, shared by the maximised player (via
/// [PlayerActions]) and the collapsed mini player.
///
/// Intensity renders nothing when ringtones are unsupported on the platform or
/// when the active track has no ringtone file, so the player never shows an
/// action that cannot work. Ringtones require a separate MP3 because Android's
/// RingtoneManager cannot use the streamed .opus original.
///
/// ignore: avoid_redundant_argument_values
class RingtoneActionButton extends HookConsumerWidget {
  final ButtonSize size;

  const RingtoneActionButton({this.size = ButtonSize.normal, super.key});

  @override
  Widget build(BuildContext context, ref) {
    final service = RingtoneService.instance;
    final playlist = ref.watch(audioPlayerProvider);
    final track = playlist.activeTrack;

    // The metadata model carries the R2 object key under 'ringtoneStoragePath'
    // (populated in supabase_data.dart). Tracks without one hide the action.
    final storagePath = useMemoized(
      () {
        if (track == null) return null;
        try {
          final dynamic t = track;
          final value = t.ringtoneStoragePath;
          return value is String && value.trim().isNotEmpty ? value : null;
        } catch (_) {
          return null;
        }
      },
      [track],
    );

    if (!service.isSupported || storagePath == null) {
      return const SizedBox.shrink();
    }

    return Tooltip(
      tooltip: TooltipContainer(child: Text(context.l10n.set_as_ringtone)).call,
      child: IconButton.ghost(
        size: size,
        icon: const Icon(SangeetIcons.ringtone),
        onPressed: () async {
          // WRITE_SETTINGS is a special permission the user grants on a system
          // screen, so ask for it first and let the next tap do the work.
          if (!await service.canWrite()) {
            await service.requestWrite();
            return;
          }
          final ok = await service.setFromStoragePath(
            storagePath,
            RingtoneType.ringtone,
          );
          if (!context.mounted) return;
          final message =
              ok ? context.l10n.ringtone_set : context.l10n.ringtone_failed;
          showToast(
            context: context,
            builder: (context, _) => Text(message),
          );
        },
      ),
    );
  }
}
