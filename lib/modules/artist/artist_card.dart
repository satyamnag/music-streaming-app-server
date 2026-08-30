import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:sangeet/components/image/universal_image.dart';
import 'package:sangeet/extensions/context.dart';
import 'package:sangeet/models/metadata/metadata.dart';

class ArtistCard extends HookConsumerWidget {
  final SangeetFullArtistObject artist;
  const ArtistCard(this.artist, {super.key});

  @override
  Widget build(BuildContext context, ref) {
    final backgroundImage = UniversalImage.imageProvider(
      artist.images.asUrlString(
        placeholder: ImagePlaceholder.artist,
      ),
    );

    return SizedBox(
      width: 180,
      child: Button.card(
        // Artist page intentionally removed app-wide: tapping an artist card
        // does nothing (keeps the route registered to avoid nav breakage).
        onPressed: () {},
        child: Column(
          children: [
            Avatar(
              initials: artist.name.trim()[0].toUpperCase(),
              provider: backgroundImage,
              size: 130,
            ),
            const Gap(10),
            // Artist name is intentionally hidden app-wide.
            const SizedBox.shrink(),
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
