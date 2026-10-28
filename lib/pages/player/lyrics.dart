import 'package:auto_route/annotations.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sangeet/collections/spotube_icons.dart';
import 'package:sangeet/components/button/back_button.dart';
import 'package:sangeet/components/lyrics/lyrics_active_line_capsule.dart';
import 'package:sangeet/components/lyrics/lyrics_music_banner.dart';
import 'package:sangeet/extensions/context.dart';
import 'package:sangeet/hooks/controllers/use_auto_scroll_controller.dart';
import 'package:sangeet/models/lyrics.dart';
import 'package:sangeet/modules/lyrics/lyrics_auto_center.dart';
import 'package:sangeet/modules/lyrics/lyrics_markup.dart';
import 'package:sangeet/pages/lyrics/multilang_lyrics.dart';
import 'package:sangeet/provider/audio_player/audio_player.dart';
import 'package:sangeet/provider/lyrics/synced.dart';
import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/modules/lyrics/use_synced_lyrics.dart';
import 'package:sangeet/services/audio_player/audio_player.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

@RoutePage()
class PlayerLyricsPage extends HookConsumerWidget {
  const PlayerLyricsPage({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final playlist = ref.watch(audioPlayerProvider);
    final track = playlist.activeTrack;
    final topTab = useState(0); // 0=Plain, 1=Sync
    final plainSub = useState(0);
    final syncSub = useState(0);

    final query = ref.watch(syncedLyricsProvider(track));
    final subtitle = query.asData?.value;
    final isLoading = query.isLoading || query.isRefreshing;
    final mapState = ref.watch(syncedLyricsMapProvider(track));
    // `static` is true when the lyrics have no timestamps (i.e. they are plain,
    // not synced). The Sync tab must only list timed/synced lyrics.
    final isStatic = mapState.asData?.value.static ?? true;

    bool hasPlain(String lang) {
      final stored = plainForTrack(track, lang)?.trim();
      if (stored != null && stored.isNotEmpty) return true;
      return plainLyricTextFor(subtitle, lang).trim().isNotEmpty;
    }

    bool hasSync(String lang) {
      // Plain (static, untimed) variants are NOT synced lyrics; they must only
      // appear on the Plain tab, never the Sync tab.
      if (isStatic) return false;
      final variants = subtitle?.variants ?? const <LyricVariant>[];
      if (variants.isEmpty) return false;
      for (final v in variants) {
        if (LyricLanguages.fieldOf(v, lang).trim().isNotEmpty) return true;
      }
      return false;
    }

    // All 5 languages in display order.
    //
    // The order is Telugu, then English TRANSLITERATION, then English
    // TRANSLATION, then the Hindi pair - the same order `kLyricLanguages` uses
    // and the same order the plain-lyrics blocks use.
    //
    // This list previously read `te, en, hi, enTr, hiTr`, i.e. both TRANSLATIONS
    // before both TRANSLITERATIONS, while its comment claimed it "matches
    // kLyricLanguages". It did not, so the Plain and Sync sub-tabs read
    // "Telugu, English (Translation), English (Transliteration)" - the exact
    // reversal reported. The comment is what let it survive review: it asserted
    // the list was already correct, so nobody re-read the list.
    //
    // Transliteration-first is the deliberate rule (see `kLyricLanguages`): a
    // listener reads the original script, then how it sounds, then what it
    // means. Ordering is asserted by `lyrics_subtab_order_test.dart`, which
    // compares this sequence against `kLyricLanguages` so the two cannot drift
    // apart again.
    const allLangs = [
      LyricLanguages.te,
      LyricLanguages.enTr,
      LyricLanguages.en,
      LyricLanguages.hiTr,
      LyricLanguages.hi,
    ];

    final availablePlain =
        isLoading ? allLangs : allLangs.where(hasPlain).toList();
    final availableSync =
        isLoading ? allLangs : allLangs.where(hasSync).toList();

    final hasAnyPlain = availablePlain.isNotEmpty;
    final hasAnySync = availableSync.isNotEmpty;

    useEffect(() {
      if (plainSub.value >= availablePlain.length &&
          availablePlain.isNotEmpty) {
        plainSub.value = 0;
      }
      if (syncSub.value >= availableSync.length && availableSync.isNotEmpty) {
        syncSub.value = 0;
      }
      return null;
    }, [availablePlain.length, availableSync.length]);

    final theme = Theme.of(context);

    Widget plainIcon(bool selected) => Icon(
          Icons.menu_book,
          size: 18,
          color: selected
              ? theme.colorScheme.primary
              : theme.colorScheme.mutedForeground,
        );
    Widget syncIcon(bool selected) => Icon(
          Icons.graphic_eq,
          size: 18,
          color: selected
              ? theme.colorScheme.primary
              : theme.colorScheme.mutedForeground,
        );

    // Top tabs: Plain / Sync (always visible)
    final topBar = Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: theme.colorScheme.muted.withValues(alpha: 0.3),
        borderRadius: theme.borderRadiusLg,
        border: Border.all(color: theme.colorScheme.border, width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TopTab(
              icon: plainIcon(topTab.value == 0),
              label: 'Plain',
              selected: topTab.value == 0,
              onTap: () => topTab.value = 0,
            ),
          ),
          Expanded(
            child: _TopTab(
              icon: syncIcon(topTab.value == 1),
              label: 'Sync',
              selected: topTab.value == 1,
              onTap: () => topTab.value = 1,
            ),
          ),
        ],
      ),
    );

    // Sub tabs for Plain
    Widget plainSubBar() {
      if (!hasAnyPlain) return const SizedBox.shrink();
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < availablePlain.length; i++)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _SubTab(
                  lang: availablePlain[i],
                  selected: plainSub.value == i,
                  onTap: () => plainSub.value = i,
                ),
              ),
          ],
        ),
      );
    }

    // Sub tabs for Sync
    Widget syncSubBar() {
      if (!hasAnySync) return const SizedBox.shrink();
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < availableSync.length; i++)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _SubTab(
                  lang: availableSync[i],
                  selected: syncSub.value == i,
                  onTap: () => syncSub.value = i,
                ),
              ),
          ],
        ),
      );
    }

    Widget plainContent() {
      if (isLoading) return const Center(child: CircularProgressIndicator());
      if (!hasAnyPlain) {
        return const _NoData();
      }
      final lang =
          availablePlain[plainSub.value.clamp(0, availablePlain.length - 1)];
      return PlainLanguageViewBuilder(track: track, lang: lang);
    }

    Widget syncContent() {
      if (isLoading) return const Center(child: CircularProgressIndicator());
      if (!hasAnySync) {
        return const _NoData();
      }
      final lang =
          availableSync[syncSub.value.clamp(0, availableSync.length - 1)];
      return _SingleSyncView(track: track, lang: lang);
    }

    return Scaffold(
      headers: [
        AppBar(
          title: Text(context.l10n.lyrics),
          trailing: const [
            BackButton(icon: SangeetIcons.angleDown),
          ],
        ),
      ],
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: topBar,
          ),
          if (topTab.value == 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: plainSubBar(),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: syncSubBar(),
            ),
          const Divider(height: 1),
          Expanded(
            child: topTab.value == 0 ? plainContent() : syncContent(),
          ),
        ],
      ),
    );
  }
}

class _TopTab extends StatelessWidget {
  final Widget icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TopTab(
      {required this.icon,
      required this.label,
      required this.selected,
      required this.onTap});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primary.withValues(alpha: 0.14)
              : Colors.transparent,
          borderRadius: theme.borderRadiusSm,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const Gap(6),
            Text(
              label,
              style: theme.typography.small.copyWith(
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.mutedForeground,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubTab extends StatelessWidget {
  final String lang;
  final bool selected;
  final VoidCallback onTap;
  const _SubTab(
      {required this.lang, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selected
        ? theme.colorScheme.primary
        : theme.colorScheme.mutedForeground;
    Widget icon;
    String label;
    switch (lang) {
      case LyricLanguages.te:
        icon = Text('అ',
            style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                height: 1));
        label = 'Telugu';
        break;
      case LyricLanguages.en:
        icon = Icon(Icons.translate, size: 14, color: color);
        label = 'Eng';
        break;
      case LyricLanguages.hi:
        icon = Icon(Icons.translate, size: 14, color: color);
        label = 'Hi';
        break;
      case LyricLanguages.enTr:
        icon = Text('Aa',
            style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1));
        label = 'Eng';
        break;
      case LyricLanguages.hiTr:
        icon = Text('अ',
            style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1));
        label = 'Hi';
        break;
      default:
        icon = const SizedBox.shrink();
        label = lang;
    }
    final isTransliteration =
        lang == LyricLanguages.enTr || lang == LyricLanguages.hiTr;
    final isTranslation =
        lang == LyricLanguages.en || lang == LyricLanguages.hi;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primary.withValues(alpha: 0.12)
              : theme.colorScheme.muted.withValues(alpha: 0.25),
          borderRadius: theme.borderRadiusMd,
          border: Border.all(
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (lang == LyricLanguages.te)
              icon
            else ...[
              Text(label,
                  style: theme.typography.small.copyWith(
                      color: color, fontWeight: FontWeight.w600, fontSize: 12)),
              const Gap(4),
              icon,
              if (isTranslation) const Gap(2),
              if (isTransliteration)
                Icon(isTransliteration ? Icons.text_fields : Icons.translate,
                    size: 10, color: color.withValues(alpha: 0.0)),
            ],
            if (lang != LyricLanguages.te)
              Padding(
                padding: const EdgeInsets.only(left: 2),
                child: Icon(
                  isTransliteration
                      ? Icons.abc
                      : (isTranslation ? Icons.translate : Icons.abc),
                  size: 0,
                  color: Colors.transparent,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NoData extends StatelessWidget {
  const _NoData();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined,
                size: 48, color: theme.colorScheme.mutedForeground),
            const Gap(12),
            Text(
              'There is no data',
              style: theme.typography.base
                  .copyWith(color: theme.colorScheme.mutedForeground),
            ),
          ],
        ),
      ),
    );
  }
}

class _SingleSyncView extends HookConsumerWidget {
  final SangeetTrackObject? track;
  final String lang;
  const _SingleSyncView({required this.track, required this.lang});
  @override
  Widget build(BuildContext context, ref) {
    if (track == null) return const _NoData();
    final delay = ref.watch(syncedLyricsDelayProvider);
    final query = ref.watch(syncedLyricsProvider(track));
    final subtitle = query.asData?.value;
    final mapState = ref.watch(syncedLyricsMapProvider(track));
    final lyricsMap = mapState.asData?.value.lyricsMap ?? const <int, String>{};
    final currentTime = useSyncedLyrics(
      ref,
      lyricsMap,
      delay,
      cues: mapState.asData?.value.cues ?? const [],
    );
    if (query.isLoading || query.isRefreshing) {
      return const Center(child: CircularProgressIndicator());
    }
    if (query.hasError) return const _NoData();
    // Plain (static/untimed) variants are not synced lyrics — do not render
    // them in the Sync view.
    if ((mapState.asData?.value.static ?? true) == true) return const _NoData();
    final variants = subtitle?.variants ?? const <LyricVariant>[];
    if (variants.isEmpty) return const _NoData();
    final hasAny =
        variants.any((v) => LyricLanguages.fieldOf(v, lang).trim().isNotEmpty);
    if (!hasAny) return const _NoData();
    var currentIndex = 0;
    for (var i = 0; i < variants.length; i++) {
      if (variants[i].time.inSeconds <= currentTime) {
        currentIndex = i;
      } else {
        break;
      }
    }
    // The singing line is pinned to a FIXED point in the middle of the view and
    // the lines above it travel upward as the track plays - the same rule the
    // full-page Sync view uses, from the same module (see LyricsAutoCenter and
    // docs/SYNCED-LYRICS.md).
    //
    // It replaces a proportional jump: `maxScrollExtent * currentIndex / length`.
    // That put the current line wherever the fraction happened to land - never
    // the centre - and drifted further off the more the line heights differed
    // (a banner, a wrapped Telugu line, the blank rows this list renders for
    // empty variants). Centring uses the line's measured geometry instead.
    final controller = useAutoScrollController();
    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        LyricsAutoCenter.centerOnLine(controller, currentIndex);
      });
      return null;
    }, [currentIndex, variants.length]);

    final theme = Theme.of(context);
    final def = kLyricLanguages.firstWhere((d) => d.key == lang,
        orElse: () => kLyricLanguages.first);
    final windowHeight = MediaQuery.sizeOf(context).height;

    return ListView.builder(
      controller: controller,
      // Half a window BELOW the last line only, so the final line can reach the
      // centre and the lock holds to the end of the track. There is deliberately
      // no matching space on top: with it the first line started in the middle of
      // the screen under a large empty area. Starting from the top means the
      // lyrics fill the view from the top down, and the singing line travels down
      // to the centre as the song plays - `Scrollable.ensureVisible` clamps its
      // target (`clampDouble(target, minScrollExtent, maxScrollExtent)`), so
      // until the current line can be centred the list stays at the top.
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: windowHeight / 2,
      ),
      itemCount: variants.length,
      itemBuilder: (context, index) {
        final text = LyricLanguages.fieldOf(variants[index], lang).trim();
        if (text.isEmpty) {
          return AutoScrollTag(
            key: ValueKey(index),
            index: index,
            controller: controller,
            child: const SizedBox(height: 8),
          );
        }
        // A line the author wrapped in double braces ({{Music}}) is a banner, not
        // sung text. This tab renders the variant fields directly, so it never saw
        // the markup rules and printed `{{Music}}` verbatim — the same song showed
        // a banner on the lyrics page and raw braces here.
        final marked = parseMarkedLyricsLine(text);
        if (marked.mark == LyricsLineMark.banner) {
          return AutoScrollTag(
            key: ValueKey(index),
            index: index,
            controller: controller,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: LyricsMusicBanner(label: marked.label),
            ),
          );
        }
        final isActive = index == currentIndex;
        return AutoScrollTag(
          key: ValueKey(index),
          index: index,
          controller: controller,
          child: GestureDetector(
            onTap: () {
              if (variants[index].time.isNegative ||
                  variants[index].time > audioPlayer.duration) {
                return;
              }
              audioPlayer.seek(variants[index].time);
            },
            behavior: HitTestBehavior.translucent,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              // The line that is playing is drawn in the cream capsule from the
              // reference screen, on its own dark ink: the cream pill is its own
              // surface, so the language's line colour (chosen for this page's
              // background) would not be legible on it.
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 240),
                style: theme.typography.base.copyWith(
                  color: isActive ? LyricsActiveLineCapsule.ink : def.color,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                  fontSize: isActive ? 19 : 16,
                  height: isActive ? 1.6 : 1.5,
                ),
                textAlign: TextAlign.center,
                child: isActive
                    ? LyricsActiveLineCapsule(child: Text(text))
                    : Text(text),
              ),
            ),
          ),
        );
      },
    );
  }
}
