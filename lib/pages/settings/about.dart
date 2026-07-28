import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sangeet/collections/assets.gen.dart';
import 'package:sangeet/components/button/back_button.dart';
import 'package:sangeet/components/titlebar/titlebar.dart';
import 'package:sangeet/extensions/context.dart';

import 'package:hooks_riverpod/hooks_riverpod.dart';
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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              children: [
                const SizedBox(height: 40),
                Center(
                  child: Assets.branding.sangeetLogoPng.image(
                    height: 200,
                    width: 200,
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: const Text(
                    "Sangeet is an extensible devotional music streaming platform",
                  )
                      .semiBold()
                      .large(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
