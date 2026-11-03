/// Taylor (the AI stylist) blueprint generated from occasion + vibe.
class Blueprint {
  const Blueprint({
    required this.headline,
    required this.banner,
    required this.reasoning,
    required this.drip,
    required this.pieces,
    required this.occasion,
    required this.vibe,
    this.fitId,
    this.alternatives = const [],
  });

  final String headline;
  final String banner;
  final String reasoning;
  final int drip;
  final List<BlueprintPiece> pieces;
  final String occasion;
  final String vibe;

  /// The banked fit Taylor picked (open it on Fit Analysis), and runners-up.
  final String? fitId;
  final List<String> alternatives;
}

class BlueprintPiece {
  const BlueprintPiece({
    required this.name,
    required this.category,
    required this.price,
    required this.image,
  });

  final String name;
  final String category;
  final int price;
  final String image;
}

/// A scene option in the photoshoot flow.
class ShootScene {
  const ShootScene({required this.id, required this.label, this.image});
  final String id;
  final String label;
  final String? image;
}

enum ShootMode { real, ai, edits }

/// One piece in the studio "swap pieces" carousel: a catalog garment or one
/// of the user's own (ready) wardrobe items.
class StudioPiece {
  const StudioPiece({
    required this.id,
    required this.name,
    required this.category,
    required this.image,
    this.price = 0,
    this.source = 'catalog',
    this.brand,
    this.subcategory,
    this.buyUrl,
  });
  final String id;
  final String name;

  /// The store it comes from; null for wardrobe pieces.
  final String? brand;

  /// What it is, finer than [category] ("jeans", "bag"); null for wardrobe
  /// pieces.
  final String? subcategory;

  /// The product page on its store; null for wardrobe pieces.
  final String? buyUrl;

  /// Studio category label (OUTERWEAR, TOPS, BOTTOMS, FOOTWEAR…).
  final String category;
  final String image;
  final int price;

  /// `catalog | wardrobe`: which id the API expects when saving a fit.
  final String source;

  bool get fromWardrobe => source == 'wardrobe';

  factory StudioPiece.fromJson(Map<String, dynamic> json) {
    final slot = json['slot'] as String? ?? json['category'] as String? ?? '';
    final price = json['price'];
    return StudioPiece(
      id: json['id'] as String,
      name: json['name'] as String? ?? StudioSlots.label(slot),
      category: StudioSlots.label(slot),
      image: json['image'] as String? ?? '',
      price: price is Map ? ((price['amount'] as num?)?.round() ?? 0) : 0,
      source: json['source'] as String? ?? 'catalog',
      brand: json['brand'] as String?,
      subcategory: json['subcategory'] as String?,
      buyUrl: json['buyUrl'] as String?,
    );
  }
}

/// The Studio's categories and the API slots behind them
/// (`GET /meta` → slots: top, bottom, outer, dress, shoes, accessory).
abstract final class StudioSlots {
  static const categories = [
    'OUTERWEAR',
    'TOPS',
    'BOTTOMS',
    'FOOTWEAR',
    'DRESSES',
    'ACCESSORIES',
  ];

  static const _slotFor = {
    'OUTERWEAR': 'outer',
    'TOPS': 'top',
    'BOTTOMS': 'bottom',
    'FOOTWEAR': 'shoes',
    'DRESSES': 'dress',
    'ACCESSORIES': 'accessory',
  };

  /// OUTERWEAR → `outer` (an extra accessory's `ACCESSORIES:2` → `accessory`).
  static String slot(String category) {
    final base = category.split(':').first;
    return _slotFor[base] ?? base.toLowerCase();
  }

  /// `outer` → OUTERWEAR (a studio label passes through unchanged).
  static String label(String slot) {
    for (final e in _slotFor.entries) {
      if (e.value == slot) return e.key;
    }
    return slot.toUpperCase();
  }

  /// The canvas key for a piece of a user fit: the category, and for
  /// accessories past the first, `ACCESSORIES:2`… (position 1 → `:2`).
  static String canvasKey(String slot, int position) {
    final category = label(slot);
    return position > 0 ? '$category:${position + 1}' : category;
  }

  /// An accessory's position (0–5) from its canvas key; 0 for the rest.
  static int position(String key) {
    final i = key.indexOf(':');
    return i < 0 ? 0 : (int.tryParse(key.substring(i + 1)) ?? 1) - 1;
  }
}

class MoodTile {
  const MoodTile({required this.id, required this.label, required this.image});
  final String id;
  final String label;
  final String image;
}

class PaletteSwatch {
  const PaletteSwatch({
    required this.id,
    required this.name,
    required this.role,
    required this.hex,
  });
  final String id;
  final String name;
  final String role;
  final int hex;
}
