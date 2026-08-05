import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sangeet/collections/spotube_icons.dart';
import 'package:sangeet/models/metadata/metadata.dart';

import 'package:sangeet/components/image/universal_image.dart';
import 'package:sangeet/extensions/context.dart';
import 'package:sangeet/provider/library/library_data_provider.dart';

/// Lets the user add a set of selected tracks to one or more of their
/// on-device user playlists, or create a brand new playlist from the selected
/// songs.
class PlaylistAddTrackDialog extends HookConsumerWidget {
  /// The id of the playlist this dialog was opened from.
  final String? openFromPlaylist;
  final List<SangeetTrackObject> tracks;
  const PlaylistAddTrackDialog({
    required this.tracks,
    required this.openFromPlaylist,
    super.key,
  });

  @override
  Widget build(BuildContext context, ref) {
    final typography = Theme.of(context).typography;
    final userPlaylists = ref.watch(userPlaylistsProvider);

    final filteredPlaylists = useMemoized(
      () =>
          userPlaylists.asData?.value
              .where((playlist) => playlist.id != openFromPlaylist)
              .toList() ??
          [],
      [userPlaylists.asData?.value, openFromPlaylist],
    );

    final playlistsCheck = useState(<String, bool>{});

    Future<void> onAdd() async {
      final selectedPlaylists = playlistsCheck.value.entries
          .where((entry) => entry.value)
          .map((entry) => entry.key)
          .toList();
      for (final playlistId in selectedPlaylists) {
        for (final track in tracks) {
          await addTrackToUserPlaylist(playlistId, track.id);
        }
      }
      ref.invalidate(userPlaylistsProvider);
      if (context.mounted) Navigator.pop(context, true);
    }

    Future<void> onCreateNew() async {
      // Create a new playlist from the selected tracks using the on-device
      // local playlist API (adds every selected track reliably).
      final controller = useTextEditingController();
      final name = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.l10n.new_playlist),
          content: TextField(
            controller: controller,
            autofocus: true,
            placeholder: Text(context.l10n.playlist_name),
          ),
          actions: [
            Button.outline(
              child: Text(context.l10n.cancel),
              onPressed: () => Navigator.pop(context),
            ),
            Button.primary(
              onPressed: () =>
                  Navigator.pop(context, controller.text.trim()),
              child: Text(context.l10n.create),
            ),
          ],
        ),
      );
      if (name == null || name.isEmpty) return;
      await createUserPlaylist(name: name);
      ref.invalidate(userPlaylistsProvider);
      final playlists = await ref.read(userPlaylistsProvider.future);
      final created = playlists.isEmpty ? null : playlists.last;
      if (created == null) return;
      for (final track in tracks) {
        await addTrackToUserPlaylist(created.id, track.id);
      }
      ref.invalidate(userPlaylistsProvider);
      if (context.mounted) Navigator.pop(context, true);
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.l10n.add_to_playlist,
              style: typography.large,
            ),
            const Spacer(),
            Button.secondary(
              leading: const Icon(SangeetIcons.addFilled),
              onPressed: onCreateNew,
              child: Text(context.l10n.new_playlist),
            ),
          ],
        ),
        actions: [
          OutlineButton(
            child: Text(context.l10n.cancel),
            onPressed: () {
              Navigator.pop(context, false);
            },
          ),
          PrimaryButton(
            onPressed: onAdd,
            child: Text(context.l10n.add),
          ),
        ],
        content: SizedBox(
          height: 300,
          child: userPlaylists.isLoading
              ? const Center(child: CircularProgressIndicator())
              : filteredPlaylists.isEmpty
                  ? Center(
                      child: Text(
                        context.l10n.no_playlists_yet,
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: filteredPlaylists.length,
                      itemBuilder: (context, index) {
                        final playlist = filteredPlaylists.elementAt(index);
                        return Button.ghost(
                          style: ButtonVariance.ghost.copyWith(
                            padding: (context, _, __) {
                              return const EdgeInsets.symmetric(vertical: 8);
                            },
                          ),
                          leading: Avatar(
                            initials: Avatar.getInitials(playlist.name),
                            provider: UniversalImage.imageProvider(
                              playlist.images.asUrlString(
                                placeholder: ImagePlaceholder.collection,
                              ),
                            ),
                          ),
                          trailing: Checkbox(
                            state:
                                (playlistsCheck.value[playlist.id] ?? false)
                                    ? CheckboxState.checked
                                    : CheckboxState.unchecked,
                            onChanged: (val) {
                              playlistsCheck.value = {
                                ...playlistsCheck.value,
                                playlist.id: val == CheckboxState.checked,
                              };
                            },
                          ),
                          onPressed: () {
                            playlistsCheck.value = {
                              ...playlistsCheck.value,
                              playlist.id:
                                  !(playlistsCheck.value[playlist.id] ?? false),
                            };
                          },
                          child: Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: Text(playlist.name),
                          ),
                        );
                      },
                    ),
        ),
      ),
    );
  }
}
