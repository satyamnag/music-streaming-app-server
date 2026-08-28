import 'package:auto_route/annotations.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sangeet/collections/spotube_icons.dart';
import 'package:sangeet/components/button/back_button.dart';
import 'package:sangeet/models/lyrics.dart';
import 'package:sangeet/pages/lyrics/multilang_lyrics.dart';
import 'package:sangeet/provider/audio_player/audio_player.dart';

@RoutePage()
class PlayerLyricsPage extends HookConsumerWidget {
  const PlayerLyricsPage({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final playlist = ref.watch(audioPlayerProvider);
    final track = playlist.activeTrack;
    final selectedIndex = useState(0);

    // Selected languages for the "Synced Lyrics" tab. Defaults to Telugu and
    // always keeps at least one selected. Converted to a stable ValueNotifier
    // so the open picker reflects live toggle state.
    final selectedLangs = useMemoized(
      () => ValueNotifier<Set<String>>({LyricLanguages.te}),
      [],
    );
    useEffect(() => selectedLangs.dispose, []);

    final tabbar = TabList(
      index: selectedIndex.value,
      onChanged: (index) => selectedIndex.value = index,
      children: const [
        TabItem(child: Text('Telugu Lyrics')),
        TabItem(child: Text('English Transliteration')),
        TabItem(child: Text('English Translation')),
        TabItem(child: Text('Synced Lyrics')),
      ],
    );

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
        index: selectedIndex.value,
        children: [
          PlainLanguageViewBuilder(track: track, lang: LyricLanguages.te),
          PlainLanguageViewBuilder(track: track, lang: LyricLanguages.enTr),
          PlainLanguageViewBuilder(track: track, lang: LyricLanguages.en),
          SyncedLanguageView(track: track, selected: selectedLangs),
        ],
      ),
    );
  }
}
