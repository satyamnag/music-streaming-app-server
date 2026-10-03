import 'package:auto_route/auto_route.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sangeet/collections/routes.gr.dart';
import 'package:sangeet/collections/spotube_icons.dart';
import 'package:sangeet/components/image/universal_image.dart';
import 'package:sangeet/components/premium/locked_badge.dart';
import 'package:sangeet/components/track_card/card_colors.dart';
import 'package:sangeet/extensions/context.dart';
import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/modules/home/sections/home_section_layout.dart';
import 'package:sangeet/modules/monetization/premium_access.dart';
import 'package:sangeet/pages/home/home_see_all.dart';
import 'package:sangeet/provider/audio_player/audio_player.dart';
import 'package:sangeet/provider/home_tracks/home_tracks.dart';

/// Home screen components Ã¢â‚¬â€ one titled horizontal row per language (e.g.
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
          Padding(
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
          Gap(8 * scale),
          SizedBox(
            height: HomeSectionLayout.rowHeight(context),
            child: ListView.separated(
              padding: EdgeInsets.symmetric(horizontal: 16.0 * scale),
              scrollDirection: Axis.horizontal,
              itemCount: shown.length + (hasMore ? 1 : 0),
              separatorBuilder: (_, __) => Gap(6 * scale),
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
                return _TrackCard(
                  track: track,
                  imageUrl: imageUrl,
                  onTap: () async {
                    await ref.read(audioPlayerProvider.notifier).load(
                        group.tracks,
                        initialIndex: index,
                        autoPlay: true);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackCard extends HookConsumerWidget {
  final SangeetTrackObject track;
  final String imageUrl;
  final VoidCallback onTap;

  const _TrackCard({
    required this.track,
    required this.imageUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, ref) {
    final theme = Theme.of(context);
    final scale = theme.scaling;
    final locked = PremiumAccess.isTrackLocked(track, ref);

    // Admin-configured card colors (null = keep the theme defaults). Bind to a
    // local first: Dart cannot type-promote a `final` field.
    final currentTrack = track;
    final String? configured =
        currentTrack is SangeetFullTrackObject ? currentTrack.cardBgColor : null;
    final String? configuredText = currentTrack is SangeetFullTrackObject
        ? currentTrack.cardTextColor
        : null;
    final bg = cardBackgroundColor(configured, theme.colorScheme.card);
    final titleColor = parseCardColor(configuredText) ??
        (configured != null
            ? readableTextOn(bg)
            : theme.colorScheme.foreground);
    final subtitleColor = parseCardColor(configuredText) ??
        (configured != null
            ? readableTextOn(bg).withValues(alpha: 0.75)
            : theme.colorScheme.mutedForeground);

    return Container(
      width: HomeSectionLayout.cardWidth * scale,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12 * scale),
        color: bg,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.light
                ? Colors.black.withValues(alpha: 0.12)
                : theme.colorScheme.primary.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: GestureDetector(
        onTap: () async {
          if (locked) {
            await PremiumAccess.gateTrackPlay(
              context: context,
              ref: ref,
              track: track,
              feature: () async => onTap(),
            );
            return;
          }
          onTap();
        },
        behavior: HitTestBehavior.opaque,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // The cover bleeds to the card's top/left/right edges; the card's
            // own Clip.antiAlias gives it the outer rounded corners at the top.
            AspectRatio(
              aspectRatio: 1,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  UniversalImage(path: imageUrl, fit: BoxFit.cover),
                  LockedBadge(locked: locked, borderRadius: 0),
                ],
              ),
            ),
            // Only the text block is padded, so the cover stays flush.
            Padding(
              padding: EdgeInsets.fromLTRB(
                HomeSectionLayout.cardPadding * scale,
                HomeSectionLayout.cardTextGap * scale,
                HomeSectionLayout.cardPadding * scale,
                HomeSectionLayout.cardPadding * scale,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    track.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.small.copyWith(
                      fontWeight: FontWeight.w600,
                      color: titleColor,
                    ),
                  ),
                  Gap(2 * scale),
                  Text(
                    track.album.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.xSmall.copyWith(
                      color: subtitleColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
