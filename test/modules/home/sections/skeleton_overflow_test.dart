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

/// Mirrors the real home card anatomy so the skeleton exercise covers the exact
/// geometry `rowHeight` measures: a full-width square cover that bleeds to the
/// card's top/left/right edges, then a text block padded on the left, right and
/// bottom only.
///
/// This stub previously hard-coded a 175px-wide card with a 150px cover inside
/// `EdgeInsets.all(10)`, which does not match `TrackCard` at all (the cover is
/// `cardWidth` wide, not 150, and there is no padding above or beside it). It
/// only avoided overflowing `rowHeight` while `_cardHeightFor` under-counted the
/// text block's bottom padding; once that was corrected the stub's own mismatch
/// surfaced as a 34px overflow. Deriving every value from the shared constants
/// keeps the stub honest at any `cardScale`.
class _HomeCardSkeletonRow extends StatelessWidget {
  const _HomeCardSkeletonRow();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scale = theme.scaling;
    final cardWidth = HomeSectionLayout.cardWidth * scale;
    return Skeletonizer(
      enabled: true,
      child: SizedBox(
        height: HomeSectionLayout.rowHeight(context),
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            Container(
              width: cardWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // The cover bleeds to the card's top/left/right edges.
                  Container(height: cardWidth, width: cardWidth),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      HomeSectionLayout.cardPadding * scale,
                      HomeSectionLayout.cardTextGap * scale,
                      HomeSectionLayout.cardPadding * scale,
                      HomeSectionLayout.cardPadding * scale,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'A good track',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.typography.small.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Gap(HomeSectionLayout.titleSubtitleGap * scale),
                        Text(
                          'An album',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.typography.xSmall,
                        ),
                      ],
                    ),
                  ),
                ],
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
