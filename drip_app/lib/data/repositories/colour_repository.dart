import 'package:flutter/painting.dart';

import '../api/api_client.dart';

/// One season of the 12-season colour system (`GET /colour/seasons`).
class ColourSeason {
  const ColourSeason({
    required this.id,
    required this.parentSeason,
    required this.name,
    required this.tagline,
    required this.description,
    required this.accent,
    required this.palette,
  });

  final String id;

  /// winter | spring | summer | autumn.
  final String parentSeason;
  final String name;
  final String tagline;
  final String description;
  final Color accent;
  final List<Color> palette;

  factory ColourSeason.fromJson(Map<String, dynamic> json) => ColourSeason(
    id: json['id'] as String,
    parentSeason: json['parentSeason'] as String? ?? '',
    name: json['name'] as String? ?? '',
    tagline: json['tagline'] as String? ?? '',
    description: json['description'] as String? ?? '',
    accent: parseHex(json['accent'] as String?) ?? const Color(0xFFE8DFC8),
    palette: [
      for (final h in (json['palette'] as List?) ?? const [])
        ?parseHex('$h'),
    ],
  );
}

/// `#1B3F8B` → Color. Null for anything else.
Color? parseHex(String? hex) {
  if (hex == null) return null;
  final h = hex.replaceFirst('#', '');
  if (h.length != 6) return null;
  final v = int.tryParse(h, radix: 16);
  return v == null ? null : Color(0xFF000000 | v);
}

abstract interface class ColourRepository {
  Future<List<ColourSeason>> seasons();
}

class ApiColourRepository implements ColourRepository {
  ApiColourRepository(this._api);
  final ApiClient _api;

  @override
  Future<List<ColourSeason>> seasons() async {
    final json = await _api.get('/colour/seasons') as Map;
    return [
      for (final s in (json['seasons'] as List?) ?? const [])
        if (s is Map) ColourSeason.fromJson(s.cast<String, dynamic>()),
    ];
  }
}

class MockColourRepository implements ColourRepository {
  @override
  Future<List<ColourSeason>> seasons() async => const [
    ColourSeason(
      id: 'winter-cool',
      parentSeason: 'winter',
      name: 'Cool Winter',
      tagline: 'Cool Undertone Dominant • High Contrast',
      description: 'Crisp, icy and high-contrast.',
      accent: Color(0xFF1B3F8B),
      palette: [Color(0xFFC8102E), Color(0xFF00693E), Color(0xFF1B3F8B)],
    ),
    ColourSeason(
      id: 'autumn-warm',
      parentSeason: 'autumn',
      name: 'Warm Autumn',
      tagline: 'Warm Undertone Dominant • Rich',
      description: 'Golden, earthy and spiced.',
      accent: Color(0xFFB5651D),
      palette: [Color(0xFFB5651D), Color(0xFF6B8E23), Color(0xFF8B4513)],
    ),
  ];
}
