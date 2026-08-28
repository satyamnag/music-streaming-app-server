import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sangeet/collections/spotube_icons.dart';
import 'package:sangeet/components/shimmers/shimmer_lyrics.dart';
import 'package:sangeet/extensions/context.dart';
import 'package:sangeet/models/lyrics.dart';
import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/modules/lyrics/use_synced_lyrics.dart';
import 'package:sangeet/provider/audio_player/audio_player.dart';
import 'package:sangeet/provider/lyrics/synced.dart';

/// A compact, self-contained lyric panel bound to a specific [track].
///
/// It fills the lower half of the [TrackPage] so the user can read and follow
/// the devotional text of the song they are looking at without opening the
/// full lyrics page. Behaviour:
///
///  * Shows the full set of lines, auto-scrolling to (and highlighting) the
///    line currently playing **when this exact track is the active one**.
///  * When another track is playing (or nothing is playing), it still shows
///    the lyrics statically so the devotional text is always available.
///  * Renders a clean "no lyrics" message when the app has none for the track.
///  * Renders nothing at all (shrink) when there is no track or the track has
///    no lyric content, so the page never shows a broken/empty box.
class TrackLyricsPanel extends HookConsumerWidget {
  final SangeetTrackObject? track;

  const TrackLyricsPanel({super.key, required this.track});

  @override
  Widget build(BuildContext context, ref) {
    final theme = Theme.of(context);
    final track = this.track;
    if (track == null) return const SizedBox.shrink();

    final playlist = ref.watch(audioPlayerProvider);
    final isActiveTrack = playlist.activeTrack?.id == track.id;

    final lyricsQuery = ref.watch(syncedLyricsProvider(track));
    final lyricsState = ref.watch(syncedLyricsMapProvider(track));
    final delay = ref.watch(syncedLyricsDelayProvider);

    final lyricsMap = lyricsState.asData?.value.lyricsMap ?? const <int, String>{};

    // Only sync timing when this exact track is actively playing; otherwise
    // render statically so timing never mismatches the wrong song.
    final currentTime = isActiveTrack
        ? useSyncedLyrics(ref, lyricsMap, delay)
        : -1;

    final value = lyricsQuery.asData?.value;
    final lines = value?.lyrics ?? const <LyricSlice>[];

    if (lines.isEmpty) {
      if (lyricsQuery.isLoading || lyricsQuery.isRefreshing) {
        return const ShimmerLyrics();
      }
      return _Message(
        icon: SangeetIcons.noLyrics,
        text: context.l10n.no_lyrics_available,
        color: theme.colorScheme.mutedForeground,
      );
    }

    var currentIndex = 0;
    if (isActiveTrack) {
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].time.inSeconds <= currentTime) {
          currentIndex = i;
        } else {
          break;
        }
      }
    }

    return _LyricsList(
      lines: lines,
      variants: value?.variants,
      currentIndex: isActiveTrack ? currentIndex : null,
      isActiveTrack: isActiveTrack,
    );
  }
}

/// Scrollable list of lyric lines with the active line highlighted and kept in
/// view. When [currentIndex] is null the list renders statically (no
/// highlight, no auto-scroll).
class _LyricsList extends HookWidget {
  final List<LyricSlice> lines;
  final List<LyricVariant>? variants;
  final int? currentIndex;
  final bool isActiveTrack;

  const _LyricsList({
    required this.lines,
    required this.variants,
    required this.currentIndex,
    required this.isActiveTrack,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = useScrollController();

    useEffect(() {
      if (currentIndex == null || !controller.hasClients) return;
      final target = lines.isEmpty
          ? 0.0
          : controller.position.maxScrollExtent *
              (currentIndex! / lines.length);
      controller.animateTo(
        target,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
      return null;
    }, [currentIndex, lines.length]);

    return ListView.builder(
      controller: controller,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      itemCount: lines.length,
      itemBuilder: (context, index) {
        final isActive = isActiveTrack && index == currentIndex;
        final text = lines[index].text.trim();
        if (text.isEmpty) return const SizedBox(height: 8);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 250),
            style: theme.typography.base.copyWith(
              color: isActive
                  ? theme.colorScheme.foreground
                  : theme.colorScheme.mutedForeground,
              fontWeight:
                  isActive ? FontWeight.w600 : FontWeight.normal,
              fontSize: isActive ? 18 : 16,
              height: 1.5,
            ),
            child: Text(
              text,
              textAlign: TextAlign.center,
            ),
          ),
        );
      },
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _Message({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              style: theme.typography.base.copyWith(color: color),
              textAlign: TextAlign.center,
            ),
            const Gap(18),
            Icon(icon, size: 48, color: color),
          ],
        ),
      ),
    );
  }
}
