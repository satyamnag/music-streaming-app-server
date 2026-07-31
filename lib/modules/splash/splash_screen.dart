import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sangeet/collections/assets.gen.dart';

/// Splash screen shown while the app initializes (plugins + local server
/// loading). Displays the round app logo centered with a loading indicator.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final background = Theme.of(context).colorScheme.background;
    final foreground = Theme.of(context).colorScheme.foreground;

    return Scaffold(
      backgroundColor: background,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipOval(
              child: Assets.branding.sangeetLogoPng.image(
                height: 120,
                width: 120,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
