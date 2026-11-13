import 'package:auto_route/auto_route.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sangeet/modules/player/sibling_tracks_sheet.dart';

@RoutePage()
class PlayerTrackSourcesPage extends StatelessWidget {
  const PlayerTrackSourcesPage({super.key});

  @override
  Widget build(BuildContext context) {
    // A pushed route, so it is OUTSIDE the root Scaffold's body and gets no
    // inset from it: without this SafeArea the sheet's title sat under the
    // status bar (the root no longer consumes the top inset - see root_app.dart).
    return const SafeArea(
      bottom: false,
      child: Scaffold(
        child: SiblingTracksSheet(floating: false),
      ),
    );
  }
}
