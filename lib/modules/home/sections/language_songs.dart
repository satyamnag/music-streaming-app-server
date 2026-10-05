import 'package:auto_route/auto_route.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sangeet/collections/routes.gr.dart';
import 'package:sangeet/collections/spotube_icons.dart';
import 'package:sangeet/components/track_card/home_card_row.dart';
import 'package:sangeet/components/track_card/home_track_card.dart';
import 'package:sangeet/extensions/context.dart';
import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/modules/home/sections/home_section_layout.dart';
import 'package:sangeet/pages/home/home_see_all.dart';
import 'package:sangeet/provider/audio_player/audio_player.dart';
import 'package:sangeet/provider/home_tracks/home_tracks.dart';

/// Home screen components — one titled horizontal row per language (e.g.
/// "Telugu Songs", "Kannada Songs"). Each language's songs appear under its own
/// component heading, so a catalog with several languages yields several
/// separate components. Tapping a track plays the language's songs from that
/// point.
///
/// Renders as a list of slivers (one per language) so the caller can spread it
/// into the home `CustomScrollView` alongside the other sections.
class HomeLanguageSongsSections extends HookConsumerWidget {
  final List<HomeLanguageGroup> languages;

  const HomeLanguageSongsSections({super.key, required this.languages});

  @override
  Widget build(BuildContext context, ref) {
    if (languages.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => _LanguageSection(group: languages[index]),
        childCount: languages.length,
      ),
    );
  }
}

/// A single language's home section: a heading "<Language> Songs" plus a
/// horizontal row of that language's tracks.
class _LanguageSection extends HookConsumerWidget {
  final HomeLanguageGroup group;

  /// Number of tracks revealed per page.
  static const int pageSize = 25;

  const _LanguageSection({required this.group});

  @override
  Widget build(BuildContext context, ref) {
    final visibleCount = useState(_LanguageSection.pageSize);
    final theme = Theme.of(context);
    final scale = theme.scaling;
    final shown = group.tracks.take(visibleCount.value).toList();
    final hasMore = group.tracks.length > visibleCount.value;

    return Padding(
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
                      child: Text('${group.language} Songs'),
                    ),
                  ),
                  IconButton.ghost(
                    size: ButtonSize.small,
                    icon: const Icon(SangeetIcons.angleRight, size: 18),
                    onPressed: () {
                      context.navigateTo(
                        HomeSeeAllRoute(
                          kind: HomeSeeAllKind.language,
                          language: group.language,
                        ),
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
                    visibleCount.value += _LanguageSection.pageSize;
                  },
                );
              }
              final track = shown[index];
              final imageUrl =
                  track.album.images.smallest(ImagePlaceholder.albumArt);

              // One play action for the card and for its play control: the
              // language's songs, from this track. Defined once so they cannot
              // drift.
              Future<void> play() => ref
                  .read(audioPlayerProvider.notifier)
                  .load(group.tracks, initialIndex: index, autoPlay: true);

              return HomeTrackCard(
                track: track,
                imageUrl: imageUrl,
                onTap: play,
                onPlay: play,
              );
            },
          ),
        ],
      ),
    );
  }
}

/// A "See More" card shown after the visible track cards. Tapping it reveals
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
