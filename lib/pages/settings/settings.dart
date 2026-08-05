import 'package:flutter/material.dart' show Material, MaterialType;
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';
import 'package:sangeet/components/titlebar/titlebar.dart';
import 'package:sangeet/extensions/context.dart';
import 'package:sangeet/pages/settings/sections/about.dart';
import 'package:sangeet/pages/settings/sections/appearance.dart';
import 'package:sangeet/pages/settings/sections/desktop.dart';
import 'package:sangeet/pages/settings/sections/language_region.dart';
import 'package:sangeet/pages/settings/sections/playback.dart';
import 'package:sangeet/provider/user_preferences/user_preferences_provider.dart';
import 'package:sangeet/utils/platform.dart';
import 'package:auto_route/auto_route.dart';

@RoutePage()
class SettingsPage extends HookConsumerWidget {
  static const name = "settings";

  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final controller = useScrollController();
    final preferencesNotifier = ref.watch(userPreferencesProvider.notifier);

    Future<void> confirmReset() async {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.l10n.restore_defaults),
          content: Text(context.l10n.restore_defaults_confirmation),
          actions: [
            Button.outline(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(context.l10n.decline),
            ),
            Button.destructive(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(context.l10n.accept),
            ),
          ],
        ),
      );
      if (accepted == true) {
        await preferencesNotifier.reset();
      }
    }

    return SafeArea(
      bottom: false,
      child: Scaffold(
        headers: [
          TitleBar(
            title: Text(context.l10n.settings),
          )
        ],
        child: Scrollbar(
          controller: controller,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: ScrollConfiguration(
                behavior: const ScrollBehavior().copyWith(scrollbars: false),
                child: Material(
                  type: MaterialType.transparency,
                  child: ListView(
                    controller: controller,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    children: [
                      Center(
                        child: Text(
                          context.l10n.settings,
                          textAlign: TextAlign.center,
                          style: context.theme.typography.h3.copyWith(
                            color: context.theme.colorScheme.foreground,
                          ),
                        ),
                      ),
                      const Gap(4),
                      Center(
                        child: Text(
                          context.l10n.settings_subtitle,
                          textAlign: TextAlign.center,
                          style: context.theme.typography.small.copyWith(
                            color: context.theme.colorScheme.mutedForeground,
                          ),
                        ),
                      ),
                      const Gap(16),
                      const SettingsLanguageRegionSection(),
                      const Gap(12),
                      const SettingsAppearanceSection(),
                      const Gap(12),
                      const SettingsPlaybackSection(),
                      if (kIsDesktop) ...[
                        const Gap(12),
                        const SettingsDesktopSection(),
                      ],
                      const Gap(12),
                      const SettingsAboutSection(),
                      const Gap(20),
                      Center(
                        child: Button.destructive(
                          onPressed: confirmReset,
                          child: Text(context.l10n.restore_defaults),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
