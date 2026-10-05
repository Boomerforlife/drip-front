import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/mock/mock_content.dart';
import '../../data/models/product.dart';
import '../../data/providers.dart';
import '../../data/repositories/outfit_repository.dart';

/// Recent searches, persisted on the device.
class RecentSearchesController extends Notifier<List<String>> {
  static const _max = 8;

  @override
  List<String> build() =>
      ref.watch(localStoreProvider).recentSearches ??
      List.of(MockContent.seedRecentSearches);

  Future<void> add(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    state = [
      q,
      ...state.where((e) => e.toLowerCase() != q.toLowerCase()),
    ].take(_max).toList();
    await ref.read(localStoreProvider).setRecentSearches(state);
  }

  Future<void> remove(String query) async {
    state = [
      for (final e in state)
        if (e != query) e,
    ];
    await ref.read(localStoreProvider).setRecentSearches(state);
  }

  Future<void> clear() async {
    state = const [];
    await ref.read(localStoreProvider).setRecentSearches(state);
  }
}

final recentSearchesProvider =
    NotifierProvider<RecentSearchesController, List<String>>(
      RecentSearchesController.new,
    );

final trendingVibesProvider = FutureProvider<List<String>>(
  (ref) => ref.watch(outfitRepositoryProvider).trendingVibes(),
);

final searchResultsProvider = FutureProvider.family<SearchResults, String>(
  (ref, query) => ref.watch(outfitRepositoryProvider).search(query),
);

/// Pieces for a search, across stores, within the user's budget (the API
/// applies it). Shows what's ready at once; while Drip is still finding and
/// cutting out pieces (`pending`) it asks again every few seconds, for about
/// a minute, and swaps the new ones in. The screen never waits on it.
class ProductSearchController extends AsyncNotifier<ProductSearch> {
  ProductSearchController(this.query);
  final String query;

  static const pollEvery = Duration(seconds: 4);
  static const maxPolls = 15;

  Timer? _timer;
  int _polls = 0;

  @override
  Future<ProductSearch> build() async {
    ref.onDispose(() => _timer?.cancel());
    final first = await ref.read(discoveryRepositoryProvider).search(query);
    _schedule(first);
    return first;
  }

  void _schedule(ProductSearch r) {
    _timer?.cancel();
    if (!r.pending || _polls >= maxPolls) return;
    _timer = Timer(pollEvery, () async {
      _polls++;
      try {
        final next = await ref.read(discoveryRepositoryProvider).search(query);
        if (!ref.mounted) return;
        state = AsyncData(next);
        _schedule(next);
      } catch (_) {
        // A failed poll leaves what's on screen; the next search tries again.
      }
    });
  }

  /// Pull to refresh.
  Future<void> refresh() async {
    _polls = 0;
    final next = await ref.read(discoveryRepositoryProvider).search(query);
    if (!ref.mounted) return;
    state = AsyncData(next);
    _schedule(next);
  }
}

final productSearchProvider = AsyncNotifierProvider.autoDispose
    .family<ProductSearchController, ProductSearch, String>(
      ProductSearchController.new,
    );
