import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart' show ListTile;

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' hide ButtonStyle;
import 'package:sangeet/collections/env.dart';
import 'package:sangeet/collections/routes.gr.dart';
import 'package:sangeet/collections/spotube_icons.dart';
import 'package:sangeet/modules/settings/section_card_with_heading.dart';
import 'package:sangeet/extensions/context.dart';
import 'package:sangeet/provider/user_preferences/user_preferences_provider.dart';

class SettingsAboutSection extends HookConsumerWidget {
  const SettingsAboutSection({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final preferences = ref.watch(userPreferencesProvider);
    final preferencesNotifier = ref.watch(userPreferencesProvider.notifier);

    return SectionCardWithHeading(
      heading: context.l10n.about,
      children: [
        if (Env.enableUpdateChecker)
          ListTile(
            leading: const Icon(SangeetIcons.update),
            title: Text(context.l10n.check_for_updates),
            trailing: Switch(
              value: preferences.checkUpdate,
              onChanged: (checked) =>
                  preferencesNotifier.setCheckUpdate(checked),
            ),
          ),
        ListTile(
          leading: const Icon(SangeetIcons.info),
          title: Text(context.l10n.about_spotube),
          trailing: const Icon(SangeetIcons.angleRight),
          onTap: () {
            context.navigateTo(const AboutSangeetRoute());
          },
        )
      ],
    );
  }
}
