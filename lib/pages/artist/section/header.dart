import 'package:auto_size_text/auto_size_text.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Consumer;
import 'package:skeletonizer/skeletonizer.dart';
import 'package:sangeet/collections/fake.dart';
import 'package:sangeet/collections/spotube_icons.dart';
import 'package:sangeet/components/image/universal_image.dart';
import 'package:sangeet/extensions/constrains.dart';
import 'package:sangeet/extensions/context.dart';
import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/provider/metadata_plugin/artist/artist.dart';
import 'package:sangeet/provider/metadata_plugin/core/auth.dart';
import 'package:sangeet/provider/metadata_plugin/library/artists.dart';
import 'package:sangeet/utils/primitive_utils.dart';

class ArtistPageHeader extends HookConsumerWidget {
  final String artistId;
  const ArtistPageHeader({super.key, required this.artistId});

  @override
  Widget build(BuildContext context, ref) {
    final artistQuery = ref.watch(metadataPluginArtistProvider(artistId));
    final artist = artistQuery.asData?.value ?? FakeData.artist;

    final theme = Theme.of(context);
    final ThemeData(:typography) = theme;

    final authenticated = ref.watch(metadataPluginAuthenticatedProvider);

final image = artist.images.asUrlString(
      placeholder: ImagePlaceholder.artist,
    );

    final actions = Skeleton.keep(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (authenticated.asData?.value == true)
            Consumer(
              builder: (context, ref, _) {
                final isFollowingQuery = ref.watch(
                  metadataPluginIsSavedArtistProvider(artist.id),
                );
                final followingArtistNotifier =
                    ref.watch(metadataPluginSavedArtistsProvider.notifier);

                return switch (isFollowingQuery) {
                  AsyncData(value: final following) => Builder(
                      builder: (context) {
                        if (following) {
                          return Button.outline(
                            onPressed: () async {
                              await followingArtistNotifier
                                  .removeFavorite([artist]);
                            },
                            child: Text(context.l10n.following),
                          );
                        }

                        return Button.primary(
                          onPressed: () async {
                            await followingArtistNotifier.addFavorite([artist]);
                          },
                          child: Text(context.l10n.follow),
                        );
                      },
                    ),
                  AsyncError() => const SizedBox(),
                  _ => const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(),
                    )
                };
              },
            ),
          const SizedBox(width: 5),
          IconButton.ghost(
            icon: const Icon(SangeetIcons.share),
            onPressed: () async {
              await SharePlus.instance.share(
                ShareParams(text: artist.externalUri),
              );
            },
          )
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, constrains) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: theme.borderRadiusXl,
                      child: UniversalImage(
                        path: image,
                        width: constrains.mdAndUp ? 200 : 120,
                        height: constrains.mdAndUp ? 200 : 120,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const Gap(20),
                    Flexible(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              OutlineBadge(
                                child:
                                    Text(context.l10n.artist).small().muted(),
                              ),
                            ],
                          ),
                          const Gap(10),
                          Flexible(
                            child: AutoSizeText(
                              artist.name,
                              style: constrains.smAndDown
                                  ? typography.h4
                                  : typography.h3,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              minFontSize: 14,
                            ),
                          ),
                          const Gap(5),
                          Flexible(
                            child: AutoSizeText(
                              context.l10n.followers(
                                artist.followers == null
                                    ? double.infinity
                                    : PrimitiveUtils.toReadableNumber(
                                        artist.followers!.toDouble(),
                                      ),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              minFontSize: 12,
                            ).muted(),
                          ),
                          if (constrains.mdAndUp) ...[
                            const Gap(20),
                            actions,
                          ]
                        ],
                      ),
                    ),
                  ],
                ),
                if (constrains.smAndDown) ...[
                  const Gap(20),
                  actions,
                ]
              ],
            ),
          ),
        );
      },
    );
  }
}
