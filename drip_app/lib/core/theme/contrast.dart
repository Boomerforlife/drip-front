import 'package:flutter/painting.dart';

import 'app_colors.dart';
import 'app_theme.dart';

/// WCAG contrast ratio between two opaque colours (1 … 21).
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

/// [fg] nudged towards white or black, whichever the [bg] contrasts with,
/// until it reaches [minRatio]. Colours that already pass are returned
/// untouched, so a theme's own colour is only changed when it has to be.
Color ensureContrast(Color fg, Color bg, {double minRatio = 3}) {
  if (contrastRatio(fg, bg) >= minRatio) return fg;
  final pole = contrastRatio(const Color(0xFFFFFFFF), bg) >=
          contrastRatio(const Color(0xFF000000), bg)
      ? const Color(0xFFFFFFFF)
      : const Color(0xFF000000);
  for (var t = 0.05; t <= 1.0001; t += 0.05) {
    final c = Color.lerp(fg, pole, t)!;
    if (contrastRatio(c, bg) >= minRatio) return c;
  }
  return pole;
}

/// A hairline edge in [edge]'s hue that stays at least [minRatio] against
/// [bg]: the softest blend of [edge] (never fainter than [minAlpha]) that
/// passes, else the nearest colour that does. Opaque, so it reads the same
/// whatever is behind it.
Color visibleEdge(
  Color edge,
  Color bg, {
  double minAlpha = 0.38,
  double minRatio = 3,
}) {
  for (var a = minAlpha; a <= 1.0001; a += 0.04) {
    final c = Color.alphaBlend(edge.withValues(alpha: a.clamp(0, 1)), bg);
    if (contrastRatio(c, bg) >= minRatio) return c;
  }
  return ensureContrast(edge, bg, minRatio: minRatio);
}

/// What a Home feature tile is painted over: the theme's ground under the
/// tile's faint lifted fill.
Color featureTileBackdrop(DripPalette p) =>
    Color.alphaBlend(AppColors.cream.withValues(alpha: 0.08), p.ground);

/// Outline of the Selfie Coordinator tile (and the other live feature tiles).
///
/// Derived from the skin's accent but checked against the tile's actual
/// backdrop, so the edge keeps at least 3:1 (the WCAG bar for UI outlines)
/// whatever the theme, light or dark, instead of being a fixed-alpha accent
/// that only works on one ground.
Color selfieCoordinatorBorderColor(DripPalette p) =>
    visibleEdge(p.accent, featureTileBackdrop(p));
