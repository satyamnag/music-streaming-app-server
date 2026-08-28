import 'package:auto_route/auto_route.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sangeet/collections/routes.gr.dart';
import 'package:sangeet/collections/spotube_icons.dart';
import 'package:sangeet/components/image/universal_image.dart';
import 'package:sangeet/components/premium/locked_badge.dart';
import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/modules/monetization/premium_access.dart';
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

  const _LanguageSection({required this.group});

  @override
  Widget build(BuildContext context, ref) {
    final theme = Theme.of(context);
    final scale = theme.scaling;

    return Padding(
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
            height: 200,
            child: ListView.separated(
              padding: EdgeInsets.symmetric(horizontal: 16.0 * scale),
              scrollDirection: Axis.horizontal,
              itemCount: group.tracks.length,
              separatorBuilder: (_, __) => Gap(12 * scale),
              itemBuilder: (context, index) {
                final track = group.tracks[index];
                final imageUrl = track.album.images
                    .smallest(ImagePlaceholder.albumArt);
                return _TrackCard(
                  track: track,
                  imageUrl: imageUrl,
                  onTap: () async {
                    await ref
                        .read(audioPlayerProvider.notifier)
                        .load(group.tracks, initialIndex: index, autoPlay: true);
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
        child: Padding(
          padding: EdgeInsets.all(10 * scale),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8 * scale),
                child: Stack(
                  children: [
                    UniversalImage(
                      path: imageUrl,
                      height: 120 * scale,
                      width: 120 * scale,
                      fit: BoxFit.cover,
                    ),
                    LockedBadge(locked: locked, borderRadius: 0),
                  ],
                ),
              ),
              Gap(8 * scale),
              Text(
                track.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.small.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.foreground,
                ),
              ),
              Gap(2 * scale),
              Text(
                track.album.name,
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
