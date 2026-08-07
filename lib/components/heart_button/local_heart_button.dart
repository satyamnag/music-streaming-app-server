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

    return Tooltip(
      tooltip: TooltipContainer(
        child: Text(
          isLiked
              ? context.l10n.remove_from_favorites
              : context.l10n.save_as_favorite,
        ),
      ).call,
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
    );
  }
}
