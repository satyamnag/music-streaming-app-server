import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sangeet/extensions/context.dart';
import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/provider/library/library_data_provider.dart';

/// A heart (like) button backed by the on-device liked-songs store.
///
/// Unlike the plugin-based [HeartButton], this works without any account:
/// clicking toggles the track in the local liked-songs table (outline heart ->
/// red filled heart) and the song shows up under "Liked Songs".
class LocalTrackHeartButton extends HookConsumerWidget {
  final SangeetTrackObject track;
  final ButtonSize size;
  const LocalTrackHeartButton({
    super.key,
    required this.track,
    this.size = ButtonSize.small,
  });

  @override
  Widget build(BuildContext context, ref) {
    final isLikedQuery = ref.watch(isLikedSongProvider(track.id));
    final isLiked = isLikedQuery.asData?.value ?? false;
    final isLoading = isLikedQuery.isLoading;

    // Pleasant heart "pop": when the track transitions to liked, the heart
    // briefly scales up beyond its normal size and settles back with an
    // easeOutBack bounce, so adding a song to "Liked Tracks" feels tactile
    // and responsive. Runs only on the transition to liked (not when the
    // screen first opens on an already-liked song).
    final wasLiked = usePrevious(isLiked);
    final popController = useAnimationController(
      duration: const Duration(milliseconds: 450),
      initialValue: 1.0,
    );
    final popScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.4)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.4, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 55,
      ),
    ]).animate(popController);

    useEffect(() {
      if (isLiked && !isLoading && wasLiked == false) {
        popController.forward(from: 0);
      }
      return null;
    }, [isLiked, isLoading, wasLiked, popController]);

    return Tooltip(
      tooltip: TooltipContainer(
        child: Text(
          isLiked
              ? context.l10n.remove_from_favorites
              : context.l10n.save_as_favorite,
        ),
      ).call,
      child: ScaleTransition(
        scale: popScale,
        child: IconButton(
          variance: ButtonVariance.ghost,
          size: size,
          enabled: !isLoading,
          icon: AnimatedSwitcher(
            switchInCurve: Curves.fastOutSlowIn,
            switchOutCurve: Curves.fastOutSlowIn,
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) {
              return ScaleTransition(scale: animation, child: child);
            },
            child: Icon(
              isLiked ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
              key: ValueKey(isLiked),
              color: isLiked ? Colors.red : null,
            ),
          ),
          onPressed: () async {
            if (isLiked) {
              await unlikeTrack(track.id);
            } else {
              await likeTrack(track.id);
            }
            ref.invalidate(likedSongsProvider);
          },
        ),
      ),
    );
  }
}
