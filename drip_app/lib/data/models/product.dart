/// One product from the Drip catalog, whatever store it came from
/// (`GET /discover/search`, Backend_app `src/discovery/search.ts`).
///
/// [ready] products show their transparent cut-out; a product still being
/// processed shows the store's own photo until the cut-out lands.
class DripProduct {
  const DripProduct({
    required this.id,
    required this.title,
    required this.ready,
    this.brand,
    this.retailer,
    this.source = 'web',
    this.price,
    this.originalPrice,
    this.image,
    this.cutout = false,
    this.buyUrl,
    this.category,
    this.subcategory,
    this.colour,
    this.colours = const [],
    this.fit,
    this.silhouette,
    this.pattern,
    this.material,
    this.sleeve,
    this.neckline,
    this.length,
    this.gender,
    this.styleTags = const [],
    this.sizes = const [],
    this.availability,
    this.confidence,
    this.reviewStatus = 'auto',
  });

  final String id;
  final String title;

  /// Cut out, tagged and published. False while the pipeline is working.
  final bool ready;
  final String? brand;
  final String? retailer;
  final String source;

  /// Rupees.
  final int? price;
  final int? originalPrice;

  /// The cut-out when [cutout], else the store's photo.
  final String? image;
  final bool cutout;
  final String? buyUrl;

  /// The collage slot: top, bottom, outer, dress, shoes, accessory.
  final String? category;
  final String? subcategory;
  final String? colour;
  final List<String> colours;
  final String? fit;
  final String? silhouette;
  final String? pattern;
  final String? material;
  final String? sleeve;
  final String? neckline;
  final String? length;
  final String? gender;
  final List<String> styleTags;
  final List<String> sizes;
  final String? availability;
  final double? confidence;
  final String reviewStatus;

  bool get onSale =>
      originalPrice != null && price != null && originalPrice! > price!;
  bool get soldOut => availability == 'out_of_stock';

  /// Words describing the garment, most useful first ("Oversized",
  /// "Graphic", "Crew neck"…). Never invented: only what the API knows.
  List<String> get facts => [
    for (final v in [
      subcategory,
      fit,
      colour,
      pattern,
      sleeve,
      neckline,
      material,
      silhouette,
      length,
    ])
      if (v != null && v.isNotEmpty) _cap(v),
  ];

  static String _cap(String s) => s[0].toUpperCase() + s.substring(1);

  static int? _amount(Object? v) =>
      v is Map ? (v['amount'] as num?)?.round() : null;

  factory DripProduct.fromJson(Map<String, dynamic> j) => DripProduct(
    id: j['id'] as String,
    title: j['title'] as String? ?? '',
    ready: (j['status'] as String? ?? 'ready') == 'ready',
    brand: j['brand'] as String?,
    retailer: j['retailer'] as String?,
    source: j['source'] as String? ?? 'web',
    price: _amount(j['price']),
    originalPrice: _amount(j['originalPrice']),
    image: j['image'] as String?,
    cutout: j['cutout'] as bool? ?? false,
    buyUrl: j['buyUrl'] as String?,
    category: j['category'] as String?,
    subcategory: j['subcategory'] as String?,
    colour: j['colour'] as String?,
    colours: [for (final c in (j['colours'] as List?) ?? const []) '$c'],
    fit: j['fit'] as String?,
    silhouette: j['silhouette'] as String?,
    pattern: j['pattern'] as String?,
    material: j['material'] as String?,
    sleeve: j['sleeve'] as String?,
    neckline: j['neckline'] as String?,
    length: j['length'] as String?,
    gender: j['gender'] as String?,
    styleTags: [for (final t in (j['styleTags'] as List?) ?? const []) '$t'],
    sizes: [for (final s in (j['sizes'] as List?) ?? const []) '$s'],
    availability: j['availability'] as String?,
    confidence: (j['confidence'] as num?)?.toDouble(),
    reviewStatus: j['reviewStatus'] as String? ?? 'auto',
  );
}

/// A search's answer: what's ready now, and whether more is on its way.
class ProductSearch {
  const ProductSearch({
    required this.products,
    this.pending = false,
    this.maxPrice,
  });
  final List<DripProduct> products;

  /// Drip is still looking across stores / cutting pieces out: ask again soon.
  final bool pending;

  /// The price cap the search used (the user's budget by default).
  final int? maxPrice;
}
