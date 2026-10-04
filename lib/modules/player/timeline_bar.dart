import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:sangeet/extensions/duration.dart';
import 'package:sangeet/modules/player/use_progress.dart';
import 'package:sangeet/provider/audio_player/audio_player.dart';
import 'package:sangeet/services/audio_player/audio_player.dart';

/// A compact horizontal playback timeline: a thin progress bar with the
/// elapsed and total time underneath.
///
/// Used by the collapsed mini player so the user can see (and scrub) progress
/// without opening the full player. It reuses the exact same [useProgress]
/// hook and seek semantics as the full player's slider, so the two can never
/// disagree about position, duration or buffering.
///
/// Layout: `[elapsed] ———————●———————— [total]` in a single row, which keeps the
/// widget short enough to sit under the track name in the mini player.
class TimelineBar extends HookConsumerWidget {
  /// Height of the draggable track. Kept thin; the touch target is padded
  /// around it so it stays comfortably tappable.
  final double barHeight;

  /// When false the bar is display-only (no seek), used while the active
  /// track's info is still loading.
  final bool interactive;

  /// Optional color override for the text labels (the mini player passes the
  /// surface foreground color).
  final Color? labelColor;

  const TimelineBar({
    super.key,
    this.barHeight = 3,
    this.interactive = true,
    this.labelColor,
  });

  @override
  Widget build(BuildContext context, ref) {
    final theme = Theme.of(context);
    final (:bufferProgress, :duration, :position, :progressStatic) =
        useProgress(ref);

    final isFetchingActiveTrack = ref.watch(
      audioPlayerProvider.select((s) => s.activeTrack == null),
    );

    final hasDuration = duration.inSeconds > 0;
    final canSeek = interactive && !isFetchingActiveTrack && hasDuration;

    final labelStyle = theme.typography.xSmall.copyWith(
      color: labelColor ?? theme.colorScheme.mutedForeground,
      // Tabular figures stop the row from jittering as the seconds tick over.
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Slider(
          // Buffered-ahead region, shown as the slider's hint value exactly
          // like the full player.
          hintValue: SliderValue.single(bufferProgress),
          // Feed the thumb ONLY from the position stream, and never write
          // local state in onChanged: mirroring the stream value back would
          // make shadcn's slider suppress the onChangeEnd seek. The thumb
          // still follows the finger while dragging and the seek fires on
          // release.
          value: SliderValue.single(progressStatic.toDouble()),
          onChanged: canSeek ? (v) {} : null,
          onChangeEnd: !canSeek
              ? null
              : (value) async {
                  await audioPlayer.seek(
                    Duration(
                      seconds: (value.value * duration.inSeconds).toInt(),
                    ),
                  );
                },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(position.toHumanReadableString(), style: labelStyle),
              Text(duration.toHumanReadableString(), style: labelStyle),
            ],
          ),
        ),
      ],
    );
  }
}
