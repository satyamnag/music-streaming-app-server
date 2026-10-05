import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sangeet/components/track_card/track_card.dart';
import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/modules/home/sections/home_section_layout.dart';
import 'package:sangeet/modules/monetization/premium_access.dart';

/// The home screen's track card, shared.
///
/// Resolves the track's own premium lock state and admin-configured card colors
/// and gates the tap through [PremiumAccess], then renders the common
/// [TrackCard] anatomy. Every surface that shows a track card (the home rows,
/// search, analytics) renders this widget, so the cover, corner radius,
/// typography and internal gaps can only be defined once.
class HomeTrackCard extends HookConsumerWidget {
  final SangeetTrackObject track;
  final String imageUrl;
  final VoidCallback onTap;

  /// What the card's play control does. Null (the default) renders no control.
  /// It runs through the same premium gate as [onTap], so a locked track can
  /// never be played by tapping the circle instead of the card.
  final VoidCallback? onPlay;

  /// Card width. Defaults to the home rows' fixed [HomeSectionLayout.cardWidth]
  /// box, which is also the cover's width; a grid passes its own tile width.
  final double? width;

  const HomeTrackCard({
    super.key,
    required this.track,
    required this.imageUrl,
    required this.onTap,
    this.onPlay,
    this.width,
  });

  @override
  Widget build(BuildContext context, ref) {
    final scale = Theme.of(context).scaling;
    final locked = PremiumAccess.isTrackLocked(track, ref);

    // Admin-configured card colors (null = keep the theme defaults). Bind to a
    // local first: Dart cannot type-promote a `final` field.
    final currentTrack = track;
    final String? configured =
        currentTrack is SangeetFullTrackObject ? currentTrack.cardBgColor : null;
    final String? configuredText = currentTrack is SangeetFullTrackObject
        ? currentTrack.cardTextColor
        : null;

    // Both of the card's tap targets play the track, so both have to clear the
    // paywall first. One gate for the two of them keeps them from drifting.
    VoidCallback? gated(VoidCallback? action) {
      if (action == null) return null;
      return () async {
        if (locked) {
          await PremiumAccess.gateTrackPlay(
            context: context,
            ref: ref,
            track: track,
            feature: () async => action(),
          );
          return;
        }
        action();
      };
    }

    return TrackCard(
      width: width ?? HomeSectionLayout.cardWidth * scale,
      imageUrl: imageUrl,
      title: track.name,
      subtitle: track.album.name,
      locked: locked,
      cardBgColor: configured,
      cardTextColor: configuredText,
      onTap: gated(onTap)!,
      onPlay: gated(onPlay),
    );
  }
}
