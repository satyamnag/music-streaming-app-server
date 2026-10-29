import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:sangeet/collections/spotube_icons.dart';
import 'package:sangeet/components/track_card/home_track_card.dart';
import 'package:sangeet/components/track_card/track_card.dart';
import 'package:sangeet/extensions/context.dart';
import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/provider/audio_player/audio_player.dart';

/// A collection's tracks drawn as the SAME shared cards every other track
/// surface uses — the home rows, the home "see all" grids and the deity
/// screens — [pageSize] at a time, followed by a "see more" button.
///
/// ## Why this exists
/// A collection (an album, the listening history) used to be a table of list
/// rows with "# / Title / Album / Duration" columns while the deity screen and
/// the home "see all" screens drew cover cards for exactly the same tracks. Two
/// anatomies for one thing read as two different products. Those surfaces now
/// render this widget, so a track looks the same wherever it appears: the same
/// card, the same cover, the same corner radius, the same title block, the same
/// play control, the same premium gate ([HomeTrackCard] runs it).
///
/// ## Pagination
/// The first page is [pageSize] tracks; "see more" reveals the next page. When
/// the revealed window runs past the tracks that are already loaded and the
/// collection has more on the server, the next page is fetched first, so the
/// button also drives the collection's own pagination.
///
/// Emits SLIVERS, so it can be dropped into any `CustomScrollView`.
class TrackGridSection extends HookConsumerWidget {
  /// Every track the caller has loaded for this collection.
  final List<SangeetTrackObject> tracks;

  /// Tracks revealed per page.
  final int pageSize;

  /// Whether the collection has further tracks on the server that are not in
  /// [tracks] yet. Drives whether "see more" is still offered once every loaded
  /// track is visible.
  final bool hasNextPage;

  /// Fetches the collection's next page. Awaited by "see more" before the
  /// window grows past the loaded tracks.
  final Future<void> Function()? onFetchMore;

  const TrackGridSection({
    super.key,
    required this.tracks,
    this.pageSize = 10,
    this.hasNextPage = false,
    this.onFetchMore,
  });

  @override
  Widget build(BuildContext context, ref) {
    final scale = Theme.of(context).scaling;
    final visibleCount = useState(pageSize);

    final shown = tracks.take(visibleCount.value).toList();
    final hasMore = tracks.length > visibleCount.value || hasNextPage;

    // One play action for the card and for its play control: this collection,
    // from this track — the same contract the home rows and the deity screen
    // follow.
    Future<void> playFrom(int index) => ref
        .read(audioPlayerProvider.notifier)
        .load(tracks, initialIndex: index, autoPlay: true);

    return SliverMainAxisGroup(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.symmetric(
            horizontal: trackGridPadding,
            vertical: 4 * scale,
          ),
          sliver: SliverGrid.builder(
            itemCount: shown.length,
            // The shared delegate: three columns, the house gutters, and a tile
            // extent derived from the card's own geometry, so nothing clips.
            gridDelegate: trackGridDelegate(context),
            itemBuilder: (context, index) {
              final track = shown[index];
              return HomeTrackCard(
                track: track,
                imageUrl: trackCardImageUrl(track),
                onTap: () => playFrom(index),
                onPlay: () => playFrom(index),
              );
            },
          ),
        ),
        if (hasMore)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Button.text(
                  onPressed: () async {
                    final next = visibleCount.value + pageSize;
                    // Only reach for the network when the window has actually
                    // run past what is loaded; otherwise the next page is
                    // already here and revealing it is instant.
                    if (next > tracks.length &&
                        hasNextPage &&
                        onFetchMore != null) {
                      await onFetchMore!();
                    }
                    visibleCount.value = next;
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(SangeetIcons.angleDown, size: 16),
                      const Gap(6),
                      Text(context.l10n.load_more),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
