import '../api/api_client.dart';
import '../mock/mock_content.dart';
import '../mock/mock_users.dart';
import '../models/outfit.dart';
import '../models/studio.dart';

class SearchResults {
  const SearchResults({
    required this.fits,
    required this.creatorHandles,
    required this.vibes,
    required this.collections,
  });

  final List<Outfit> fits;
  final List<String> creatorHandles;
  final List<String> vibes;
  final List<({String id, String title, int count, String tag})> collections;

  int get total => fits.length + creatorHandles.length + collections.length;
}

/// Complete looks: Fit Analysis, saves and likes, and the user's library.
abstract interface class OutfitRepository {
  Future<Outfit?> byId(String id);

  /// `GET /studio`: saved, liked, Gen renders and the user's own fits.
  Future<StudioLibrary> library();
  Future<void> setSaved(String id, {required bool saved});
  Future<void> setLiked(String id, {required bool liked});

  // Discover, search and creator pages have no backend endpoint yet (their
  // UI says "coming after beta"). Only the mock answers these.
  Future<List<Outfit>> discover({String? category, String query = ''});
  Future<SearchResults> search(String query);
  Future<List<String>> trendingVibes();
  Future<List<Outfit>> byCreator(String handle);
}

class ApiOutfitRepository implements OutfitRepository {
  ApiOutfitRepository(this._api);
  final ApiClient _api;

  @override
  Future<Outfit?> byId(String id) async {
    try {
      final json = await _api.get('/outfits/$id') as Map;
      return Outfit.fromJson(json.cast<String, dynamic>());
    } on ApiException catch (e) {
      if (e.isNotFound) return null;
      rethrow;
    }
  }

  @override
  Future<StudioLibrary> library() async => StudioLibrary.fromJson(
    (await _api.get('/studio') as Map).cast<String, dynamic>(),
  );

  @override
  Future<void> setSaved(String id, {required bool saved}) => saved
      ? _api.put('/outfits/$id/save')
      : _api.delete('/outfits/$id/save');

  @override
  Future<void> setLiked(String id, {required bool liked}) => liked
      ? _api.put('/outfits/$id/like')
      : _api.delete('/outfits/$id/like');

  @override
  Future<List<Outfit>> discover({String? category, String query = ''}) async =>
      const [];

  @override
  Future<SearchResults> search(String query) async => const SearchResults(
    fits: [],
    creatorHandles: [],
    vibes: [],
    collections: [],
  );

  @override
  Future<List<String>> trendingVibes() async => const [];

  @override
  Future<List<Outfit>> byCreator(String handle) async => const [];
}

class MockOutfitRepository implements OutfitRepository {
  final List<Outfit> _outfits = List.of(MockContent.outfits);
  final Set<String> _saved = {...MockContent.savedOutfitIds};

  Future<void> _latency() =>
      Future<void>.delayed(const Duration(milliseconds: 250));

  @override
  Future<List<Outfit>> discover({String? category, String query = ''}) async {
    await _latency();
    final q = query.trim().toLowerCase();
    return _outfits.where((o) {
      final inCategory = category == null || o.categories.contains(category);
      final matches = q.isEmpty || _haystack(o).contains(q);
      return inCategory && matches;
    }).toList();
  }

  String _haystack(Outfit o) =>
      '${o.title} ${o.creatorHandle} ${o.tags.join(' ')} ${o.categories.join(' ')}'
          .toLowerCase();

  @override
  Future<Outfit?> byId(String id) async {
    for (final o in _outfits) {
      if (o.id == id) return o;
    }
    return null;
  }

  @override
  Future<StudioLibrary> library() async {
    await _latency();
    return StudioLibrary(
      saved: _outfits.where((o) => _saved.contains(o.id)).toList(),
      liked: _outfits.where((o) => o.isLiked).toList(),
    );
  }

  @override
  Future<void> setSaved(String id, {required bool saved}) async {
    saved ? _saved.add(id) : _saved.remove(id);
  }

  @override
  Future<void> setLiked(String id, {required bool liked}) async {
    final i = _outfits.indexWhere((o) => o.id == id);
    if (i >= 0) _outfits[i] = _outfits[i].copyWith(isLiked: liked);
  }

  @override
  Future<SearchResults> search(String query) async {
    await _latency();
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      return const SearchResults(
        fits: [],
        creatorHandles: [],
        vibes: [],
        collections: [],
      );
    }
    final terms = q.split(RegExp(r'\s+'));
    bool hit(String s) => terms.any(s.toLowerCase().contains);

    final fits = _outfits.where((o) => hit(_haystack(o))).toList();
    // Accounts match on name, handle, tagline or style DNA; authors of matching
    // fits are surfaced too.
    final creators = {
      for (final u in MockUsers.directory)
        if (u.handle != MockUsers.meHandle &&
            hit('${u.name} ${u.handle} ${u.tagline} ${u.styleDna.join(' ')}'))
          u.handle,
      for (final o in fits)
        if (o.creatorHandle != MockUsers.meHandle) o.creatorHandle,
    }.toList();
    final vibes = MockContent.trendingVibes.where(hit).toList();
    final collections = MockContent.collections
        .where((c) => hit('${c.title} ${c.tag}'))
        .toList();
    return SearchResults(
      fits: fits,
      creatorHandles: creators,
      vibes: vibes,
      collections: collections,
    );
  }

  @override
  Future<List<String>> trendingVibes() async => MockContent.trendingVibes;

  @override
  Future<List<Outfit>> byCreator(String handle) async =>
      _outfits.where((o) => o.creatorHandle == handle).toList();
}
