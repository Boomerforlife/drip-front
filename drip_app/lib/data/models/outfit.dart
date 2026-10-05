/// A complete look: the unit of the Fashion Scroll and Home (the API's
/// `Outfit`), also shown on Fit Analysis, Saved Looks and profiles.
///
/// API fits are either `collage` (flat-lay of cut-out garments) or `photo`
/// (someone wearing the fit). They have no creator or title of their own:
/// they're curated by Drip, so [creatorHandle] is `drip` and [title] is built
/// from the colour story or the pieces.
class Outfit {
  const Outfit({
    required this.id,
    required this.title,
    required this.image,
    required this.price,
    required this.rate,
    required this.creatorHandle,
    this.kind = 'photo',
    this.tags = const [],
    this.categories = const [],
    this.pieces = const [],
    this.hotspots = const [],
    this.season = const [],
    this.colourStory,
    this.formality,
    this.isLiked = false,
  });

  final String id;
  final String title;
  final String image;

  /// Total in INR (0 when no piece is priced).
  final int price;

  /// Drip rate / score (0–100).
  final int rate;
  final String creatorHandle;

  /// `collage` | `photo`.
  final String kind;
  final List<String> tags;

  /// Discover categories the look belongs to (Y2K, STREET, ...).
  final List<String> categories;
  final List<OutfitPiece> pieces;
  final List<Hotspot> hotspots;
  final List<String> season;
  final String? colourStory;

  /// 1 (casual) – 5 (formal).
  final int? formality;
  final bool isLiked;

  bool get isCollage => kind == 'collage';

  int get totalPrice => pieces.fold(0, (sum, p) => sum + p.price);

  Outfit copyWith({bool? isLiked}) => Outfit(
    id: id,
    title: title,
    image: image,
    price: price,
    rate: rate,
    creatorHandle: creatorHandle,
    kind: kind,
    tags: tags,
    categories: categories,
    pieces: pieces,
    hotspots: hotspots,
    season: season,
    colourStory: colourStory,
    formality: formality,
    isLiked: isLiked ?? this.isLiked,
  );

  /// From the API wire shape (`docs/API.md`, "Scroll").
  factory Outfit.fromJson(Map<String, dynamic> json) {
    final pieces = [
      for (final p in (json['pieces'] as List?) ?? const [])
        if (p is Map) OutfitPiece.fromJson(p.cast<String, dynamic>()),
    ];
    final colourStory = json['colourStory'] as String?;
    final season = [
      for (final s in (json['season'] as List?) ?? const []) '$s',
    ];
    final formality = (json['formality'] as num?)?.toInt();
    return Outfit(
      id: json['id'] as String,
      title: _titleFor(colourStory, pieces),
      image: json['image'] as String? ?? '',
      price: moneyAmount(json['price']) ?? 0,
      rate: (json['dripRate'] as num?)?.round() ?? 0,
      creatorHandle: 'drip',
      kind: json['kind'] as String? ?? 'collage',
      pieces: pieces,
      hotspots: [
        for (final h in (json['hotspots'] as List?) ?? const [])
          if (h is Map) Hotspot.fromJson(h.cast<String, dynamic>()),
      ],
      season: season,
      colourStory: colourStory,
      formality: formality,
      tags: [
        if (formality != null) formalityLabel(formality),
        for (final s in season)
          if (s != 'all-season') s,
      ],
    );
  }

  static String _titleFor(String? colourStory, List<OutfitPiece> pieces) {
    if (colourStory != null && colourStory.trim().isNotEmpty) {
      return colourStory.trim();
    }
    final named = pieces.map((p) => p.name).where((n) => n.isNotEmpty);
    if (named.isNotEmpty) return named.first;
    return 'Drip fit';
  }

  static String formalityLabel(int f) => switch (f) {
    <= 1 => 'casual',
    2 => 'relaxed',
    3 => 'smart',
    4 => 'dressy',
    _ => 'formal',
  };
}

/// `{ amount, currency }` → amount (INR for the beta). Null when unpriced.
int? moneyAmount(Object? json) =>
    json is Map ? (json['amount'] as num?)?.round() : null;

/// A single garment inside an [Outfit] (Fit Analysis "garment calibration spec").
class OutfitPiece {
  const OutfitPiece({
    required this.slot,
    required this.name,
    required this.brand,
    required this.price,
    this.image,
    this.buyUrl,
  });

  /// TOP / BOTTOM / SHOES… (upper-case for display).
  final String slot;
  final String name;

  /// The store ("Snitch"); empty when unknown.
  final String brand;
  final int price;
  final String? image;
  final String? buyUrl;

  factory OutfitPiece.fromJson(Map<String, dynamic> json) {
    final category = (json['category'] as String? ?? '').toUpperCase();
    return OutfitPiece(
      slot: category.isEmpty ? 'PIECE' : category,
      name: json['name'] as String? ?? '',
      brand: json['brand'] as String? ?? '',
      price: moneyAmount(json['price']) ?? 0,
      image: json['image'] as String?,
      buyUrl: json['buyUrl'] as String?,
    );
  }
}

/// A tappable annotation drawn on the outfit hero image.
class Hotspot {
  const Hotspot({
    required this.label,
    required this.x,
    required this.y,
    this.highlighted = false,
    this.filled = false,
    this.slot = '',
  });

  final String label;

  /// The garment's slot in the fit (`top`, `shoes`…); empty when unknown.
  final String slot;

  /// Position as a fraction of the image (0–1).
  final double x;
  final double y;
  final bool highlighted;

  /// Filled pill (active hotspot) vs. outlined text callout.
  final bool filled;

  factory Hotspot.fromJson(Map<String, dynamic> json) => Hotspot(
    label: (json['label'] as String? ?? '').toUpperCase(),
    x: (json['x'] as num?)?.toDouble() ?? 0.5,
    y: (json['y'] as num?)?.toDouble() ?? 0.5,
    slot: json['slot'] as String? ?? '',
  );
}
