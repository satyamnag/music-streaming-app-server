import 'package:auto_route/auto_route.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:sangeet/collections/spotube_icons.dart';
import 'package:sangeet/components/image/universal_image.dart';
import 'package:sangeet/components/ui/button_tile.dart';
import 'package:sangeet/extensions/context.dart';
import 'package:sangeet/extensions/duration.dart';
import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/modules/library/user_downloads/download_item.dart';
import 'package:sangeet/provider/audio_player/audio_player.dart';
import 'package:sangeet/provider/download_manager_provider.dart';
import 'package:sangeet/provider/downloads/downloads_provider.dart';
import 'package:sangeet/provider/history/history.dart';
import 'package:sangeet/services/downloads_index/downloads_index.dart';

@RoutePage()
class UserDownloadsPage extends HookConsumerWidget {
  static const name = 'user_downloads';
  const UserDownloadsPage({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final downloadQueue = ref.watch(downloadManagerProvider);
    final downloadManagerNotifier = ref.watch(downloadManagerProvider.notifier);
    final downloadedTracks = ref.watch(downloadedTracksProvider);
    final playlist = ref.watch(audioPlayerProvider);
    final playlistNotifier = ref.watch(audioPlayerProvider.notifier);
    final historyNotifier = ref.watch(playbackHistoryActionsProvider);
    final activeDownloadCount = downloadQueue
        .where((task) => task.status != DownloadStatus.completed)
        .length;

    Future<void> playDownloaded(DownloadedTrack downloaded) async {
      final track = downloaded.toTrackObject();
      if (playlist.tracks.any((t) => t.id == track.id)) {
        await playlistNotifier.jumpToTrack(track);
      } else {
        await playlistNotifier.load([track], initialIndex: 0, autoPlay: true);
      }
      await historyNotifier.addTracks([track]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: AutoSizeText(
                  context.l10n.currently_downloading(activeDownloadCount),
                  maxLines: 1,
                ).semiBold(),
              ),
              const SizedBox(width: 10),
              Button.destructive(
                onPressed: downloadQueue.isEmpty
                    ? null
                    : downloadManagerNotifier.clearAll,
                child: Text(context.l10n.cancel_all),
              ),
            ],
          ),
        ),
        Expanded(
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 200),
              children: [
                for (final task in downloadQueue) DownloadItem(task: task),
                if (downloadedTracks.isNotEmpty) ...[
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    child: Text(
                      '${context.l10n.downloads} (${downloadedTracks.length})',
                    ).semiBold(),
                  ),
                  for (final downloaded in downloadedTracks)
                    ButtonTile(
                      style: ButtonVariance.ghost,
                      leading: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: UniversalImage(
                            height: 40,
                            width: 40,
                            path: downloaded.albumImageUrl.isEmpty
                                ? placeholderUrlMap[ImagePlaceholder.albumArt]!
                                : downloaded.albumImageUrl,
                          ),
                        ),
                      ),
                      title: Text(
                        downloaded.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        downloaded.artists.join(', '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            Duration(milliseconds: downloaded.durationMs)
                                .toHumanReadableString(padZero: false),
                          ),
                          const SizedBox(width: 10),
                          const Icon(SangeetIcons.play),
                        ],
                      ),
                      onPressed: () => playDownloaded(downloaded),
                    ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
