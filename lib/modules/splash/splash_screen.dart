import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sangeet/collections/assets.gen.dart';

/// Splash screen shown while the app initializes (plugins + local server
/// loading).
///
/// UX details:
///  - The app logo fades in with a subtle scale (from 96% to 100%) using an
///    ease-out curve, then a thin brand-accent progress ring spins around it.
///  - A soft ambient ring sits behind the logo so the spinner never visually
///    "pops" against the background.
///  - Respects the OS "reduce motion" setting: the fade/scale are skipped so
///    the content simply appears.
///  - Exposed to accessibility tools with a clear loading announcement.
class SplashScreen extends HookWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Scaffold(
      backgroundColor: scheme.background,
      child: Center(
        child: Semantics(
          container: true,
          label: 'Soulful Bhakti is loading',
          liveRegion: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 172,
                height: 172,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Soft ambient glow behind the logo so the spinner arc is
                    // always comfortably visible against the background.
                    Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: scheme.primary.withValues(alpha: 0.05),
                      ),
                    ),
                    if (reduceMotion)
                      _buildLogo(scheme)
                    else
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 650),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: Transform.scale(
                              scale: 0.96 + 0.04 * value,
                              child: child,
                            ),
                          );
                        },
                        child: _buildLogo(scheme),
                      ),
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: SizedBox.expand(
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: scheme.primary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(20),
              Text(
                'Soulful Bhakti',
                style: TextStyle(
                  fontFamily: 'Cookie',
                  fontSize: 34,
                  letterSpacing: 1.8,
                  color: scheme.foreground,
                ),
              ),
              const Gap(6),
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
      ),
    );
  }

  Widget _buildLogo(ColorScheme scheme) {
    return ClipOval(
      child: Assets.branding.sangeetLogoPng.image(
        height: 120,
        width: 120,
        fit: BoxFit.cover,
      ),
    );
  }
}
