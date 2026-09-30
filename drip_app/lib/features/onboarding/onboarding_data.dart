import 'package:flutter/painting.dart';

/// The choices offered by the onboarding flow (`Drip Onboarding.dc.html`).

class EraOption {
  const EraOption(this.id, this.label, this.glow);
  final String id;
  final String label;

  /// The backdrop glow the flow fades to when this era is picked.
  final Color glow;
}

class ColourOption {
  const ColourOption(this.id, this.name, this.hex);
  final String id;
  final String name;
  final int hex; // 0xFFRRGGBB

  Color get color => Color(hex);
}

class FitOption {
  const FitOption(this.id, this.label, this.desc, this.bar);
  final String id;
  final String label;
  final String desc;

  /// The bar length (0–100) in the fit picker.
  final int bar;
}

abstract final class OnboardingData {
  static const eras = [
    EraOption('y2k', 'Y2K', Color(0xFF48C8FF)),
    EraOption('streetwear', 'Streetwear', Color(0xFFFF2020)),
    EraOption('minimal', 'Minimal', Color(0xFFC2A882)),
    EraOption('grunge', 'Grunge', Color(0xFF6B7048)),
    EraOption('vintage', 'Vintage', Color(0xFFD2601F)),
    EraOption('preppy', 'Preppy', Color(0xFF2F4BD6)),
    EraOption('techwear', 'Techwear', Color(0xFF48C8FF)),
  ];

  static const genres = [
    'Quiet luxury',
    'Gorpcore',
    'Indie sleaze',
    'Old money',
    'Dark academia',
    'Coquette',
    'Boho',
    'Athleisure',
    'Workwear',
    'Desi fusion',
    'Skater',
    'Cottagecore',
    'Balletcore',
    'Avant-garde',
  ];

  static const genreImages = [
    'scene_editorial',
    'piece_shell_jacket',
    'create_preview',
    'scene_campus',
    'discover_gray_overcoat',
    'discover_pastel_shock',
    'story_lxnafits',
    'shoot_cobalt_oversized',
    'piece_bomber',
    'story_parismoto',
    'profile_fit_2',
    'wardrobe_vintage_hoodie',
    'scene_studio',
    'scene_metaverse',
  ];

  static const genreDescriptions = [
    'Soft neutrals, zero logos.',
    'Trail-ready shells, city-proof.',
    'Flash-lit, messy, unbothered.',
    'Polo, loafers, inherited calm.',
    'Tweed, libraries, dim light.',
    'Bows, lace and soft pinks.',
    'Flowy, earthy, festival-ready.',
    'Gym fit that skips the gym.',
    'Heavy canvas, honest stitching.',
    'Kurta cuts meet street fits.',
    'Baggy, scuffed, board-ready.',
    'Linen, florals, slow mornings.',
    'Wraps, tulle, pointe-soft.',
    'Rules optional, shapes loud.',
  ];

  static const colours = [
    ColourOption('cream', 'Cream', 0xFFE8DFC8),
    ColourOption('red', 'Drip Red', 0xFFFF2020),
    ColourOption('cyan', 'Future Cyan', 0xFF48C8FF),
    ColourOption('jet', 'Jet', 0xFF15161C),
    ColourOption('olive', 'Olive', 0xFF6B7048),
    ColourOption('sand', 'Sand', 0xFFC2A882),
    ColourOption('cobalt', 'Cobalt', 0xFF2F4BD6),
    ColourOption('blush', 'Blush', 0xFFE9B8B8),
    ColourOption('forest', 'Forest', 0xFF24513A),
    ColourOption('plum', 'Plum', 0xFF5A2A4F),
    ColourOption('burnt', 'Burnt Orange', 0xFFD2601F),
    ColourOption('lilac', 'Lilac', 0xFFB9A6E8),
  ];

  static const _warm = {'cream', 'red', 'olive', 'sand', 'blush', 'burnt'};

  static const clothes = [
    ('TOPS', ['Graphic tees', 'Shirts', 'Hoodies', 'Knitwear', 'Crop tops']),
    (
      'BOTTOMS',
      ['Cargos', 'Baggy denim', 'Tailored trousers', 'Skirts', 'Shorts'],
    ),
    (
      'LAYERS',
      ['Bombers', 'Overcoats', 'Puffers', 'Leather jackets', 'Blazers'],
    ),
    ('FOOTWEAR', ['Sneakers', 'Boots', 'Loafers', 'Chunky soles', 'Sandals']),
  ];

  static const accessories = [
    'Chains',
    'Rings',
    'Caps',
    'Beanies',
    'Shades',
    'Watches',
    'Belts',
    'Bags',
    'Scarves',
    'Bracelets',
    'Earrings',
    'Gloves',
  ];

  static const brands = [
    'Nike',
    'Adidas',
    'Zara',
    'H&M',
    'Uniqlo',
    'Levi’s',
    'Puma',
    'New Balance',
    'Bewakoof',
    'Snitch',
    'Fabindia',
    'Thrifted',
    'Indie labels',
    'Sneaker drops',
  ];

  static const brandSubs = [
    'Sport',
    'Street',
    'High street',
    'Everyday',
    'Basics',
    'Denim',
    'Sport',
    'Dad shoes',
    'Graphic tees',
    'Menswear',
    'Handloom',
    'Second hand',
    'Small batch',
    'Limited drops',
  ];

  static const fits = [
    FitOption('oversized', 'Oversized', 'Dropped shoulders', 92),
    FitOption('regular', 'Regular', 'True to size', 70),
    FitOption('slim', 'Tailored', 'Close to the body', 48),
  ];

  static const budgetMin = 500;
  static const budgetMax = 15000;

  /// Perceived luminance 0–1 (for picking a readable tick colour).
  static double luminance(int hex) {
    final r = (hex >> 16) & 0xFF, g = (hex >> 8) & 0xFF, b = hex & 0xFF;
    return (0.299 * r + 0.587 * g + 0.114 * b) / 255;
  }

  /// Warm vs cool, used to name the colour season on the ticket.
  static bool isWarm(String id, int hex) {
    if (_warm.contains(id)) return true;
    if (colours.any((c) => c.id == id)) return false;
    final r = (hex >> 16) & 0xFF, g = (hex >> 8) & 0xFF, b = hex & 0xFF;
    final rf = r / 255, gf = g / 255, bf = b / 255;
    final mx = [rf, gf, bf].reduce((a, b) => a > b ? a : b);
    final mn = [rf, gf, bf].reduce((a, b) => a < b ? a : b);
    if (mx == mn) return true;
    final d = mx - mn;
    var h = mx == rf
        ? ((gf - bf) / d) % 6
        : mx == gf
        ? (bf - rf) / d + 2
        : (rf - gf) / d + 4;
    h = (h * 60 + 360) % 360;
    return h < 70 || h > 330;
  }
}
