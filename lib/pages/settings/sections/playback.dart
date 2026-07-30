import 'package:auto_route/auto_route.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' show ListTile;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sangeet/collections/routes.gr.dart';
import 'package:sangeet/collections/spotube_icons.dart';
import 'package:sangeet/components/adaptive/adaptive_select_tile.dart';
import 'package:sangeet/modules/settings/playback/edit_connect_port_dialog.dart';
import 'package:sangeet/modules/settings/section_card_with_heading.dart';
import 'package:sangeet/extensions/context.dart';
import 'package:sangeet/provider/metadata_plugin/audio_source/quality_presets.dart';
import 'package:sangeet/provider/user_preferences/user_preferences_provider.dart';
import 'package:sangeet/utils/platform.dart';

class SettingsPlaybackSection extends HookConsumerWidget {
  const SettingsPlaybackSection({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final preferences = ref.watch(userPreferencesProvider);
    final preferencesNotifier = ref.watch(userPreferencesProvider.notifier);
    final sourcePresets = ref.watch(audioSourcePresetsProvider);
    final sourcePresetsNotifier =
        ref.watch(audioSourcePresetsProvider.notifier);
    final theme = Theme.of(context);
    final opusIdx = sourcePresets.presets.indexWhere((p) => p.name == 'opus');
    final opusContainerIdx = opusIdx >= 0 ? opusIdx : 0;

    return SectionCardWithHeading(
      heading: context.l10n.playback,
      children: [
        if (sourcePresets.presets.isNotEmpty) ...[
          AdaptiveSelectTile(
            secondary: const Icon(SangeetIcons.plugin),
            title: Text(context.l10n.streaming_music_format),
            value: opusContainerIdx,
            options: [
              SelectItemButton(value: opusContainerIdx, child: const Text('opus')),
            ],
            onChanged: null,
          ),
          AdaptiveSelectTile(
            secondary: const Icon(SangeetIcons.audioQuality),
            title: Text(context.l10n.streaming_music_quality),
            value: sourcePresets.selectedStreamingQualityIndex,
            options: [
              for (final MapEntry(:key, value: quality) in sourcePresets
                  .presets[sourcePresets.selectedStreamingContainerIndex]
                  .qualities
                  .asMap()
                  .entries)
                SelectItemButton(value: key, child: Text(quality.toString())),
            ],
            onChanged: (value) {
              if (value == null) return;
              sourcePresetsNotifier.setSelectedStreamingQualityIndex(value);
            },
          ),
          AdaptiveSelectTile(
            secondary: const Icon(SangeetIcons.plugin),
            title: Text(context.l10n.download_music_format),
            value: sourcePresets.selectedDownloadingContainerIndex,
            options: [
              for (final MapEntry(:key, value: preset)
                  in sourcePresets.presets.asMap().entries)
                SelectItemButton(value: key, child: Text(preset.name)),
            ],
            onChanged: (value) {
              if (value == null) return;
              sourcePresetsNotifier.setSelectedDownloadingContainerIndex(value);
            },
          ),
          AdaptiveSelectTile(
            secondary: const Icon(SangeetIcons.audioQuality),
            title: Text(context.l10n.download_music_quality),
            value: sourcePresets.selectedStreamingQualityIndex,
            options: [
              for (final MapEntry(:key, value: quality) in sourcePresets
                  .presets[sourcePresets.selectedDownloadingContainerIndex]
                  .qualities
                  .asMap()
                  .entries)
                SelectItemButton(value: key, child: Text(quality.toString())),
            ],
            onChanged: (value) {
              if (value == null) return;
              sourcePresetsNotifier.setSelectedStreamingQualityIndex(value);
            },
          ),
        ],
        ListTile(
          title: Text(context.l10n.cache_music),
          subtitle: const Text('Always enabled'),
          leading: const Icon(SangeetIcons.cache),
          trailing: const Icon(SangeetIcons.done),
        ),
        ListTile(
          leading: const Icon(SangeetIcons.playlistRemove),
          title: Text(context.l10n.blacklist),
          subtitle: Text(context.l10n.blacklist_description),
          onTap: () {
            context.navigateTo(const BlackListRoute());
          },
          trailing: const Icon(SangeetIcons.angleRight),
        ),
        ListTile(
          leading: const Icon(SangeetIcons.normalize),
          title: Text(context.l10n.normalize_audio),
          trailing: Switch(
            value: preferences.normalizeAudio,
            onChanged: preferencesNotifier.setNormalizeAudio,
          ),
        ),
        ListTile(
            leading: const Icon(SangeetIcons.repeat),
            title: Text(context.l10n.endless_playback),
            trailing: Switch(
              value: preferences.endlessPlayback,
              onChanged: preferencesNotifier.setEndlessPlayback,
            )),
        ListTile(
          title: Text(context.l10n.enable_connect),
          subtitle: Text(context.l10n.enable_connect_description),
          leading: const Icon(SangeetIcons.connect),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 10,
            children: [
              Tooltip(
                tooltip: TooltipContainer(
                  child: Text(context.l10n.edit_port),
                ).call,
                child: IconButton.outline(
                  icon: const Icon(SangeetIcons.edit),
                  size: ButtonSize.small,
                  onPressed: () {
                    showDialog(
                      context: context,
                      barrierColor: Colors.black.withValues(alpha: 0.5),
                      builder: (context) =>
                          const SettingsPlaybackEditConnectPortDialog(),
                    );
                  },
                ),
              ),
              Switch(
                value: preferences.enableConnect,
                onChanged: preferencesNotifier.setEnableConnect,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
