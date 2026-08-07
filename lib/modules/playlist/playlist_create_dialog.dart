import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:sangeet/collections/spotube_icons.dart';
import 'package:sangeet/components/form/checkbox_form_field.dart';
import 'package:sangeet/components/form/text_form_field.dart';
import 'package:sangeet/components/image/universal_image.dart';
import 'package:sangeet/extensions/context.dart';
import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/provider/library/library_data_provider.dart';
import 'package:sangeet/provider/metadata_plugin/library/playlists.dart';
import 'package:sangeet/provider/metadata_plugin/playlist/playlist.dart';
import 'package:sangeet/services/logger/logger.dart';

class PlaylistCreateDialog extends HookConsumerWidget {
  /// Track ids to add to the playlist
  final List<String> trackIds;
  final String? playlistId;
  const PlaylistCreateDialog({
    super.key,
    this.trackIds = const [],
    this.playlistId,
  });

  @override
  Widget build(BuildContext context, ref) {
    final userPlaylists = ref.watch(metadataPluginSavedPlaylistsProvider);
    final playlist =
        ref.watch(metadataPluginPlaylistProvider(playlistId ?? ""));
    final playlistNotifier =
        ref.watch(metadataPluginPlaylistProvider(playlistId ?? "").notifier);

    final isSubmitting = useState(false);

    final formKey = useMemoized(() => GlobalKey<FormBuilderState>(), []);

    final updatingPlaylist = useMemoized(
      () => userPlaylists.asData?.value.items
          .firstWhereOrNull((playlist) => playlist.id == playlistId),
      [
        userPlaylists.asData?.value.items,
        playlistId,
      ],
    );

    final isUpdatingPlaylist = playlistId != null;

    final l10n = context.l10n;
    final theme = Theme.of(context);

    useEffect(() {
      if (playlist.asData?.value != null) {
        formKey.currentState?.patchValue({
          'playlistName': playlist.asData!.value.name,
          'description': playlist.asData!.value.description,
        });
      }

      return;
    }, [playlist]);

    final onError = useCallback((error) {
      showToast(
        context: context,
        location: ToastLocation.topRight,
        builder: (context, overlay) {
          return SurfaceCard(
            child: Basic(
              title: Text(
                l10n.error(l10n.epic_failure),
                style: theme.typography.normal.copyWith(
                  color: theme.colorScheme.destructive,
                ),
              ),
            ),
          );
        },
      );
    }, [l10n, theme]);

    Future<void> onCreate() async {
      if (!formKey.currentState!.saveAndValidate()) return;

      var succeeded = false;
      try {
        isSubmitting.value = true;
        final values = formKey.currentState!.value;

        final playlistName =
            (values['playlistName'] ?? '').toString().trim();
        final description =
            (values['description'] ?? '').toString().trim();

        // Create via the on-device local playlist API. The metadata-plugin
        // bytecode path is unavailable in this build (its compiled bytecode is
        // not readable by the bundled hetu_script), so we persist playlists
        // directly through the local server, matching playlist_add_track_dialog.
        // Playlists are local-only (no public/collaborative options).
        if (isUpdatingPlaylist) {
          // Local playlists have no update endpoint; recreate is not supported
          // here, so keep the existing plugin-driven modify for completeness.
          await playlistNotifier.modify(
            name: playlistName,
            description: description,
            onError: onError,
          );
          succeeded = true;
        } else {
          await createUserPlaylist(
            name: playlistName,
            description: description,
          );
          ref.invalidate(userPlaylistsProvider);
          final playlists = await ref.read(userPlaylistsProvider.future);
          final created =
              playlists.isEmpty ? null : playlists.last;
          if (created != null && trackIds.isNotEmpty) {
            for (final trackId in trackIds) {
              await addTrackToUserPlaylist(created.id, trackId);
            }
          }
          succeeded = true;
        }
      } catch (e, stack) {
        AppLogger.reportError(e, stack);
      } finally {
        isSubmitting.value = false;
        if (context.mounted && succeeded) {
          Navigator.pop(context);
        }
      }
    }

    return AlertDialog(
      title: Text(
        isUpdatingPlaylist
            ? context.l10n.update_playlist
            : context.l10n.create_a_playlist,
      ),
      actions: [
        Button.outline(
          child: Text(context.l10n.cancel),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        Button.primary(
          onPressed: onCreate,
          enabled: !playlist.isLoading & !isSubmitting.value,
          child: Text(
            isUpdatingPlaylist ? context.l10n.update : context.l10n.create,
          ),
        ),
      ],
      content: Container(
        width: MediaQuery.of(context).size.width,
        constraints: const BoxConstraints(maxWidth: 500),
        child: FormBuilder(
          key: formKey,
          initialValue: {
            'playlistName': updatingPlaylist?.name,
            'description': updatingPlaylist?.description,
            'local': true,
          },
          child: ListView(
            shrinkWrap: true,
            children: [
              FormBuilderField<XFile?>(
                name: 'image',
                validator: (value) {
                  if (value == null) return null;
                  final file = File(value.path);

                  if (file.lengthSync() > 256000) {
                    return "Image size should be less than 256kb";
                  }

                  if (extension(file.path) != ".png") {
                    return "Image should be in PNG format";
                  }
                  return null;
                },
                builder: (field) {
                  return Column(
                    spacing: 10,
                    children: [
                      UniversalImage(
                        path: field.value?.path ??
                            (updatingPlaylist?.images).asUrlString(
                              placeholder: ImagePlaceholder.collection,
                            ),
                        height: 200,
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Button.secondary(
                            leading: const Icon(SangeetIcons.edit),
                            child: Text(
                              field.value?.path != null ||
                                      updatingPlaylist?.images != null
                                  ? context.l10n.change_cover
                                  : context.l10n.add_cover,
                            ),
                            onPressed: () async {
                              final imageFile = await ImagePicker().pickImage(
                                source: ImageSource.gallery,
                              );

                              if (imageFile != null) {
                                field.didChange(imageFile);
                                field.validate();
                                field.save();
                              }
                            },
                          ),
                          const SizedBox(width: 10),
                          IconButton.destructive(
                            icon: const Icon(SangeetIcons.trash),
                            enabled: field.value != null,
                            onPressed: () {
                              field.didChange(null);
                              field.validate();
                              field.save();
                            },
                          ),
                        ],
                      ),
                      if (field.hasError)
                        Text(
                          field.errorText ?? "",
                          style: theme.typography.normal.copyWith(
                            color: theme.colorScheme.destructive,
                          ),
                        )
                    ],
                  );
                },
              ),
              const Gap(20),
              TextFormBuilderField(
                name: 'playlistName',
                label: Text(context.l10n.playlist_name),
                placeholder: Text(context.l10n.name_of_playlist),
                validator: FormBuilderValidators.required(),
              ),
              const Gap(20),
              TextFormBuilderField(
                name: 'description',
                label: Text(context.l10n.description),
                placeholder: Text(context.l10n.description),
                keyboardType: TextInputType.multiline,
                maxLines: 5,
              ),
              const Gap(20),
              // Playlists are always local-only (kept on this device). The
              // "Local" tick is required and pre-checked so it is always on.
              CheckboxFormBuilderField(
                name: 'local',
                trailing: Text(context.l10n.local),
                validator: (value) {
                  if (value != true) {
                    return 'Playlists must be local';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PlaylistCreateDialogButton extends HookConsumerWidget {
  const PlaylistCreateDialogButton({super.key});

  showPlaylistDialog(BuildContext context) {
    showDialog(
      context: context,
      alignment: Alignment.center,
      builder: (context) => const ToastLayer(
        child: PlaylistCreateDialog(),
      ),
    );
  }

  @override
  Widget build(BuildContext context, ref) {
    return Button.secondary(
      leading: const Icon(SangeetIcons.addFilled),
      child: Text(context.l10n.playlist),
      onPressed: () async {
        // After the create dialog closes, refresh the on-device user playlists
        // so the new playlist appears in the library immediately.
        showPlaylistDialog(context);
        await Future.delayed(const Duration(milliseconds: 100));
        ref.invalidate(userPlaylistsProvider);
      },
    );
  }
}
