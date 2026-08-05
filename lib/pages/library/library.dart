import 'package:auto_route/auto_route.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sangeet/collections/routes.gr.dart';
import 'package:sangeet/collections/side_bar_tiles.dart';
import 'package:sangeet/components/titlebar/titlebar.dart';
import 'package:sangeet/extensions/constrains.dart';
import 'package:sangeet/extensions/context.dart';

@RoutePage()
class LibraryPage extends HookConsumerWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final router = context.watchRouter;
    final sidebarLibraryTileList = useMemoized(
      () => getSidebarLibraryTileList(context.l10n),
      [context.l10n],
    );
    final index = sidebarLibraryTileList.indexWhere(
      (e) => router.currentPath.startsWith(e.pathPrefix),
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        context.navigateTo(const HomeRoute());
      },
      child: SafeArea(
        bottom: false,
        child: LayoutBuilder(builder: (context, constraints) {
          return Scaffold(
            headers: [
              if (constraints.smAndDown)
                TitleBar(
                  automaticallyImplyLeading: false,
                  child: TabContainer(
                    selected: index,
                    onSelect: (index) {
                      context.navigateTo(sidebarLibraryTileList[index].route);
                    },
                    builder: (context, children) => Row(
                      children: [
                        for (final child in children) Expanded(child: child),
                      ],
                    ),
                    children: [
                      for (final tile in sidebarLibraryTileList)
                        TabItem(
                          child: Center(
                            child: Text(tile.title),
                          ),
                        ),
                    ],
                  ),
                )
              else
                const TitleBar(
                  automaticallyImplyLeading: false,
                  backgroundColor: Colors.transparent,
                  surfaceBlur: 0,
                  height: 32,
                ),
              const Gap(10),
            ],
            child: const AutoRouter(),
          );
        }),
      ),
    );
  }
}
