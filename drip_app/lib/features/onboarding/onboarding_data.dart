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

/// The type treatments for labels without a logo.
enum MarkFace {
  /// Bungee caps: loud, poster-like.
  poster,

  /// Fredoka, lowercase: friendly and round.
  round,

  /// Manrope light, lowercase: quiet, crafted.
  light,

  /// Manrope extra-bold.
  heavy,

  /// Manrope extra-bold caps, widely tracked.
  spaced,

  /// DM Mono caps, tracked like a price tag.
  tag,
}

class BrandLook {
  const BrandLook(
    this.fill,
    this.ink, {
    this.logo,
    this.ratio = 1,
    this.mark,
    this.face = MarkFace.heavy,
  });

  /// The tile's colour and the colour drawn on it (0xAARRGGBB).
  final int fill;
  final int ink;

  /// An SVG logo, and its width ÷ height.
  final String? logo;
  final double ratio;

  /// Otherwise, the name as set on the tile, and how.
  final String? mark;
  final MarkFace face;
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

  /// Genres that sit naturally with each era: what "more like you" offers
  /// once eras are picked.
  static const eraGenres = {
    'y2k': ['Coquette', 'Indie sleaze', 'Balletcore'],
    'streetwear': ['Skater', 'Athleisure', 'Gorpcore'],
    'minimal': ['Quiet luxury', 'Old money'],
    'grunge': ['Indie sleaze', 'Dark academia', 'Skater'],
    'vintage': ['Old money', 'Boho', 'Cottagecore', 'Desi fusion'],
    'preppy': ['Old money', 'Dark academia', 'Quiet luxury'],
    'techwear': ['Gorpcore', 'Avant-garde', 'Workwear'],
  };

  /// Up to six genres for [eras], in the order the eras are offered.
  static List<String> suggestedGenres(Set<String> eras) {
    final out = <String>[];
    for (final e in OnboardingData.eras) {
      if (!eras.contains(e.id)) continue;
      for (final g in eraGenres[e.id] ?? const <String>[]) {
        if (!out.contains(g)) out.add(g);
      }
    }
    return out.take(6).toList();
  }

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

  /// How each label's tile looks: filled edge to edge in the label's own
  /// colour, with its logo (Simple Icons, where one exists) or a type mark
  /// set in Drip's faces. The type marks are Drip's treatment of the name,
  /// not imitations of anyone's logo; the categories take Drip's palette.
  /// Drop an official SVG in `assets/brands/` and give it a [BrandLook.logo]
  /// to swap one in.
  static const brandLooks = <String, BrandLook>{
    'Nike': BrandLook(
      0xFFF36F21,
      0xFFFFFFFF,
      logo: 'assets/brands/nike.svg',
      ratio: 2.86,
    ),
    'Adidas': BrandLook(
      0xFFF4F4F2,
      0xFF111111,
      logo: 'assets/brands/adidas.svg',
      ratio: 1.59,
    ),
    'Zara': BrandLook(
      0xFF101010,
      0xFFF4F1EA,
      logo: 'assets/brands/zara.svg',
      ratio: 2.4,
    ),
    'H&M': BrandLook(
      0xFFE50010,
      0xFFFFFFFF,
      logo: 'assets/brands/hm.svg',
      ratio: 1.51,
    ),
    'Uniqlo': BrandLook(
      0xFFF4F4F2,
      0xFFE60012,
      logo: 'assets/brands/uniqlo.svg',
      ratio: 1,
    ),
    'Levi’s': BrandLook(
      0xFF24395C, // denim indigo
      0xFFF4F1EA,
      mark: 'LEVI’S',
      face: MarkFace.poster,
    ),
    'Puma': BrandLook(
      0xFF161616,
      0xFFFFFFFF,
      logo: 'assets/brands/puma.svg',
      ratio: 1.3,
    ),
    'New Balance': BrandLook(
      0xFF77797B, // the grey of the grey sneakers
      0xFFFFFFFF,
      logo: 'assets/brands/newbalance.svg',
      ratio: 2.08,
    ),
    'Bewakoof': BrandLook(
      0xFFFDD835,
      0xFF111111,
      mark: 'bewakoof',
      face: MarkFace.round,
    ),
    'Snitch': BrandLook(
      0xFFE9E2D6,
      0xFF111111,
      mark: 'SNITCH',
      face: MarkFace.spaced,
    ),
    'Fabindia': BrandLook(
      0xFFB5532A, // terracotta, for the handloom
      0xFFF6EBDD,
      mark: 'fabindia',
      face: MarkFace.light,
    ),
    'Thrifted': BrandLook(
      0xFFC2A882, // Drip sand
      0xFF2A2219,
      mark: 'THRIFTED',
      face: MarkFace.tag,
    ),
    'Indie labels': BrandLook(
      0xFFB9A6E8, // Drip lilac
      0xFF1E1530,
      mark: 'indie\nlabels',
      face: MarkFace.heavy,
    ),
    'Sneaker drops': BrandLook(
      0xFFD7FF3A, // volt
      0xFF111111,
      mark: 'SNEAKER\nDROPS',
      face: MarkFace.poster,
    ),
  };

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
