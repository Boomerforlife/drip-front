/// Where an uploaded garment is in the pipeline (`processing → ready`, or
/// `failed`). Saved catalog garments are ready straight away.
enum WardrobeStatus { processing, ready, failed }

/// A digitised garment in the user's wardrobe.
class WardrobeItem {
  const WardrobeItem({
    required this.id,
    required this.name,
    required this.category,
    required this.image,
    required this.status,
    this.brand = '',
    this.colorway = '',
    this.price = 0,
    this.tags = const [],
    this.section = 'TOPS & OUTERWEAR',
    this.state = WardrobeStatus.ready,
    this.slot,
    this.origin = 'upload',
    this.garmentId,
    this.addedAt,
  });

  final String id;
  final String name;

  /// Display category (Tops, Outerwear, Shoes…).
  final String category;

  /// A 1-hour signed URL for uploads (the cutout once ready, the original
  /// photo while processing). Display only, never persist.
  final String image;

  /// Sub-label shown under the name (`DIGITIZED · READY`).
  final String status;
  final String brand;
  final String colorway;
  final double price;
  final List<String> tags;
  final String section;
  final WardrobeStatus state;

  /// API slot: `top | bottom | outer | dress | shoes | accessory` (null until
  /// tagged).
  final String? slot;

  /// `upload` (the user's photo) or `saved` (a catalog garment).
  final String origin;
  final String? garmentId;
  final DateTime? addedAt;

  bool get isProcessing => state == WardrobeStatus.processing;
  bool get isReady => state == WardrobeStatus.ready;
  bool get isFailed => state == WardrobeStatus.failed;

  WardrobeItem copyWith({
    String? name,
    String? brand,
    String? colorway,
    String? category,
    double? price,
    List<String>? tags,
  }) => WardrobeItem(
    id: id,
    name: name ?? this.name,
    category: category ?? this.category,
    image: image,
    status: status,
    brand: brand ?? this.brand,
    colorway: colorway ?? this.colorway,
    price: price ?? this.price,
    tags: tags ?? this.tags,
    section: section,
    state: state,
    slot: slot,
    origin: origin,
    garmentId: garmentId,
    addedAt: addedAt,
  );

  /// From the API (`WardrobeItem` in docs/API.md).
  factory WardrobeItem.fromJson(Map<String, dynamic> json) {
    final state = switch (json['status']) {
      'processing' => WardrobeStatus.processing,
      'failed' => WardrobeStatus.failed,
      _ => WardrobeStatus.ready,
    };
    final slot = json['category'] as String?;
    final colour = json['colour'] as String?;
    final origin = json['origin'] as String? ?? 'upload';
    final category = categoryLabel(slot);
    return WardrobeItem(
      id: json['id'] as String,
      name: switch (state) {
        WardrobeStatus.processing => 'New garment',
        WardrobeStatus.failed => 'Unreadable photo',
        WardrobeStatus.ready => [
          if (colour != null) _cap(colour),
          _noun(slot),
        ].join(' '),
      },
      category: category,
      image: json['image'] as String? ?? '',
      status: switch (state) {
        WardrobeStatus.processing => 'PROCESSING · CUTTING OUT…',
        WardrobeStatus.failed => "COULDN'T READ THIS PHOTO",
        WardrobeStatus.ready =>
          origin == 'saved' ? 'SAVED FROM DRIP' : 'DIGITIZED · READY',
      },
      colorway: colour == null ? '' : _cap(colour),
      tags: [
        for (final t in (json['styleTags'] as List?) ?? const []) '#$t'.toUpperCase(),
        for (final s in (json['season'] as List?) ?? const [])
          if (s != 'all-season') '$s'.toUpperCase(),
      ],
      section: sectionForSlot(slot),
      state: state,
      slot: slot,
      origin: origin,
      garmentId: json['garmentId'] as String?,
      addedAt: DateTime.tryParse(json['addedAt'] as String? ?? ''),
    );
  }

  static String categoryLabel(String? slot) => switch (slot) {
    'top' => 'Tops',
    'bottom' => 'Bottoms',
    'outer' => 'Outerwear',
    'dress' => 'Dresses',
    'shoes' => 'Shoes',
    'accessory' => 'Accessories',
    _ => 'Unsorted',
  };

  static String sectionForSlot(String? slot) => switch (slot) {
    'bottom' => 'BOTTOMS',
    'dress' => 'DRESSES',
    'shoes' => 'SHOES',
    'accessory' => 'ACCESSORIES',
    null => 'IN PROGRESS',
    _ => 'TOPS & OUTERWEAR',
  };

  static String _noun(String? slot) => switch (slot) {
    'top' => 'Top',
    'bottom' => 'Bottoms',
    'outer' => 'Jacket',
    'dress' => 'Dress',
    'shoes' => 'Shoes',
    'accessory' => 'Accessory',
    _ => 'Garment',
  };

  static String _cap(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}

/// Result of the garment-capture "detection" step (mock only: the API tags
/// garments in a background job instead).
class GarmentDetection {
  const GarmentDetection({
    required this.label,
    required this.confidence,
    required this.description,
    required this.name,
    required this.category,
    required this.tags,
  });

  final String label;
  final int confidence;
  final String description;
  final String name;
  final String category;
  final List<String> tags;
}
