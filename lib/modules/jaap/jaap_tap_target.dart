import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';

import 'package:sangeet/extensions/context.dart';

/// The single large counting button. One press = one repetition.
///
/// Feedback is haptic and immediate; the caller updates its in-memory count
/// synchronously, so a tap never waits on disk. There is deliberately no
/// confirmation dialog and no error surface here - interrupting japa is the one
/// thing this screen must never do.
class JaapTapTarget extends HookWidget {
  final VoidCallback onTap;
  final bool targetReached;

  const JaapTapTarget({required this.onTap, this.targetReached = false, super.key});

  @override
  Widget build(BuildContext context) {
    final scale = useAnimationController(
      duration: const Duration(milliseconds: 90),
      lowerBound: 0.97,
      upperBound: 1.0,
      initialValue: 1.0,
    );

    return GestureDetector(
      onTapDown: (_) => scale.reverse(),
      onTapUp: (_) => scale.forward(),
      onTapCancel: () => scale.forward(),
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: ScaleTransition(
        scale: scale,
        child: Container(
          width: double.infinity,
          height: 180,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: targetReached
                ? context.theme.colorScheme.primary.withValues(alpha: 0.18)
                : context.theme.colorScheme.primary,
          ),
          alignment: Alignment.center,
          child: Text(
            context.l10n.jaap_tap_to_count,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: targetReached
                  ? context.theme.colorScheme.primary
                  : context.theme.colorScheme.primaryForeground,
            ),
          ),
        ),
      ),
    );
  }
}
