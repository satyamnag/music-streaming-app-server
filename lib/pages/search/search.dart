import 'dart:async';

import 'package:flutter/services.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fuzzywuzzy/fuzzywuzzy.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sangeet/collections/routes.gr.dart';

import 'package:sangeet/collections/spotube_icons.dart';
import 'package:sangeet/components/fallbacks/error_box.dart';
import 'package:sangeet/components/fallbacks/no_default_metadata_plugin.dart';
import 'package:sangeet/components/titlebar/titlebar.dart';
import 'package:sangeet/extensions/context.dart';
import 'package:sangeet/extensions/string.dart';
import 'package:sangeet/hooks/controllers/use_shadcn_text_editing_controller.dart';
import 'package:sangeet/pages/search/tabs/all.dart';
import 'package:sangeet/pages/search/tabs/artists.dart';
import 'package:sangeet/pages/search/tabs/playlists.dart';
import 'package:sangeet/pages/search/tabs/tracks.dart';
import 'package:sangeet/provider/metadata_plugin/search/all.dart';
import 'package:sangeet/services/kv_store/kv_store.dart';
import 'package:auto_route/auto_route.dart';
import 'package:sangeet/services/metadata/errors/exceptions.dart';

final searchTermStateProvider = StateProvider<String>((ref) {
  return "";
});

@RoutePage()
class SearchPage extends HookConsumerWidget {
  static const name = "search";

  const SearchPage({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final controller = useShadcnTextEditingController();
    final focusNode = useFocusNode();

    final searchTerm = ref.watch(searchTermStateProvider);
    // The Supabase plugin is bundled and always available; we still watch its
    // chips provider so a plugin-load failure surfaces as an error state.
    final searchChipSnapshot = ref.watch(metadataPluginSearchChipsProvider);
    // Filter chips shown on the search screen. The Supabase plugin reports no
    // chips (its catalog is track-only), so we define the filters here: "all"
    // (everything) and "songs" (the full song list). Both list all songs when
    // the search box is empty; typing narrows the results.
    const filterChips = ["all", "songs"];
    final selectedChip = useState<String?>(filterChips.first);

    useEffect(() {
      controller.text = searchTerm;

      return null;
    }, []);

    // Debounced live search: fire the search ~450ms after the user stops
    // typing, so results update progressively without a network request per
    // keystroke. Explicit submit still triggers immediately and persists the
    // query in the recent-searches store.
    final debounce = useRef<Timer?>(null);
    useEffect(
      () {
        return () => debounce.value?.cancel();
      },
      [debounce],
    );

    void scheduleSearch(String value) {
      debounce.value?.cancel();
      debounce.value = Timer(
        const Duration(milliseconds: 450),
        () {
          // Empty input clears the search (returns to the full catalog);
          // non-empty input triggers the live search.
          ref.read(searchTermStateProvider.notifier).state = value.trim();
        },
      );
    }

    void onSubmitted(String value) {
      debounce.value?.cancel();
      ref.read(searchTermStateProvider.notifier).state = value;
      focusNode.unfocus();
      if (value.trim().isEmpty) {
        return;
      }
      KVStoreService.setRecentSearches(
        {
          value,
          ...KVStoreService.recentSearches,
        }.toList(),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        context.navigateTo(const HomeRoute());
      },
      child: SafeArea(
        bottom: false,
        child: Scaffold(
          headers: [
            if (kTitlebarVisible)
              const TitleBar(automaticallyImplyLeading: false, height: 30)
          ],
          child: Builder(builder: (context) {
            if (searchChipSnapshot.error
                case MetadataPluginException(
                  errorCode: MetadataPluginErrorCode.noDefaultMetadataPlugin,
                  message: _
                )) {
              return const NoDefaultMetadataPlugin();
            }

            if (searchChipSnapshot.hasError) {
              return ErrorBox(
                error: searchChipSnapshot.error!,
                onRetry: () {
                  ref.invalidate(metadataPluginSearchChipsProvider);
                },
              );
            }

            return Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        child: ListenableBuilder(
                            listenable: controller,
                            builder: (context, _) {
                              final suggestions = controller.text.isEmpty
                                  ? KVStoreService.recentSearches
                                  : KVStoreService.recentSearches
                                      .where(
                                        (s) =>
                                            weightedRatio(
                                              s.toLowerCase(),
                                              controller.text.toLowerCase(),
                                            ) >
                                            50,
                                      )
                                      .toList();

                              return AutoComplete(
                                suggestions: suggestions,
                                completer: (suggestion) => suggestion,
                                mode: AutoCompleteMode.replaceAll,
                                child: TextField(
                                  autofocus: true,
                                  controller: controller,
                                  focusNode: focusNode,
                                  features: [
                                    const InputFeature.leading(
                                      Icon(SangeetIcons.search),
                                    ),
                                    InputFeature.trailing(
                                      AnimatedCrossFade(
                                        duration:
                                            const Duration(milliseconds: 300),
                                        crossFadeState:
                                            controller.text.isNotEmpty
                                                ? CrossFadeState.showFirst
                                                : CrossFadeState.showSecond,
                                        firstChild: IconButton.ghost(
                                          size: ButtonSize.small,
                                          icon: const Icon(SangeetIcons.close),
                                          onPressed: () {
                                            controller.clear();
                                          },
                                        ),
                                        secondChild: const SizedBox.square(
                                            dimension: 28),
                                      ),
                                    )
                                  ],
                                  textInputAction: TextInputAction.search,
                                  placeholder: Text(context.l10n.search),
                                  onChanged: scheduleSearch,
                                  onSubmitted: onSubmitted,
                                ),
                              );
                            }),
                      ),
                    ),
                  ],
                ),
                Row(
                  spacing: 8,
                  children: [
                    const Gap(12),
                    for (final chip in filterChips)
                      Chip(
                        style: selectedChip.value == chip
                            ? ButtonVariance.primary.copyWith(
                                decoration: (context, states, value) {
                                  return ButtonVariance.primary
                                      .decoration(context, states)
                                      .copyWithIfBoxDecoration(
                                        borderRadius:
                                            BorderRadius.circular(100),
                                      );
                                },
                              )
                            : ButtonVariance.secondary.copyWith(
                                decoration: (context, states, value) {
                                  return ButtonVariance.secondary
                                      .decoration(context, states)
                                      .copyWithIfBoxDecoration(
                                        borderRadius:
                                            BorderRadius.circular(100),
                                      );
                                },
                              ),
                        child: Text(chip.capitalize()),
                        onPressed: () {
                          selectedChip.value = chip;
                        },
                      ),
                  ],
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: switch (selectedChip.value) {
                      "songs" || "tracks" => const SearchPageTracksTab(),
                      "artists" => const SearchPageArtistsTab(),
                      "playlists" => const SearchPagePlaylistsTab(),
                      _ => const SearchPageAllTab(),
                    },
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}
