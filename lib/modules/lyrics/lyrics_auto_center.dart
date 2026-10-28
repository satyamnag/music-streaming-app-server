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
/// [Scrollable.ensureVisible] with a fractional [alignment] is the exact
/// primitive for this. Flutter's documentation for the offset it computes
/// (`RenderAbstractViewport.getOffsetToReveal`) describes `alignment` as where
/// the child is positioned between the leading edge (0.0) and the trailing edge
/// (1.0) of the viewport, and it resolves that offset from the item's REAL
/// laid-out geometry - which matters here because the active line is drawn
/// larger than its neighbours and its height therefore changes as it is
/// highlighted.
///
/// The position used to be the centre (0.5). It is now [alignment] = 0.3, i.e.
/// just under a third of the way down, which keeps the forthcoming lines in
/// view instead of spending the bottom half of the screen on them.
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

  /// Where the singing line sits in the viewport, as a fraction from the TOP.
  ///
  /// `0.3` puts it just under a third of the way down - high enough that the two
  /// or three lines still to come are already visible beneath it, and low enough
  /// that the line just sung stays visible above it. Every line is scrolled to
  /// this same fraction, which is what makes the position FIXED: the text moves
  /// behind a stationary focal point.
  static const double alignment = 0.3;

  /// The space a lyrics list must reserve BELOW its last line so that line can
  /// still be placed at [alignment].
  ///
  /// With the anchor 30% down, a line needs the remaining 70% of the viewport
  /// below it to reach it. Reserving less would leave the final lines unable to
  /// rise to the anchor, so the lock would silently break near the end of the
  /// track. Callers pass their window height (a little larger than the real
  /// viewport, which only means slightly more trailing room - harmless).
  static double trailingSpace(double windowHeight) =>
      windowHeight * (1 - alignment);

  /// Long enough to read as a glide, short enough to land before the next line.
  /// A cue typically lasts seconds, so this never lags the song.
  static const Duration animationDuration = Duration(milliseconds: 420);

  static const Curve animationCurve = Curves.easeInOutCubic;

  /// `scroll_to_index` asserts `duration > Duration.zero` for its own scroll, so
  /// the "jump" that lands near an unbuilt line is 1 ms rather than zero:
  /// visually instantaneous for the reader, and the package's precondition holds.
  /// (Passing zero throws in debug and is what the auto-centre test caught.)
  static const Duration jumpDuration = Duration(milliseconds: 1);

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
        duration: jumpDuration,
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final built = _contextOf(controller, index);
      if (built != null) unawaited(_reveal(built, duration, curve));
    });
  }

  /// Returns the view to the beginning, so a track that starts again - or loops
  /// back to the top - takes the lyrics back to the top before the singing line
  /// travels down to the centre again. No-op when already at the top.
  static void scrollToStart(
    AutoScrollController controller, {
    Duration duration = animationDuration,
    Curve curve = animationCurve,
  }) {
    if (!controller.hasClients) return;
    if (controller.offset == 0) return;
    unawaited(controller.animateTo(0, duration: duration, curve: curve));
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
