import 'package:auto_route/auto_route.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sangeet/collections/routes.gr.dart';
import 'package:sangeet/components/image/universal_image.dart';
import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/provider/home_tracks/home_tracks.dart';

/// A horizontal "Language Songs" row shown on the home screen — one card per
/// language (e.g. "Telugu Songs", "Kannada Songs"). Tapping a card opens that
/// language's song list (the same `album-language-<lang>` album screen that
/// the server already serves), so the user can browse or play all songs in a
/// given language.
class HomeLanguageSongsSection extends HookConsumerWidget {
  final List<HomeLanguageGroup> languages;

  const HomeLanguageSongsSection({super.key, required this.languages});

  @override
  Widget build(BuildContext context, ref) {
    if (languages.isEmpty) {
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
              child: DefaultTextStyle(
                style: theme.typography.h4.copyWith(
                  color: theme.colorScheme.foreground,
                ),
                child: const Text('Language Songs'),
              ),
            ),
            Gap(8 * scale),
            SizedBox(
              height: 200,
              child: ListView.separated(
                padding: EdgeInsets.symmetric(horizontal: 16.0 * scale),
                scrollDirection: Axis.horizontal,
                itemCount: languages.length,
                separatorBuilder: (_, __) => Gap(12 * scale),
                itemBuilder: (context, index) {
                  final group = languages[index];
                  final trackCount = group.tracks.length;
                  final coverUrl = group.tracks.isNotEmpty
                      ? group.tracks.first.album.images
                          .smallest(ImagePlaceholder.albumArt)
                      : '';

                  return _LanguageCard(
                    language: group.language,
                    trackCount: trackCount,
                    imageUrl: coverUrl,
                    onTap: () {
                      // Build a lightweight album object so the existing
                      // album-language-<lang> screen (served by the server)
                      // opens with the language's full song list.
                      final firstTrack = group.tracks.isNotEmpty
                          ? group.tracks.first
                          : null;
                      final album = SangeetSimpleAlbumObject(
                        id:
                            'album-language-${group.language.toLowerCase().replaceAll(' ', '-')}',
                        name: '${group.language} Songs',
                        externalUri: firstTrack?.album.externalUri ?? '',
                        artists: firstTrack?.album.artists ??
                            const <SangeetSimpleArtistObject>[],
                        images: firstTrack?.album.images ??
                            const <SangeetImageObject>[],
                        albumType: SangeetAlbumType.album,
                        releaseDate: firstTrack?.album.releaseDate,
                      );
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

class _LanguageCard extends HookWidget {
  final String language;
  final int trackCount;
  final String imageUrl;
  final VoidCallback onTap;

  const _LanguageCard({
    required this.language,
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
                '$language Songs',
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
