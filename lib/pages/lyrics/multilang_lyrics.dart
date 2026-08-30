import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';
import 'package:sangeet/collections/spotube_icons.dart';
import 'package:sangeet/components/shimmers/shimmer_lyrics.dart';
import 'package:sangeet/extensions/constrains.dart';
import 'package:sangeet/extensions/context.dart';
import 'package:sangeet/models/lyrics.dart';
import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/modules/lyrics/use_synced_lyrics.dart';
import 'package:sangeet/provider/lyrics/synced.dart';
import 'package:sangeet/services/audio_player/audio_player.dart';

/// Per-language display definition used across the multi-language lyrics tabs.
/// Each language gets its own [color] and [label] so a listener can
/// distinguish the five columns at a glance.
class LyricLanguageDef {
  final String key;
  final String label;
  final Color color;
  const LyricLanguageDef(this.key, this.label, this.color);
}

/// The five supported lyric languages, in display order. Keys map 1:1 to the
/// [LyricLanguages] constants and therefore to the server's `synced_lyrics_*`
/// columns.
const List<LyricLanguageDef> kLyricLanguages = [
  LyricLanguageDef(LyricLanguages.te, 'Telugu', Color(0xFFD4AF37)),
  LyricLanguageDef(
    LyricLanguages.en,
    'English Translation',
    Color(0xFF22C55E),
  ),
  LyricLanguageDef(LyricLanguages.hi, 'Hindi Translation', Color(0xFF43A047)),
  LyricLanguageDef(
    LyricLanguages.enTr,
    'English Transliteration',
    Color(0xFF2196F3),
  ),
  LyricLanguageDef(
    LyricLanguages.hiTr,
    'Hindi Transliteration',
    Color(0xFF8E24AA),
  ),
];

/// A small, appropriate icon for a lyric language (used in the Sync picker).
Widget _langIcon(String key, Color color) => switch (key) {
      LyricLanguages.te => Text(
          'అ',
          style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w600, height: 1),
        ),
      LyricLanguages.enTr => Text(
          'Aa',
          style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w600, height: 1),
        ),
      LyricLanguages.hiTr => Text(
          'अ',
          style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w600, height: 1),
        ),
      LyricLanguages.en || LyricLanguages.hi =>
        Icon(Icons.translate, size: 16, color: color),
      _ => const SizedBox.shrink(),
    };

/// Derives the plain (timestamp-free) text for a single language from the
/// aligned multi-language [variants]. Returns an empty string when the track
/// has no text for that language.
///
/// Telugu additionally falls back to the track's primary [lyrics] (the server's
/// `lyrics`/synced-main column) so older cached lyrics without `variants` still
/// show something in the "Telugu Lyrics" tab.
String plainLyricTextFor(SubtitleSimple? subtitle, String lang) {
  final variants = subtitle?.variants;
  if (variants != null && variants.isNotEmpty) {
    final buf = <String>[];
    for (final v in variants) {
      final t = LyricLanguages.fieldOf(v, lang).trim();
      if (t.isNotEmpty) buf.add(t);
    }
    if (buf.isNotEmpty) return buf.join('\n');
  }

  if (lang == LyricLanguages.te) {
    final texts = (subtitle?.lyrics ?? const <LyricSlice>[])
        .map((l) => l.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    return texts.join('\n');
  }

  return '';
}

/// A simple, friendly "no lyrics" empty state.
class _NoLyrics extends StatelessWidget {
  const _NoLyrics();

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
              context.l10n.no_lyrics_available,
              style: theme.typography.base.copyWith(
                color: theme.colorScheme.mutedForeground,
              ),
              textAlign: TextAlign.center,
            ),
            const Gap(18),
            Icon(
              SangeetIcons.noLyrics,
              size: 52,
              color: theme.colorScheme.mutedForeground,
            ),
          ],
        ),
      ),
    );
  }
}

/// The admin-stored plain lyrics for [lang] on [track], or null when the track
/// has none for that language. When present, the Plain tab shows this text
/// (authored in the admin) instead of deriving it from the synced variants.
String? plainForTrack(SangeetTrackObject? track, String lang) {
  if (track is! SangeetFullTrackObject) return null;
  return switch (lang) {
    LyricLanguages.te => track.plainLyrics,
    LyricLanguages.en => track.plainLyricsEn,
    LyricLanguages.hi => track.plainLyricsHi,
    LyricLanguages.enTr => track.plainLyricsEnTr,
    LyricLanguages.hiTr => track.plainLyricsHiTr,
    _ => null,
  };
}

/// Builder wrapper that observes the lyrics provider for one plain language.
class PlainLanguageViewBuilder extends HookConsumerWidget {
  final SangeetTrackObject? track;
  final String lang;

  const PlainLanguageViewBuilder({
    super.key,
    required this.track,
    required this.lang,
  });

  @override
  Widget build(BuildContext context, ref) {
    final theme = Theme.of(context);
    final query = ref.watch(syncedLyricsProvider(track));
    final subtitle = query.asData?.value;

    if (track == null) return const _NoLyrics();

    if (query.isLoading || query.isRefreshing) {
      return const ShimmerLyrics();
    }

    if (query.hasError) {
      return const _NoLyrics();
    }

    // Prefer admin-authored plain lyrics for the language; otherwise derive
    // from the synced variants (backward compatible).
    final stored = plainForTrack(track, lang)?.trim();
    final text = (stored != null && stored.isNotEmpty)
        ? stored
        : plainLyricTextFor(subtitle, lang);
    if (text.isEmpty) return const _NoLyrics();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: SelectableText(
            text,
            textAlign: TextAlign.center,
            style: theme.typography.base.copyWith(
              color: theme.colorScheme.foreground,
              fontSize: 20,
              height: 1.9,
            ),
          ),
        ),
      ),
    );
  }
}

/// Multi-language, synchronized lyrics view with a language selector and
/// playback-synced highlighting + auto-scroll + tap-to-seek.
class SyncedLanguageView extends HookConsumerWidget {
  final SangeetTrackObject? track;
  final ValueNotifier<Set<String>> selected;

  const SyncedLanguageView({
    super.key,
    required this.track,
    required this.selected,
  });

  @override
  Widget build(BuildContext context, ref) {
    if (track == null) return const _NoLyrics();

    final delay = ref.watch(syncedLyricsDelayProvider);
    final query = ref.watch(syncedLyricsProvider(track));
    final subtitle = query.asData?.value;
    final mapState = ref.watch(syncedLyricsMapProvider(track));
    final lyricsMap = mapState.asData?.value.lyricsMap ?? const <int, String>{};

    final currentTime = useSyncedLyrics(ref, lyricsMap, delay);

    if (query.isLoading || query.isRefreshing) {
      return const ShimmerLyrics();
    }
    if (query.hasError) return const _NoLyrics();

    final variants = subtitle?.variants ?? const <LyricVariant>[];
    final hasData =
        variants.any((v) => kLyricLanguages.any(
              (d) => selected.value.contains(d.key) &&
                  LyricLanguages.fieldOf(v, d.key).trim().isNotEmpty,
            ));

    return Column(
      children: [
        Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: LanguageMultiSelect(selected: selected),
          ),
        ),
        Expanded(
          child: variants.isEmpty
              ? const _NoLyrics()
              : _SyncedLines(
                  variants: variants,
                  selected: selected,
                  currentTime: Duration(seconds: currentTime),
                  hasData: hasData,
                ),
        ),
      ],
    );
  }
}

/// Playback-synced scrollable list. Highlights and keeps in view the current
/// line, and taps seek.
class _SyncedLines extends HookWidget {
  final List<LyricVariant> variants;
  final ValueNotifier<Set<String>> selected;
  final Duration currentTime;
  final bool hasData;

  const _SyncedLines({
    required this.variants,
    required this.selected,
    required this.currentTime,
    required this.hasData,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Current line index = last variant whose time is at/before now.
    var currentIndex = 0;
    for (var i = 0; i < variants.length; i++) {
      if (variants[i].time <= currentTime) {
        currentIndex = i;
      } else {
        break;
      }
    }

    final controller = useScrollController();

    useEffect(() {
      if (!controller.hasClients || variants.isEmpty) return;
      final target = controller.position.maxScrollExtent *
          (currentIndex / variants.length);
      controller.animateTo(
        target,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
      return null;
    }, [currentIndex, variants.length]);

    if (!hasData) return const _NoLyrics();

    return ListView.builder(
      controller: controller,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: variants.length,
      itemBuilder: (context, index) {
        final variant = variants[index];
        final isActive = index == currentIndex;

        final blocks = <Widget>[];
        for (final def in kLyricLanguages) {
          if (!selected.value.contains(def.key)) continue;
          final text = LyricLanguages.fieldOf(variant, def.key).trim();
          if (text.isEmpty) continue;
          blocks.add(
            _LangBlock(def: def, text: text, isActive: isActive),
          );
        }

        if (blocks.isEmpty) return const SizedBox(height: 8);

        return GestureDetector(
          onTap: () {
            if (variant.time.isNegative ||
                variant.time > audioPlayer.duration) {
              return;
            }
            audioPlayer.seek(variant.time);
          },
          behavior: HitTestBehavior.translucent,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isActive
                  ? theme.colorScheme.primary.withValues(alpha: 0.08)
                  : Colors.transparent,
              borderRadius: theme.borderRadiusMd,
              border: Border(
                left: BorderSide(
                  width: 3,
                  color: isActive
                      ? theme.colorScheme.primary
                      : Colors.transparent,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: blocks,
            ),
          ),
        );
      },
    );
  }
}

/// One language's text inside a synced block: a colored label chip followed by
/// the language's text, so the five languages are instantly distinguishable.
class _LangBlock extends StatelessWidget {
  final LyricLanguageDef def;
  final String text;
  final bool isActive;

  const _LangBlock({
    required this.def,
    required this.text,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Each language is identified purely by its colour, so no language-name
    // label is shown on the lyric lines.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: theme.typography.base.copyWith(
          color: def.color,
          fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
          fontSize: 16,
          height: 1.5,
        ),
      ),
    );
  }
}

/// Multi-select dropdown (desktop) / bottom drawer (mobile) for choosing which
/// languages appear in the "Synced Lyrics" tab. Enforces a minimum of one and
/// a maximum of five selections, defaulting to Telugu.
class LanguageMultiSelect extends HookConsumerWidget {
  final ValueNotifier<Set<String>> selected;

  const LanguageMultiSelect({super.key, required this.selected});

  void _toggle(BuildContext context, String key) {
    final cur = {...selected.value};
    if (cur.contains(key)) {
      if (cur.length <= 1) return; // keep at least one
      cur.remove(key);
    } else {
      cur.add(key);
    }
    selected.value = cur;
  }

  Widget _row(BuildContext context, LyricLanguageDef def) {
    return Button.ghost(
      style: ButtonVariance.ghost.copyWith(
        padding: (context, _, __) =>
            const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      ),
      trailing: ValueListenableBuilder<Set<String>>(
        valueListenable: selected,
        builder: (context, sel, _) => Checkbox(
          state: sel.contains(def.key)
              ? CheckboxState.checked
              : CheckboxState.unchecked,
          activeColor: def.color,
          onChanged: (_) => _toggle(context, def.key),
        ),
      ),
      onPressed: () => _toggle(context, def.key),
      child: Padding(
        padding: const EdgeInsets.only(left: 6),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _langIcon(def.key, def.color),
              const SizedBox(width: 8),
              Text(def.label),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, ref) {
    return ValueListenableBuilder<Set<String>>(
      valueListenable: selected,
      builder: (context, sel, _) {
        final summary = sel.isEmpty
            ? context.l10n.synced
            : '${sel.length} ${_lang(sel.length)}';

        return Tooltip(
          tooltip: TooltipContainer(
            child: Text(context.l10n.synced),
          ).call,
          child: Button.outline(
            child: Text(summary),
            onPressed: () {
              final mediaQuery = MediaQuery.of(context);
              final rows = List<Widget>.generate(
                kLyricLanguages.length,
                (i) => _row(context, kLyricLanguages[i]),
              );

              if (mediaQuery.mdAndUp) {
                showPopover(
                  alignment: Alignment.bottomCenter,
                  context: context,
                  builder: (context) {
                    return SurfaceCard(
                      padding: EdgeInsets.zero,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 320),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: rows,
                        ),
                      ),
                    );
                  },
                );
              } else {
                openDrawer(
                  context: context,
                  draggable: true,
                  showDragHandle: true,
                  position: OverlayPosition.bottom,
                  borderRadius: context.theme.borderRadiusMd,
                  transformBackdrop: false,
                  builder: (context) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: rows,
                      ),
                    );
                  },
                );
              }
            },
          ),
        );
      },
    );
  }

  String _lang(int n) => n == 1 ? 'language' : 'languages';
}
