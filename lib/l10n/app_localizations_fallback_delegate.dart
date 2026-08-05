import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:sangeet/l10n/generated/app_localizations.dart';
import 'package:sangeet/l10n/generated/app_localizations_en.dart';

/// Localizations delegate that resolves every language selectable in the app.
///
/// Languages with real ARB translations (e.g. Hindi, French, Chinese) load the
/// generated [AppLocalizations] class for that locale. Any other language
/// falls back to the English localizations so the app is always fully
/// functional — the selected language is still applied to text direction and
/// system-level (Material) localizations.
class AppLocalizationsFallbackDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsFallbackDelegate();

  static const Set<String> _translatedCodes = {
    'ar',
    'bn',
    'ca',
    'cs',
    'de',
    'en',
    'es',
    'eu',
    'fa',
    'fi',
    'fr',
    'hi',
    'id',
    'it',
    'ja',
    'ka',
    'ko',
    'ne',
    'nl',
    'pl',
    'pt',
    'ru',
    'ta',
    'th',
    'tl',
    'tr',
    'uk',
    'vi',
    'zh',
  };

  @override
  Future<AppLocalizations> load(Locale locale) {
    if (_translatedCodes.contains(locale.languageCode)) {
      return SynchronousFuture<AppLocalizations>(
        lookupAppLocalizations(locale),
      );
    }
    return SynchronousFuture<AppLocalizations>(
      AppLocalizationsEn(),
    );
  }

  @override
  bool isSupported(Locale locale) => true;

  @override
  bool shouldReload(AppLocalizationsFallbackDelegate old) => false;
}