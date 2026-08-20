import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sangeet/models/metadata/metadata.dart';

class ArtistLink extends StatelessWidget {
  final List<SangeetSimpleArtistObject> artists;
  final WrapCrossAlignment crossAxisAlignment;
  final WrapAlignment mainAxisAlignment;
  final TextStyle textStyle;
  final bool hideOverflowArtist;
  final void Function(String route)? onRouteChange;
  final VoidCallback? onOverflowArtistClick;

  const ArtistLink({
    super.key,
    required this.artists,
    this.crossAxisAlignment = WrapCrossAlignment.center,
    this.mainAxisAlignment = WrapAlignment.center,
    this.textStyle = const TextStyle(),
    this.onRouteChange,
    this.hideOverflowArtist = true,
    this.onOverflowArtistClick,
  }) : assert(hideOverflowArtist ? onOverflowArtistClick != null : true);

  @override
  Widget build(BuildContext context) {
    // Artist names are intentionally hidden app-wide. Keep the component
    // signature intact so callers and navigation still compile/work; just do
    // not render any artist name text.
    return const SizedBox.shrink();
  }
}
