import 'package:flutter/painting.dart';

import 'app_colors.dart';
import 'drip_skin.dart';

/// Typography helpers matching the Figma type ramp.
///
/// Figma "100%" line-height is the font's natural line-height, so [height] is
/// left null by default. A pixel line-height from the design is passed as
/// [lineHeight] and converted to a Flutter height multiplier.
abstract final class AppText {
  static const _even = TextLeadingDistribution.even;

  /// The Figma file draws icons as unicode glyphs (✦ ◀ ⌕ ✕ ♥ …) that the brand
  /// fonts lack, so bundled symbol fonts back every style up. Manrope comes
  /// last for the rupee sign (₹), which DM Mono doesn't have.
  static const fallback = [
    'Noto Sans Symbols',
    'Noto Sans Symbols 2',
    'Noto Emoji',
    'Manrope',
  ];

  static TextStyle _base(
    String family,
    double size,
    Color color,
    FontWeight weight,
    double? letterSpacing,
    double? lineHeight,
    List<FontVariation>? variations,
  ) {
    return TextStyle(
      fontFamily: family,
      fontFamilyFallback: fallback,
      fontSize: size,
      color: color,
      fontWeight: weight,
      letterSpacing: letterSpacing,
      height: lineHeight == null ? null : lineHeight / size,
      leadingDistribution: _even,
      fontVariations: variations,
    );
  }

  /// Smallest size any label is set at. The Figma drew some meta at 8–9px,
  /// which is unreadable on a phone held at arm's length.
  static const double minLabel = 10;

  /// DM Mono — labels, meta, numbers. Never smaller than [minLabel].
  static TextStyle mono(
    double size, {
    Color color = AppColors.cream,
    FontWeight weight = FontWeight.w400,
    double? letterSpacing,
    double? lineHeight,
  }) => _base(
    'DM Mono',
    size < minLabel ? minLabel : size,
    color,
    weight,
    letterSpacing,
    lineHeight,
    null,
  );

  /// The active theme's headline typeface (set by the app when the theme
  /// changes; the default is Bungee, the original DRIP voice).
  static DisplayFace face = DisplayFace.bungee;

  /// Headlines. Each theme speaks in its own face: Bungee (poster caps),
  /// Fredoka (soft and rounded) or Manrope ExtraBold (clean editorial).
  static TextStyle display(
    double size, {
    Color color = AppColors.cream,
    double? letterSpacing,
    double? lineHeight,
  }) => switch (face) {
    DisplayFace.bungee => _base(
      'Bungee',
      size,
      color,
      FontWeight.w400,
      letterSpacing,
      lineHeight,
      null,
    ),
    DisplayFace.fredoka => _base(
      'Fredoka',
      size * 1.06,
      color,
      FontWeight.w700,
      letterSpacing,
      lineHeight,
      [const FontVariation('wght', 700)],
    ),
    DisplayFace.manrope => _base(
      'Manrope',
      size * 1.02,
      color,
      FontWeight.w800,
      letterSpacing ?? -0.3,
      lineHeight,
      [const FontVariation('wght', 800)],
    ),
  };

  /// Manrope — body copy and buttons.
  static TextStyle manrope(
    double size, {
    Color color = AppColors.cream,
    FontWeight weight = FontWeight.w400,
    double? letterSpacing,
    double? lineHeight,
  }) => _base('Manrope', size, color, weight, letterSpacing, lineHeight, [
    FontVariation('wght', weight.value.toDouble()),
  ]);

  /// Inter — glyph icons and a few UI strings.
  static TextStyle inter(
    double size, {
    Color color = AppColors.cream,
    FontWeight weight = FontWeight.w400,
    double? letterSpacing,
    double? lineHeight,
  }) => _base('Inter', size, color, weight, letterSpacing, lineHeight, [
    FontVariation('wght', weight.value.toDouble()),
  ]);

  /// Fredoka — the "drip" wordmark.
  static TextStyle fredoka(
    double size, {
    Color color = AppColors.cream,
    double? letterSpacing,
    double? lineHeight,
  }) => _base(
    'Fredoka',
    size,
    color,
    FontWeight.w400,
    letterSpacing,
    lineHeight,
    [FontVariation('wght', 400)],
  );
}
