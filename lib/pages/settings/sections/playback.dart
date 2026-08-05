import 'package:flutter/material.dart' show ListTile;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sangeet/collections/routes.gr.dart';
import 'package:sangeet/collections/spotube_icons.dart';
import 'package:sangeet/modules/settings/playback/edit_connect_port_dialog.dart';
import 'package:sangeet/modules/settings/section_card_with_heading.dart';
import 'package:sangeet/extensions/context.dart';
import 'package:sangeet/provider/user_preferences/user_preferences_provider.dart';
import 'package:auto_route/auto_route.dart';

class SettingsPlaybackSection extends HookConsumerWidget {
  const SettingsPlaybackSection({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final preferences = ref.watch(userPreferencesProvider);
    final preferencesNotifier = ref.watch(userPreferencesProvider.notifier);
    return SectionCardWithHeading(
      heading: context.l10n.playback,
      children: [
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
      ListTile(
          leading: const Icon(SangeetIcons.connect),
          title: Text(context.l10n.devices),
          subtitle: Text(context.l10n.enable_connect_description),
          trailing: const Icon(SangeetIcons.angleRight),
          onTap: () {
            context.navigateTo(const ConnectRoute());
          },
        ),
      ],
    );
  }
}
