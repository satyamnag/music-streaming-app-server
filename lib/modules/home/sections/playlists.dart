import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sangeet/components/horizontal_playbutton_card_view/horizontal_playbutton_card_view.dart';
import 'package:sangeet/extensions/context.dart';
import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/provider/library/library_data_provider.dart';

/// A horizontal "Playlists" row shown on the home screen between "Recently
/// played" and "Newest arrivals". It shows the developer-curated default
/// playlists plus any playlists the user created on this device.
class HomePlaylistsSection extends HookConsumerWidget {
  const HomePlaylistsSection({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final ownerPlaylistsQuery = ref.watch(ownerPlaylistsProvider);
    final userPlaylistsQuery = ref.watch(userPlaylistsProvider);

    final ownerPlaylists = ownerPlaylistsQuery.asData?.value ??
        const <SangeetSimplePlaylistObject>[];
    final userPlaylists = userPlaylistsQuery.asData?.value ??
        const <SangeetSimplePlaylistObject>[];

    final isLoading = ownerPlaylistsQuery.isLoading || userPlaylistsQuery.isLoading;

    if (!isLoading && ownerPlaylists.isEmpty && userPlaylists.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverToBoxAdapter(
      child: HorizontalPlaybuttonCardView<SangeetSimplePlaylistObject>(
        title: Text(context.l10n.playlists),
        items: [...ownerPlaylists, ...userPlaylists],
        hasNextPage: false,
        onFetchMore: () {},
        isLoadingNextPage: isLoading,
      ),
    );
  }
}
