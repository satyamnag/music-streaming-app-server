import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sangeet/modules/settings/section_card_with_heading.dart';
import 'package:sangeet/extensions/context.dart';

class SettingsAccountSection extends HookConsumerWidget {
  const SettingsAccountSection({super.key});

  @override
  Widget build(context, ref) {
    return SectionCardWithHeading(
      heading: context.l10n.account,
      children: [],
    );
  }
}
