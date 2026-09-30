import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/outfit.dart';
import '../../data/models/studio.dart';
import '../../data/providers.dart';
import '../home/feed_controller.dart';

/// The user's own space (`GET /studio`): saved and liked fits, Gen renders
/// and the fits they built. Refetched after saves, likes and Gen.
final libraryProvider = FutureProvider<StudioLibrary>(
  (ref) => ref.watch(outfitRepositoryProvider).library(),
);

/// One fit, from wherever it's already loaded (the feed, the library) or else
/// `GET /outfits/:id`. Null when it doesn't exist.
final outfitProvider = FutureProvider.family<Outfit?, String>((ref, id) async {
  final cached = ref.read(feedOutfitProvider(id));
  if (cached != null) return cached;
  final lib = ref.read(libraryProvider).value;
  for (final o in [...?lib?.saved, ...?lib?.liked]) {
    if (o.id == id) return o;
  }
  return ref.watch(outfitRepositoryProvider).byId(id);
});

/// What the user has liked and saved. Seeded from the library, updated
/// optimistically on tap, and reverted if the API call fails.
class FitMarks {
  const FitMarks({this.liked = const {}, this.saved = const {}});
  final Set<String> liked;
  final Set<String> saved;

  bool isLiked(String id) => liked.contains(id);
  bool isSaved(String id) => saved.contains(id);
}

class FitMarksController extends Notifier<FitMarks> {
  @override
  FitMarks build() {
    // Re-seed only from a finished fetch: while the library refetches it
    // still holds the old lists, which would briefly undo a fresh toggle.
    ref.listen(libraryProvider, (_, next) {
      final lib = next.value;
      if (lib != null && !next.isLoading) state = _from(lib);
    });
    final lib = ref.read(libraryProvider).value;
    return lib == null ? const FitMarks() : _from(lib);
  }

  static FitMarks _from(StudioLibrary lib) => FitMarks(
    liked: {for (final o in lib.liked) o.id},
    saved: {for (final o in lib.saved) o.id},
  );

  /// Returns the new state. Throws (after reverting) if the API refused.
  Future<bool> toggleLike(String id) async {
    final before = state;
    final liked = !before.isLiked(id);
    state = FitMarks(
      liked: liked ? {...before.liked, id} : ({...before.liked}..remove(id)),
      saved: before.saved,
    );
    try {
      await ref.read(outfitRepositoryProvider).setLiked(id, liked: liked);
    } catch (_) {
      state = before;
      rethrow;
    }
    return liked;
  }

  /// Returns the new state. Throws (after reverting) if the API refused.
  Future<bool> toggleSave(String id) async {
    final before = state;
    final saved = !before.isSaved(id);
    state = FitMarks(
      liked: before.liked,
      saved: saved ? {...before.saved, id} : ({...before.saved}..remove(id)),
    );
    try {
      await ref.read(outfitRepositoryProvider).setSaved(id, saved: saved);
    } catch (_) {
      state = before;
      rethrow;
    }
    // The Saved list shows full fits, so pick up the server's copy.
    ref.invalidate(libraryProvider);
    return saved;
  }
}

final fitMarksProvider = NotifierProvider<FitMarksController, FitMarks>(
  FitMarksController.new,
);

/// Saved looks (Wardrobe → SAVED), minus anything unsaved since the last
/// library fetch.
final savedOutfitsProvider = Provider<AsyncValue<List<Outfit>>>((ref) {
  final marks = ref.watch(fitMarksProvider);
  return ref
      .watch(libraryProvider)
      .whenData(
        (lib) => [
          for (final o in lib.saved)
            if (marks.isSaved(o.id)) o,
        ],
      );
});

/// Discover and search results (mock only until those endpoints exist; the
/// screens are behind "coming after beta").
class OutfitCatalogController extends AsyncNotifier<List<Outfit>> {
  @override
  Future<List<Outfit>> build() =>
      ref.watch(outfitRepositoryProvider).discover();
}

final outfitCatalogProvider =
    AsyncNotifierProvider<OutfitCatalogController, List<Outfit>>(
      OutfitCatalogController.new,
    );
