import 'package:auto_route/auto_route.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:sangeet/collections/routes.gr.dart';
import 'package:sangeet/collections/spotube_icons.dart';
import 'package:sangeet/components/image/universal_image.dart';
import 'package:sangeet/extensions/constrains.dart';
import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/modules/connect/connect_device.dart';
import 'package:sangeet/provider/metadata_plugin/core/auth.dart';
import 'package:sangeet/provider/metadata_plugin/core/user.dart';

class SidebarFooter extends HookConsumerWidget implements NavigationBarItem {
  const SidebarFooter({
    super.key,
  });

  @override
  Widget build(BuildContext context, ref) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);
    final userSnapshot = ref.watch(metadataPluginUserProvider);
    final data = userSnapshot.asData?.value;

    final avatarImg = (data?.images).asUrlString(
      index: (data?.images.length ?? 1) - 1,
      placeholder: ImagePlaceholder.artist,
    );

    final authenticated = ref.watch(metadataPluginAuthenticatedProvider);

    if (mediaQuery.mdAndDown) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 10,
        children: [
          const ConnectDeviceButton.sidebar(),
          IconButton(
            variance: ButtonVariance.ghost,
            icon: const Icon(SangeetIcons.settings),
            onPressed: () => context.navigateTo(const SettingsRoute()),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.only(left: 12),
      width: 180,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 10,
        children: [
          const ConnectDeviceButton.sidebar(),
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (authenticated.asData?.value == true && data == null)
                const CircularProgressIndicator()
              else if (data != null)
                Flexible(
                  child: GestureDetector(
                    onTap: () {
                      context.navigateTo(const ProfileRoute());
                    },
                    child: Row(
                      children: [
                        Avatar(
                          initials: Avatar.getInitials(data.name),
                          provider: UniversalImage.imageProvider(avatarImg),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            data.name,
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.fade,
                            style: theme.typography.normal
                                .copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              IconButton(
                variance: ButtonVariance.ghost,
                icon: const Icon(SangeetIcons.settings),
                onPressed: () {
                  context.navigateTo(const SettingsRoute());
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  bool get selectable => false;
}
