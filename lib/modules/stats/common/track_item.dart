import 'package:auto_route/auto_route.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sangeet/collections/routes.gr.dart';
import 'package:sangeet/components/track_card/home_track_card.dart';
import 'package:sangeet/components/track_card/track_card.dart';
import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/modules/monetization/premium_access.dart';
import 'package:sangeet/provider/audio_player/audio_player.dart';

/// One row of a stats list: the shared home track card — same cover, card shape
/// and text as the home screen's track rows — with the row's own stat (its play
/// count, minutes, …) beside it.
class StatsTrackItem extends HookConsumerWidget {
  final SangeetTrackObject track;
  final Widget info;
  const StatsTrackItem({
    super.key,
    required this.track,
    required this.info,
  });

  @override
  Widget build(BuildContext context, ref) {
    final locked = PremiumAccess.isTrackLocked(track, ref);

    void open() => context.navigateTo(TrackRoute(trackId: track.id));

    // The row stays tappable around the card, so the play count opens the track
    // like the rest of the row always has.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (locked) {
          PremiumAccess.gateTrackPlay(
            context: context,
            ref: ref,
            track: track,
            feature: () async => open(),
          );
          return;
        }
        open();
      },
      child: Row(
        children: [
          HomeTrackCard(
            track: track,
            imageUrl: trackCardImageUrl(track),
            onTap: open,
            // The row's tap opens the track, so the play control plays it —
            // the app's usual single-track play (the search results load the
            // same way). The card gates both through the premium check.
            onPlay: () => ref
                .read(audioPlayerProvider.notifier)
                .load([track], autoPlay: true),
          ),
          // The stat keeps its place at the row's trailing edge; the flexible
          // side is the gap, so a long stat wraps instead of overflowing.
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: info,
            ),
          ),
        ],
      ),
    );
  }
}
