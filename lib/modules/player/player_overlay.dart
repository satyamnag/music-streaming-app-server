import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:sangeet/modules/player/player_overlay_collapsed.dart';

import 'package:sangeet/modules/root/spotube_navigation_bar.dart';
import 'package:sangeet/modules/player/player.dart';
import 'package:sangeet/provider/audio_player/audio_player.dart';

final playerOverlayControllerProvider = StateProvider<PanelController>((ref) {
  return PanelController();
});

class PlayerOverlay extends HookConsumerWidget {
  final String albumArt;

  const PlayerOverlay({
    required this.albumArt,
    super.key,
  });

  @override
  Widget build(BuildContext context, ref) {
    final playlist = ref.watch(audioPlayerProvider);
    final canShow = playlist.activeTrack != null;

    final screenSize = MediaQuery.sizeOf(context);

    final panelController = ref.watch(playerOverlayControllerProvider);

    return SlidingUpPanel(
      maxHeight: screenSize.height,
      backdropEnabled: false,
      minHeight: canShow ? PlayerOverlayCollapsedSection.collapsedHeight : 0,
      onPanelSlide: (position) {
        final invertedPosition = 1 - position;
        ref.read(navigationPanelHeight.notifier).state =
            kNavigationBarHeight * invertedPosition;
      },
      controller: panelController,
      color: Colors.transparent,
      // Parallax OFF.
      //
      // With it on, SlidingUpPanel offsets the expanded body by the collapsed
      // header height (PlayerOverlayCollapsedSection.collapsedHeight = 86dp) as
      // the panel slides. Measured on the device: that offset pushed the top of
      // the player - the close chevron, the info button and the top of the cover -
      // above the screen edge, which is the "upper part is cut" the player was
      // reported for. Turning it off makes the body start exactly at the panel's
      // top edge, so its own SafeArea is all the inset it needs.
      parallaxEnabled: false,
      renderPanelSheet: false,
      header: SizedBox(
        height: PlayerOverlayCollapsedSection.collapsedHeight,
        width: screenSize.width,
        child: PlayerOverlayCollapsedSection(panelController: panelController),
      ),
      panelBuilder: (scrollController) => PlayerView(
        panelController: panelController,
        scrollController: scrollController,
      ),
    );
  }
}
