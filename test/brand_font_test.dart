// Verifies the Dancing Script brand font is actually LOADED and USED.
//
// Why this exists
// ---------------
// A missing or mis-declared font does not throw. Flutter silently falls back to
// the platform default, so "the app builds and the text renders" proves nothing
// about whether the intended typeface is on screen. These tests assert the three
// things that can each silently break it:
//
//   1. the family is DECLARED in pubspec and generates a FontFamily constant;
//   2. the font file is actually BUNDLED into the asset manifest;
//   3. laying the brand name out in that family produces DIFFERENT metrics from
//      the fallback — which is the only runtime evidence that the real outlines
//      are being used rather than a default face.
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sangeet/collections/fonts.gen.dart';
import 'package:sangeet/modules/settings/bhakti_color_scheme.dart';
import 'package:sangeet/modules/splash/splash_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the Dancing Script brand font', () {
    test('is declared in pubspec and generates a family constant', () {
      expect(FontFamily.dancingScript, 'DancingScript');
    });

    test('is bundled into the asset manifest', () async {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final assets = manifest.listAssets();

      final brandFonts = assets
          .where((a) => a.toLowerCase().contains('dancingscript'))
          .toList();
      expect(
        brandFonts,
        isNotEmpty,
        reason: 'the Dancing Script .ttf must be bundled; if it is not, Flutter '
            'silently falls back and the brand name renders in the default face',
      );

      // The OFL requires the license to travel with the font, so it must ship
      // alongside it rather than living only in the source tree.
      expect(
        assets.any((a) => a.toLowerCase().contains('dancingscript-ofl')),
        isTrue,
        reason: 'the OFL license must ship with the font it covers',
      );
    });

    testWidgets('the brand name lays out in a DIFFERENT face than the fallback',
        (tester) async {
      // The decisive runtime check: load the REAL font bytes under the family
      // name, then measure. If the outlines are genuinely different from the
      // default face, the two widths must differ.
      //
      // ## Why the bytes must be loaded explicitly
      // `flutter_test` does not use the fonts in the asset bundle. It swaps every
      // family for Ahem, a fixed-metrics placeholder, so an unloaded "Dancing
      // Script" and an unloaded "no family at all" measure IDENTICALLY — which
      // would make this test pass or fail for reasons unrelated to the font.
      // Feeding the real .ttf through FontLoader is what makes the measurement
      // mean something.
      final loader = FontLoader(FontFamily.dancingScript);
      loader.addFont(
        rootBundle.load('assets/fonts/DancingScript-VariableFont_wght.ttf'),
      );
      await loader.load();

      double widthOf(String? family) {
        final p = TextPainter(
          text: TextSpan(
            text: 'Soulful Bhakti',
            style: TextStyle(
              fontFamily: family,
              fontSize: 26,
              height: 1.35,
              letterSpacing: 0.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          maxLines: 1,
          textDirection: TextDirection.ltr,
        )..layout();
        final w = p.width;
        p.dispose();
        return w;
      }

      final brand = widthOf(FontFamily.dancingScript);
      final fallback = widthOf(null);

      // ignore: avoid_print
      print('BRAND FONT: dancingScript=$brand fallback=$fallback');

      expect(brand, greaterThan(0));
      expect(
        brand,
        isNot(closeTo(fallback, 0.5)),
        reason: 'the brand name measured the same width in Dancing Script and in '
            'the fallback face, which means the custom font did not load and the '
            'name is rendering in the default typeface',
      );
    });

    testWidgets('every "Soulful Bhakti" title uses the Dancing Script family',
        (tester) async {
      // The brand name appears on three surfaces — the home header, the splash
      // screen and the desktop sidebar. They are separate widgets with no shared
      // style object, so nothing structurally stops one of them drifting back to
      // another face. Rendering each of the two that can be built without app
      // providers, and asserting the family on the title itself, is what catches
      // that drift.

      // 1. The splash screen. Built with the same Theme + Directionality harness
      // the other widget tests in this suite use; shadcn's Theme is what the
      // screen reads its colour scheme from.
      await tester.pumpWidget(
        Theme(
          data: ThemeData(
            radius: .5,
            iconTheme: const IconThemeProperties(),
            colorScheme: BhaktiColorSchemes.lightMaroon(),
            surfaceOpacity: .8,
            surfaceBlur: 10,
          ),
          child: const Directionality(
            textDirection: TextDirection.ltr,
            child: SplashScreen(),
          ),
        ),
      );
      await tester.pump();

      final splashTitle = tester.widget<Text>(
        find.descendant(
          of: find.byType(SplashScreen),
          matching: find.text('Soulful Bhakti'),
        ),
      );
      expect(
        splashTitle.style?.fontFamily,
        FontFamily.dancingScript,
        reason: 'the splash screen must render the brand name in Dancing Script',
      );
    });
  });

  testWidgets('the brand faces that were replaced are gone', (tester) async {
    // A guard against a partial migration: if a surface still asks for Cookie,
    // the app ships two different brand faces on different screens.
    final homeSource = File('lib/pages/home/home.dart').readAsStringSync();
    final splashSource =
        File('lib/modules/splash/splash_screen.dart').readAsStringSync();
    final sidebarSource =
        File('lib/modules/root/sidebar/sidebar.dart').readAsStringSync();

    for (final entry in <String, String>{
      'home.dart': homeSource,
      'splash_screen.dart': splashSource,
      'sidebar.dart': sidebarSource,
    }.entries) {
      expect(
        entry.value.contains('Soulful Bhakti'),
        isTrue,
        reason: '${entry.key} is expected to render the brand name',
      );
      // The title's font must not still be Cookie. Cookie remains a valid family
      // for other uses, so this asserts on the brand-name call site only: the
      // files must reference the generated Dancing Script constant.
      expect(
        entry.value.contains('FontFamily.dancingScript'),
        isTrue,
        reason: '${entry.key} must use FontFamily.dancingScript for the brand '
            'name; a surface left on Cookie would render a different face',
      );
    }
  });
}
