import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sangeet/modules/home/sections/home_section_layout.dart';

/// A horizontal row of home cards: an optional section heading followed by one
/// line of cards sized to exactly the height they need.
///
/// Every horizontal card row in the app renders through this widget (the home
/// sections and the search screen's album row) so the row geometry — side
/// padding, card gap and height — stays defined once, next to the card geometry
/// in [HomeSectionLayout].
class HomeCardRow extends StatelessWidget {
  /// Optional section heading, e.g. the home rows' title + "see all" arrow. It
  /// is rendered with the home rows' heading gap above the cards.
  final Widget? header;

  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;

  /// Exact row height, or null to take the one-card-height default
  /// ([HomeSectionLayout.rowHeight]).
  ///
  /// A row must be exactly as tall as the card it holds: too short clips the
  /// card, too tall leaves a dead band under it. The default fits the one-line
  /// title + subtitle album/playlist card; a row of TRACK cards has to pass
  /// [HomeSectionLayout.twoLineTrackRowHeight] instead, because those cards
  /// reserve two title lines and carry no subtitle. The caller knows which card
  /// it renders, so the choice is made there rather than guessed here.
  final double? height;

  const HomeCardRow({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.header,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final scale = Theme.of(context).scaling;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (header != null) ...[
          header!,
          Gap(8 * scale),
        ],
        SizedBox(
          height: height ?? HomeSectionLayout.rowHeight(context),
          child: ListView.separated(
            padding: EdgeInsets.symmetric(horizontal: 16.0 * scale),
            scrollDirection: Axis.horizontal,
            itemCount: itemCount,
            separatorBuilder: (_, __) => Gap(6 * scale),
            itemBuilder: itemBuilder,
          ),
        ),
      ],
    );
  }
}
