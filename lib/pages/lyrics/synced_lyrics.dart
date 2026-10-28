import 'dart:async';

import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sangeet/collections/spotube_icons.dart';
import 'package:sangeet/components/lyrics/lyrics_active_line_capsule.dart';
import 'package:sangeet/components/lyrics/lyrics_music_banner.dart';
import 'package:sangeet/modules/lyrics/lyrics_auto_center.dart';
import 'package:sangeet/modules/lyrics/lyrics_markup.dart';
import 'package:sangeet/modules/lyrics/zoom_controls.dart';
import 'package:sangeet/components/shimmers/shimmer_lyrics.dart';
import 'package:sangeet/extensions/constrains.dart';
import 'package:sangeet/extensions/context.dart';
import 'package:sangeet/hooks/controllers/use_auto_scroll_controller.dart';
import 'package:sangeet/models/lyrics.dart';
import 'package:sangeet/modules/lyrics/use_synced_lyrics.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:sangeet/provider/audio_player/audio_player.dart';
import 'package:sangeet/provider/lyrics/synced.dart';
import 'package:sangeet/services/audio_player/audio_player.dart';
import 'package:sangeet/services/logger/logger.dart';

class SyncedLyrics extends HookConsumerWidget {
  final PaletteColor palette;
  final bool? isModal;
  final int defaultTextZoom;

  const SyncedLyrics({
    required this.palette,
    this.isModal,
    this.defaultTextZoom = 100,
    super.key,
  });

  @override
  Widget build(BuildContext context, ref) {
    final mediaQuery = MediaQuery.sizeOf(context);

    final playlist = ref.watch(audioPlayerProvider);

    final controller = useAutoScrollController();

    final delay = ref.watch(syncedLyricsDelayProvider);

    final timedLyricsQuery =
        ref.watch(syncedLyricsProvider(playlist.activeTrack));

    final lyricValue = timedLyricsQuery.asData?.value;

    final lyricsState = ref.watch(
      syncedLyricsMapProvider(playlist.activeTrack),
    );
    final currentTime = useSyncedLyrics(
      ref,
      lyricsState.asData?.value.lyricsMap ?? {},
      delay,
      cues: lyricsState.asData?.value.cues ?? const [],
    );
    final textZoomLevel = useState<int>(defaultTextZoom);

    // Which line is playing.
    //
    // The highlight itself is still decided per item (a slice is active when its
    // second matches, so slices that share a second all light up); this index is
    // the one line the view pins to the centre - the first of any duplicates,
    // which is the line a reader would call "the current one".
    final activeIndex = lyricValue == null
        ? -1
        : lyricValue.lyrics
            .indexWhere((line) => line.time.inSeconds == currentTime);

    final typography = Theme.of(context).typography;

    ref.listen(
      audioPlayerProvider.select((s) => s.activeTrack),
      (previous, next) {
        controller.animateTo(
          0,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
        ref.read(syncedLyricsDelayProvider.notifier).state = 0;
      },
    );

    // Pin the singing line to a FIXED point in the middle of the view, so the
    // lines above it travel upward as the track plays and the reader's eye never
    // has to chase the highlight.
    //
    // Runs when the active line changes, and when the reader changes the text
    // zoom - zoom changes every line's height, which would otherwise leave the
    // centred line off-centre. Post-frame, so the line is measured at its final
    // size: the active line is drawn larger than its neighbours, and centring
    // before that growth has been laid out leaves it a few pixels low.
    useEffect(() {
      if (activeIndex < 0) return null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        LyricsAutoCenter.centerOnLine(controller, activeIndex);
      });
      return null;
    }, [activeIndex, textZoomLevel.value]);

    final headlineTextStyle = (mediaQuery.mdAndUp
            ? typography.h3
            : typography.h4.copyWith(fontSize: 25))
        .copyWith(
      color: palette.titleTextColor,
    );

    final bodyTextTheme = typography.large.copyWith(
      color: palette.bodyTextColor,
    );

    // Ink for every synced lyric line, and the halo that keeps it legible where
    // the album art behind it is uneven.
    //
    // `bodyTextColor` is the colour palette_generator computed for a guaranteed
    // 4.5:1 against `palette.color` — and `palette.color` at 70% over the blurred
    // card is what the lyrics are actually drawn on, so it is the only colour here
    // with a guarantee attached. The halo is the OPPOSITE shade of the ink (white
    // text gets a dark halo and vice versa), the same trick the home header uses
    // over its wallpaper, so a glyph never loses its edge against a bright or busy
    // patch of artwork.
    final lyricColor = palette.bodyTextColor;
    final lyricShadow = Shadow(
      color: lyricColor.computeLuminance() > 0.5
          ? const Color(0x8A000000)
          : const Color(0x8AFFFFFF),
      blurRadius: 6,
    );

    useEffect(() {
      StreamSubscription? subscription;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        subscription = audioPlayer.positionStream.listen((event) {
          try {
            if (event > Duration.zero || !controller.hasClients) return;
            controller.animateTo(
              0,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
            );
          } catch (e, stack) {
            AppLogger.reportError(e, stack);
          }
        });
      });

      return subscription?.cancel;
    }, [controller]);

    return Stack(
      children: [
        CustomScrollView(
          controller: controller,
          slivers: [
            if (isModal != true)
              SliverAppBar(
                automaticallyImplyLeading: false,
                backgroundColor: Colors.transparent,
                centerTitle: true,
                title: Text(
                  playlist.activeTrack?.name ?? context.l10n.not_playing,
                  style: headlineTextStyle,
                ),
                bottom: const PreferredSize(
                  preferredSize: Size.fromHeight(0),
                  child: SizedBox.shrink(),
                ),
              ),
            if (lyricValue != null &&
                lyricValue.lyrics.isNotEmpty &&
                lyricsState.asData?.value.static != true) ...[
              // Half a window of empty space above the first line and below the
              // last. Without it only the MIDDLE of a song could put its line in
              // the centre - the first line could never travel down to the focal
              // point, nor the last one up to it. Sized from the window rather
              // than the viewport because the viewport's height is only known
              // after layout, and being slightly generous costs nothing: the
              // centre itself is set exactly by LyricsAutoCenter.
              SliverToBoxAdapter(
                child: SizedBox(height: mediaQuery.height / 2),
              ),
              SliverList.builder(
                itemCount: lyricValue.lyrics.length,
                itemBuilder: (context, index) {
                  final lyricSlice = lyricValue.lyrics[index];
                  final isActive = lyricSlice.time.inSeconds == currentTime;
                  final variant = (lyricValue.variants != null &&
                          index < lyricValue.variants!.length)
                      ? lyricValue.variants![index]
                      : null;
                  final subLines = variant == null
                      ? const <String>[]
                      : [
                          for (final lang in LyricLanguages.order)
                            if (lang != LyricLanguages.te) //
                              LyricLanguages.fieldOf(variant, lang),
                        ].where((t) => t.trim().isNotEmpty).toList();

                  // A line the author wrapped in double braces ({{Music}})
                  // renders as a short "♪ Music ♪" banner instead of sung text.
                  // Checked before the empty-line branch so a banner is never
                  // swallowed as a spacer.
                  final marked = parseMarkedLyricsLine(lyricSlice.text);

                  // The scroll that keeps this line centred is NOT started here
                  // any more. It runs from one post-frame effect (the
                  // LyricsAutoCenter call above): a scroll begun inside
                  // itemBuilder runs during build, against the package's
                  // estimated row height, and can fire again for every rebuild
                  // of the active line.
                  return AutoScrollTag(
                    key: ValueKey(index),
                    index: index,
                    controller: controller,
                    child: marked.mark == LyricsLineMark.banner
                        ? Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8.0,
                              vertical: 4.0,
                            ),
                            child: LyricsMusicBanner(label: marked.label),
                          )
                        : lyricSlice.text.isEmpty && subLines.isEmpty
                            // A blank lyric line is a stanza break: it takes no
                            // height of its own, and the padding on its
                            // neighbours supplies the gap. The old special case
                            // that gave the LAST line half a screen of height is
                            // gone - the sliver after the list is that spacer
                            // now, and applies at both ends rather than only at
                            // the bottom.
                            ? const SizedBox.shrink()
                        : Center(
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 250),
                                style: TextStyle(
                                  // The palette's OWN body colour, for every line.
                                  //
                                  // The lyric backdrop is album-art derived — the
                                  // blurred card plus `palette.color` at 70% — and
                                  // palette_generator picks black or white for a
                                  // guaranteed 4.5:1 against exactly that colour.
                                  // The theme's `foreground` is chosen against the
                                  // app surface instead, and its `mutedForeground`
                                  // is a mid grey that lands well under 4.5:1 here,
                                  // which is why the inactive lines and the
                                  // translations used to be hard to read.
                                  //
                                  // The active line is distinguished by SIZE and
                                  // WEIGHT rather than by dimming the others, because
                                  // dimming is precisely what costs contrast.
                                  //
                                  // The playing line is the one exception, and not
                                  // for emphasis: it sits ON the cream capsule, where
                                  // the palette ink - chosen against the artwork -
                                  // would be white on cream. The capsule owns its
                                  // surface, so it supplies its own ink.
                                  color: isActive
                                      ? LyricsActiveLineCapsule.ink
                                      : lyricColor,
                                  // No halo under the capsule: the pill is the
                                  // backdrop there, and a shadowed glyph on cream
                                  // reads as a smudge rather than a highlight.
                                  shadows: isActive
                                      ? const <Shadow>[]
                                      : [lyricShadow],
                                  fontWeight: isActive
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  // The playing line is clearly ZOOMED for
                                  // instant recognition.
                                  fontSize: (isActive ? 30 : 24) *
                                      (textZoomLevel.value / 100),
                                  height: isActive ? 1.35 : 1.25,
                                ),
                                textAlign: TextAlign.center,
                                child: MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: GestureDetector(
                                    onTap: () async {
                                      final time = Duration(
                                        seconds:
                                            lyricSlice.time.inSeconds - delay,
                                      );
                                      if (time > audioPlayer.duration ||
                                          time.isNegative) {
                                        return;
                                      }
                                      audioPlayer.seek(time);
                                    },
                                    child: isActive
                                        // The line that is playing is drawn
                                        // inside the cream capsule, on its own
                                        // dark ink - the reference design's
                                        // highlight, built from the colours the
                                        // lyric decorations already use.
                                        ? LyricsActiveLineCapsule(
                                            child: _SyncedLine(
                                              mainText: lyricSlice.text,
                                              subLines: subLines,
                                              color: LyricsActiveLineCapsule.ink,
                                              mainFontSize: (isActive ? 28 : 26) *
                                                  (textZoomLevel.value / 100),
                                            ),
                                          )
                                        : _SyncedLine(
                                            mainText: lyricSlice.text,
                                            subLines: subLines,
                                            color: lyricColor,
                                            mainFontSize: (isActive ? 28 : 26) *
                                                (textZoomLevel.value / 100),
                                          ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                  );
                },
              ),
              // The matching half-window below the last line, so the final line
              // of a song can reach the centre too.
              SliverToBoxAdapter(
                child: SizedBox(height: mediaQuery.height / 2),
              ),
            ],
            if (playlist.activeTrack != null &&
                (timedLyricsQuery.isLoading || timedLyricsQuery.isRefreshing))
              const SliverToBoxAdapter(child: ShimmerLyrics())
            else if (playlist.activeTrack != null &&
                (timedLyricsQuery.hasError)) ...[
              SliverToBoxAdapter(
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    context.l10n.no_lyrics_available,
                    style: bodyTextTheme,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SliverGap(26),
              const SliverToBoxAdapter(
                child: Icon(SangeetIcons.noLyrics, size: 60),
              ),
            ] else if (lyricsState.asData?.value.static == true)
              SliverFillRemaining(
                child: Center(
                  child: RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: bodyTextTheme,
                      children: [
                        TextSpan(
                          text: context.l10n.synced_lyrics_not_available,
                        ),
                        TextSpan(
                          text: " ${context.l10n.plain_lyrics} ",
                          style: typography.large.copyWith(
                            color: palette.bodyTextColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextSpan(text: context.l10n.tab_instead),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        Align(
          alignment: Alignment.bottomRight,
          child: Builder(builder: (context) {
            final actions = [
              ZoomControls(
                value: delay,
                onChanged: (value) =>
                    ref.read(syncedLyricsDelayProvider.notifier).state = value,
                interval: 1,
                unit: "s",
                increaseIcon: const Icon(SangeetIcons.add),
                decreaseIcon: const Icon(SangeetIcons.remove),
                direction: isModal == true ? Axis.horizontal : Axis.vertical,
              ),
              ZoomControls(
                value: textZoomLevel.value,
                onChanged: (value) => textZoomLevel.value = value,
                min: 50,
                max: 200,
              ),
            ];

            return isModal == true
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: actions,
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: actions,
                  );
          }),
        ),
      ],
    );
  }
}

/// Renders one synced lyric line. [mainText] is the Telugu (or primary) line shown
/// large; [subLines] carries the non-empty English/Hindi translations &
/// transliterations rendered smaller beneath it. When there are no sub-lines it
/// simply renders the single [mainText].
class _SyncedLine extends StatelessWidget {
  final String mainText;
  final List<String> subLines;

  /// Ink for the translation sub-lines.
  ///
  /// [mainText] deliberately carries NO style of its own. It inherits colour,
  /// weight and size from the [AnimatedDefaultTextStyle] that wraps this widget,
  /// which is where the active/inactive distinction lives — passing colours in
  /// here as well would look like it controlled the main line while doing nothing.
  final Color color;

  final double mainFontSize;

  const _SyncedLine({
    required this.mainText,
    required this.subLines,
    required this.color,
    required this.mainFontSize,
  });

  @override
  Widget build(BuildContext context) {
    if (subLines.isEmpty) {
      return Text(mainText);
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(mainText),
        const Gap(6),
        for (final line in subLines)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              line,
              style: TextStyle(
                fontSize: (mainFontSize * 0.62),
                // The SAME ink as the main line, at ~62% of its size. These used
                // to be a muted grey at 70% opacity on the inactive lines, which
                // was the lowest-contrast text on the screen and the hardest to
                // read; a translation is not decoration.
                color: color,
                fontWeight: FontWeight.normal,
              ),
            ),
          ),
      ],
    );
  }
}
