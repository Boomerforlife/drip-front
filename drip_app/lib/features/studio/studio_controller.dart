import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/stylist.dart';
import '../../data/models/studio.dart';
import '../../data/providers.dart';
import '../outfits/outfit_controller.dart';

/// Studio canvas state: one piece per category. The history stack powers
/// UNDO; [saved] is the server's copy of this fit once it's been saved (it
/// carries the drip rate, which the server computes).
class StudioState {
  const StudioState({
    required this.category,
    required this.worn,
    this.history = const [],
    this.fromWardrobe = false,
    this.saved,
    this.dirty = false,
  });

  final String category;

  /// Worn piece per Studio category.
  final Map<String, StudioPiece> worn;
  final List<Map<String, StudioPiece>> history;

  /// Whether pieces come from the user's wardrobe instead of the catalogue.
  final bool fromWardrobe;
  final UserFit? saved;

  /// Changed since the last save.
  final bool dirty;

  int get total => worn.values.fold(0, (s, p) => s + p.price);

  /// The server's score for the last save, if it still matches the canvas.
  int? get dripRate => dirty ? null : saved?.dripRate;

  StudioState copyWith({
    String? category,
    Map<String, StudioPiece>? worn,
    List<Map<String, StudioPiece>>? history,
    bool? fromWardrobe,
    UserFit? saved,
    bool? dirty,
  }) => StudioState(
    category: category ?? this.category,
    worn: worn ?? this.worn,
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

class StudioController extends Notifier<StudioState> {
  final _rng = Random();

  static const _start = 'TOPS';

  @override
  StudioState build() => const StudioState(category: _start, worn: {});

  void setCategory(String c) => state = state.copyWith(category: c);

  void select(StudioPiece piece) {
    final category = state.category;
    if (state.worn[category]?.id == piece.id) {
      // Tapping the worn piece takes it off.
      final next = {...state.worn}..remove(category);
      state = state.copyWith(
        worn: next,
        history: [...state.history, state.worn],
        dirty: true,
      );
      return;
    }
    state = state.copyWith(
      worn: {...state.worn, category: piece},
      history: [...state.history, state.worn],
      dirty: true,
    );
  }

  /// A random piece for every category that has any. Loads the carousels it
  /// needs; categories with nothing to offer are left empty.
  Future<void> randomize() async {
    final next = <String, StudioPiece>{};
    for (final cat in const ['OUTERWEAR', 'TOPS', 'BOTTOMS', 'FOOTWEAR']) {
      try {
        final options = await ref.read(
          studioPiecesProvider((cat, state.fromWardrobe)).future,
        );
        if (options.isNotEmpty && (cat != 'OUTERWEAR' || _rng.nextBool())) {
          next[cat] = options[_rng.nextInt(options.length)];
        }
      } catch (_) {
        // A category that fails to load just stays empty.
      }
    }
    if (!ref.mounted || next.isEmpty) return;
    state = state.copyWith(
      worn: next,
      history: [...state.history, state.worn],
      dirty: true,
    );
  }

  bool get canUndo => state.history.isNotEmpty;

  void undo() {
    if (state.history.isEmpty) return;
    final h = [...state.history];
    final prev = h.removeLast();
    state = state.copyWith(worn: prev, history: h, dirty: true);
  }

  void reset() => state = StudioState(
    category: _start,
    worn: const {},
    fromWardrobe: state.fromWardrobe,
  );

  /// Opens a fit saved earlier, so saving again updates it in place.
  void load(UserFit fit) => state = StudioState(
    category: _start,
    worn: {
      for (final e in fit.pieces.entries) StudioSlots.label(e.key): e.value,
    },
    fromWardrobe: fit.pieces.values.any((p) => p.fromWardrobe),
    saved: fit,
  );

  /// Switches the piece source and starts a fresh canvas.
  void useSource({required bool wardrobe}) =>
      state = StudioState(category: _start, worn: const {}, fromWardrobe: wardrobe);

  /// Saves the canvas as a private user fit (creates it, or replaces the one
  /// saved earlier in this session). The server returns the drip rate.
  Future<UserFit> save({String? name}) async {
    final fit = await ref
        .read(studioRepositoryProvider)
        .saveFit(id: state.saved?.id, name: name, worn: state.worn);
    if (ref.mounted) state = state.copyWith(saved: fit, dirty: false);
    ref.invalidate(libraryProvider);
    return fit;
  }
}

final studioProvider = NotifierProvider<StudioController, StudioState>(
  StudioController.new,
);
