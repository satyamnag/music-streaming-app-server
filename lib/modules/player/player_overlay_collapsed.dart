import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:sangeet/collections/intents.dart';
import 'package:sangeet/collections/spotube_icons.dart';
import 'package:sangeet/components/track_card/card_colors.dart';
import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/modules/player/player_track_details.dart';
import 'package:sangeet/modules/player/ringtone_action_button.dart';
import 'package:sangeet/modules/player/timeline_bar.dart';
import 'package:sangeet/modules/root/spotube_navigation_bar.dart';
import 'package:sangeet/provider/audio_player/audio_player.dart';
import 'package:sangeet/provider/audio_player/querying_track_info.dart';
import 'package:sangeet/services/audio_player/audio_player.dart';

class PlayerOverlayCollapsedSection extends HookConsumerWidget {
  /// Height of the collapsed mini player.
  ///
  /// Shared with [PlayerOverlay] (which sizes the SlidingUpPanel header and
  /// minHeight with it) so the panel geometry and the content can never drift
  /// apart — a mismatch would clip the timeline or leave dead space.
  ///
  /// Budget: the artwork/title row, plus the 5px outer padding above and below.
  /// The [TimelineBar] now lives INSIDE that row (handed to
  /// [PlayerTrackDetails.footer]) so it runs from the artwork's right edge to
  /// the controls' left edge, directly beneath the track name. It no longer
  /// occupies a band of its own under the artwork and the buttons.
  ///
  /// Deliberately left at 86 instead of being tightened to the smaller content:
  /// the row keeps its single `Expanded` child, so it always fills whatever
  /// height it is given — no dead band, and no possibility of a RenderFlex
  /// overflow. The artwork (its own 80px box minus 6px padding, so 68 max)
  /// absorbs the space the bar gave up and now renders at full size. Lower this
  /// value to shrink the artwork back; the row needs about 54 at minimum.
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

    // Admin-configured background for the mini player while THIS track plays.
    // Bound to a local first: Dart cannot type-promote a field, and only the
    // server's "full" track carries the column at all.
    final activeTrack = playlist.activeTrack;
    final configuredMiniBg = activeTrack is SangeetFullTrackObject
        ? activeTrack.miniplayerBgColor
        : null;
    final miniBg = parseCardColor(configuredMiniBg);

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
                // An admin-configured colour FILLS the bar. The surface blur and
                // opacity are dropped in that case on purpose: they exist so the
                // artwork behind the bar shows through, and an author who picked
                // this colour wants to see that colour. With no colour set the
                // card keeps exactly the appearance it had before, because
                // `filled: false` with the theme's own card colour is what the
                // default resolved to anyway.
                filled: miniBg != null,
                fillColor: miniBg ?? theme.colorScheme.card,
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
                                  // The playback timeline lives inside the
                                  // details column, so it sits directly under
                                  // the track name and spans only the gap
                                  // between the artwork and the controls.
                                  footer: Padding(
                                    padding: const EdgeInsets.only(
                                      top: 2,
                                      right: 4,
                                    ),
                                    child: TimelineBar(
                                      interactive: !isFetchingActiveTrack,
                                      labelColor:
                                          theme.colorScheme.mutedForeground,
                                    ),
                                  ),
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
                  ],
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
