/// Keeps the line that is being sung pinned to a FIXED point in the lyrics
/// view, so the block moves up behind it as the track plays.
///
/// WHY THIS IS ITS OWN MODULE
/// --------------------------
/// The behaviour is the whole point of the Synced Lyrics screen, and it depends
/// on scroll geometry that a widget test can reproduce cheaply - so the rule
/// lives here, tested directly, instead of being buried in a build method where
/// it could only be checked by looking at a phone.
///
/// HOW THE POSITION IS CHOSEN
/// --------------------------
/// [Scrollable.ensureVisible] with `alignment: 0.5` is the exact primitive for
/// this. Flutter's documentation for the offset it computes
/// (`RenderAbstractViewport.getOffsetToReveal`) states: "If alignment is 0.5,
/// the child must be positioned as close to the center of the viewport as
/// possible." It resolves that offset from the item's REAL laid-out geometry,
/// which matters here because the active line is drawn larger than its
/// neighbours and its height therefore changes as it is highlighted.
///
/// The previous implementation asked `scroll_to_index` for
/// `AutoScrollPosition.middle` from inside `itemBuilder` - during build, and
/// against the package's row estimate rather than the item's measured extent.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

class LyricsAutoCenter {
  LyricsAutoCenter._();

  /// Where the singing line sits in the viewport. `0.5` is the centre, and it is
  /// what makes the position FIXED: every line is scrolled to this same
  /// fraction, so the text moves up behind a stationary focal point.
  static const double alignment = 0.5;

  /// Long enough to read as a glide, short enough to land before the next line.
  /// A cue typically lasts seconds, so this never lags the song.
  static const Duration animationDuration = Duration(milliseconds: 420);

  static const Curve animationCurve = Curves.easeInOutCubic;

  /// Scrolls [controller] so line [index] sits at [alignment] in the viewport.
  ///
  /// Does nothing when [index] is negative (nothing is playing) or the view has
  /// not been laid out yet - the caller may invoke this on every cue change
  /// without guarding further.
  static void centerOnLine(
    AutoScrollController controller,
    int index, {
    Duration duration = animationDuration,
    Curve curve = animationCurve,
  }) {
    if (index < 0 || !controller.hasClients) return;

    final lineContext = _contextOf(controller, index);
    if (lineContext != null) {
      unawaited(_reveal(lineContext, duration, curve));
      return;
    }

    // The line is outside the range the list has built - a seek, or the first
    // frame after opening the screen mid-song. Jump to the package's estimate
    // WITHOUT animating (a long slide across the whole song would be a scroll
    // effect nobody asked for), then centre exactly on the next frame, when the
    // item exists and its measured height is known.
    unawaited(
      controller.scrollToIndex(
        index,
        preferPosition: AutoScrollPosition.middle,
        duration: Duration.zero,
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final built = _contextOf(controller, index);
      if (built != null) unawaited(_reveal(built, duration, curve));
    });
  }

  static Future<void> _reveal(
    BuildContext lineContext,
    Duration duration,
    Curve curve,
  ) {
    return Scrollable.ensureVisible(
      lineContext,
      alignment: alignment,
      duration: duration,
      curve: curve,
    );
  }

  /// The context of a line that is currently laid out, or null when the list has
  /// not built it (the caller then falls back to an estimated jump).
  static BuildContext? _contextOf(AutoScrollController controller, int index) {
    final state = controller.tagMap[index];
    final context = state?.context;
    if (context == null || !context.mounted) return null;
    if (context.findRenderObject() == null) return null;
    return context;
  }
}
