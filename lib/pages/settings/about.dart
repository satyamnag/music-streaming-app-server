import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:sangeet/collections/assets.gen.dart';
import 'package:sangeet/collections/spotube_icons.dart';
import 'package:sangeet/components/button/back_button.dart';
import 'package:sangeet/components/titlebar/titlebar.dart';
import 'package:sangeet/extensions/context.dart';
import 'package:url_launcher/url_launcher_string.dart';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:auto_route/auto_route.dart';

@RoutePage()
class AboutSangeetPage extends HookConsumerWidget {
  static const name = "about";

  const AboutSangeetPage({super.key});

  @override
  Widget build(BuildContext context, ref) {
    // Show the installed app version as "buildNumber (version)", e.g. "71 (1.0.0)",
    // so the About screen always reflects the actual running build.
    final packageInfo = useFuture(PackageInfo.fromPlatform());
    final versionLabel = packageInfo.data == null
        ? ""
        : "${packageInfo.data!.buildNumber} (${packageInfo.data!.version})";
    return SafeArea(
      bottom: false,
      child: Scaffold(
        headers: [
          TitleBar(
            leading: const [BackButton()],
            title: Text(context.l10n.about_spotube),
          )
        ],
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 120),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              children: [
                const SizedBox(height: 40),
                Center(
                  child: ClipOval(
                    child: Assets.branding.sangeetLogoPng.image(
                      height: 200,
                      width: 200,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                if (versionLabel.isNotEmpty)
                  Center(
                    child: Text(
                      versionLabel,
                      style: Theme.of(context)
                          .typography
                          .xSmall
                          .copyWith(color: Theme.of(context).colorScheme.mutedForeground),
                    ),
                  ),
                const SizedBox(height: 20),
                Center(
                  child: Text(
                    "Welcome to Soulful Bhakti - a new era of devotional music.\n\n"
                    "We blend the serenity of traditional ragas with modern "
                    "instrumentation to create soulful devotional songs that "
                    "bring peace, devotion and spiritual comfort.\n\n"
                    "Created for listeners of all ages, from children to elders, "
                    "our music is ideal for morning prayers, meditation, quiet "
                    "reflection or as a peaceful companion throughout the day.\n\n"
                    "Experience gentle, meaningful visuals that reflect the "
                    "divine presence in everyday life.",
                    textAlign: TextAlign.justify,
                  ).semiBold().large(),
                ),
                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Copyright & Rights Notice",
                    style: Theme.of(context).typography.h3,
                  ).bold(),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "All rights, title, and interest in and to all tracks released "
                    "by Soulful Bhakti are owned and/or controlled by Soulful Bhakti, "
                    "to the extent applicable. Unauthorized copying, reproduction, "
                    "duplication, distribution, modification, or other use of any "
                    "track, in whole or in part, is strictly prohibited without prior "
                    "written authorization from the applicable rights holder.\n\n"
                    "Soulful Bhakti is a part of FAMERELAY.",
                    textAlign: TextAlign.justify,
                  ),
                ),
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Button(
                    style: const ButtonStyle.outline(),
                    leading: const Icon(SangeetIcons.connect),
                    onPressed: () {
                      launchUrlString(
                        "https://www.soulfulbhakti.com/privacy",
                        mode: LaunchMode.externalApplication,
                      );
                    },
                    child: const Text("Privacy Policy"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
