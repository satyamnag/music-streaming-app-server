import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:sangeet/collections/fake.dart';
import 'package:sangeet/collections/spotube_icons.dart';
import 'package:sangeet/components/track_tile/track_tile.dart';
import 'package:sangeet/extensions/context.dart';
import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/modules/monetization/superwall_gate.dart';
import 'package:sangeet/provider/audio_player/audio_player.dart';

/// A titled vertical list of tracks used for the home screen sections
/// ("Newest Arrivals", "Top Trending").
///
/// Shows the section title, then the first [pageSize] tracks. A "See More"
/// button reveals the next [pageSize] tracks on each tap until all tracks are
/// visible. Tapping a track starts playback of the whole section from that
/// track. Shows a compact skeleton while the tracks are loading.
class HomeTrackSection extends HookConsumerWidget {
  final String title;
  final List<SangeetTrackObject> tracks;
  final bool isLoading;

  /// Number of tracks revealed per page.
  static const int pageSize = 5;

  const HomeTrackSection({
    super.key,
    required this.title,
    required this.tracks,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context, ref) {
    final theme = Theme.of(context);
    final playlist = ref.watch(audioPlayerProvider);
    final visibleCount = useState(pageSize);

    final List<Widget> tiles;
    if (isLoading) {
      tiles = List.generate(pageSize, (index) {
        return Skeletonizer(
          enabled: true,
          child: TrackTile(
            track: FakeData.track,
            playlist: playlist,
          ),
        );
      });
    } else {
      final shown = tracks.take(visibleCount.value).toList();
      tiles = [
        for (var index = 0; index < shown.length; index++)
          TrackTile(
            index: index,
            track: shown[index],
            playlist: playlist,
            onTap: () async {
              await gateFeature(
                placement: SuperwallPlacements.premiumPlayback,
                feature: () async {
                  await ref.read(audioPlayerProvider.notifier).load(
                        tracks,
                        initialIndex: index,
                        autoPlay: true,
                      );
                },
              );
            },
          ),
      ];
    }

    final hasMore = tracks.length > visibleCount.value;

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 16.0 * theme.scaling,
            ),
            child: Row(
              children: [
                DefaultTextStyle(
                  style: theme.typography.h4.copyWith(
                    color: theme.colorScheme.foreground,
                  ),
                  child: Text(title),
                ),
                const Spacer(),
                if (isLoading)
                  Text(
                    context.l10n.loading,
                    style: theme.typography.small.copyWith(
                      color: theme.colorScheme.mutedForeground,
                    ),
                  )
                else if (tracks.isNotEmpty)
                  Text(
                    '${tracks.length}',
                    style: theme.typography.small.copyWith(
                      color: theme.colorScheme.mutedForeground,
                    ),
                  ),
              ],
            ),
          ),
          const Gap(4),
          ...tiles,
          if (!isLoading && hasMore) ...[
            const Gap(4),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 16.0 * theme.scaling,
              ),
              child: Button.text(
                onPressed: () {
                  visibleCount.value += pageSize;
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(SangeetIcons.angleDown, size: 16),
                    const Gap(6),
                    Text(context.l10n.see_more),
                  ],
                ),
              ),
            ),
          ],
          const Gap(8),
        ],
      ),
    );
  }
}
