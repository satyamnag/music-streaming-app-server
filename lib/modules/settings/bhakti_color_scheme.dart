import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Soulful Bhakti color scheme derived from the app logo.
///
/// Logo palette:
///   - Deep maroon primary   #520101 (HSL 0, 0.98, 0.16)
///   - Gold accent           #e0a000 (HSL 43, 1.0, 0.44)
///   - White background      #fcfcfc
class BhaktiColorSchemes {
  const BhaktiColorSchemes._();

  /// Returns light maroon color scheme.
  static ColorScheme lightMaroon() {
    return ColorScheme(
      brightness: Brightness.light,
      background: const HSLColor.fromAHSL(1, 0.0, 0.0, 1.0).toColor(),
      foreground: const HSLColor.fromAHSL(1, 0.0, 0.12, 0.04).toColor(),
      card: const HSLColor.fromAHSL(1, 0.0, 0.0, 1.0).toColor(),
      cardForeground: const HSLColor.fromAHSL(1, 0.0, 0.12, 0.04).toColor(),
      popover: const HSLColor.fromAHSL(1, 0.0, 0.0, 1.0).toColor(),
      popoverForeground: const HSLColor.fromAHSL(1, 0.0, 0.12, 0.04).toColor(),
      primary: const HSLColor.fromAHSL(1, 0.0, 0.98, 0.16).toColor(),
      primaryForeground: const HSLColor.fromAHSL(1, 0.0, 0.0, 0.98).toColor(),
      secondary: const HSLColor.fromAHSL(1, 0.0, 0.1, 0.96).toColor(),
      secondaryForeground: const HSLColor.fromAHSL(1, 0.0, 0.9, 0.16).toColor(),
      muted: const HSLColor.fromAHSL(1, 0.0, 0.1, 0.96).toColor(),
      mutedForeground: const HSLColor.fromAHSL(1, 0.0, 0.05, 0.45).toColor(),
      accent: const HSLColor.fromAHSL(1, 43.0, 1.0, 0.44).toColor(),
      accentForeground: const HSLColor.fromAHSL(1, 0.0, 0.0, 0.02).toColor(),
      destructive: const HSLColor.fromAHSL(1, 0.0, 0.84, 0.6).toColor(),
      destructiveForeground:
          const HSLColor.fromAHSL(1, 0.0, 0.0, 0.98).toColor(),
      border: const HSLColor.fromAHSL(1, 0.0, 0.1, 0.9).toColor(),
      input: const HSLColor.fromAHSL(1, 0.0, 0.1, 0.9).toColor(),
      ring: const HSLColor.fromAHSL(1, 0.0, 0.98, 0.16).toColor(),
      chart1: const HSLColor.fromAHSL(1, 43.0, 1.0, 0.44).toColor(),
      chart2: const HSLColor.fromAHSL(1, 0.0, 0.98, 0.3).toColor(),
      chart3: const HSLColor.fromAHSL(1, 28.0, 0.9, 0.5).toColor(),
      chart4: const HSLColor.fromAHSL(1, 0.0, 0.8, 0.4).toColor(),
      chart5: const HSLColor.fromAHSL(1, 50.0, 0.9, 0.6).toColor(),
      sidebar: const HSLColor.fromAHSL(1, 0.0, 0.1, 0.98).toColor(),
      sidebarForeground: const HSLColor.fromAHSL(1, 0.0, 0.12, 0.04).toColor(),
      sidebarPrimary: const HSLColor.fromAHSL(1, 0.0, 0.98, 0.16).toColor(),
      sidebarPrimaryForeground:
          const HSLColor.fromAHSL(1, 0.0, 0.0, 0.98).toColor(),
      sidebarAccent: const HSLColor.fromAHSL(1, 43.0, 0.9, 0.94).toColor(),
      sidebarAccentForeground:
          const HSLColor.fromAHSL(1, 0.0, 0.9, 0.16).toColor(),
      sidebarBorder: const HSLColor.fromAHSL(1, 0.0, 0.1, 0.9).toColor(),
      sidebarRing: const HSLColor.fromAHSL(1, 0.0, 0.98, 0.16).toColor(),
    );
  }

  /// Returns dark maroon color scheme.
  static ColorScheme darkMaroon() {
    return ColorScheme(
      brightness: Brightness.dark,
      background: const HSLColor.fromAHSL(1, 0.0, 0.15, 0.04).toColor(),
      foreground: const HSLColor.fromAHSL(1, 0.0, 0.05, 0.95).toColor(),
      card: const HSLColor.fromAHSL(1, 0.0, 0.15, 0.04).toColor(),
      cardForeground: const HSLColor.fromAHSL(1, 0.0, 0.05, 0.95).toColor(),
      popover: const HSLColor.fromAHSL(1, 0.0, 0.15, 0.04).toColor(),
      popoverForeground: const HSLColor.fromAHSL(1, 0.0, 0.05, 0.95).toColor(),
      primary: const HSLColor.fromAHSL(1, 0.0, 0.6, 0.3).toColor(),
      primaryForeground: const HSLColor.fromAHSL(1, 0.0, 0.0, 0.98).toColor(),
      secondary: const HSLColor.fromAHSL(1, 0.0, 0.1, 0.15).toColor(),
      secondaryForeground: const HSLColor.fromAHSL(1, 0.0, 0.05, 0.95).toColor(),
      muted: const HSLColor.fromAHSL(1, 0.0, 0.1, 0.15).toColor(),
      mutedForeground: const HSLColor.fromAHSL(1, 0.0, 0.05, 0.64).toColor(),
      accent: const HSLColor.fromAHSL(1, 43.0, 0.9, 0.55).toColor(),
      accentForeground: const HSLColor.fromAHSL(1, 0.0, 0.0, 0.05).toColor(),
      destructive: const HSLColor.fromAHSL(1, 0.0, 0.63, 0.31).toColor(),
      destructiveForeground:
          const HSLColor.fromAHSL(1, 0.0, 0.0, 0.98).toColor(),
      border: const HSLColor.fromAHSL(1, 0.0, 0.1, 0.15).toColor(),
      input: const HSLColor.fromAHSL(1, 0.0, 0.1, 0.15).toColor(),
      ring: const HSLColor.fromAHSL(1, 43.0, 0.9, 0.55).toColor(),
      chart1: const HSLColor.fromAHSL(1, 43.0, 0.9, 0.55).toColor(),
      chart2: const HSLColor.fromAHSL(1, 0.0, 0.6, 0.4).toColor(),
      chart3: const HSLColor.fromAHSL(1, 28.0, 0.9, 0.55).toColor(),
      chart4: const HSLColor.fromAHSL(1, 0.0, 0.7, 0.5).toColor(),
      chart5: const HSLColor.fromAHSL(1, 50.0, 0.9, 0.6).toColor(),
      sidebar: const HSLColor.fromAHSL(1, 0.0, 0.15, 0.04).toColor(),
      sidebarForeground: const HSLColor.fromAHSL(1, 0.0, 0.05, 0.95).toColor(),
      sidebarPrimary: const HSLColor.fromAHSL(1, 0.0, 0.6, 0.3).toColor(),
      sidebarPrimaryForeground:
          const HSLColor.fromAHSL(1, 0.0, 0.0, 0.98).toColor(),
      sidebarAccent: const HSLColor.fromAHSL(1, 43.0, 0.8, 0.2).toColor(),
      sidebarAccentForeground:
          const HSLColor.fromAHSL(1, 0.0, 0.05, 0.95).toColor(),
      sidebarBorder: const HSLColor.fromAHSL(1, 0.0, 0.1, 0.15).toColor(),
      sidebarRing: const HSLColor.fromAHSL(1, 43.0, 0.9, 0.55).toColor(),
    );
  }

  /// Returns maroon color scheme for the given [mode].
  static ColorScheme maroon(ThemeMode mode) {
    return mode == ThemeMode.light ? lightMaroon() : darkMaroon();
  }
}
