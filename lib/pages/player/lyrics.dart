import 'package:auto_route/annotations.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sangeet/collections/spotube_icons.dart';
import 'package:sangeet/components/button/back_button.dart';
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

    // Selected languages for the "Synced" tab. Defaults to Telugu and always
    // keeps at least one selected. Converted to a stable ValueNotifier so the
    // open picker reflects live toggle state.
    final selectedLangs = useMemoized(
      () => ValueNotifier<Set<String>>({LyricLanguages.te}),
      [],
    );
    useEffect(() => selectedLangs.dispose, []);

    // Tab model: (key, label). Only tabs that actually have lyric data in the
    // database are shown; empty tabs are hidden entirely.
    const tabs = <({String key, String label})>[
      (key: 'te', label: 'Te'),
      (key: 'enTr', label: 'En (Transliteration)'),
      (key: 'en', label: 'En (Translation)'),
      (key: 'synced', label: 'Synced'),
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

    final tabbar = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: TabList(
        index: selectedIndex.value,
        onChanged: (index) => selectedIndex.value = index,
        children: [
          for (final tab in available) TabItem(child: Text(tab.label)),
        ],
      ),
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
          leading: [tabbar],
          trailing: const [
            BackButton(icon: SangeetIcons.angleDown),
          ],
        ),
      ],
      child: IndexedStack(
        index: selectedIndex.value.clamp(0, content.length - 1),
        children: content,
      ),
    );
  }
}
