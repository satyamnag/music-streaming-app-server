import 'dart:math';

import 'package:auto_route/auto_route.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';

import 'package:sangeet/collections/side_bar_tiles.dart';
import 'package:sangeet/extensions/constrains.dart';
import 'package:sangeet/extensions/context.dart';
import 'package:sangeet/models/database/database.dart';
import 'package:sangeet/provider/user_preferences/user_preferences_provider.dart';

final navigationPanelHeight = StateProvider<double>((ref) => 50);

class SangeetNavigationBar extends HookConsumerWidget {
  const SangeetNavigationBar({
    super.key,
  });

  @override
  Widget build(BuildContext context, ref) {
    final mediaQuery = MediaQuery.of(context);

    final layoutMode =
        ref.watch(userPreferencesProvider.select((s) => s.layoutMode));

    final navbarTileList = useMemoized(
      () => getNavbarTileList(context.l10n),
      [context.l10n],
    );

    final panelHeight = ref.watch(navigationPanelHeight);

    final router = context.watchRouter;
    final selectedIndex = max(
      0,
      navbarTileList.indexWhere(
        (e) => router.currentPath.startsWith(e.pathPrefix),
      ),
    );

    if (layoutMode == LayoutMode.extended ||
        (mediaQuery.mdAndUp && layoutMode == LayoutMode.adaptive) ||
        panelHeight < 10) {
      return const SizedBox();
    }

    final theme = Theme.of(context);

    // One tab = icon above its label. The selected tab is tinted with the
    // brand primary while the rest stay neutral, so the current section reads
    // at a glance the way the reference design shows it.
    Widget tab(int index) {
      final tile = navbarTileList[index];
      final selected = index == selectedIndex;
      return NavigationButton(
        style: selected
            ? const ButtonStyle.fixed(density: ButtonDensity.icon)
            : const ButtonStyle.muted(density: ButtonDensity.icon),
        child: Icon(
          tile.icon,
          size: 22,
          color: selected ? theme.colorScheme.primary : null,
        ),
        label: Text(
          tile.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        onPressed: () {
          context.navigateTo(tile.route);
        },
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      height: panelHeight,
      child: SingleChildScrollView(
        child: Column(
          children: [
            const Divider(),
            NavigationBar(
              index: selectedIndex,
              // Labels are always visible, under the icon: the bar shows
              // Home / Library / My Bhakti / Profile exactly as specified.
              labelType: NavigationLabelType.all,
              labelPosition: NavigationLabelPosition.bottom,
              labelSize: NavigationLabelSize.small,
              surfaceBlur: context.theme.surfaceBlur,
              surfaceOpacity: context.theme.surfaceOpacity,
              children: [
                for (var i = 0; i < navbarTileList.length; i++) tab(i),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
