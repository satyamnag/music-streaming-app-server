// Regression guard for the RenderFlex overflow observed on the emulator:
//   "A RenderFlex overflowed by 4.0 pixels on the bottom" (6x) inside a
//   Skeletonizer paint context during the loading/skeleton phase.
// Flutter's debug overflow reporting turns any RenderFlex overflow in a
// widget test into a test failure, so pumping the skeleton states below is a
// direct reproduction: if any skeleton row overflows, this test fails and the
// error names the exact widget.
import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:sangeet/components/playbutton_view/playbutton_card.dart';
import 'package:sangeet/l10n/l10n.dart';
import 'package:sangeet/modules/home/sections/home_section_layout.dart';
import 'package:sangeet/modules/home/sections/track_section.dart';
import 'package:sangeet/modules/settings/bhakti_color_scheme.dart';
import 'package:sangeet/modules/stats/summary/summary_card.dart';

Widget _harness(Widget child) {
  return ProviderScope(
    child: material.MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: L10n.all,
      locale: const Locale('en'),
      home: Builder(
        builder: (context) => Theme(
          data: ThemeData(
            radius: .5,
            iconTheme: const IconThemeProperties(),
            colorScheme: BhaktiColorSchemes.lightMaroon(),
            surfaceOpacity: .8,
            surfaceBlur: 10,
          ),
          child: child,
        ),
      ),
    ),
  );
}

/// 150px-art PlaybuttonCard skeleton inside the exact playbutton row height
/// (row = card height + 16px of list padding, as used by the real rows).
class _PlaybuttonSkeletonRow extends StatelessWidget {
  const _PlaybuttonSkeletonRow();

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      enabled: true,
      child: SizedBox(
        height: HomeSectionLayout.playbuttonRowHeight(context),
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            SizedBox(
              width: 150,
              child: PlaybuttonCard(
                imageUrl: 'https://placehold.co/150x150.png',
                isPlaying: false,
                isLoading: false,
                title: 'Playbutton',
                description: 'A really cool playbutton',
                isOwner: false,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mirrors the home card anatomy (10 padding + 150 art + 4 gap + title line)
/// so the skeleton exercise covers the exact geometry rowHeight measures.
class _HomeCardSkeletonRow extends StatelessWidget {
  const _HomeCardSkeletonRow();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scale = theme.scaling;
    return Skeletonizer(
      enabled: true,
      child: SizedBox(
        height: HomeSectionLayout.rowHeight(context),
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            Container(
              width: 175 * scale,
              child: Padding(
                padding: EdgeInsets.all(10 * scale),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(height: 150 * scale, width: 150 * scale),
                    const Gap(4),
                    Text(
                      'A good track',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.small,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  testWidgets('home section skeleton states do not overflow', (tester) async {
    tester.view.physicalSize = const material.Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _harness(
        CustomScrollView(
          slivers: [
            const HomeTrackSection(
              title: 'Newest Arrivals',
              tracks: [],
              isLoading: true,
            ),
            const SliverToBoxAdapter(child: _PlaybuttonSkeletonRow()),
            const SliverToBoxAdapter(child: _HomeCardSkeletonRow()),
            // Stats summary grid skeleton: 6 SummaryCards (mirrors
            // StatsPageSummarySection) — the 6 same-amount overflows seen on
            // the emulator point at this grid.
            SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.5,
              ),
              delegate: SliverChildListDelegate(
                List.generate(
                  6,
                  (i) => const Skeletonizer(
                    enabled: true,
                    child: SummaryCard.unformatted(
                      title: '4,234',
                      unit: 'mins',
                      description: 'listened to music',
                      color: Colors.blue,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));

    // Sanity: the skeleton grid actually laid out (6 cards, non-zero size).
    final cardRect = tester.getRect(find.byType(SummaryCard).first);
    expect(cardRect.width, greaterThan(0));
    expect(cardRect.height, greaterThan(0));
  });
}
