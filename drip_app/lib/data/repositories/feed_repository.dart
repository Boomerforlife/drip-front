import '../api/api_client.dart';
import '../mock/mock_content.dart';
import '../models/outfit.dart';

/// One page of the Fashion Scroll. [nextCursor] is opaque; null means the end
/// of the feed.
class FeedPage {
  const FeedPage({required this.items, this.nextCursor});
  final List<Outfit> items;
  final String? nextCursor;
}

/// The Fashion Scroll (and Home's fresh fits): ranked, not-seen `Outfit`s.
abstract interface class FeedRepository {
  Future<FeedPage> page({String? cursor});

  /// `open | skip | like | unlike | save`, with how long the card was on
  /// screen. Trains the ranking; failures are ignored by callers.
  Future<void> signal(String outfitId, String action, {int? dwellMs});
}

class ApiFeedRepository implements FeedRepository {
  ApiFeedRepository(this._api);
  final ApiClient _api;

  @override
  Future<FeedPage> page({String? cursor}) async {
    final json =
        await _api.get('/scroll', query: {'cursor': ?cursor}) as Map;
    return FeedPage(
      items: [
        for (final o in (json['items'] as List?) ?? const [])
          if (o is Map) Outfit.fromJson(o.cast<String, dynamic>()),
      ],
      nextCursor: json['nextCursor'] as String?,
    );
  }

  @override
  Future<void> signal(String outfitId, String action, {int? dwellMs}) =>
      _api.post('/outfits/$outfitId/signal', {
        'action': action,
        'dwellMs': ?dwellMs,
      });
}

/// Fixture feed for tests: the mock catalogue, three to a page.
class MockFeedRepository implements FeedRepository {
  MockFeedRepository({List<Outfit>? outfits, this.pageSize = 3})
    : _outfits = outfits ?? MockContent.outfits;

  final List<Outfit> _outfits;
  final int pageSize;
  final signals = <(String, String)>[];

  @override
  Future<FeedPage> page({String? cursor}) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final start = int.tryParse(cursor ?? '0') ?? 0;
    final end = (start + pageSize).clamp(0, _outfits.length);
    return FeedPage(
      items: _outfits.sublist(start, end),
      nextCursor: end < _outfits.length ? '$end' : null,
    );
  }

  @override
  Future<void> signal(String outfitId, String action, {int? dwellMs}) async {
    signals.add((outfitId, action));
  }
}
