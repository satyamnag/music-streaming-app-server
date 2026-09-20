import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:sangeet/provider/jaap/jaap_provider.dart';

/// Horizontal selector for the user's counters. Tap to switch, "+" to create.
class JaapCounterChips extends HookWidget {
  final List<JaapCounter> counters;
  final int? selectedId;
  final ValueChanged<int> onSelect;
  final VoidCallback onCreate;

  const JaapCounterChips({
    required this.counters,
    required this.selectedId,
    required this.onSelect,
    required this.onCreate,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          for (final c in counters) ...[
            Button(
              style: c.id == selectedId
                  ? const ButtonStyle.primary()
                  : const ButtonStyle.outline(),
              onPressed: () => onSelect(c.id),
              child: Text(c.name),
            ),
            const Gap(8),
          ],
          Button(
            style: const ButtonStyle.outline(),
            onPressed: onCreate,
            child: const Icon(FeatherIcons.plus),
          ),
        ],
      ),
    );
  }
}
