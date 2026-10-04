import 'dart:math' as math;

import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Parses an admin-configured card color (`#rrggbb` or `#rgb`, with or without
/// the leading `#`) into a [Color].
///
/// Returns null for null/empty/malformed input so every caller can fall back
/// to the theme default instead of throwing — a bad value stored by hand in the
/// database must never break a screen.
Color? parseCardColor(String? value) {
  if (value == null) return null;
  var hex = value.trim();
  if (hex.isEmpty) return null;
  if (hex.startsWith('#')) hex = hex.substring(1);
  if (hex.length == 3) {
    hex = hex.split('').map((c) => '$c$c').join();
  }
  if (hex.length != 6) return null;
  final parsed = int.tryParse(hex, radix: 16);
  if (parsed == null) return null;
  return Color(0xFF000000 | parsed);
}

/// The card box background color for a track/album: the admin-configured
/// color when set, otherwise [fallback] (the theme's card color).
Color cardBackgroundColor(String? configured, Color fallback) =>
    parseCardColor(configured) ?? fallback;

/// The card text color: the admin-configured color when set, otherwise
/// [fallback] (the theme's foreground or muted foreground).
Color cardTextColor(String? configured, Color fallback) =>
    parseCardColor(configured) ?? fallback;

/// Relative luminance (WCAG 2.x) of [color].
double _relativeLuminance(Color color) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(color.r) +
      0.7152 * channel(color.g) +
      0.0722 * channel(color.b);
}

/// WCAG contrast ratio between two colors (1..21).
double contrastRatio(Color a, Color b) {
  final la = _relativeLuminance(a);
  final lb = _relativeLuminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

const Color _black = Color(0xFF000000);
const Color _white = Color(0xFFFFFFFF);

/// Whether black or white text reads better on [background].
///
/// Used as a safety net: when an admin picks a background but leaves the text
/// color unset, the card still gets readable text instead of inheriting a
/// foreground that disappears into the new background.
///
/// The choice compares the two real WCAG contrast ratios rather than testing a
/// luminance threshold. A threshold picks white for mid-tone colors such as
/// teal (#07a7a9), where black actually scores 7.1:1 and white only 2.95:1 —
/// i.e. the threshold would produce unreadable text on a perfectly good
/// background.
Color readableTextOn(Color background) =>
    contrastRatio(background, _black) >= contrastRatio(background, _white)
        ? _black
        : _white;
