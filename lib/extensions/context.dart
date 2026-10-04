import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sangeet/l10n/l10n.dart';

extension AppLocale on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}

extension PlayerFooterReserve on BuildContext {
  /// Bottom inset a scrollable page must reserve so the floating mini player
  /// and bottom navigation bar never cover the page's last items.
  ///
  /// Mirrors the canonical home-screen pattern (a trailing
  /// `SizedBox(height: paddingOf.bottom + 12 * scaling)`): the app-wide footer
  /// reserve is [MediaQuery.paddingOf]'s bottom (~100px, set in
  /// `root_app.dart`), which is a little short of the real overlay height
  /// (mini player + navigation bar), so +12 gives the same breathing room the
  /// home screen uses.
  ///
  /// The mini player grew when the playback timeline was added
  /// ([PlayerOverlayCollapsedSection.collapsedHeight]), so this reserve is
  /// derived from that constant rather than a stale hard-coded height.
  double get bottomPlayerReserve =>
      MediaQuery.paddingOf(this).bottom + 12 * Theme.of(this).scaling;

  /// Extra space the Lyrics screen needs below its content, on top of the
  /// app-wide footer padding, so the mini player and navigation bar never
  /// overlap the last lyric line.
  double get lyricsBottomReserve => bottomPlayerReserve;
}
