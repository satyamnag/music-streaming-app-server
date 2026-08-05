import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sangeet/components/links/artist_link.dart';
import 'package:sangeet/components/ui/button_tile.dart';
import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/components/image/universal_image.dart';

class StatsAlbumItem extends StatelessWidget {
  final SangeetSimpleAlbumObject album;
  final Widget info;
  const StatsAlbumItem({super.key, required this.album, required this.info});

  @override
  Widget build(BuildContext context) {
    return ButtonTile(
      style: ButtonVariance.ghost,
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: UniversalImage(
          path: (album.images).asUrlString(
            placeholder: ImagePlaceholder.albumArt,
          ),
          width: 40,
          height: 40,
        ),
      ),
      title: Text(album.name),
      subtitle: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("${album.albumType.formatted} • "),
          Flexible(
            child: ArtistLink(
              artists: album.artists,
              mainAxisAlignment: WrapAlignment.start,
            ),
          ),
        ],
      ),
      trailing: info,
      onPressed: () {},
    );
  }
}
