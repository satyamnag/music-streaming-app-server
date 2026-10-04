import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_undraw/flutter_undraw.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:sangeet/collections/spotube_icons.dart';
import 'package:sangeet/components/playbutton_view/playbutton_card.dart';
import 'package:sangeet/components/playbutton_view/playbutton_tile.dart';
import 'package:sangeet/components/waypoint.dart';
import 'package:sangeet/extensions/constrains.dart';
import 'package:sangeet/extensions/context.dart';
import 'package:sangeet/modules/home/sections/home_section_layout.dart';
import 'package:very_good_infinite_list/very_good_infinite_list.dart';

const _dummyPlaybuttonCard = PlaybuttonCard(
  imageUrl: 'https://placehold.co/150x150.png',
  isLoading: false,
  isPlaying: false,
  title: "Playbutton",
  description: "A really cool playbutton",
  isOwner: false,
);

const _dummyPlaybuttonTile = PlaybuttonTile(
  imageUrl: 'https://placehold.co/150x150.png',
  isLoading: false,
  isPlaying: false,
  title: "Playbutton",
  description: "A really cool playbutton",
  isOwner: false,
);

/// A [PlaybuttonCard] grid/list view (selectable) sliver widget
/// with support for infinite scrolling
class PlaybuttonView extends StatelessWidget {
  final int itemCount;
  final Widget Function(BuildContext context, int index) gridItemBuilder;
  final Widget Function(BuildContext context, int index) listItemBuilder;
  final bool hasMore;
  final bool isLoading;
  final VoidCallback onRequestMore;
  final ScrollController controller;

  final Widget? leading;

  /// Optional grid geometry for callers whose grid items are not
  /// [PlaybuttonCard]s. The library renders the shared home cards, whose height
  /// is derived from the tile width, so it passes the home grid delegate; null
  /// keeps the [PlaybuttonCard] geometry these tiles default to.
  final SliverGridDelegate? gridDelegate;

  /// Optional card shown in the grid's place of a [PlaybuttonCard] while
  /// loading (and at the trailing "load more" waypoint), so a grid of a
  /// different card keeps its own skeleton shape.
  final Widget? gridPlaceholder;

  /// Optional row shown in the list's place of a [PlaybuttonTile] while
  /// loading.
  final Widget? listPlaceholder;

  const PlaybuttonView({
    super.key,
    required this.itemCount,
    required this.gridItemBuilder,
    required this.listItemBuilder,
    required this.hasMore,
    required this.isLoading,
    required this.onRequestMore,
    required this.controller,
    this.leading,
    this.gridDelegate,
    this.gridPlaceholder,
    this.listPlaceholder,
  });

  @override
  Widget build(BuildContext context) {
    final scale = context.theme.scaling;

    return SliverLayoutBuilder(
      builder: (context, constrains) => HookBuilder(builder: (context) {
        final isGrid = useState(constrains.mdAndUp);
        final hasUserInteracted = useRef(false);

        useEffect(() {
          if (hasUserInteracted.value) return null;
          if (isGrid.value != constrains.mdAndUp) {
            isGrid.value = constrains.mdAndUp;
          }
          return null;
        }, [constrains]);

        return SliverMainAxisGroup(
          slivers: [
            SliverToBoxAdapter(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (leading != null) leading!,
                  Toggle(
                    value: isGrid.value,
                    style:
                        const ButtonStyle.outline(density: ButtonDensity.icon),
                    onChanged: (value) {
                      isGrid.value = value;
                      hasUserInteracted.value = true;
                    },
                    child: const Icon(SangeetIcons.grid),
                  ),
                  const SizedBox(width: 8),
                  Toggle(
                    value: !isGrid.value,
                    style:
                        const ButtonStyle.outline(density: ButtonDensity.icon),
                    onChanged: (value) {
                      isGrid.value = !value;
                      hasUserInteracted.value = true;
                    },
                    child: const Icon(SangeetIcons.list),
                  ),
                ],
              ),
            ),
            const SliverGap(10),
            // Toggle between grid and list view
            switch ((isGrid.value, isLoading)) {
              (true, _) => !isLoading && itemCount == 0
                  ? SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          spacing: 10,
                          children: [
                            Undraw(
                              height: 200 * context.theme.scaling,
                              illustration: UndrawIllustration.taken,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            Text(
                              context.l10n.nothing_found,
                              textAlign: TextAlign.center,
                            ).muted().small()
                          ],
                        ),
                      ),
                    )
                  : SliverGrid.builder(
                      itemCount:
                          isLoading ? 6 : (hasMore ? itemCount + 1 : itemCount),
                      gridDelegate: gridDelegate ??
                          SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 150 * scale,
                            mainAxisExtent: HomeSectionLayout
                                .playbuttonCardHeight(context),
                            crossAxisSpacing: 12 * scale,
                            mainAxisSpacing: 12 * scale,
                          ),
                      itemBuilder: (context, index) {
                        if (isLoading) {
                          return Skeletonizer(
                            enabled: true,
                            child: gridPlaceholder ?? _dummyPlaybuttonCard,
                          );
                        }

                        if (index == itemCount) {
                          if (!hasMore) return const SizedBox.shrink();
                          return Waypoint(
                            controller: controller,
                            isGrid: true,
                            onTouchEdge: onRequestMore,
                            child: Skeletonizer(
                              enabled: true,
                              child: gridPlaceholder ?? _dummyPlaybuttonCard,
                            ),
                          );
                        }

                        return gridItemBuilder(context, index);
                      },
                    ),
              (false, true) => Skeletonizer.sliver(
                  enabled: true,
                  child: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) =>
                          listPlaceholder ?? _dummyPlaybuttonTile,
                      childCount: 6,
                    ),
                  ),
                ),
              (false, false) => SliverInfiniteList(
                  itemCount: itemCount,
                  loadingBuilder: (context) => Skeletonizer(
                    enabled: true,
                    child: listPlaceholder ?? _dummyPlaybuttonTile,
                  ),
                  itemBuilder: listItemBuilder,
                  onFetchData: onRequestMore,
                  hasReachedMax: !hasMore,
                  isLoading: isLoading,
                  emptyBuilder: (context) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 10,
                      children: [
                        Undraw(
                          height: 200 * context.theme.scaling,
                          illustration: UndrawIllustration.taken,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        Text(
                          context.l10n.nothing_found,
                          textAlign: TextAlign.center,
                        ).muted().small()
                      ],
                    );
                  },
                ),
            }
          ],
        );
      }),
    );
  }
}
