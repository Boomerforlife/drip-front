import '../api/api_client.dart';
import '../mock/mock_content.dart';
import '../models/stylist.dart';
import '../models/studio.dart';

/// Studio canvas (pieces, the user's own fits) and Gen (photoshoots).
abstract interface class StudioRepository {
  /// The swap-pieces carousel for one Studio category (OUTERWEAR, TOPS…).
  Future<List<StudioPiece>> pieces(
    String category, {
    bool fromWardrobe = false,
  });

  /// Creates ([id] null) or replaces a user fit. The server scores it.
  Future<UserFit> saveFit({
    String? id,
    String? name,
    String? baseFitId,
    required Map<String, StudioPiece> worn,
  });

  Future<void> deleteFit(String id);

  /// Reserves a Gen credit and queues the render. 429 when credits run out.
  Future<GenJob> startGen({
    required String fitId,
    String? sceneId,
    ShootMode mode = ShootMode.ai,
  });

  /// Poll this about every 2 s until [GenJob.isFinished].
  Future<GenJob> genJob(String id);
}

/// What the renders are called for display.
class ShootRender {
  const ShootRender({
    required this.image,
    required this.title,
    required this.scene,
    required this.score,
    this.fellBack = false,
  });
  final String image;
  final String title;
  final String scene;
  final int score;

  /// Gen couldn't render, so this is the fit's collage (credit refunded).
  final bool fellBack;
}

class ApiStudioRepository implements StudioRepository {
  ApiStudioRepository(this._api);
  final ApiClient _api;

  @override
  Future<List<StudioPiece>> pieces(
    String category, {
    bool fromWardrobe = false,
  }) async {
    final json =
        await _api.get(
              '/studio/pieces',
              query: {
                'slot': StudioSlots.slot(category),
                'source': fromWardrobe ? 'wardrobe' : 'catalog',
              },
            )
            as Map;
    return [
      for (final p in (json['pieces'] as List?) ?? const [])
        if (p is Map) StudioPiece.fromJson(p.cast<String, dynamic>()),
    ];
  }

  @override
  Future<UserFit> saveFit({
    String? id,
    String? name,
    String? baseFitId,
    required Map<String, StudioPiece> worn,
  }) async {
    final body = {
      'name': ?name,
      'baseFitId': ?baseFitId,
      'items': [
        for (final e in worn.entries)
          {
            'slot': StudioSlots.slot(e.key),
            if (e.value.fromWardrobe)
              'wardrobeItemId': e.value.id
            else
              'garmentId': e.value.id,
          },
      ],
    };
    final json = id == null
        ? await _api.post('/studio/fits', body)
        : await _api.put('/studio/fits/$id', body);
    return UserFit.fromJson((json as Map).cast<String, dynamic>());
  }

  @override
  Future<void> deleteFit(String id) => _api.delete('/studio/fits/$id');

  @override
  Future<GenJob> startGen({
    required String fitId,
    String? sceneId,
    ShootMode mode = ShootMode.ai,
  }) async {
    final json =
        await _api.post('/gen', {
              'fitId': fitId,
              'sceneId': ?sceneId,
              'mode': mode.name,
            })
            as Map;
    return GenJob(
      id: json['jobId'] as String,
      fitId: fitId,
      status: json['status'] as String? ?? 'queued',
    );
  }

  @override
  Future<GenJob> genJob(String id) async =>
      GenJob.fromJson((await _api.get('/gen/$id') as Map).cast<String, dynamic>());
}

/// Fixture Studio for tests.
class MockStudioRepository implements StudioRepository {
  @override
  Future<List<StudioPiece>> pieces(
    String category, {
    bool fromWardrobe = false,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    return MockContent.studioPieces
        .where((p) => p.category == category)
        .toList();
  }

  @override
  Future<UserFit> saveFit({
    String? id,
    String? name,
    String? baseFitId,
    required Map<String, StudioPiece> worn,
  }) async {
    // Stable pseudo-score derived from the piece ids.
    final seed = worn.values.fold<int>(
      0,
      (a, p) => a + p.id.codeUnits.fold(0, (x, c) => x + c),
    );
    return UserFit(
      id: id ?? 'uf_${DateTime.now().microsecondsSinceEpoch}',
      name: name ?? 'Studio fit',
      baseFitId: baseFitId,
      pieces: {for (final e in worn.entries) StudioSlots.slot(e.key): e.value},
      dripRate: worn.length < 2 ? null : 84 + seed % 15,
      price: worn.values.fold<int>(0, (s, p) => s + p.price),
    );
  }

  @override
  Future<void> deleteFit(String id) async {}

  @override
  Future<GenJob> startGen({
    required String fitId,
    String? sceneId,
    ShootMode mode = ShootMode.ai,
  }) async => GenJob(id: 'gen_$fitId', fitId: fitId, status: 'queued');

  @override
  Future<GenJob> genJob(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return GenJob(
      id: id,
      fitId: id.replaceFirst('gen_', ''),
      status: 'done',
      outputUrl: MockContent.shootResult,
    );
  }
}
