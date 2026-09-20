import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:sangeet/extensions/context.dart';

/// Collects a counter's name and daily target (vow / sankalpa).
///
/// Used both for creating a counter and for editing one, so the fields carry
/// the current values when [initialName] / [initialTarget] are supplied.
/// Returns `(name, target)` on save, or null when cancelled.
class JaapNewCounterDialog extends HookWidget {
  final String? initialName;
  final int? initialTarget;

  const JaapNewCounterDialog({
    this.initialName,
    this.initialTarget,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final name = useTextEditingController(text: initialName ?? '');
    final target = useTextEditingController(
      text: (initialTarget ?? 108).toString(),
    );
    final error = useState<String?>(null);

    void submit() {
      final cleanName = name.text.trim();
      final parsedTarget = int.tryParse(target.text.trim());
      if (cleanName.isEmpty) {
        error.value = context.l10n.jaap_name_required;
        return;
      }
      if (parsedTarget == null || parsedTarget <= 0) {
        error.value = context.l10n.jaap_target_invalid;
        return;
      }
      Navigator.of(context).pop((name: cleanName, target: parsedTarget));
    }

    return AlertDialog(
      title: Text(context.l10n.jaap_new_counter),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: name,
            placeholder: Text(context.l10n.jaap_name),
          ),
          const Gap(12),
          TextField(
            controller: target,
            placeholder: Text(context.l10n.jaap_daily_target),
            keyboardType: const TextInputType.numberWithOptions(decimal: false),
          ),
          if (error.value != null) ...[
            const Gap(8),
            Text(error.value!, style: const TextStyle(color: Colors.red)),
          ],
        ],
      ),
      actions: [
        Button.outline(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.cancel),
        ),
        Button.primary(onPressed: submit, child: Text(context.l10n.save)),
      ],
    );
  }
}
