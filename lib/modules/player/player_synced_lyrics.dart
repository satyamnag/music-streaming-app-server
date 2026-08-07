import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sangeet/collections/spotube_icons.dart';
import 'package:sangeet/modules/lyrics/use_synced_lyrics.dart';
import 'package:sangeet/provider/audio_player/audio_player.dart';
import 'package:sangeet/provider/lyrics/synced.dart';
import 'package:sangeet/services/audio_player/audio_player.dart';

/// A compact, inline synced-lyrics preview shown on the now-playing (music)
/// page between the track title and the player controls.
///
/// It shows the current lyric line (highlighted) together with the next one,
/// and auto-scrolls as playback advances so the user can follow the song
/// without opening the full lyrics page. Hidden when no synced lyrics exist
/// (falls back to showing the plain first line if only plain lyrics exist).
class PlayerSyncedLyrics extends HookConsumerWidget {
  const PlayerSyncedLyrics({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final theme = Theme.of(context);
    final playlist = ref.watch(audioPlayerProvider);
    final track = playlist.activeTrack;

    final delay = ref.watch(syncedLyricsDelayProvider);
    final lyricsState = ref.watch(syncedLyricsMapProvider(track));
    final lyricValue = lyricsState.asData?.value.lyricsMap ?? const {};
    final currentTime =
        useSyncedLyrics(ref, lyricValue, delay);

    if (track == null) return const SizedBox.shrink();

    final query = ref.watch(syncedLyricsProvider(track));
    final value = query.asData?.value;
    final lines = value?.lyrics ?? const [];

    if (lines.isEmpty) return const SizedBox.shrink();

    // Locate the current line index from the current playback position.
    var currentIndex = 0;
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].time.inSeconds <= currentTime) {
        currentIndex = i;
      } else {
        break;
      }
    }

    final currentLine = lines[currentIndex].text.trim();
    final nextLine = currentIndex + 1 < lines.length
        ? lines[currentIndex + 1].text.trim()
        : null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.muted.withValues(alpha: 0.35),
        borderRadius: theme.borderRadiusLg,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            SangeetIcons.music,
            size: 16,
            color: theme.colorScheme.mutedForeground,
          ),
          const Gap(10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  currentLine.isNotEmpty ? currentLine : (nextLine ?? ''),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.base.copyWith(
                    color: theme.colorScheme.foreground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (nextLine != null && nextLine != currentLine) ...[
                  const Gap(2),
                  Text(
                    nextLine,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.small.copyWith(
                      color: theme.colorScheme.mutedForeground,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Gap(8),
          GestureDetector(
            onTap: () {
              // Rewind to the current lyric line's timestamp.
              audioPlayer.seek(lines[currentIndex].time);
            },
            child: Tooltip(
              tooltip: TooltipContainer(
                child: const Text('Jump to current lyric'),
              ).call,
              child: const Icon(
                SangeetIcons.play,
                size: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
