import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';
import 'package:sangeet/components/titlebar/titlebar.dart';
import 'package:sangeet/components/track_presentation/presentation_list.dart';
import 'package:sangeet/components/track_presentation/presentation_props.dart';
import 'package:sangeet/components/track_presentation/presentation_top.dart';
import 'package:sangeet/components/track_presentation/presentation_modifiers.dart';
import 'package:sangeet/extensions/constrains.dart';
import 'package:sangeet/extensions/context.dart';
import 'package:sangeet/utils/platform.dart';

class TrackPresentation extends HookConsumerWidget {
  final TrackPresentationOptions options;
  const TrackPresentation({
    super.key,
    required this.options,
  });

  @override
  Widget build(BuildContext context, ref) {
    final scrollController = useScrollController();
    final focusNode = useFocusNode();
    final scale = context.theme.scaling;

    useEffect(() {
      if (!kIsMobile) return null;
      void listener() {
        if (!scrollController.hasClients) return;

        if (focusNode.hasFocus) {
          scrollController.animateTo(
            300 * scale,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      }

      focusNode.addListener(listener);
      return () {
        focusNode.removeListener(listener);
      };
    }, [focusNode, scrollController, scale]);

    return Data<TrackPresentationOptions>.inherit(
      data: options,
      child: SafeArea(
        bottom: false,
        child: Scaffold(
          headers: const [TitleBar()],
          child: CustomScrollView(
            controller: scrollController,
            slivers: [
              const TrackPresentationTopSection(),
              const SliverGap(16),
              SliverList.list(
                children: [
                  TrackPresentationModifiersSection(
                    focusNode: focusNode,
                  ),
                  LayoutBuilder(builder: (context, constrains) {
                    return Basic(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 16,
                      ),
                      leading: constrains.mdAndUp ? const Text("  #") : null,
                      title: Row(
                        children: [
                          Expanded(
                            flex: constrains.lgAndUp ? 5 : 6,
                            child: Text(context.l10n.title),
                          ),
                          if (constrains.mdAndUp)
                            Expanded(
                              flex: 3,
                              child: Text(context.l10n.album),
                            ),
                          Text(context.l10n.duration),
                        ],
                      ),
                    ).small().muted();
                  }),
                ],
              ),
              const PresentationListSection(),
              // Reserve the floating footer's height, not a fixed 10.
              //
              // `SliverGap(10)` left ten logical pixels against a mini player
              // (86) plus navigation bar (50) that float OVER the list, so the
              // last row of tracks sat behind the player on every screen built
              // from this component - the liked playlist and every other
              // TrackPresentation page.
              //
              // `bottomPlayerReserve` reads `MediaQuery.paddingOf(this).bottom`,
              // which the scaffold has already set to the footers' measured
              // `footerHeight` (see `root_app.dart`), so this tracks the footer
              // as it changes instead of assuming a size.
              SliverToBoxAdapter(
                child: SizedBox(height: context.bottomPlayerReserve),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
