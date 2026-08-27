import 'package:collection/collection.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';
import 'package:sangeet/collections/spotube_icons.dart';
import 'package:sangeet/models/lyrics.dart';
import 'package:sangeet/modules/lyrics/zoom_controls.dart';
import 'package:sangeet/components/shimmers/shimmer_lyrics.dart';
import 'package:sangeet/extensions/constrains.dart';
import 'package:sangeet/extensions/context.dart';

import 'package:sangeet/provider/audio_player/audio_player.dart';
import 'package:sangeet/provider/lyrics/synced.dart';

class PlainLyrics extends HookConsumerWidget {
  final PaletteColor palette;
  final bool? isModal;
  final int defaultTextZoom;
  const PlainLyrics({
    required this.palette,
    this.isModal,
    this.defaultTextZoom = 100,
    super.key,
  });

  @override
  Widget build(BuildContext context, ref) {
    final playlist = ref.watch(audioPlayerProvider);
    final lyricsQuery = ref.watch(syncedLyricsProvider(playlist.activeTrack));
    final mediaQuery = MediaQuery.of(context);
    final typography = Theme.of(context).typography;

    final textZoomLevel = useState<int>(defaultTextZoom);

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isModal != true) ...[
              Center(
                child: Text(
                  playlist.activeTrack?.name ?? "",
                  style: mediaQuery.mdAndUp
                      ? typography.h3
                      : typography.h4.copyWith(
                          color: palette.titleTextColor,
                        ),
                ),
              ),
            ],
            Expanded(
              child: SingleChildScrollView(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Builder(
                      builder: (context) {
                        if (lyricsQuery.isLoading || lyricsQuery.isRefreshing) {
                          return const ShimmerLyrics();
                        } else if (lyricsQuery.hasError) {
                          return Container(
                            alignment: Alignment.center,
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  context.l10n.no_lyrics_available,
                                  style: typography.large.copyWith(
                                    color: palette.bodyTextColor,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const Gap(26),
                                const Icon(SangeetIcons.noLyrics, size: 60),
                              ],
                            ),
                          );
                        }

                        final subtitle = lyricsQuery.asData?.value;
                        final variants = subtitle?.variants;

                        // When multi-language variants exist, render a clean
                        // labelled block per timestamp (Telugu + English/Hindi
                        // translations & transliterations). Otherwise fall back
                        // to the existing single-language plain text.
                        if (variants != null && variants.isNotEmpty) {
                          return AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            style: TextStyle(
                              color: isModal == true
                                  ? context.theme.colorScheme.foreground
                                  : palette.bodyTextColor,
                              fontSize: 20 * textZoomLevel.value / 100,
                              height: 1.9,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (final variant in variants)
                                  _PlainVariantBlock(
                                    variant: variant,
                                    zoom: textZoomLevel.value,
                                    color: isModal == true
                                        ? context.theme.colorScheme.foreground
                                        : palette.bodyTextColor,
                                  ),
                              ],
                            ),
                          );
                        }

                        final lyrics =
                            subtitle!.lyrics.mapIndexed((i, e) {
                          final next = subtitle.lyrics.elementAtOrNull(i + 1);
                          if (next != null &&
                              e.time - next.time >
                                  const Duration(milliseconds: 700)) {
                            return "${e.text}\n";
                          }

                          return e.text;
                        }).join("\n");

                        return AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: TextStyle(
                            color: isModal == true
                                ? context.theme.colorScheme.foreground
                                : palette.bodyTextColor,
                            fontSize: 24 * textZoomLevel.value / 100,
                            height: textZoomLevel.value < 70
                                ? 1.5
                                : textZoomLevel.value > 150
                                    ? 1.7
                                    : 2,
                          ),
                          child: SelectableText(
                            playlist.activeTrack == null
                                ? context.l10n.no_tracks_playing
                                : lyrics,
                            textAlign: TextAlign.center,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        Align(
          alignment: Alignment.bottomRight,
          child: ZoomControls(
            value: textZoomLevel.value,
            onChanged: (value) => textZoomLevel.value = value,
            min: 50,
            max: 200,
          ),
        ),
      ],
    );
  }
}

/// Renders one plain (all-languages) block for a single timestamp: the Telugu
/// text plus the English / Hindi translations & transliterations, each with a
/// muted heading so a listener can read the full multi-language set at a
/// glance. Blank language values are omitted so the block stays clean.
class _PlainVariantBlock extends StatelessWidget {
  final LyricVariant variant;
  final int zoom;
  final Color color;

  const _PlainVariantBlock({
    required this.variant,
    required this.zoom,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final headingStyle = TextStyle(
      fontSize: (20 * zoom / 100) * 0.72,
      color: theme.colorScheme.mutedForeground,
      fontWeight: FontWeight.w600,
    );
    final bodyStyle = TextStyle(
      fontSize: 20 * zoom / 100,
      height: 1.6,
      color: color,
    );

    final rows = <({String label, String text})>[
      (label: 'Telugu', text: variant.te),
      (label: 'English (Translation)', text: variant.en),
      (label: 'Hindi (Translation)', text: variant.hi),
      (label: 'English (Transliteration)', text: variant.enTr),
      (label: 'Hindi (Transliteration)', text: variant.hiTr),
    ].where((row) => row.text.trim().isNotEmpty).toList();

    if (rows.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final row in rows) ...[
            Text(row.label, style: headingStyle),
            const Gap(3),
            SelectableText(row.text, style: bodyStyle),
            const Gap(8),
          ],
        ],
      ),
    );
  }
}
