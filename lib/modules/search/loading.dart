import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';
import 'package:sangeet/extensions/constrains.dart';
import 'package:sangeet/extensions/context.dart';
import 'package:sangeet/pages/search/search.dart';

class SearchPlaceholder extends HookConsumerWidget {
  final AsyncValue snapshot;
  final Widget child;
  const SearchPlaceholder({
    super.key,
    required this.child,
    required this.snapshot,
  });

  @override
  Widget build(BuildContext context, ref) {
    final theme = context.theme;
    final mediaQuery = MediaQuery.sizeOf(context);

    final searchTerm = ref.watch(searchTermStateProvider);

    return switch ((searchTerm.isEmpty, snapshot.isLoading)) {
      // Empty query still returns the full catalog from the server, so show
      // the results (all songs) instead of a "type to search" placeholder.
      (false, true) => Container(
          constraints: BoxConstraints(
            maxWidth:
                mediaQuery.lgAndUp ? mediaQuery.width * 0.5 : mediaQuery.width,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                context.l10n.crunching_results,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: theme.colorScheme.foreground.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 20),
              const LinearProgressIndicator(),
            ],
          ),
        ),
      _ => child,
    };
  }
}
