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
import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/modules/lyrics/use_synced_lyrics.dart';
import 'package:sangeet/services/audio_player/audio_player.dart';

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

    bool hasPlain(String lang) {
      final stored = plainForTrack(track, lang)?.trim();
      if (stored != null && stored.isNotEmpty) return true;
      return plainLyricTextFor(subtitle, lang).trim().isNotEmpty;
    }

    bool hasSync(String lang) {
      final variants = subtitle?.variants ?? const <LyricVariant>[];
      if (variants.isEmpty) return false;
      for (final v in variants) {
        if (LyricLanguages.fieldOf(v, lang).trim().isNotEmpty) return true;
      }
      return false;
    }

    // All 5 languages in display order (matches kLyricLanguages)
    const allLangs = [
      LyricLanguages.te,
      LyricLanguages.en,
      LyricLanguages.hi,
      LyricLanguages.enTr,
      LyricLanguages.hiTr,
    ];

    final availablePlain = isLoading
        ? allLangs
        : allLangs.where(hasPlain).toList();
    final availableSync = isLoading
        ? allLangs
        : allLangs.where(hasSync).toList();

    final hasAnyPlain = availablePlain.isNotEmpty;
    final hasAnySync = availableSync.isNotEmpty;

    useEffect(() {
      if (plainSub.value >= availablePlain.length && availablePlain.isNotEmpty) {
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
          color: selected ? theme.colorScheme.primary : theme.colorScheme.mutedForeground,
        );
    Widget syncIcon(bool selected) => Icon(
          Icons.graphic_eq,
          size: 18,
          color: selected ? theme.colorScheme.primary : theme.colorScheme.mutedForeground,
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
      final lang = availablePlain[plainSub.value.clamp(0, availablePlain.length - 1)];
      return PlainLanguageViewBuilder(track: track, lang: lang);
    }

    Widget syncContent() {
      if (isLoading) return const Center(child: CircularProgressIndicator());
      if (!hasAnySync) {
        return const _NoData();
      }
      final lang = availableSync[syncSub.value.clamp(0, availableSync.length - 1)];
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
  const _TopTab({required this.icon, required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? theme.colorScheme.primary.withValues(alpha: 0.14) : Colors.transparent,
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
                color: selected ? theme.colorScheme.primary : theme.colorScheme.mutedForeground,
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
  const _SubTab({required this.lang, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selected ? theme.colorScheme.primary : theme.colorScheme.mutedForeground;
    Widget icon;
    String label;
    switch (lang) {
      case LyricLanguages.te:
        icon = Text('అ', style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w600, height: 1));
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
        icon = Text('Aa', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600, height: 1));
        label = 'Eng';
        break;
      case LyricLanguages.hiTr:
        icon = Text('अ', style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w600, height: 1));
        label = 'Hi';
        break;
      default:
        icon = const SizedBox.shrink();
        label = lang;
    }
    final isTransliteration = lang == LyricLanguages.enTr || lang == LyricLanguages.hiTr;
    final isTranslation = lang == LyricLanguages.en || lang == LyricLanguages.hi;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? theme.colorScheme.primary.withValues(alpha: 0.12) : theme.colorScheme.muted.withValues(alpha: 0.25),
          borderRadius: theme.borderRadiusMd,
          border: Border.all(color: selected ? theme.colorScheme.primary : theme.colorScheme.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (lang == LyricLanguages.te) icon else ...[
              Text(label, style: theme.typography.small.copyWith(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
              const Gap(4),
              icon,
              if (isTranslation) const Gap(2),
              if (isTransliteration)
                Icon(isTransliteration ? Icons.text_fields : Icons.translate, size: 10, color: color.withValues(alpha: 0.0)),
            ],
            if (lang != LyricLanguages.te)
              Padding(
                padding: const EdgeInsets.only(left: 2),
                child: Icon(
                  isTransliteration ? Icons.abc : (isTranslation ? Icons.translate : Icons.abc),
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
            Icon(Icons.inbox_outlined, size: 48, color: theme.colorScheme.mutedForeground),
            const Gap(12),
            Text(
              'There is no data',
              style: theme.typography.base.copyWith(color: theme.colorScheme.mutedForeground),
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
    final currentTime = useSyncedLyrics(ref, lyricsMap, delay);
    if (query.isLoading || query.isRefreshing) return const Center(child: CircularProgressIndicator());
    if (query.hasError) return const _NoData();
    final variants = subtitle?.variants ?? const <LyricVariant>[];
    if (variants.isEmpty) return const _NoData();
    final hasAny = variants.any((v) => LyricLanguages.fieldOf(v, lang).trim().isNotEmpty);
    if (!hasAny) return const _NoData();
    var currentIndex = 0;
    for (var i = 0; i < variants.length; i++) {
      if (variants[i].time.inSeconds <= currentTime) {
        currentIndex = i;
      } else {
        break;
      }
    }
    final controller = useScrollController();
    useEffect(() {
      if (!controller.hasClients || variants.isEmpty) return;
      final target = controller.position.maxScrollExtent * (currentIndex / variants.length);
      controller.animateTo(target, duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
      return null;
    }, [currentIndex, variants.length]);
    final theme = Theme.of(context);
    final def = kLyricLanguages.firstWhere((d) => d.key == lang, orElse: () => kLyricLanguages.first);
    return ListView.builder(
      controller: controller,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: variants.length,
      itemBuilder: (context, index) {
        final text = LyricLanguages.fieldOf(variants[index], lang).trim();
        if (text.isEmpty) return const SizedBox(height: 8);
        final isActive = index == currentIndex;
        return GestureDetector(
          onTap: () {
            if (variants[index].time.isNegative || variants[index].time > audioPlayer.duration) return;
            audioPlayer.seek(variants[index].time);
          },
          behavior: HitTestBehavior.translucent,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isActive ? theme.colorScheme.primary.withValues(alpha: 0.08) : Colors.transparent,
              borderRadius: theme.borderRadiusMd,
              border: Border(left: BorderSide(width: 3, color: isActive ? theme.colorScheme.primary : Colors.transparent)),
            ),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: theme.typography.base.copyWith(color: def.color, fontWeight: isActive ? FontWeight.w600 : FontWeight.w400, fontSize: 16, height: 1.5),
            ),
          ),
        );
      },
    );
  }
}


