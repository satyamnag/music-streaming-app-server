import 'package:auto_route/auto_route.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sangeet/collections/routes.gr.dart';
import 'package:sangeet/components/image/universal_image.dart';
import 'package:sangeet/components/ui/button_tile.dart';
import 'package:sangeet/models/metadata/metadata.dart';

class StatsArtistItem extends StatelessWidget {
  final SangeetSimpleArtistObject artist;
  final Widget info;
  const StatsArtistItem({
    super.key,
    required this.artist,
    required this.info,
  });

  @override
  Widget build(BuildContext context) {
    return ButtonTile(
      style: ButtonVariance.ghost,
      // Artist name is intentionally hidden app-wide.
      title: const Text(''),
      leading: Avatar(
        initials: artist.name.substring(0, 1),
        provider: UniversalImage.imageProvider(
          (artist.images).asUrlString(
            placeholder: ImagePlaceholder.artist,
          ),
        ),
      ),
      trailing: info,
      onPressed: () {
        context.navigateTo(ArtistRoute(artistId: artist.id));
      },
    );
  }
}
