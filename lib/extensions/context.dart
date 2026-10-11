import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sangeet/l10n/l10n.dart';

extension AppLocale on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}

extension PlayerFooterReserve on BuildContext {
  /// Minimum height of the floating footer stack: the collapsed mini player
  /// (`PlayerOverlayCollapsedSection.collapsedHeight` == 86) plus the bottom
  /// navigation bar (50).
  ///
  /// This is the FLOOR for [bottomPlayerReserve]. It exists because the
  /// inherited padding is not always the footer height: a page that builds its
  /// own `Scaffold` (the stats, playlist-detail, settings and search pages all
  /// do) receives the OUTER padding, and `floatingFooter` only adds
  /// `footerHeight` to the subtree of the scaffold that declared it. On those
  /// routes the padding can therefore be just the system inset (a few dp),
  /// which under-reserved the last row into the mini player - the bug reported
  /// with screenshots across many screens.
  ///
  /// Keeping the floor means the reserve is correct on every route, while the
  /// padding term still lets it GROW when the real footer is taller (e.g. the
  /// navigation bar is expanded) or when a system gesture bar is present.
  static const double _minFooterStack = 86 + 50;

  /// Bottom inset a scrollable page must reserve so the floating mini player
  /// and bottom navigation bar never cover the page's last items.
  ///
  /// `max(padding.bottom, footer stack) + 12`, so it is never short:
  ///  - the padding term tracks the real, animated footer height where the
  ///    scaffold does provide it (and any system inset), and
  ///  - the floor guarantees the last row clears the mini player even on
  ///    routes where that padding is not propagated.
  ///
  /// The `+12` is breathing room, matching the trailing spacer the home screen
  /// uses.
  double get bottomPlayerReserve {
    final padding = MediaQuery.paddingOf(this).bottom;
    final stack = padding > _minFooterStack ? padding : _minFooterStack;
    return stack + 12 * Theme.of(this).scaling;
  }

  /// Extra space the Lyrics screen needs below its content, on top of the
  /// app-wide footer padding, so the mini player and navigation bar never
  /// overlap the last lyric line.
  double get lyricsBottomReserve => bottomPlayerReserve;
}
