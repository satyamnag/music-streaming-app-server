import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// count / target with a ring that fills as the count approaches the vow.
/// Deliberately shows the raw numbers large: "complete a chosen number" is a
/// stated goal, so the number must be readable at a glance.
class JaapProgressRing extends HookWidget {
  final int count;
  final int target;

  const JaapProgressRing({required this.count, required this.target, super.key});

  @override
  Widget build(BuildContext context) {
    final progress =
        target <= 0 ? 0.0 : (count / target).clamp(0.0, 1.0).toDouble();
    return SizedBox(
      width: 220,
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 200,
            height: 200,
            child: CircularProgressIndicator(
              value: progress,
              size: 200,
              strokeWidth: 10,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$count',
                style: const TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                '/ $target',
                style: TextStyle(
                  fontSize: 18,
                  color: Theme.of(context).colorScheme.mutedForeground,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
