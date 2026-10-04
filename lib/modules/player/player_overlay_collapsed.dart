import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:sangeet/collections/intents.dart';
import 'package:sangeet/collections/spotube_icons.dart';
import 'package:sangeet/modules/player/player_track_details.dart';
import 'package:sangeet/modules/player/ringtone_action_button.dart';
import 'package:sangeet/modules/player/timeline_bar.dart';
import 'package:sangeet/modules/root/spotube_navigation_bar.dart';
import 'package:sangeet/provider/audio_player/audio_player.dart';
import 'package:sangeet/provider/audio_player/querying_track_info.dart';
import 'package:sangeet/services/audio_player/audio_player.dart';

class PlayerOverlayCollapsedSection extends HookConsumerWidget {
  /// Height of the collapsed mini player, including the timeline bar.
  ///
  /// Shared with [PlayerOverlay] (which sizes the SlidingUpPanel header and
  /// minHeight with it) so the panel geometry and the content can never drift
  /// apart — a mismatch would clip the timeline or leave dead space.
  ///
  /// Budget: artwork/title row + [TimelineBar] (one row: the elapsed and total
  /// labels flank the slider) + the 5px outer padding above and below.
  ///
  /// Reduced from 104 once the timeline became a single row instead of a slider
  /// with a second label row beneath it, so the bar sits tight under the track
  /// name exactly as in the design.
  static const double collapsedHeight = 86;

  final PanelController panelController;
  const PlayerOverlayCollapsedSection({
    super.key,
    required this.panelController,
  });

  @override
  Widget build(BuildContext context, ref) {
    final playlist = ref.watch(audioPlayerProvider);
    final canShow = playlist.activeTrack != null;

    final isFetchingActiveTrack = ref.watch(queryingTrackInfoProvider);
    final playing =
        useStream(audioPlayer.playingStream).data ?? audioPlayer.isPlaying;

    final theme = Theme.of(context);

    final shouldShow = useState(true);

    ref.listen(navigationPanelHeight, (_, height) {
      shouldShow.value = height.ceil() == 50;
    });

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: canShow && shouldShow.value
          ? Padding(
              padding: const EdgeInsets.all(5),
              child: SurfaceCard(
                surfaceBlur: theme.surfaceBlur,
                surfaceOpacity: theme.surfaceOpacity,
                padding: EdgeInsets.zero,
                borderRadius: theme.borderRadiusLg,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                panelController.open();
                              },
                              child: Container(
                                width: double.infinity,
                                color: Colors.transparent,
                                child: PlayerTrackDetails(
                                  track: playlist.activeTrack,
                                  color: theme.colorScheme.foreground,
                                ),
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              IconButton.ghost(
                                icon: const Icon(SangeetIcons.skipBack),
                                onPressed: isFetchingActiveTrack
                                    ? null
                                    : audioPlayer.skipToPrevious,
                              ),
                              Consumer(
                                builder: (context, ref, _) {
                                  return IconButton.ghost(
                                    icon: isFetchingActiveTrack
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(),
                                          )
                                        : Icon(
                                            playing
                                                ? SangeetIcons.pause
                                                : SangeetIcons.play,
                                          ),
                                    onPressed: Actions.handler<PlayPauseIntent>(
                                      context,
                                      PlayPauseIntent(ref),
                                    ),
                                  );
                                },
                              ),
                              IconButton.ghost(
                                icon: const Icon(SangeetIcons.skipForward),
                                onPressed: isFetchingActiveTrack
                                    ? null
                                    : audioPlayer.skipToNext,
                              ),
                              // 4th action: hidden unless the platform supports
                              // ringtones and this track has a ringtone file.
                              const RingtoneActionButton(
                                size: ButtonSize.xSmall,
                              ),
                              const Gap(5),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Horizontal playback timeline with elapsed / total time,
                    // shown directly beneath the track name & controls.
                    Padding(
                      padding: const EdgeInsets.only(left: 10, right: 10, bottom: 2),
                      child: TimelineBar(
                        interactive: !isFetchingActiveTrack,
                        labelColor: theme.colorScheme.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
