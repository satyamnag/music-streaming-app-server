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
    final sidebarLibraryTileList = useMemoized(
      () => getSidebarLibraryTileList(context.l10n),
      [context.l10n],
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
                  title: Center(
                    child: Text(
                      sidebarLibraryTileList.first.title,
                      style: Theme.of(context).typography.h4,
                    ),
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
