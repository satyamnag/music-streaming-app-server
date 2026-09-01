import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:sangeet/collections/spotube_icons.dart';
import 'package:sangeet/components/dialogs/playlist_add_track_dialog.dart';
import 'package:sangeet/components/heart_button/local_heart_button.dart';
import 'package:sangeet/components/hover_builder.dart';
import 'package:sangeet/components/image/universal_image.dart';
import 'package:sangeet/components/track_tile/track_options_button.dart';
import 'package:sangeet/components/ui/button_tile.dart';
import 'package:sangeet/extensions/constrains.dart';
import 'package:sangeet/extensions/context.dart';
import 'package:sangeet/extensions/duration.dart';
import 'package:sangeet/components/track_presentation/presentation_props.dart';
import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/modules/monetization/premium_access.dart';
import 'package:sangeet/modules/player/player_overlay.dart';
import 'package:sangeet/provider/audio_player/querying_track_info.dart';
import 'package:sangeet/provider/audio_player/state.dart';
import 'package:sangeet/services/audio_preload/track_byte_prefetcher.dart';
import 'package:sangeet/utils/platform.dart';

final _overlay = ValueNotifier<OverlayCompleter<dynamic>?>(null);

class TrackTile extends HookConsumerWidget {
  /// [index] will not be shown if null
  final int? index;
  final SangeetTrackObject track;
  final bool selected;
  final bool selectionMode;
  final ValueChanged<bool?>? onChanged;
  final Future<void> Function()? onTap;
  final VoidCallback? onLongPress;
  final bool userPlaylist;
  final String? playlistId;
  final AudioPlayerState playlist;

  final List<Widget>? leadingActions;

  const TrackTile({
    super.key,
    this.index,
    required this.track,
    this.selected = false,
    this.selectionMode = false,
    required this.playlist,
    this.onTap,
    this.onLongPress,
    this.onChanged,
    this.userPlaylist = false,
    this.playlistId,
    this.leadingActions,
  });

  @override
  Widget build(BuildContext context, ref) {
    final theme = Theme.of(context);

    final isLoading = useState(false);

    // A paid (locked) track is never "playing" for a free user: the play/pause
    // overlay must not appear (only the lock badge does), and the row must not
    // light up as the active track. Paid users are unaffected.
    // Also: if the track is shown inside a locked album presentation, it is
    // considered locked even when its own status is 'free' (album lock
    // cascades to all its tracks per product requirement).
    final isLocked = () {
      if (PremiumAccess.isTrackLocked(track, ref)) return true;
      try {
        final collection = TrackPresentationOptions.of(context).collection;
        return PremiumAccess.isAlbumLocked(collection, ref);
      } catch (_) {}
      return false;
    }();
    final isPlaying = !isLocked && playlist.activeTrack?.id == track.id;

    final isSelected = isPlaying || isLoading.value;

    // Warm-up prefetch: as soon as this track is built/visible on any screen
    // (home, playlists, search, ...), request ~20% of its audio bytes in the
    // background so a tap-to-play starts in a fraction of a second. Sliver
    // lists only build tiles near the viewport, so this effectively fires for
    // tracks that are actually on screen. Idempotent and concurrency-bounded
    // inside the prefetcher.
    useEffect(() {
      if (!isPlaying) {
        TrackBytePrefetcher.instance.prefetch(track, ref.read);
      }
      return null;
    }, [track.id]);

    final imageProvider = useMemoized(
      () => UniversalImage.imageProvider(
        (track.album.images).smallest(ImagePlaceholder.albumArt),
      ),
      [track.album.images],
    );

    // Treat either explicit selectionMode or presence of onChanged as selection
    // context. Some lists enable selection by providing `onChanged` without
    // toggling a dedicated `selectionMode` flag (e.g. playlists), so we must
    // disable inner navigation in both cases.
    final effectiveSelection = selectionMode || onChanged != null;

    return LayoutBuilder(builder: (context, constrains) {
      return Listener(
        onPointerDown: (event) {
          if (event.buttons != kSecondaryMouseButton) return;
          if (_overlay.value != null) {
            _overlay.value?.remove();
            _overlay.value = null;
          }
          _overlay.value = TrackOptionsButton.showOptions(
            context,
            Offset.zero,
            track,
            userPlaylist: userPlaylist,
            playlistId: playlistId,
          );
        },
        child: HoverBuilder(
          permanentState: isSelected || constrains.smAndDown ? true : null,
          builder: (context, isHovering) => Stack(
            children: [
              ButtonTile(
            selected: isSelected,
            onPressed: () async {
              try {
                isLoading.value = true;
                // In selection mode, taps toggle checkboxes — never gate those.
                if (onChanged != null) {
                  await onTap?.call();
                  return;
                }
                // Locked (paid) tracks: never play for non-premium users.
                // Present the Superwall paywall — playback runs only after a
                // successful purchase.
                await PremiumAccess.gateTrackPlay(
                  context: context,
                  ref: ref,
                  track: track,
                  feature: onTap ?? () async {},
                );
              } finally {
                if (context.mounted) {
                  isLoading.value = false;
                }
              }
            },
            onLongPress: onLongPress,
            style: ButtonVariance.ghost.copyWith(
              padding: (context, states, value) =>
                  const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
            ),
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...?leadingActions,
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 300),
                  crossFadeState: index != null && onChanged == null
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  firstChild: Checkbox(
                    state: selected
                        ? CheckboxState.checked
                        : CheckboxState.unchecked,
                    onChanged: (state) =>
                        onChanged?.call(state == CheckboxState.checked),
                  ),
                  secondChild: constrains.smAndDown
                      ? const SizedBox(width: 16)
                      : SizedBox(
                          width: 50,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Text(
                              '${(index ?? 0) + 1}',
                              maxLines: 1,
                              style: theme.typography.small,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                ),
                Stack(
                  children: [
                    Container(
                      height: 40,
                      width: 40,
                      decoration: BoxDecoration(
                        borderRadius: theme.borderRadiusMd,
                        image: DecorationImage(
                          fit: BoxFit.cover,
                          image: imageProvider,
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        decoration: BoxDecoration(
                          borderRadius: theme.borderRadiusMd,
                          color: isHovering
                              ? Colors.black.withAlpha(102)
                              : Colors.transparent,
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: Center(
                        child: Skeleton.ignore(
                          child: Consumer(
                            builder: (context, ref, _) {
                              final isFetchingActiveTrack =
                                  ref.watch(queryingTrackInfoProvider);
                              // Locked (paid) tracks always show a padlock in
                              // place of the play/pause indicator and never
                              // toggle to pause/loading.
                              if (isLocked) {
                                return const Icon(
                                  Icons.lock,
                                  color: Colors.white,
                                );
                              }
                              return AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                child: switch ((
                                  isPlaying,
                                  isFetchingActiveTrack,
                                  isPlaying,
                                  isHovering,
                                  isLoading.value
                                )) {
                                  (true, true, _, _, _) ||
                                  (_, _, _, _, true) =>
                                    const SizedBox(
                                      width: 26,
                                      height: 26,
                                      child: CircularProgressIndicator(),
                                    ),
                                  (_, _, true, _, _) => Icon(
                                      SangeetIcons.pause,
                                      color: theme.colorScheme.primary,
                                    ),
                                  (_, _, _, true, _) => const Icon(
                                      SangeetIcons.play,
                                      color: Colors.white,
                                    ),
                                  _ => const SizedBox.shrink(),
                                },
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            title: Row(
              children: [
                Expanded(
                  flex: 6,
                  child: AbsorbPointer(
                    absorbing: selectionMode,
                    child: switch (track) {
                    SangeetLocalTrackObject() => Text(
                        track.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    _ => Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                child: Button(
                style: ButtonVariance.link.copyWith(
                padding: (context, states, value) =>
                  EdgeInsets.zero,
                ),
                onPressed: effectiveSelection
                  ? null
                  : () async {
                    if (PremiumAccess.isTrackLocked(track, ref)) {
                      await PremiumAccess.gateTrackPlay(
                        context: context,
                        ref: ref,
                        track: track,
                        feature: () async {
                          // Play this track, then open the full on-screen player
                          // (PlayerView) instead of the legacy Track detail page.
                          await onTap?.call();
                          if (context.mounted) {
                            ref
                                .read(playerOverlayControllerProvider)
                                .open();
                          }
                        },
                      );
                      return;
                    }
                    // Play this track, then open the full on-screen player
                    // (PlayerView) instead of the legacy Track detail page.
                    await onTap?.call();
                    if (context.mounted) {
                      ref
                          .read(playerOverlayControllerProvider)
                          .open();
                    }
                  },
                              child: Text(
                                track.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                  },
                  ),
                ),
                if (constrains.mdAndUp) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 4,
                    child: switch (track) {
                      SangeetLocalTrackObject() => Text(
                          track.album.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      _ => Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            track.album.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        )
                    },
                  ),
                ],
              ],
            ),
            subtitle: const SizedBox.shrink(),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(width: 8),
                Text(
                  Duration(milliseconds: track.durationMs)
                      .toHumanReadableString(padZero: false),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(width: 8),
                // Locked (paid) tracks are covered by the gray overlay above,
                // so the trailing row keeps the normal heart button (which is
                // inert under the overlay's IgnorePointer).
                LocalTrackHeartButton(track: track),
                const SizedBox(width: 4),
                Builder(
                  builder: (context) {
                    return Tooltip(
                      tooltip: TooltipContainer(
                        child: Text(context.l10n.add_to_playlist),
                      ).call,
                      child: IconButton.ghost(
                        size: ButtonSize.small,
                        icon: const Icon(SangeetIcons.playlistAdd),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => PlaylistAddTrackDialog(
                              tracks: [track],
                              openFromPlaylist: playlistId,
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
                Builder(
                  builder: (context) {
                    return TrackOptionsButton(
                      track: track,
                      userPlaylist: userPlaylist,
                      playlistId: playlistId,
                    );
                  },
                ),
                if (kIsDesktop) const Gap(10),
              ],
            ),
          ),

            ],
          ),
        ),
      );
    });
  }
}
