import 'package:auto_route/auto_route.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

import 'package:sangeet/collections/assets.gen.dart';
import 'package:sangeet/collections/routes.gr.dart';
import 'package:sangeet/collections/spotube_icons.dart';
import 'package:sangeet/components/framework/app_pop_scope.dart';
import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/modules/player/player_actions.dart';
import 'package:sangeet/modules/player/player_controls.dart';
import 'package:sangeet/modules/player/volume_slider.dart';
import 'package:sangeet/components/dialogs/track_details_dialog.dart';
import 'package:sangeet/components/titlebar/titlebar.dart';
import 'package:sangeet/components/image/universal_image.dart';
import 'package:sangeet/extensions/constrains.dart';
import 'package:sangeet/extensions/context.dart';
import 'package:sangeet/modules/root/spotube_navigation_bar.dart';
import 'package:sangeet/provider/audio_player/audio_player.dart';
import 'package:sangeet/services/audio_player/audio_player.dart';
import 'package:sangeet/provider/server/active_track_sources.dart';
import 'package:sangeet/provider/volume_provider.dart';

class PlayerView extends HookConsumerWidget {
  final PanelController panelController;
  final ScrollController scrollController;
  const PlayerView({
    super.key,
    required this.panelController,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context, ref) {
    final sourcedCurrentTrack = ref.watch(activeTrackSourcesProvider);
    final currentActiveTrack =
        ref.watch(audioPlayerProvider.select((s) => s.activeTrack));
    final currentActiveTrackSource = sourcedCurrentTrack.asData?.value?.source;
    final isLocalTrack = currentActiveTrack is SangeetLocalTrackObject;
    final mediaQuery = MediaQuery.sizeOf(context);

    final shouldHide = useState(true);

    ref.listen(navigationPanelHeight, (_, height) {
      shouldHide.value = height.ceil() == 50;
    });

    if (shouldHide.value) {
      return const SizedBox();
    }

    useEffect(() {
      if (mediaQuery.lgAndUp) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          panelController.close();
        });
      }
      return null;
    }, [mediaQuery.lgAndUp]);

    String albumArt = useMemoized(
      () => (currentActiveTrack?.album.images).asUrlString(
        placeholder: ImagePlaceholder.albumArt,
      ),
      [currentActiveTrack?.album.images],
    );

    useEffect(() {
      for (final renderView in WidgetsBinding.instance.renderViews) {
        renderView.automaticSystemUiAdjustment = false;
      }

      return () {
        for (final renderView in WidgetsBinding.instance.renderViews) {
          renderView.automaticSystemUiAdjustment = true;
        }
      };
    }, [panelController.isAttached && panelController.isPanelOpen]);

    return AppPopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        await panelController.close();
      },
      child: SurfaceCard(
        borderWidth: 0,
        surfaceOpacity: 0.9,
        padding: EdgeInsets.zero,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          headers: [
            SafeArea(
              bottom: false,
              child: TitleBar(
                surfaceOpacity: 0,
                surfaceBlur: 0,
                leading: [
                  IconButton.ghost(
                    size: const ButtonSize(1.2),
                    icon: const Icon(SangeetIcons.angleDown),
                    onPressed: panelController.close,
                  )
                ],
                trailing: [
                  if (!isLocalTrack)
                    Tooltip(
                      tooltip: TooltipContainer(
                        child: Text(context.l10n.details),
                      ).call,
                      child: IconButton.ghost(
                        size: const ButtonSize(1.2),
                        icon: const Icon(SangeetIcons.info),
                        onPressed: currentActiveTrackSource == null
                            ? null
                            : () {
                                showDialog(
                                    context: context,
                                    builder: (context) {
                                      return TrackDetailsDialog(
                                        track: currentActiveTrack
                                            as SangeetFullTrackObject,
                                      );
                                    });
                              },
                      ),
                    )
                ],
              ),
            ),
          ],
          child: SingleChildScrollView(
            controller: scrollController,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.all(8),
                    constraints:
                        const BoxConstraints(maxHeight: 300, maxWidth: 300),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(100),
                          spreadRadius: 2,
                          blurRadius: 10,
                          offset: Offset.zero,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: UniversalImage(
                        path: albumArt,
                        placeholder: Assets.images.albumPlaceholder.path,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Original / Karaoke switch (enabled only when a karaoke file
                  // exists for the track).
                  _OriginalKaraokeToggle(
                    karaokeAvailable: currentActiveTrack is SangeetFullTrackObject &&
                        (currentActiveTrack.karaokeStoragePath?.trim().isNotEmpty ?? false),
                  ),
                  const SizedBox(height: 44),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AutoSizeText(
                          currentActiveTrack?.name ?? context.l10n.not_playing,
                          style: const TextStyle(fontSize: 22),
                          maxFontSize: 22,
                          maxLines: 1,
                          textAlign: TextAlign.start,
                        ),
                        if (isLocalTrack)
                          const SizedBox.shrink()
                        else
                          const SizedBox.shrink(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  const PlayerControls(),
                  const SizedBox(height: 25),
                  const PlayerActions(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    showQueue: false,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlineButton(
                          leading: const Icon(SangeetIcons.queue),
                          child: Text(context.l10n.queue),
                          onPressed: () {
                            if (!context.mounted) return;
                            context.pushRoute(const PlayerQueueRoute());
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlineButton(
                          leading: const Icon(SangeetIcons.music),
                          child: Text(context.l10n.lyrics),
                          onPressed: () {
                            if (!context.mounted) return;
                            context.pushRoute(const PlayerLyricsRoute());
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                  ),
                  const SizedBox(height: 25),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Consumer(builder: (context, ref, _) {
                      final volume = ref.watch(volumeProvider);
                      return VolumeSlider(
                        fullWidth: true,
                        value: volume,
                        onChanged: (value) {
                          ref.read(volumeProvider.notifier).setVolume(value);
                        },
                      );
                    }),
                  ),
                  const Gap(25),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}


/// Original / Karaoke switch shown between the cover art and the track name.
/// "Original" is the default (current playback, unchanged). "Karaoke" replays
/// the track's karaoke variant when one exists; otherwise it is disabled.
class _OriginalKaraokeToggle extends HookConsumerWidget {
  final bool karaokeAvailable;
  const _OriginalKaraokeToggle({required this.karaokeAvailable});

  @override
  Widget build(BuildContext context, ref) {
    final karaoke = useState(false);
    final notifier = ref.read(audioPlayerProvider.notifier);
    final activeTrack = ref.watch(
      audioPlayerProvider.select((s) => s.activeTrack?.id),
    );

    // Reset the toggle to "Original" whenever the playing track changes or
    // karaoke becomes unavailable, so the UI never shows a stale selection.
    useEffect(() {
      karaoke.value = false;
      return null;
    }, [activeTrack, karaokeAvailable]);

    void select(bool k) {
      if (k && !karaokeAvailable) return;
      if (karaoke.value == k) return;
      karaoke.value = k;
      notifier.toggleKaraoke(
        karaoke: k,
        position: audioPlayer.position,
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _ToggleButton(
          label: 'Original',
          selected: !karaoke.value,
          enabled: true,
          onTap: () => select(false),
        ),
        const SizedBox(width: 10),
        _ToggleButton(
          label: 'Karaoke',
          selected: karaoke.value,
          enabled: karaokeAvailable,
          onTap: () => select(true),
        ),
      ],
    );
  }
}

class _ToggleButton extends StatelessWidget {
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _ToggleButton({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primary
              : theme.colorScheme.muted,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.border,
          ),
        ),
        child: Text(
          label,
          style: theme.typography.small.copyWith(
            color: selected
                ? theme.colorScheme.primaryForeground
                : enabled
                    ? theme.colorScheme.mutedForeground
                    : theme.colorScheme.mutedForeground
                        .withValues(alpha: 0.4),
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
