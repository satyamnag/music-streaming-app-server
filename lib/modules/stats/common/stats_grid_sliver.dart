import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sangeet/components/track_card/track_card.dart';

/// A GRID sliver that fills its tiles exactly, for the analytics screens.
///
/// ## Why not `SliverInfiniteList`
/// `very_good_infinite_list` builds a `SliverList` (see its
/// `sliver_infinite_list.dart`), and its public API exposes no grid delegate.
/// The analytics screens used it with a `Row`-based item, which is why they
/// showed a wide blank column beside every tile: the card took the full tile
/// width and the stat was squeezed into what was left.
///
/// A `SliverGrid` with the shared [trackGridDelegate] is what the home screen
/// uses, so the analytics grids now have the same column count, gutters, tile
/// width and card extent as home - the requirement that album and track surfaces
/// look the same everywhere.
///
/// ## What is deliberately NOT here
/// No pagination, no empty state, no loading state. Those belong to the SCREEN,
/// which already owns the providers that drive them; this builds the grid for a
/// list it is given. Keeping it to layout means the three analytics screens can
/// share it without sharing their data flow.
class StatsGridSliver extends StatelessWidget {
  /// The cells, in display order.
  final List<Widget> children;

  /// Extra space below the last row, so the floating mini player cannot hide it.
  ///
  /// Passed in rather than read here because the value comes from
  /// `context.bottomPlayerReserve`, and a caller that has already computed it
  /// should not pay for it twice.
  final double bottomPadding;

  const StatsGridSliver({
    super.key,
    required this.children,
    this.bottomPadding = 0,
  });

  @override
  Widget build(BuildContext context) {
    final grid = SliverPadding(
      // The same horizontal padding the home grids use, so the columns line up
      // with every other card surface.
      padding: const EdgeInsets.symmetric(horizontal: trackGridPadding),
      sliver: SliverGrid(
        gridDelegate: trackGridDelegate(context),
        delegate: SliverChildBuilderDelegate(
          (context, index) => children[index],
          childCount: children.length,
        ),
      ),
    );

    if (bottomPadding <= 0) return grid;

    return SliverMainAxisGroup(
      slivers: [
        grid,
        SliverToBoxAdapter(child: SizedBox(height: bottomPadding)),
      ],
    );
  }
}
