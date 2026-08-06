import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sangeet/collections/assets.gen.dart';
import 'package:sangeet/components/button/back_button.dart';
import 'package:sangeet/components/titlebar/titlebar.dart';
import 'package:sangeet/extensions/context.dart';

import 'package:flutter/gestures.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:auto_route/auto_route.dart';

@RoutePage()
class AboutSangeetPage extends HookConsumerWidget {
  static const name = "about";

  const AboutSangeetPage({super.key});

  @override
  Widget build(BuildContext context, ref) {
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
                    "Credits",
                    style: Theme.of(context).typography.h3,
                  ).bold(),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Poetry: Late Sri Chakalakonda Chenchuramayya\n"
                    "Lyrics: Dr. Sri Ramakantha Rao Chakalakonda\n"
                    "Music Producer: Karthik Chandan Palepu\n"
                    "Animation: Mannem Venkat Reddy",
                    textAlign: TextAlign.left,
                  ),
                ),
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: "Subscribe to ",
                        ),
                        TextSpan(
                          text: "@SoulfulBhaktiTelugu",
                          style: TextStyle(
                            color: Colors.sky[400],
                            decoration: TextDecoration.underline,
                            decorationColor: Colors.sky[400],
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              launchUrlString(
                                "https://www.youtube.com/@SoulfulBhaktiTelugu",
                              );
                            },
                        ),
                      ],
                    ),
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
