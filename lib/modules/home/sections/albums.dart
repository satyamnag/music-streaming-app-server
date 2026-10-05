import 'package:auto_route/auto_route.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sangeet/collections/routes.gr.dart';
import 'package:sangeet/collections/spotube_icons.dart';
import 'package:sangeet/components/track_card/home_album_card.dart';
import 'package:sangeet/components/track_card/home_card_row.dart';
import 'package:sangeet/extensions/context.dart';
import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/modules/home/sections/home_section_layout.dart';
import 'package:sangeet/pages/home/home_see_all.dart';
import 'package:sangeet/provider/audio_player/audio_player.dart';
import 'package:sangeet/provider/home_tracks/home_tracks.dart';

/// A horizontal "Albums" row shown on the home screen. Songs that share the
/// same album name are grouped into a single album (named after that album),
/// and each album's cover is the thumbnail of its most played song. Tapping a
/// card opens the album screen with its full song list (like playlists).
class HomeAlbumsSection extends HookConsumerWidget {
  final List<HomeAlbum> albums;

  /// Number of albums revealed per page.
  static const int pageSize = 25;

  const HomeAlbumsSection({super.key, required this.albums});

  @override
  Widget build(BuildContext context, ref) {
    final visibleCount = useState(HomeAlbumsSection.pageSize);

    if (albums.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final theme = Theme.of(context);
    final scale = theme.scaling;
    final shown = albums.take(visibleCount.value).toList();
    final hasMore = albums.length > visibleCount.value;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            HomeCardRow(
              header: Padding(
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
                        onPressed: () {
                          context.navigateTo(
                            HomeSeeAllRoute(kind: HomeSeeAllKind.albums),
                          );
                        },
                      ),
                  ],
                ),
              ),
              itemCount: shown.length + (hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (hasMore && index == shown.length) {
                  return _SeeMoreCard(
                    onTap: () {
                      visibleCount.value += HomeAlbumsSection.pageSize;
                    },
                  );
                }
                final album = shown[index].album;
                final tracks = shown[index].tracks;
                final imageUrl =
                    album.images.smallest(ImagePlaceholder.albumArt);

                return HomeAlbumCard(
                  album: album,
                  subtitle: '${tracks.length} songs',
                  imageUrl: imageUrl,
                  onTap: () {
                    // Open the album screen listing its songs (like a
                    // playlist) instead of immediately playing the album.
                    context.navigateTo(AlbumRoute(id: album.id, album: album));
                  },
                  // The card's tap opens the album; the play control plays it
                  // instead, which is the only thing the circle can mean.
                  onPlay: () => ref
                      .read(audioPlayerProvider.notifier)
                      .load(tracks, autoPlay: true),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// A "See More" card shown after the visible album cards. Tapping it reveals
/// the next page of cards.
class _SeeMoreCard extends StatelessWidget {
  final VoidCallback onTap;

  const _SeeMoreCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scale = theme.scaling;

    return Container(
      width: HomeSectionLayout.cardWidth * scale,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12 * scale),
        color: theme.colorScheme.card,
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.25),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                SangeetIcons.angleDown,
                size: 22 * scale,
                color: theme.colorScheme.primary,
              ),
              Gap(8 * scale),
              Text(
                context.l10n.see_more,
                style: theme.typography.xSmall.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
