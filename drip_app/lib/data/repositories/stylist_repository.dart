import '../api/api_client.dart';
import '../mock/mock_content.dart';
import '../models/outfit.dart';
import '../models/stylist.dart';
import '../models/wardrobe.dart';

/// Taylor, the AI stylist: occasion + vibe in, a banked fit and her reasoning
/// out.
abstract interface class StylistRepository {
  Future<Blueprint> generateBlueprint({
    required String occasion,
    required String vibe,
    required bool restrictToWardrobe,
    required List<WardrobeItem> wardrobe,
  });
}

/// Taylor has nothing to pick from yet (the catalog is still being filled).
class NoFitsYet implements Exception {
  const NoFitsYet();
}

/// `POST /taylor` → `{ fit_id, reason, alternatives }`, then `GET /outfits/:id`
/// to dress the result. The server reads the wardrobe itself, so the client
/// never uploads it; occasion and vibe must come from `GET /meta`.
class ApiStylistRepository implements StylistRepository {
  ApiStylistRepository(this._api);
  final ApiClient _api;

  @override
  Future<Blueprint> generateBlueprint({
    required String occasion,
    required String vibe,
    required bool restrictToWardrobe,
    required List<WardrobeItem> wardrobe,
  }) async {
    final Map pick;
    try {
      pick =
          await _api.post('/taylor', {
                'occasion': occasion,
                'vibe': vibe,
                'restrictToWardrobe': restrictToWardrobe,
              })
              as Map;
    } on ApiException catch (e) {
      if (e.isNotFound) throw const NoFitsYet();
      rethrow;
    }
    final fitId = pick['fit_id'] as String;
    final outfit = Outfit.fromJson(
      (await _api.get('/outfits/$fitId') as Map).cast<String, dynamic>(),
    );
    return Blueprint(
      headline: "I'D WEAR\nTHIS.",
      banner: outfit.image,
      reasoning: pick['reason'] as String? ?? '',
      drip: outfit.rate,
      pieces: [
        for (final p in outfit.pieces)
          BlueprintPiece(
            name: p.name.isEmpty ? p.slot : p.name,
            category: p.slot,
            price: p.price,
            image: p.image ?? outfit.image,
          ),
      ],
      occasion: occasion,
      vibe: vibe,
      fitId: fitId,
      alternatives: [
        for (final a in (pick['alternatives'] as List?) ?? const []) '$a',
      ],
    );
  }
}

/// Deterministic fixture for tests.
class MockStylistRepository implements StylistRepository {
  @override
  Future<Blueprint> generateBlueprint({
    required String occasion,
    required String vibe,
    required bool restrictToWardrobe,
    required List<WardrobeItem> wardrobe,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 1400));

    final pieces = restrictToWardrobe && wardrobe.isNotEmpty
        ? [
            for (final w in wardrobe.take(3))
              BlueprintPiece(
                name: w.name,
                category: w.category.toUpperCase(),
                price: w.price.round(),
                image: w.image,
              ),
          ]
        : [
            BlueprintPiece(
              name: 'Cyber Shell Overcoat',
              category: 'OUTERWEAR',
              price: 189,
              image: MockContent.taylorOvercoat,
            ),
            const BlueprintPiece(
              name: 'Chrome Cargo Loose Track Pants',
              category: 'BOTTOMS',
              price: 110,
              image: 'assets/images/result_neo_cargo.jpg',
            ),
            const BlueprintPiece(
              name: 'Platform Heavy Boots v2',
              category: 'FOOTWEAR',
              price: 220,
              image: 'assets/images/wardrobe_chunky_boots.jpg',
            ),
          ];

    final score = 90 + ((occasion.length + vibe.length) % 9);
    return Blueprint(
      headline: "I'D WEAR\nTHIS.",
      banner: MockContent.taylorBanner,
      reasoning:
          'The ${pieces.first.name.toLowerCase()} anchors the $vibe silhouette, balanced by heavy hardware '
          'below. Built for $occasion: waterproof utility up top, comfortable structure underneath.',
      drip: score,
      pieces: pieces,
      occasion: occasion,
      vibe: vibe,
      fitId: MockContent.outfits.first.id,
    );
  }
}
