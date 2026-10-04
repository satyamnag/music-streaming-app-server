import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:sangeet/extensions/duration.dart';
import 'package:sangeet/modules/player/use_progress.dart';
import 'package:sangeet/provider/audio_player/audio_player.dart';
import 'package:sangeet/services/audio_player/audio_player.dart';

/// A compact horizontal playback timeline laid out exactly like the reference
/// mini player: `01:12 ————————●———————— 04:36`, i.e. the elapsed time to the
/// LEFT of the bar, the total time to its RIGHT, all on one row.
///
/// Used by the collapsed mini player so the user can see (and scrub) progress
/// without opening the full player. It reuses the exact same [useProgress]
/// hook and seek semantics as the full player's slider, so the two can never
/// disagree about position, duration or buffering.
///
/// An earlier version stacked the two labels on a row *below* the bar, which
/// cost an extra ~17px of height and did not match the design. Flanking them
/// keeps the widget short enough to sit under the track name.
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

    // The bar takes all the space the two labels leave, so the labels stay at
    // their natural width and never truncate a long duration.
    final slider = Slider(
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
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(position.toHumanReadableString(), style: labelStyle),
        Gap(8 * theme.scaling),
        Expanded(child: slider),
        Gap(8 * theme.scaling),
        Text(duration.toHumanReadableString(), style: labelStyle),
      ],
    );
  }
}
