import 'package:auto_route/auto_route.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sangeet/collections/routes.gr.dart';
import 'package:sangeet/collections/spotube_icons.dart';
import 'package:sangeet/components/image/universal_image.dart';
import 'package:sangeet/extensions/context.dart';
import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/provider/home_tracks/home_tracks.dart';

/// A horizontal "Albums" row shown on the home screen. Songs that share the
/// same album name are grouped into a single album (named after that album),
/// and each album's cover is the thumbnail of its most played song. Tapping a
/// card opens the album screen with its full song list (like playlists).
class HomeAlbumsSection extends HookConsumerWidget {
  final List<HomeAlbum> albums;

  const HomeAlbumsSection({super.key, required this.albums});

  @override
  Widget build(BuildContext context, ref) {
    if (albums.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final theme = Theme.of(context);
    final scale = theme.scaling;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0 * scale),
              child: Row(
                children: [
                  Expanded(
                    child: DefaultTextStyle(
                      style: theme.typography.h4.copyWith(
                        color: theme.colorScheme.foreground,
                      ),
                      child: Text(context.l10n.albums),
                    ),
                  ),
                  if (albums.length > 5)
                    IconButton.ghost(
                      size: ButtonSize.small,
                      icon: const Icon(SangeetIcons.angleRight, size: 18),
                      onPressed: () {},
                    ),
                ],
              ),
            ),
            Gap(8 * scale),
            SizedBox(
              height: 200,
              child: ListView.separated(
                padding: EdgeInsets.symmetric(horizontal: 16.0 * scale),
                scrollDirection: Axis.horizontal,
                itemCount: albums.length,
                separatorBuilder: (_, __) => Gap(12 * scale),
                itemBuilder: (context, index) {
                  final album = albums[index].album;
                  final tracks = albums[index].tracks;
                  final imageUrl = album.images
                      .smallest(ImagePlaceholder.albumArt);

                  return _AlbumCard(
                    album: album,
                    trackCount: tracks.length,
                    imageUrl: imageUrl,
                    onTap: () {
                      // Open the album screen listing its songs (like a
                      // playlist) instead of immediately playing the album.
                      context.navigateTo(AlbumRoute(id: album.id, album: album));
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlbumCard extends HookWidget {
  final SangeetSimpleAlbumObject album;
  final int trackCount;
  final String imageUrl;
  final VoidCallback onTap;

  const _AlbumCard({
    required this.album,
    required this.trackCount,
    required this.imageUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scale = theme.scaling;

    return Container(
      width: 140 * scale,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12 * scale),
        color: theme.colorScheme.card,
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: EdgeInsets.all(10 * scale),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8 * scale),
                child: UniversalImage(
                  path: imageUrl,
                  height: 120 * scale,
                  width: 120 * scale,
                  fit: BoxFit.cover,
                ),
              ),
              Gap(8 * scale),
              Text(
                album.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.small.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.foreground,
                ),
              ),
              Gap(2 * scale),
              Text(
                '$trackCount songs',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.xSmall.copyWith(
                  color: theme.colorScheme.mutedForeground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
