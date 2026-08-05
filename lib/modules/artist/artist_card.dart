import 'package:auto_route/auto_route.dart';
import 'package:auto_size_text/auto_size_text.dart';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:sangeet/collections/routes.gr.dart';
import 'package:sangeet/components/image/universal_image.dart';
import 'package:sangeet/extensions/context.dart';
import 'package:sangeet/models/metadata/metadata.dart';

class ArtistCard extends HookConsumerWidget {
  final SangeetFullArtistObject artist;
  const ArtistCard(this.artist, {super.key});

  @override
  Widget build(BuildContext context, ref) {
    final theme = Theme.of(context);
    final backgroundImage = UniversalImage.imageProvider(
      artist.images.asUrlString(
        placeholder: ImagePlaceholder.artist,
      ),
    );

    return SizedBox(
      width: 180,
      child: Button.card(
        onPressed: () {
          context.navigateTo(ArtistRoute(artistId: artist.id));
        },
        child: Column(
          children: [
            Avatar(
              initials: artist.name.trim()[0].toUpperCase(),
              provider: backgroundImage,
              size: 130,
            ),
            const Gap(10),
            AutoSizeText(
              artist.name,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: theme.typography.bold,
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                SecondaryBadge(
                  child: Text(
                    artist.songCount != null
                        ? '${artist.songCount} ${context.l10n.songs}'
                        : context.l10n.artist.toUpperCase(),
                  ),
                )
              ],
            )
          ],
        ),
      ),
    );
  }
}
