import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sangeet/l10n/l10n.dart';

extension AppLocale on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}

extension PlayerFooterReserve on BuildContext {
  /// Bottom inset a scrollable page must reserve so the floating mini player
  /// (63px) and bottom navigation bar (50px) never cover the page's last
  /// items. Mirrors the canonical home-screen pattern
  /// (`home.dart` trailing `SizedBox(height: paddingOf.bottom + 12 * scaling)`):
  /// the app-wide footer reserve is `MediaQuery.paddingOf(context).bottom`
  /// (~100px, set in root_app.dart), which is ~13px short of the ~113px
  /// overlay, so +12 gives the same breathing room home uses.
  double get bottomPlayerReserve =>
      MediaQuery.paddingOf(this).bottom + 12 * Theme.of(this).scaling;
}
