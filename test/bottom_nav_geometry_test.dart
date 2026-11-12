// Guards the bottom navigation bar's HEIGHT against the real widget.
//
// The reported defect: the labels (Home / Library / My Bhakti / Profile) sat
// flush against the bottom edge of the bar, because the bar's container was
// hard-coded to 64dp while its own content measures more than that. The content
// was silently clipped — the `SingleChildScrollView` inside the bar made the
// overflow invisible instead of throwing.
//
// This test builds the SAME NavigationBar the app builds (same label type,
// position, size, button style and theme) and measures it, so the constant can
// never drift below what the widget actually needs:
//
//   * the divider + bar must fit inside `kNavigationBarHeight` (no clipping);
//   * the label must keep a real clearance above the bar's bottom edge;
//   * the label must still sit BELOW its icon, as the design requires.
//
// If this fails, raise `kNavigationBarHeight` — do not loosen the assertion.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sangeet/modules/root/spotube_navigation_bar.dart';
import 'package:sangeet/modules/settings/bhakti_color_scheme.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Mirrors the app's theme (see `main.dart`: `ThemeData(radius: .5, …)` plus
/// `scaling: AdaptiveScaling(1)`).
Widget _harness(Widget child) {
  return Theme(
    data: ThemeData(
      radius: .5,
      iconTheme: const IconThemeProperties(),
      colorScheme: BhaktiColorSchemes.lightMaroon(),
      surfaceOpacity: .8,
      surfaceBlur: 10,
    ),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(size: Size(360, 800)),
        child: Align(alignment: Alignment.topLeft, child: child),
      ),
    ),
  );
}

/// The app's own tab builder, copied field for field from
/// `SangeetNavigationBar.tab` (style, label, 22dp icon).
NavigationButton _tab(String label, IconData icon) => NavigationButton(
      style: const ButtonStyle.fixed(density: ButtonDensity.icon),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      onPressed: () {},
      child: Icon(icon, size: 22),
    );

Widget _bar({int selected = 0}) => SizedBox(
      width: 360,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Divider(),
          NavigationBar(
            index: selected,
            labelType: NavigationLabelType.all,
            labelPosition: NavigationLabelPosition.bottom,
            labelSize: NavigationLabelSize.small,
            children: [
              _tab('Home', Icons.home),
              _tab('Library', Icons.library_music),
              _tab('My Bhakti', Icons.music_note),
              _tab('Profile', Icons.person),
            ],
          ),
        ],
      ),
    );

void main() {
  testWidgets('the bar fits inside kNavigationBarHeight (nothing is clipped)',
      (tester) async {
    await tester.pumpWidget(_harness(_bar()));
    await tester.pump(const Duration(milliseconds: 300));

    final content = tester.getSize(find.byType(Column).first);

    expect(
      content.height,
      lessThanOrEqualTo(kNavigationBarHeight),
      reason: 'the divider + NavigationBar measure ${content.height}dp but the '
          'bar reserves only ${kNavigationBarHeight}dp, so the labels are cut '
          'off. Raise kNavigationBarHeight.',
    );
  });

  testWidgets('every label keeps clearance above the bar bottom edge',
      (tester) async {
    await tester.pumpWidget(_harness(_bar()));
    await tester.pump(const Duration(milliseconds: 300));

    final bar = tester.getRect(find.byType(NavigationBar));
    for (final label in ['Home', 'Library', 'My Bhakti', 'Profile']) {
      final rect = tester.getRect(find.text(label));
      expect(
        bar.bottom - rect.bottom,
        greaterThanOrEqualTo(12),
        reason: '"$label" sits ${bar.bottom - rect.bottom}dp above the bar '
            'bottom; <12dp reads as touching the bottom of the screen',
      );
    }
  });

  testWidgets('each label still sits BELOW its icon', (tester) async {
    await tester.pumpWidget(_harness(_bar()));
    await tester.pump(const Duration(milliseconds: 300));

    final label = tester.getRect(find.text('Home'));
    final icon = tester.getRect(find.byIcon(Icons.home));

    expect(label.top, greaterThan(icon.bottom),
        reason: 'the reference design puts the label under the icon');
  });

  group('home header: search and bell are evenly spaced', () {
    // The reported defect: the search icon sat too far from the bell. Both are
    // `IconButton.ghost`, each a 36dp box (20dp glyph + 8dp padding per side),
    // so the visible gap is padding + row gap + padding. The header's trailing
    // `Gap(10)` plus the bell's own 8dp padding leaves 18dp between the bell's
    // glyph and the screen edge; a 2dp row gap makes the glyph-to-glyph distance
    // 18dp as well. This measures the real widgets rather than trusting the
    // arithmetic, so a change in shadcn's button padding fails here instead of
    // silently re-breaking the rhythm on the device.
    Widget cluster() => SizedBox(
          width: 360,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton.ghost(
                icon: const Icon(Icons.search, size: 20),
                onPressed: () {},
              ),
              const Gap(2),
              IconButton.ghost(
                icon: const Icon(Icons.notifications_none, size: 20),
                onPressed: () {},
              ),
              const Gap(10),
            ],
          ),
        );

    testWidgets('the glyph-to-glyph gap equals the glyph-to-edge inset',
        (tester) async {
      await tester.pumpWidget(_harness(cluster()));
      await tester.pump(const Duration(milliseconds: 300));

      final search = tester.getRect(find.byIcon(Icons.search));
      final bell = tester.getRect(find.byIcon(Icons.notifications_none));
      final box = tester.getRect(find.byType(IconButton).first);

      final between = bell.left - search.right;
      final edge = 360 - bell.right;

      expect(between, closeTo(edge, 0.01),
          reason: 'the two actions must look evenly spaced: $between between, '
              '$edge to the edge');
      expect(between, 18,
          reason: 'the measured rhythm is 8 + 2 + 8 = 18dp; if shadcn changed '
              'its icon-button padding this number moves with it');
      expect(box.width, greaterThanOrEqualTo(36),
          reason: 'the glyph must keep its 36dp hit area (no overlap between '
              'the two actions)');
      expect(box.width, greaterThanOrEqualTo(24),
          reason: 'WCAG 2.2 AA target size floor');
    });

    testWidgets('home.dart keeps the 2dp + 10dp pair', (tester) async {
      final source = File('lib/pages/home/home.dart').readAsStringSync();
      final searchAt = source.indexOf('SangeetIcons.search');
      final bellAt = source.indexOf('NotificationBell(');

      expect(searchAt, greaterThan(-1));
      expect(bellAt, greaterThan(searchAt),
          reason: 'search must be the action left of the bell');

      final between = source.substring(searchAt, bellAt);
      expect(between.contains('const Gap(2)'), isTrue,
          reason: 'the 2dp gap is what makes the glyph spacing even; the old '
              '10dp gap measured 26dp against an 18dp edge inset');
    });
  });
}
