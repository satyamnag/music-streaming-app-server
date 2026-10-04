import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sangeet/components/track_card/home_album_card.dart';
import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/modules/monetization/premium_access.dart';

/// One row of a stats list: the shared home album card — same cover, card shape
/// and text as the home screen's album rows — with the row's own stat (its play
/// count) beside it.
class StatsAlbumItem extends HookConsumerWidget {
  final SangeetSimpleAlbumObject album;
  final Widget info;
  const StatsAlbumItem({super.key, required this.album, required this.info});

  @override
  Widget build(BuildContext context, ref) {
    final locked = PremiumAccess.isAlbumLocked(album, ref);

    // The row stays tappable around the card. Like the tile it replaces, a
    // stats album row only opens the payment gate for a locked album; it does
    // not navigate.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (locked) {
          PremiumAccess.gateAlbumPlay(
            context: context,
            ref: ref,
            album: album,
            feature: () async {},
          );
        }
      },
      child: Row(
        children: [
          HomeAlbumCard(
            album: album,
            imageUrl: album.images.smallest(ImagePlaceholder.albumArt),
            subtitle: '${album.albumType.formatted} • ',
            onTap: () {},
          ),
          // The stat keeps its place at the row's trailing edge; the flexible
          // side is the gap, so a long stat wraps instead of overflowing.
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: info,
            ),
          ),
        ],
      ),
    );
  }
}
