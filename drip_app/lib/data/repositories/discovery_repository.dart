import '../api/api_client.dart';
import '../models/product.dart';

/// Pieces from across stores (Backend_app `docs/API.md` "Discovery"). Search
/// answers from the catalog straight away and, the first time a query is
/// seen, asks Drip's workers to look across stores; `pending` says to ask
/// again shortly.
abstract interface class DiscoveryRepository {
  /// [anyPrice] ignores the user's budget; [maxPrice] overrides it.
  Future<ProductSearch> search(
    String query, {
    int? maxPrice,
    bool anyPrice = false,
  });
  Future<DripProduct?> product(String id);

  /// A product link from any store. Throws [ApiException] (422 with a reason
  /// when the store can't be read).
  Future<DripProduct> importLink(String url);

  /// Admins: products waiting for review.
  Future<List<DripProduct>> reviewQueue();
  Future<void> review(
    String id, {
    required bool approve,
    Map<String, String?> edits = const {},
  });
}

class ApiDiscoveryRepository implements DiscoveryRepository {
  ApiDiscoveryRepository(this._api);
  final ApiClient _api;

  List<DripProduct> _list(Object? v) => [
    for (final p in (v as List?) ?? const [])
      DripProduct.fromJson((p as Map).cast<String, dynamic>()),
  ];

  @override
  Future<ProductSearch> search(
    String query, {
    int? maxPrice,
    bool anyPrice = false,
  }) async {
    final res = await _api.get(
      '/discover/search',
      query: {
        'q': query,
        if (maxPrice != null) 'maxPrice': '$maxPrice',
        if (anyPrice) 'anyPrice': '1',
      },
    ) as Map;
    return ProductSearch(
      products: _list(res['products']),
      pending: res['pending'] as bool? ?? false,
      maxPrice: (res['maxPrice'] as num?)?.toInt(),
    );
  }

  @override
  Future<DripProduct?> product(String id) async {
    try {
      return DripProduct.fromJson(
        (await _api.get('/discover/products/$id') as Map)
            .cast<String, dynamic>(),
      );
    } on ApiException catch (e) {
      if (e.isNotFound) return null;
      rethrow;
    }
  }

  @override
  Future<DripProduct> importLink(String url) async {
    final res = await _api.post('/discover/import', {'url': url}) as Map;
    return DripProduct.fromJson(
      (res['product'] as Map).cast<String, dynamic>(),
    );
  }

  @override
  Future<List<DripProduct>> reviewQueue() async =>
      _list((await _api.get('/admin/review') as Map)['products']);

  @override
  Future<void> review(
    String id, {
    required bool approve,
    Map<String, String?> edits = const {},
  }) => _api.post('/admin/review/$id', {
    'action': approve ? 'approve' : 'reject',
    if (edits.isNotEmpty) 'edits': edits,
  });
}

/// Offline stand-in for tests: a few cut-out pieces, and one "still
/// processing" product that turns ready on the next search.
class MockDiscoveryRepository implements DiscoveryRepository {
  int searches = 0;
  final List<String> imported = [];
  final Set<String> reviewed = {};

  static const _tee = DripProduct(
    id: 'p-tee',
    title: 'Boxy Oversized Tee',
    ready: true,
    brand: 'Snitch',
    retailer: 'Snitch',
    source: 'shopify',
    price: 1299,
    originalPrice: 1799,
    image: 'assets/images/piece_bomber.jpg',
    cutout: true,
    buyUrl: 'https://www.snitch.co.in/products/boxy-tee',
    category: 'top',
    subcategory: 't-shirt',
    colour: 'black',
    fit: 'oversized',
    pattern: 'solid',
    sleeve: 'short sleeve',
    neckline: 'crew neck',
    styleTags: ['streetwear'],
    confidence: 0.9,
  );
  static const _cargo = DripProduct(
    id: 'p-cargo',
    title: 'Baggy Cargo Pants',
    ready: true,
    brand: 'Bluorng',
    retailer: 'Bluorng',
    source: 'shopify',
    price: 2499,
    image: 'assets/images/result_neo_cargo.jpg',
    cutout: true,
    buyUrl: 'https://www.bluorng.com/products/cargo',
    category: 'bottom',
    subcategory: 'cargos',
    colour: 'beige',
    fit: 'baggy',
    confidence: 0.85,
  );
  static const _pending = DripProduct(
    id: 'p-new',
    title: 'Washed Black Tee',
    ready: false,
    brand: 'Capsul',
    retailer: 'Capsul',
    source: 'shopify',
    price: 1499,
    image: 'assets/images/piece_bomber.jpg',
    buyUrl: 'https://shopcapsul.com/products/washed',
    category: 'top',
  );

  @override
  Future<ProductSearch> search(
    String query, {
    int? maxPrice,
    bool anyPrice = false,
  }) async {
    searches++;
    final first = searches == 1;
    final all = [_tee, _cargo, if (first) _pending else _readyVersionOfPending];
    final q = query.toLowerCase();
    final hits = all.where(
      (p) => q
          .split(' ')
          .any(
            (w) => '${p.title} ${p.subcategory} ${p.colour}'
                .toLowerCase()
                .contains(w),
          ),
    );
    return ProductSearch(
      products: [
        for (final p in hits)
          if (anyPrice || maxPrice == null || (p.price ?? 0) <= maxPrice) p,
      ],
      pending: first,
      maxPrice: anyPrice ? null : maxPrice,
    );
  }

  static const _readyVersionOfPending = DripProduct(
    id: 'p-new',
    title: 'Washed Black Tee',
    ready: true,
    brand: 'Capsul',
    retailer: 'Capsul',
    source: 'shopify',
    price: 1499,
    image: 'assets/images/piece_bomber.jpg',
    cutout: true,
    buyUrl: 'https://shopcapsul.com/products/washed',
    category: 'top',
    subcategory: 't-shirt',
    colour: 'black',
  );

  @override
  Future<DripProduct?> product(String id) async => [
    _tee,
    _cargo,
    _readyVersionOfPending,
  ].where((p) => p.id == id).firstOrNull;

  @override
  Future<DripProduct> importLink(String url) async {
    if (url.contains('myntra')) {
      throw const ApiException(
        422,
        'www.myntra.com refused automated access (HTTP 403). Try the brand\'s own store.',
      );
    }
    imported.add(url);
    return DripProduct(
      id: 'p-import-${imported.length}',
      title: 'Imported piece',
      ready: false,
      buyUrl: url,
      retailer: Uri.parse(url).host,
    );
  }

  @override
  Future<List<DripProduct>> reviewQueue() async => [
    if (!reviewed.contains('p-review'))
      const DripProduct(
        id: 'p-review',
        title: 'Linen Overshirt',
        ready: true,
        brand: 'Cord',
        image: 'assets/images/piece_bomber.jpg',
        cutout: true,
        category: 'outer',
        subcategory: 'jacket',
        colour: 'beige',
        material: 'linen',
        confidence: 0.62,
        reviewStatus: 'pending',
      ),
  ];

  @override
  Future<void> review(
    String id, {
    required bool approve,
    Map<String, String?> edits = const {},
  }) async => reviewed.add(id);
}
