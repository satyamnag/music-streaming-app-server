import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sangeet/modules/home/sections/home_section_layout.dart';

/// Presents a home card at the home row's own fixed width inside a grid tile.
///
/// A grid tile is fluid — it takes whatever width the column maths gives it,
/// which on a 360dp phone is 165–169dp (measured) and on a 411dp phone
/// 190–194dp. The home rows use a fixed [HomeSectionLayout.cardWidth] (125dp at
/// scale 1), so a card placed directly in a tile came out noticeably bigger than
/// the same card on the home screen. This centres the card in its tile at the
/// home width, so album and track cards are the same size everywhere in the app.
///
/// The centring is not cosmetic: a grid tile hands its child TIGHT constraints,
/// and a tight constraint wins over the width a card asks for, so the cards'
/// own `width: cardWidth * scaling` was silently stretched to fill the tile.
/// [Align] passes LOOSE constraints instead, which is what lets the fixed-width
/// box below actually take its width. Cards then line up along the top of their
/// tiles ([Alignment.topCenter]) rather than floating in the middle of taller
/// tiles.
class HomeCardTile extends StatelessWidget {
  /// The album/track card to present. It renders at
  /// [HomeSectionLayout.cardWidth] (times the theme scaling) regardless of how
  /// wide its tile is.
  final Widget child;

  const HomeCardTile({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: HomeSectionLayout.cardWidth * Theme.of(context).scaling,
        child: child,
      ),
    );
  }
}

/// Exact grid tile height for a [HomeCardTile], derived from the same geometry
/// the card renders with so the tile never clips or leaves a dead band.
///
/// The card inside a tile is only [HomeSectionLayout.cardWidth] wide (see
/// [HomeCardTile]), so a tile sized from the fluid tile width would be taller
/// than the card and leave an empty band under every row. [withSubtitle] must
/// match the card variant placed in the tile: false for a card whose second
/// line is omitted.
double homeCardTileExtent(BuildContext context, {bool withSubtitle = true}) {
  return HomeSectionLayout.trackCardHeightFor(
    context,
    HomeSectionLayout.cardWidth * Theme.of(context).scaling,
    withSubtitle: withSubtitle,
  );
}
