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
                itemCount: tracks.length,
                itemBuilder: (context, index) {
                  return TrackTile(
                    index: index,
                    track: tracks[index],
                    playlist: playlist,
                    onTap: () async {
                      await ref.read(audioPlayerProvider.notifier).load(
                            tracks,
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
