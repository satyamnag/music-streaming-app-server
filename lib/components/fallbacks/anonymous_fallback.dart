import 'package:auto_route/auto_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_undraw/flutter_undraw.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';
import 'package:sangeet/collections/routes.gr.dart';
import 'package:sangeet/extensions/context.dart';
import 'package:sangeet/provider/auth/clerk_auth_provider.dart';
import 'package:sangeet/provider/metadata_plugin/core/auth.dart';

import 'package:sangeet/utils/platform.dart';

class AnonymousFallback extends ConsumerWidget {
  final Widget? child;
  const AnonymousFallback({
    super.key,
    this.child,
  });

  @override
  Widget build(BuildContext context, ref) {
    final isLoggedIn = ref.watch(metadataPluginAuthenticatedProvider);
    final clerkAuth = ref.watch(clerkAuthProvider);
    final clerkSignedIn =
        clerkAuth.value?.signedIn == true && clerkAuth.isLoading == false;

    if (isLoggedIn.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final authenticated = isLoggedIn.asData?.value == true || clerkSignedIn;
    if (authenticated && child != null) return child!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: 10,
        children: [
          Undraw(
            illustration: kIsMobile
                ? UndrawIllustration.accessDenied
                : UndrawIllustration.secureLogin,
            height: 200 * context.theme.scaling,
            color: context.theme.colorScheme.primary,
          ),
          Text(context.l10n.not_logged_in),
          Button.primary(
            child: Text(context.l10n.login),
            onPressed: () => context.navigateTo(const SettingsRoute()),
          )
        ],
      ),
    );
  }
}
