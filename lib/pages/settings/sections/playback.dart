import 'package:flutter/material.dart' show ListTile;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sangeet/collections/spotube_icons.dart';
import 'package:sangeet/modules/settings/section_card_with_heading.dart';
import 'package:sangeet/extensions/context.dart';
import 'package:sangeet/provider/user_preferences/user_preferences_provider.dart';

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
            leading: const Icon(SangeetIcons.repeat),
            title: Text(context.l10n.endless_playback),
            trailing: Switch(
              value: preferences.endlessPlayback,
              onChanged: preferencesNotifier.setEndlessPlayback,
            )),
      ],
    );
  }
}
