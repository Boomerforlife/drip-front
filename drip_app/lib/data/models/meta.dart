/// A `{ id, label }` option from `GET /meta`.
class MetaOption {
  const MetaOption(this.id, this.label);
  final String id;
  final String label;

  static List<MetaOption> listFrom(Object? json) => [
    for (final o in (json as List?) ?? const [])
      if (o is Map) MetaOption('${o['id']}', '${o['label'] ?? o['id']}'),
  ];
}

/// The lists the app renders, owned by the server so the app never sends a
/// value the backend doesn't understand (`GET /meta`, cached for an hour).
class AppMeta {
  const AppMeta({
    required this.occasions,
    required this.vibes,
    required this.moods,
    required this.discoverCategories,
    required this.slots,
    required this.colourFamilies,
    required this.seasons,
    required this.scenes,
    required this.currency,
    required this.genCreditsPerUser,
  });

  final List<MetaOption> occasions;
  final List<MetaOption> vibes;
  final List<MetaOption> moods;
  final List<MetaOption> discoverCategories;

  /// Garment slots: `top | bottom | outer | dress | shoes | accessory`.
  final List<String> slots;
  final List<String> colourFamilies;
  final List<String> seasons;
  final List<MetaOption> scenes;
  final String currency;
  final int genCreditsPerUser;

  factory AppMeta.fromJson(Map<String, dynamic> json) {
    List<String> strings(Object? v) => [
      for (final s in (v as List?) ?? const []) '$s',
    ];
    return AppMeta(
      occasions: MetaOption.listFrom(json['occasions']),
      vibes: MetaOption.listFrom(json['vibes']),
      moods: MetaOption.listFrom(json['moods']),
      discoverCategories: MetaOption.listFrom(json['discoverCategories']),
      slots: strings(json['slots']),
      colourFamilies: strings(json['colourFamilies']),
      seasons: strings(json['seasons']),
      scenes: MetaOption.listFrom(json['scenes']),
      currency: json['currency'] as String? ?? 'INR',
      genCreditsPerUser: (json['genCreditsPerUser'] as num?)?.toInt() ?? 3,
    );
  }
}
