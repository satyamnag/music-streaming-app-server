import 'package:auto_route/annotations.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sangeet/collections/spotube_icons.dart';
import 'package:sangeet/components/button/back_button.dart';
import 'package:sangeet/extensions/context.dart';
import 'package:sangeet/models/lyrics.dart';
import 'package:sangeet/pages/lyrics/multilang_lyrics.dart';
import 'package:sangeet/provider/audio_player/audio_player.dart';
import 'package:sangeet/provider/lyrics/synced.dart';

@RoutePage()
class PlayerLyricsPage extends HookConsumerWidget {
  const PlayerLyricsPage({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final playlist = ref.watch(audioPlayerProvider);
    final track = playlist.activeTrack;
    final selectedIndex = useState(0);

    final query = ref.watch(syncedLyricsProvider(track));
    final subtitle = query.asData?.value;
    final isLoading = query.isLoading || query.isRefreshing;

    // Selected languages for the "Sync" tab. Defaults to Telugu and always
    // keeps at least one selected. Converted to a stable ValueNotifier so the
    // open picker reflects live toggle state.
    final selectedLangs = useMemoized(
      () => ValueNotifier<Set<String>>({LyricLanguages.te}),
      [],
    );
    useEffect(() => selectedLangs.dispose, []);

    // Tab model: (key, label). Only tabs that actually have lyric data in the
    // database are shown; empty tabs are hidden entirely. Concise single-line
    // labels keep the bar uncluttered.
    const tabs = <({String key, String label})>[
      (key: 'te', label: 'Te'),
      (key: 'enTr', label: 'Eng Tr'),
      (key: 'en', label: 'Eng'),
      (key: 'synced', label: 'Sync'),
    ];

    bool hasPlain(String lang) => plainLyricTextFor(subtitle, lang).isNotEmpty;
    bool qualifies(({String key, String label}) tab) => switch (tab.key) {
          'te' => hasPlain(LyricLanguages.te),
          'enTr' => hasPlain(LyricLanguages.enTr),
          'en' => hasPlain(LyricLanguages.en),
          'synced' => (subtitle?.variants?.isNotEmpty ?? false) ||
              (subtitle?.lyrics.isNotEmpty ?? false),
          _ => true,
        };

    // While loading we cannot know yet, so keep all tabs. Otherwise filter out
    // tabs with no data; if none qualify, keep all (their content shows the
    // friendly "no lyrics" state so the screen is never blank).
    final available = isLoading
        ? tabs
        : (() {
            final withData = tabs.where(qualifies).toList();
            return withData.isEmpty ? tabs : withData;
          })();

    // Keep the selected tab valid when available tabs change.
    useEffect(() {
      if (selectedIndex.value >= available.length) {
        selectedIndex.value = 0;
      }
      return null;
    }, [available.length]);

    final theme = Theme.of(context);

    // Segmented pill bar with vertical dividers + a red underline under the
    // active tab, matching the reference design.
    final tabbar = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: theme.colorScheme.muted.withValues(alpha: 0.3),
            borderRadius: theme.borderRadiusLg,
            border: Border.all(color: theme.colorScheme.border, width: 1),
          ),
          child: Row(
            children: [
              for (var i = 0; i < available.length; i++)
                Expanded(
                  child: _LyricsTab(
                    icon: _tabIcon(
                      available[i].key,
                      selectedIndex.value == i
                          ? theme.colorScheme.primary
                          : theme.colorScheme.mutedForeground,
                    ),
                    label: available[i].label,
                    selected: selectedIndex.value == i,
                    isLast: i == available.length - 1,
                    onTap: () => selectedIndex.value = i,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (var i = 0; i < available.length; i++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 3,
                    decoration: BoxDecoration(
                      color: selectedIndex.value == i
                          ? theme.colorScheme.primary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );

    final content = <Widget>[
      for (final tab in available)
        switch (tab.key) {
          'te' => PlainLanguageViewBuilder(track: track, lang: LyricLanguages.te),
          'enTr' => PlainLanguageViewBuilder(track: track, lang: LyricLanguages.enTr),
          'en' => PlainLanguageViewBuilder(track: track, lang: LyricLanguages.en),
          _ => SyncedLanguageView(track: track, selected: selectedLangs),
        },
    ];

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
            child: tabbar,
          ),
          Expanded(
            child: IndexedStack(
              index: selectedIndex.value.clamp(0, content.length - 1),
              children: content,
            ),
          ),
        ],
      ),
    );
  }
}

Widget _tabIcon(String key, Color color) => switch (key) {
      'te' => Text(
          'అ',
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            height: 1,
          ),
        ),
      'enTr' => Text(
          'Aa',
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            height: 1,
          ),
        ),
      'en' => Icon(Icons.menu_book, size: 20, color: color),
      _ => Icon(Icons.graphic_eq, size: 20, color: color),
    };

/// One icon-above-label tab with a thin vertical divider (except the last) and
/// a tinted pill highlight for the active tab.
class _LyricsTab extends StatelessWidget {
  final Widget icon;
  final String label;
  final bool selected;
  final bool isLast;
  final VoidCallback onTap;

  const _LyricsTab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.isLast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primary.withValues(alpha: 0.14)
              : Colors.transparent,
          borderRadius: theme.borderRadiusSm,
          border: isLast
              ? null
              : Border(
                  right: BorderSide(color: theme.colorScheme.border),
                ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
