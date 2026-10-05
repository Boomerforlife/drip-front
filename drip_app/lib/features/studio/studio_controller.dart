import 'dart:math';
import 'dart:ui' show Rect;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/stylist.dart';
import '../../data/models/studio.dart';
import '../../data/providers.dart';
import '../../data/repositories/local_store.dart';
import '../outfits/outfit_controller.dart';
import 'studio_layouts.dart';

/// What the canvas looks like at one moment: the pieces, where the user put
/// them, and which sits on top. UNDO steps back through these.
class StudioSnapshot {
  const StudioSnapshot(this.worn, this.placed, this.stack);
  final Map<String, StudioPiece> worn;
  final Map<String, Rect> placed;
  final List<String> stack;
}

/// Studio canvas state: one piece per category. Pieces sit where their
/// layout puts them until the user drags one; [placed] holds those moved
/// boxes (fractions of the canvas). [saved] is the server's copy of this fit
/// once it's been saved (it carries the drip rate, which the server computes).
class StudioState {
  const StudioState({
    required this.category,
    required this.worn,
    this.placed = const {},
    this.stack = const [],
    this.history = const [],
    this.fromWardrobe = false,
    this.saved,
    this.dirty = false,
  });

  final String category;

  /// Worn piece per Studio category.
  final Map<String, StudioPiece> worn;

  /// Pieces the user moved or resized: category → box (0–1 of the canvas).
  final Map<String, Rect> placed;

  /// Back-to-front drawing order: the last piece touched is on top.
  final List<String> stack;
  final List<StudioSnapshot> history;

  /// Whether pieces come from the user's wardrobe instead of the catalogue.
  final bool fromWardrobe;
  final UserFit? saved;

  /// Changed since the last save.
  final bool dirty;

  int get total => worn.values.fold(0, (s, p) => s + p.price);

  /// The server's score for the last save, if it still matches the canvas.
  int? get dripRate => dirty ? null : saved?.dripRate;

  StudioSnapshot get snapshot => StudioSnapshot(worn, placed, stack);

  StudioState copyWith({
    String? category,
    Map<String, StudioPiece>? worn,
    Map<String, Rect>? placed,
    List<String>? stack,
    List<StudioSnapshot>? history,
    bool? fromWardrobe,
    UserFit? saved,
    bool? dirty,
  }) => StudioState(
    category: category ?? this.category,
    worn: worn ?? this.worn,
    placed: placed ?? this.placed,
    stack: stack ?? this.stack,
    history: history ?? this.history,
    fromWardrobe: fromWardrobe ?? this.fromWardrobe,
    saved: saved ?? this.saved,
    dirty: dirty ?? this.dirty,
  );
}

/// The swap-pieces carousel for a (category, from-wardrobe) pair.
final studioPiecesProvider =
    FutureProvider.family<List<StudioPiece>, (String, bool)>(
      (ref, key) => ref
          .watch(studioRepositoryProvider)
          .pieces(key.$1, fromWardrobe: key.$2),
    );

/// Catalogue pieces in [category] that appear in fits the user saved or
/// liked: their "saved products". Matched by cut-out (the same CDN image) or
/// by name, since a fit's pieces don't carry the garment id a user fit needs.
final savedStudioPiecesProvider =
    FutureProvider.family<List<StudioPiece>, String>((ref, category) async {
      final library = await ref.watch(libraryProvider.future);
      final images = <String>{};
      final names = <String>{};
      for (final fit in [...library.saved, ...library.liked]) {
        for (final p in fit.pieces) {
          if (p.image != null && p.image!.isNotEmpty) images.add(p.image!);
          if (p.name.isNotEmpty) names.add(p.name.toLowerCase());
        }
      }
      if (images.isEmpty && names.isEmpty) return const [];
      final all = await ref.watch(
        studioPiecesProvider((category, false)).future,
      );
      return [
        for (final p in all)
          if (images.contains(p.image) || names.contains(p.name.toLowerCase()))
            p,
      ];
    });

/// Store pages for pieces seen in the user's saved and liked fits, by cut-out
/// and by lower-cased name: VISIT in the piece picker.
final pieceLinksProvider = Provider<Map<String, String>>((ref) {
  final library = ref.watch(libraryProvider).value;
  if (library == null) return const {};
  return {
    for (final fit in [...library.saved, ...library.liked])
      for (final p in fit.pieces)
        if (p.buyUrl != null && p.buyUrl!.isNotEmpty) ...{
          if (p.image != null && p.image!.isNotEmpty) p.image!: p.buyUrl!,
          p.name.toLowerCase(): p.buyUrl!,
        },
  };
});

class StudioController extends Notifier<StudioState> {
  final _rng = Random();

  static const _start = 'TOPS';

  @override
  StudioState build() => const StudioState(category: _start, worn: {});

  void setCategory(String c) => state = state.copyWith(category: c);

  List<StudioSnapshot> get _pushed => [...state.history, state.snapshot];

  List<String> _toFront(List<String> stack, String category) => [
    for (final c in stack)
      if (c != category) c,
    category,
  ];

  /// Puts [piece] on the canvas in the current category, or takes it off if
  /// it's already worn. A dress and a top/bottoms can't be worn together
  /// (same rule as the backend's fits); returns a note when one replaced the
  /// other, so the screen can say so.
  String? select(StudioPiece piece) {
    final base = baseCategory(state.category);
    if (base == 'ACCESSORIES') return _toggleAccessory(piece);
    final category = base;
    if (state.worn[category]?.id == piece.id) {
      remove(category);
      return null;
    }
    final next = {...state.worn, category: piece};
    final placed = {...state.placed};
    String? note;
    void drop(String c) {
      next.remove(c);
      placed.remove(c);
    }

    if (category == 'DRESSES' &&
        (next.containsKey('TOPS') || next.containsKey('BOTTOMS'))) {
      drop('TOPS');
      drop('BOTTOMS');
      note = 'A dress replaces the top and bottoms';
    } else if ((category == 'TOPS' || category == 'BOTTOMS') &&
        next.containsKey('DRESSES')) {
      drop('DRESSES');
      note = 'Swapped the dress for separates';
    }
    state = state.copyWith(
      worn: next,
      placed: placed,
      stack: _toFront(state.stack, category),
      history: _pushed,
      dirty: true,
    );
    return note;
  }

  /// Most accessories one fit can carry.
  static const maxAccessories = maxStudioAccessories;

  /// Accessories stack up: picking one adds it (under the next free key),
  /// picking a worn one takes it off.
  String? _toggleAccessory(StudioPiece piece) {
    for (final e in state.worn.entries) {
      if (isAccessoryKey(e.key) && e.value.id == piece.id) {
        remove(e.key);
        return null;
      }
    }
    final worn = state.worn.keys.where(isAccessoryKey).length;
    if (worn >= maxAccessories) {
      return 'Up to $maxAccessories extras on one fit';
    }
    var key = 'ACCESSORIES';
    for (var n = 2; state.worn.containsKey(key); n++) {
      key = 'ACCESSORIES:$n';
    }
    state = state.copyWith(
      worn: {...state.worn, key: piece},
      stack: _toFront(state.stack, key),
      history: _pushed,
      dirty: true,
    );
    return null;
  }

  /// Puts [piece] in place of the one under [key] (one UNDO step). It takes
  /// the layout's spot for its kind, since its shape differs from the old one.
  void swap(String key, StudioPiece piece) {
    if (!state.worn.containsKey(key) || state.worn[key]!.id == piece.id) {
      return;
    }
    state = state.copyWith(
      worn: {...state.worn, key: piece},
      placed: {...state.placed}..remove(key),
      stack: _toFront(state.stack, key),
      history: _pushed,
      dirty: true,
    );
  }

  /// Takes the piece in [category] off the canvas.
  void remove(String category) {
    if (!state.worn.containsKey(category)) return;
    state = state.copyWith(
      worn: {...state.worn}..remove(category),
      placed: {...state.placed}..remove(category),
      stack: [...state.stack]..remove(category),
      history: _pushed,
      dirty: true,
    );
  }

  /// A drag or pinch is starting on [category]: remember the canvas for UNDO,
  /// bring the piece to the front and make it the one being edited.
  void beginMove(String category) {
    state = state.copyWith(
      category: category,
      stack: _toFront(state.stack, category),
      history: _pushed,
    );
  }

  /// The piece in [category] now sits at [box] (fractions of the canvas).
  void move(String category, Rect box) {
    state = state.copyWith(
      placed: {...state.placed, category: box},
      dirty: true,
    );
  }

  /// Puts every moved piece back where the layout wants it.
  void snapBack() {
    if (state.placed.isEmpty) return;
    state = state.copyWith(placed: const {}, history: _pushed, dirty: true);
  }

  /// Browse the catalogue or the user's own wardrobe. The canvas keeps what's
  /// on it: a fit can mix both.
  void setSource({required bool wardrobe}) =>
      state = state.copyWith(fromWardrobe: wardrobe);

  /// A random piece for every category that has any. Loads the carousels it
  /// needs; categories with nothing to offer are left empty.
  Future<void> randomize() async {
    final next = <String, StudioPiece>{};
    const optional = {'OUTERWEAR', 'ACCESSORIES'};
    for (final cat in const [
      'TOPS',
      'BOTTOMS',
      'FOOTWEAR',
      'OUTERWEAR',
      'ACCESSORIES',
    ]) {
      try {
        final options = await ref.read(
          studioPiecesProvider((cat, state.fromWardrobe)).future,
        );
        if (options.isNotEmpty &&
            (!optional.contains(cat) || _rng.nextBool())) {
          next[cat] = options[_rng.nextInt(options.length)];
        }
      } catch (_) {
        // A category that fails to load just stays empty.
      }
    }
    if (!ref.mounted || next.isEmpty) return;
    state = state.copyWith(
      worn: next,
      placed: const {},
      stack: next.keys.toList(),
      history: _pushed,
      dirty: true,
    );
  }

  bool get canUndo => state.history.isNotEmpty;

  void undo() {
    if (state.history.isEmpty) return;
    final h = [...state.history];
    final prev = h.removeLast();
    state = state.copyWith(
      worn: prev.worn,
      placed: prev.placed,
      stack: prev.stack,
      history: h,
      dirty: true,
    );
  }

  void reset() => state = StudioState(
    category: _start,
    worn: const {},
    fromWardrobe: state.fromWardrobe,
  );

  /// Opens a fit saved earlier, so saving again updates it in place.
  void load(UserFit fit) {
    final store = ref.read(localStoreProvider);
    final worn = wornForFit(fit, store);
    state = StudioState(
      category: _start,
      worn: worn,
      placed: placementForFit(fit, store)
        ..removeWhere((k, _) => !worn.containsKey(k)),
      stack: [
        for (final k in fit.stack)
          if (worn.containsKey(k)) k,
        for (final k in worn.keys)
          if (!fit.stack.contains(k)) k,
      ],
      fromWardrobe: worn.values.any((p) => p.fromWardrobe),
      saved: fit,
    );
  }

  /// Switches the piece source and starts a fresh canvas.
  void useSource({required bool wardrobe}) => state = StudioState(
    category: _start,
    worn: const {},
    fromWardrobe: wardrobe,
  );

  /// Saves the canvas as a private user fit (creates it, or replaces the one
  /// saved earlier in this session): every piece, where it sits and which is
  /// on top. The server returns the drip rate.
  Future<UserFit> save({String? name}) async {
    final fit = await ref
        .read(studioRepositoryProvider)
        .saveFit(
          id: state.saved?.id,
          name: name,
          worn: state.worn,
          placed: state.placed,
          stack: state.stack,
        );
    // The server has all of it now: drop what older builds kept here.
    await ref.read(localStoreProvider).forgetStudioFit(fit.id);
    if (ref.mounted) state = state.copyWith(saved: fit, dirty: false);
    ref.invalidate(libraryProvider);
    return fit;
  }
}

/// A saved fit's pieces by canvas key. Fits saved before the API kept every
/// accessory may have extras on this device; they're read until the fit is
/// saved again.
Map<String, StudioPiece> wornForFit(UserFit fit, LocalStore store) => {
  ...fit.pieces,
  for (final e in (store.studioExtras(fit.id) ?? const {}).entries)
    if (!fit.pieces.containsKey(e.key)) e.key: StudioPiece.fromJson(e.value),
};

/// Where a saved fit's pieces sit: the server's boxes, or for a fit saved
/// before it kept them, the ones stored on this device.
Map<String, Rect> placementForFit(UserFit fit, LocalStore store) =>
    fit.boxes.isNotEmpty
    ? {...fit.boxes}
    : savedPlacement(store.studioPositions(fit.id));

/// Stored `[x, y, w, h]` lists → boxes.
Map<String, Rect> savedPlacement(Map<String, List<double>>? raw) => {
  for (final e in (raw ?? const <String, List<double>>{}).entries)
    if (e.value.length == 4)
      e.key: Rect.fromLTWH(e.value[0], e.value[1], e.value[2], e.value[3]),
};

final studioProvider = NotifierProvider<StudioController, StudioState>(
  StudioController.new,
);
