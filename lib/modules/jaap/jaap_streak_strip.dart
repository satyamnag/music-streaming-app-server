import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';

import 'package:sangeet/extensions/context.dart';
import 'package:sangeet/provider/jaap/jaap_provider.dart';

/// Current streak plus a 7-day dot strip: filled = that day met the target.
/// This is the "regularity over days and weeks" goal made visible at a glance.
class JaapStreakStrip extends HookWidget {
  final int streak;
  final List<JaapDayStatus> week;

  const JaapStreakStrip({required this.streak, required this.week, super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('$streak',
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
            const Gap(6),
            Text(context.l10n.jaap_days,
                style: TextStyle(color: context.theme.colorScheme.mutedForeground)),
          ],
        ),
        const Gap(10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final d in week)
              Container(
                width: 14,
                height: 14,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: d.targetMet ? context.theme.colorScheme.primary : null,
                  border: Border.all(
                    color: context.theme.colorScheme.primary,
                    width: 2,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
