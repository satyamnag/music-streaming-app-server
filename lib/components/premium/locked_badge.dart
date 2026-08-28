import 'package:flutter/material.dart' as material;
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// A reusable lock indicator overlay placed over a cover image to mark a
/// paid/locked track or album. Renders a dark translucent scrim with a centred
/// lock icon so locked content is clearly greyed out and instantly recognisable.
class LockedBadge extends StatelessWidget {
  final bool locked;
  final double iconSize;
  final double borderRadius;

  const LockedBadge({
    super.key,
    required this.locked,
    this.iconSize = 32,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    if (!locked) return const SizedBox.shrink();
    return Positioned.fill(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Container(
          color: Colors.black.withValues(alpha: 0.45),
          alignment: Alignment.center,
          child: Icon(
            material.Icons.lock,
            size: iconSize,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
