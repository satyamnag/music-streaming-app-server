import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sangeet/l10n/l10n.dart';

extension AppLocale on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}

extension PlayerFooterReserve on BuildContext {
  /// Bottom inset a scrollable page must reserve so the floating mini player
  /// and bottom navigation bar never cover the page's last items.
  ///
  /// Derived from the inherited bottom padding, which `root_app.dart` no longer
  /// overwrites: with `floatingFooter: true` the scaffold adds the footers'
  /// measured `footerHeight` to it, so this value equals the real overlay height
  /// (mini player + navigation bar). The `+12` is breathing room, matching the
  /// trailing spacer the home screen uses.
  ///
  /// This used to be documented as "`paddingOf.bottom` (~100px, set in
  /// root_app.dart), which is a little short of the real overlay height". That
  /// was true and was the bug: `root_app.dart` discarded the scaffold's computed
  /// padding for a fixed 100, so the reserve was ~36px short of the ~136px
  /// footer and the last row of every screen sat under the mini player. Because
  /// the reserve is read from the padding, correcting that one line corrected
  /// all of these call sites at once - and it now follows the navigation bar as
  /// it animates, which a constant could not.
  double get bottomPlayerReserve =>
      MediaQuery.paddingOf(this).bottom + 12 * Theme.of(this).scaling;

  /// Extra space the Lyrics screen needs below its content, on top of the
  /// app-wide footer padding, so the mini player and navigation bar never
  /// overlap the last lyric line.
  double get lyricsBottomReserve => bottomPlayerReserve;
}
