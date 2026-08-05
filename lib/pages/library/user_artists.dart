import 'package:flutter/material.dart' as material;
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:collection/collection.dart';
import 'package:flutter_undraw/flutter_undraw.dart';
import 'package:fuzzywuzzy/fuzzywuzzy.dart';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:sangeet/collections/fake.dart';

import 'package:sangeet/collections/spotube_icons.dart';
import 'package:sangeet/components/fallbacks/anonymous_fallback.dart';
import 'package:sangeet/components/fallbacks/error_box.dart';
import 'package:sangeet/components/fallbacks/no_default_metadata_plugin.dart';
import 'package:sangeet/modules/artist/artist_card.dart';
import 'package:sangeet/components/inter_scrollbar/inter_scrollbar.dart';
import 'package:sangeet/extensions/constrains.dart';
import 'package:sangeet/extensions/context.dart';
import 'package:sangeet/provider/metadata_plugin/core/auth.dart';
import 'package:sangeet/provider/auth/clerk_auth_provider.dart';
import 'package:sangeet/provider/library/library_data_provider.dart';
import 'package:auto_route/auto_route.dart';
import 'package:sangeet/services/metadata/errors/exceptions.dart';

@RoutePage()
class UserArtistsPage extends HookConsumerWidget {
  static const name = 'user_artists';
  const UserArtistsPage({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final authenticated = ref.watch(metadataPluginAuthenticatedProvider);
    final clerkAuth = ref.watch(clerkAuthProvider);
    final isClerkSignedIn = clerkAuth.value?.signedIn == true;

    final artistQuery = ref.watch(libraryArtistsProvider);

    final searchText = useState('');

    final filteredArtists = useMemoized(() {
      final artists = artistQuery.asData?.value ?? [];

      if (searchText.value.isEmpty) {
        return artists.toList();
      }
      return artists
          .map((e) => (
                weightedRatio(e.name, searchText.value),
                e,
              ))
          .sorted((a, b) => b.$1.compareTo(a.$1))
          .where((e) => e.$1 > 50)
          .map((e) => e.$2)
          .toList();
    }, [artistQuery.asData?.value, searchText.value]);

    final controller = useScrollController();

    if (artistQuery.error
        case MetadataPluginException(
          errorCode: MetadataPluginErrorCode.noDefaultMetadataPlugin,
          message: _,
        )) {
      return const Center(child: NoDefaultMetadataPlugin());
    }

    if (authenticated.asData?.value != true && !isClerkSignedIn) {
      return const AnonymousFallback();
    }

    if (artistQuery.hasError) {
      return ErrorBox(
        error: artistQuery.error!,
        onRetry: () {
          ref.invalidate(libraryArtistsProvider);
        },
      );
    }

    return SafeArea(
      bottom: false,
      child: Scaffold(
        child: material.RefreshIndicator.adaptive(
          onRefresh: () async {
            ref.invalidate(libraryArtistsProvider);
          },
          child: InterScrollbar(
            controller: controller,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: CustomScrollView(
                controller: controller,
                slivers: [
                  SliverAppBar(
                    automaticallyImplyLeading: false,
                    backgroundColor: Theme.of(context).colorScheme.background,
                    floating: true,
                    flexibleSpace: SizedBox(
                      height: 48,
                      child: TextField(
                        onChanged: (value) => searchText.value = value,
                        features: const [
                          InputFeature.leading(Icon(SangeetIcons.filter)),
                        ],
                        placeholder: Text(context.l10n.filter_artist),
                      ),
                    ),
                  ),
                  const SliverGap(10),
                  if (filteredArtists.isNotEmpty || artistQuery.isLoading)
                    SliverLayoutBuilder(builder: (context, constrains) {
                      return SliverGrid.builder(
                        itemCount: filteredArtists.length,
                        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 200,
                          mainAxisExtent: constrains.smAndDown ? 225 : 250,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemBuilder: (context, index) {
                          return Skeletonizer(
                            enabled: artistQuery.isLoading,
                            child: ArtistCard(
                              filteredArtists.elementAtOrNull(index) ??
                                  FakeData.artist,
                            ),
                          );
                        },
                      );
                    })
                  else if (filteredArtists.isEmpty &&
                      searchText.value.isEmpty &&
                      !artistQuery.isLoading)
                    SliverToBoxAdapter(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        spacing: 10,
                        children: [
                          Undraw(
                            height: 200 * context.theme.scaling,
                            illustration: UndrawIllustration.followMeDrone,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          Text(
                            context.l10n.not_following_artists,
                            textAlign: TextAlign.center,
                          ).muted().small()
                        ],
                      ),
                    )
                  else
                    SliverToBoxAdapter(
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
                  const SliverSafeArea(sliver: SliverGap(10)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
