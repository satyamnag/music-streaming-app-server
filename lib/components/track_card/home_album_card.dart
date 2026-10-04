import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sangeet/components/track_card/track_card.dart';
import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/modules/home/sections/home_section_layout.dart';
import 'package:sangeet/modules/monetization/premium_access.dart';

/// The home screen's album card, shared.
///
/// Resolves the album's own premium lock state and admin-configured card colors
/// and gates the tap through [PremiumAccess], then renders the common
/// [TrackCard] anatomy — the same cover, corner radius, typography and internal
/// gaps as the track cards.
class HomeAlbumCard extends HookConsumerWidget {
  final SangeetSimpleAlbumObject album;
  final String imageUrl;

  /// The card's second line. The home rows pass the album's song count; other
  /// screens pass the line they already showed.
  final String subtitle;
  final VoidCallback onTap;

  /// Card width. Defaults to the home rows' fixed [HomeSectionLayout.cardWidth]
  /// box, which is also the cover's width; a grid passes its own tile width.
  final double? width;

  const HomeAlbumCard({
    super.key,
    required this.album,
    required this.imageUrl,
    required this.subtitle,
    required this.onTap,
    this.width,
  });

  @override
  Widget build(BuildContext context, ref) {
    final scale = Theme.of(context).scaling;
    final locked = PremiumAccess.isAlbumLocked(album, ref);

    return TrackCard(
      width: width ?? HomeSectionLayout.cardWidth * scale,
      imageUrl: imageUrl,
      title: album.name,
      subtitle: subtitle,
      locked: locked,
      // Admin-configured card colors (null = keep the theme defaults).
      cardBgColor: album.cardBgColor,
      cardTextColor: album.cardTextColor,
      onTap: () async {
        if (locked) {
          await PremiumAccess.gateAlbumPlay(
            context: context,
            ref: ref,
            album: album,
            feature: () async => onTap(),
          );
          return;
        }
        onTap();
      },
    );
  }
}
