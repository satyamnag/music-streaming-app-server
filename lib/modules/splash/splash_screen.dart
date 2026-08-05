import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sangeet/collections/assets.gen.dart';

/// Splash screen shown while the app initializes (plugins + local server
/// loading). The app logo is centered with the brand name below it, and a
/// round loading indicator in the brand accent color spins around the logo
/// until the home screen appears.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.background,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 172,
              height: 172,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: scheme.primary,
                    ),
                  ),
                  ClipOval(
                    child: Assets.branding.sangeetLogoPng.image(
                      height: 120,
                      width: 120,
                      fit: BoxFit.cover,
                    ),
                  ),
                ],
              ),
            ),
            const Gap(16),
            Text(
              'Soulful Bhakti',
              style: TextStyle(
                fontFamily: 'Cookie',
                fontSize: 34,
                letterSpacing: 1.8,
                color: scheme.foreground,
              ),
            ),
            const Gap(4),
            Text(
              'Devotional Music',
              style: TextStyle(
                fontSize: 12,
                letterSpacing: 2,
                color: scheme.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
