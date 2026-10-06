import 'package:auto_route/auto_route.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sangeet/components/button/back_button.dart';
import 'package:sangeet/components/titlebar/titlebar.dart';
import 'package:sangeet/components/track_tile/track_tile.dart';
import 'package:sangeet/extensions/context.dart';
import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/provider/audio_player/audio_player.dart';
import 'package:sangeet/provider/history/recent_tracks.dart';
import 'package:sangeet/provider/home_tracks/home_tracks.dart';

/// A full-screen list of all recently played tracks.
///
/// Reached from the clock icon on the home "Recently Played" section header.
/// Shows every track in the listening history, most recent first. Tapping a
/// track starts playback of the whole list from that track.
@RoutePage()
class RecentlyPlayedPage extends HookConsumerWidget {
  const RecentlyPlayedPage({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final history = ref.watch(recentlyPlayedTracksProvider);
    final tracks = history.asData?.value ?? const <SangeetTrackObject>[];
    final playlist = ref.watch(audioPlayerProvider);
    final theme = Theme.of(context);

    // Play the LIVE CATALOGUE object where one exists, not the history snapshot.
    //
    // History rows are snapshots taken when a track was last played, so they hold
    // none of the admin-configured fields (the mini player background, the card
    // colours). Loading them made the mini player fall back to the theme even when
    // the track HAD a colour set in the admin. The same resolution is done on the
    // home shelf's Recently Played row, so the two agree.
    final catalog = ref.watch(homeTracksProvider).asData?.value ?? const [];
    final byId = {for (final t in catalog) t.id: t};
    final playable = [for (final t in tracks) byId[t.id] ?? t];

    return SafeArea(
      bottom: false,
      child: Scaffold(
        headers: [
          TitleBar(
            leading: const [BackButton()],
            title: Text(context.l10n.recently_played),
          ),
        ],
        child: tracks.isEmpty
            ? Center(
                child: Text(
                  context.l10n.no_tracks,
                  style: theme.typography.base.copyWith(
                    color: theme.colorScheme.mutedForeground,
                  ),
                ),
              )
            : ListView.builder(
                padding: EdgeInsets.only(bottom: context.bottomPlayerReserve),
                itemCount: tracks.length,
                itemBuilder: (context, index) {
                  return TrackTile(
                    index: index,
                    track: tracks[index],
                    playlist: playlist,
                    onTap: () async {
                      await ref.read(audioPlayerProvider.notifier).load(
                            playable,
                            initialIndex: index,
                            autoPlay: true,
                          );
                    },
                  );
                },
              ),
      ),
    );
  }
}
