import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sangeet/services/audio_player/audio_player.dart';
import 'package:sangeet/services/logger/logger.dart';

/// Returns the whole-second time of the LAST cue at or before [at] (binary
/// search over the sorted SRT cues), or null when [at] precedes all cues.
/// Pure and unit-tested in isolation.
int? activeSecondFor(List<Duration> sortedCues, Duration at) {
  var lo = 0;
  var hi = sortedCues.length - 1;
  var best = -1;
  while (lo <= hi) {
    final mid = (lo + hi) >> 1;
    if (sortedCues[mid] <= at) {
      best = mid;
      lo = mid + 1;
    } else {
      hi = mid - 1;
    }
  }
  return best >= 0 ? sortedCues[best].inSeconds : null;
}

int useSyncedLyrics(
  WidgetRef ref,
  Map<int, String> lyricsMap,
  int delay, {
  List<Duration>? cues,
}) {
  final stream = audioPlayer.positionStream;

  final currentTime = useState(0);

  useEffect(() {
    return stream.listen((pos) {
      try {
        final at = pos + Duration(seconds: delay);
        Duration? match;
        if (cues != null && cues.isNotEmpty) {
          // The ACTIVE lyric is the LAST cue at or before (position + delay),
          // matched at ms precision against the backend SRT. This replaces the
          // old whole-second containsKey check, which activated cues up to a
          // second early and held stale lines.
          final second = activeSecondFor(cues, at);
          if (second != null) match = Duration(seconds: second);
        } else if (lyricsMap.containsKey(at.inSeconds)) {
          match = Duration(seconds: at.inSeconds);
        }
        if (match != null) currentTime.value = match.inSeconds;
      } catch (e, stack) {
        AppLogger.reportError(e, stack);
      }
    }).cancel;
  }, [lyricsMap, delay, cues]);

  return (Duration(seconds: currentTime.value)).inSeconds;
}
