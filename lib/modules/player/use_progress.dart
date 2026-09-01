import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sangeet/provider/audio_player/audio_player.dart';
import 'package:sangeet/services/audio_player/audio_player.dart';

({
  double progressStatic,
  Duration position,
  Duration duration,
  double bufferProgress
}) useProgress(WidgetRef ref) {
  final bufferProgress =
      useStream(audioPlayer.bufferedPositionStream).data?.inSeconds ?? 0;

  final duration = useState(Duration.zero);
  final position = useState(Duration.zero);

  // Re-sync whenever the active track changes, so a newly loaded song's
  // duration and position are picked up (and the previous track's values are
  // not carried over).
  final activeTrackId = ref.watch(
    (audioPlayerProvider).select((s) => s.activeTrack?.id),
  );

  final sliderMax = duration.value.inSeconds;
  final sliderValue = position.value.inSeconds;

  useEffect(() {
    // Ensure the engine's position/duration getters reflect the current track.
    duration.value = audioPlayer.duration;
    position.value = audioPlayer.position;

    final durationSubscription = audioPlayer.durationStream.listen((event) {
      duration.value = event;
    });

    final positionSubscription = audioPlayer.positionStream.listen((event) {
      position.value = event;
    });

    return () {
      positionSubscription.cancel();
      durationSubscription.cancel();
    };
  }, [activeTrackId]);

  return (
    progressStatic:
        sliderMax == 0 || sliderValue > sliderMax ? 0 : sliderValue / sliderMax,
    position: position.value,
    duration: duration.value,
    bufferProgress: sliderMax == 0 || bufferProgress > sliderMax
        ? 0
        : bufferProgress / sliderMax,
  );
}
