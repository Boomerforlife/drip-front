import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/stylist.dart';
import '../../data/providers.dart';
import '../wardrobe/wardrobe_controller.dart';

class StylistState {
  const StylistState({
    this.occasion = 'Concert',
    this.vibe = 'Experimental Cyber',
    this.restrictToWardrobe = true,
    this.blueprint = const AsyncData(null),
  });

  final String occasion;
  final String vibe;
  final bool restrictToWardrobe;
  final AsyncValue<Blueprint?> blueprint;

  StylistState copyWith({
    String? occasion,
    String? vibe,
    bool? restrictToWardrobe,
    AsyncValue<Blueprint?>? blueprint,
  }) => StylistState(
    occasion: occasion ?? this.occasion,
    vibe: vibe ?? this.vibe,
    restrictToWardrobe: restrictToWardrobe ?? this.restrictToWardrobe,
    blueprint: blueprint ?? this.blueprint,
  );
}

class StylistController extends Notifier<StylistState> {
  @override
  StylistState build() => const StylistState();

  void setOccasion(String v) => state = state.copyWith(occasion: v);
  void setVibe(String v) => state = state.copyWith(vibe: v);
  void setRestrict(bool v) => state = state.copyWith(restrictToWardrobe: v);

  Future<Blueprint?> generate() async {
    state = state.copyWith(blueprint: const AsyncLoading());
    final wardrobe = await ref.read(wardrobeProvider.future);
    final result = await AsyncValue.guard<Blueprint?>(
      () => ref
          .read(stylistRepositoryProvider)
          .generateBlueprint(
            occasion: state.occasion,
            vibe: state.vibe,
            restrictToWardrobe: state.restrictToWardrobe,
            wardrobe: wardrobe,
          ),
    );
    if (!ref.mounted) return null;
    state = state.copyWith(blueprint: result);
    return result.value;
  }

}

/// Occasion and vibe labels Taylor accepts (from `GET /meta`).
final stylistOptionsProvider = FutureProvider<(List<String>, List<String>)>((
  ref,
) async {
  final meta = await ref.watch(metaProvider.future);
  return (
    [for (final o in meta.occasions) o.label],
    [for (final v in meta.vibes) v.label],
  );
});

final stylistProvider = NotifierProvider<StylistController, StylistState>(
  StylistController.new,
);
