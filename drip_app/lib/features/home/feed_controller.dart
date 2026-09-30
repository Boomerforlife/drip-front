import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/ootd.dart';
import '../../data/models/outfit.dart';
import '../../data/providers.dart';

/// The Fashion Scroll: ranked, not-seen [Outfit]s, a page at a time.
class FeedState {
  const FeedState({
    required this.items,
    this.nextCursor,
    this.loadingMore = false,
    this.loadMoreFailed = false,
  });

  final List<Outfit> items;

  /// Null once the feed has been read to the end.
  final String? nextCursor;
  final bool loadingMore;
  final bool loadMoreFailed;

  bool get hasMore => nextCursor != null;

  FeedState copyWith({
    List<Outfit>? items,
    String? Function()? nextCursor,
    bool? loadingMore,
    bool? loadMoreFailed,
  }) => FeedState(
    items: items ?? this.items,
    nextCursor: nextCursor == null ? this.nextCursor : nextCursor(),
    loadingMore: loadingMore ?? this.loadingMore,
    loadMoreFailed: loadMoreFailed ?? this.loadMoreFailed,
  );
}

class FeedController extends AsyncNotifier<FeedState> {
  @override
  Future<FeedState> build() async {
    final page = await ref.watch(feedRepositoryProvider).page();
    return FeedState(items: page.items, nextCursor: page.nextCursor);
  }

  /// Fetches the next page (no-op while one is loading or at the end).
  Future<void> loadMore() async {
    final s = state.value;
    if (s == null || !s.hasMore || s.loadingMore) return;
    state = AsyncData(s.copyWith(loadingMore: true, loadMoreFailed: false));
    try {
      final page = await ref
          .read(feedRepositoryProvider)
          .page(cursor: s.nextCursor);
      if (!ref.mounted) return;
      final seen = {for (final o in s.items) o.id};
      state = AsyncData(
        s.copyWith(
          items: [
            ...s.items,
            for (final o in page.items)
              if (!seen.contains(o.id)) o,
          ],
          nextCursor: () => page.nextCursor,
          loadingMore: false,
        ),
      );
    } catch (_) {
      if (!ref.mounted) return;
      state = AsyncData(s.copyWith(loadingMore: false, loadMoreFailed: true));
    }
  }

  /// A card was viewed (`open`) or swiped past (`skip`). Fire and forget: a
  /// lost signal only makes the ranking slightly less sharp.
  void signal(String outfitId, String action, {int? dwellMs}) {
    if (!ref.mounted) return;
    ref
        .read(feedRepositoryProvider)
        .signal(outfitId, action, dwellMs: dwellMs)
        .ignore();
  }
}

final feedProvider = AsyncNotifierProvider<FeedController, FeedState>(
  FeedController.new,
);

/// A fit already loaded in the feed, if it's there.
final feedOutfitProvider = Provider.family<Outfit?, String>((ref, id) {
  final items = ref.watch(feedProvider).value?.items;
  if (items == null) return null;
  for (final o in items) {
    if (o.id == id) return o;
  }
  return null;
});

// ─────────────────────────────────────────────────────────────── social
// Creator posts, stories and comments: the social layer, which isn't in the
// v1 backend. The mock keeps the (after-beta) UI rendering.

/// Creator posts (OOTD viewer, create-post flow).
class PostsController extends AsyncNotifier<List<Ootd>> {
  @override
  Future<List<Ootd>> build() => ref.watch(postsRepositoryProvider).feed();

  void _replace(Ootd next) {
    final list = state.value;
    if (list == null) return;
    state = AsyncData([for (final o in list) o.id == next.id ? next : o]);
  }

  Future<void> toggleLike(String id) async {
    final current = state.value?.firstWhere((o) => o.id == id);
    if (current == null) return;
    final liked = !current.isLiked;
    _replace(
      current.copyWith(isLiked: liked, likes: current.likes + (liked ? 1 : -1)),
    );
    await ref.read(postsRepositoryProvider).setLiked(id, liked: liked);
  }

  Future<void> toggleSave(String id) async {
    final current = state.value?.firstWhere((o) => o.id == id);
    if (current == null) return;
    final saved = !current.isSaved;
    _replace(
      current.copyWith(isSaved: saved, saves: current.saves + (saved ? 1 : -1)),
    );
    await ref.read(postsRepositoryProvider).setSaved(id, saved: saved);
  }

  Future<void> addComment(String id, String text) async {
    await ref.read(postsRepositoryProvider).addComment(id, text);
    final current = state.value?.where((o) => o.id == id).firstOrNull;
    if (current == null) return;
    _replace(current.copyWith(comments: current.comments + 1));
    ref.invalidate(commentsProvider(id));
  }

  Future<void> share(String id) async {
    await ref.read(postsRepositoryProvider).recordShare(id);
    final current = state.value?.where((o) => o.id == id).firstOrNull;
    if (current == null) return;
    _replace(current.copyWith(shares: current.shares + 1));
  }

  Future<void> publish(Ootd post) async {
    await ref.read(postsRepositoryProvider).publish(post);
    state = AsyncData([post, ...?state.value]);
  }
}

final postsProvider = AsyncNotifierProvider<PostsController, List<Ootd>>(
  PostsController.new,
);

/// Comments for one post.
final commentsProvider = FutureProvider.family<List<OotdComment>, String>(
  (ref, id) => ref.watch(postsRepositoryProvider).comments(id),
);

class StoriesController extends AsyncNotifier<List<Story>> {
  @override
  Future<List<Story>> build() => ref.watch(postsRepositoryProvider).stories();

  void markSeen(String handle) {
    final list = state.value;
    if (list == null) return;
    state = AsyncData([
      for (final s in list) s.handle == handle ? s.copyWith(unseen: false) : s,
    ]);
  }
}

final storiesProvider = AsyncNotifierProvider<StoriesController, List<Story>>(
  StoriesController.new,
);

/// Looks up a single post by id from the loaded posts.
final ootdProvider = Provider.family<Ootd?, String>((ref, id) {
  final list = ref.watch(postsProvider).value;
  if (list == null) return null;
  for (final o in list) {
    if (o.id == id) return o;
  }
  return null;
});
