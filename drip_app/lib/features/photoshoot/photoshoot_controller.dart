import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/api_client.dart';
import '../../data/mock/mock_content.dart';
import '../../data/models/outfit.dart';
import '../../data/models/studio.dart';
import '../../data/models/stylist.dart';
import '../../data/providers.dart';
import '../../data/repositories/studio_repository.dart';
import '../outfits/outfit_controller.dart';

class PhotoshootState {
  const PhotoshootState({
    this.mode = ShootMode.ai,
    this.fitId,
    this.sceneId = 'tokyo',
    this.customLabel,
    this.render = const AsyncData(null),
  });

  final ShootMode mode;

  /// A banked fit (saved or liked). Null picks the first available.
  final String? fitId;
  final String sceneId;

  /// Name typed for the "CUSTOM ✦" scene.
  final String? customLabel;
  final AsyncValue<ShootRender?> render;

  PhotoshootState copyWith({
    ShootMode? mode,
    String? fitId,
    String? sceneId,
    String? customLabel,
    AsyncValue<ShootRender?>? render,
  }) => PhotoshootState(
    mode: mode ?? this.mode,
    fitId: fitId ?? this.fitId,
    sceneId: sceneId ?? this.sceneId,
    customLabel: customLabel ?? this.customLabel,
    render: render ?? this.render,
  );

  String get sceneLabel {
    if (sceneId == 'custom') return (customLabel ?? 'CUSTOM').toUpperCase();
    return MockContent.scenes.firstWhere((s) => s.id == sceneId).label;
  }
}

/// Gen ran out of credits (the API's 429 on `POST /gen`).
class GenCreditsUsedUp implements Exception {
  const GenCreditsUsedUp();
}

/// The fits Gen can shoot: saved and liked banked fits (not user-built ones).
final shootableFitsProvider = Provider<AsyncValue<List<Outfit>>>((ref) {
  return ref.watch(libraryProvider).whenData((lib) {
    final seen = <String>{};
    return [
      for (final o in [...lib.saved, ...lib.liked])
        if (seen.add(o.id)) o,
    ];
  });
});

class PhotoshootController extends Notifier<PhotoshootState> {
  static const pollEvery = Duration(seconds: 2);
  static const giveUpAfter = Duration(minutes: 3);

  @override
  PhotoshootState build() => const PhotoshootState();

  void setMode(ShootMode m) => state = state.copyWith(mode: m);
  void setFit(String id) => state = state.copyWith(fitId: id);
  void setScene(String id, {String? customLabel}) =>
      state = state.copyWith(sceneId: id, customLabel: customLabel);

  /// Renders the shoot of [fit]. In "real look" mode [realImage] is the photo
  /// the user took (no Gen, no credit). Otherwise it's a Gen job: reserve a
  /// credit, then poll until it finishes.
  Future<void> generate({required Outfit fit, String? realImage}) async {
    final label = state.sceneLabel;
    final title = '${fit.title} · $label'.toUpperCase();
    state = state.copyWith(render: const AsyncLoading());
    final result = await AsyncValue.guard<ShootRender?>(() async {
      if (realImage != null) {
        return ShootRender(
          image: realImage,
          title: title,
          scene: label,
          score: fit.rate,
        );
      }
      final repo = ref.read(studioRepositoryProvider);
      var job = await _start(repo, fit.id);
      final deadline = DateTime.now().add(giveUpAfter);
      while (!job.isFinished) {
        if (DateTime.now().isAfter(deadline)) {
          throw const ApiException(0, 'The render is taking too long');
        }
        await Future<void>.delayed(pollEvery);
        if (!ref.mounted) return null;
        job = await repo.genJob(job.id);
      }
      ref
        ..invalidate(accountProvider) // credits left
        ..invalidate(libraryProvider); // the render joins the library
      if (job.failed || job.outputUrl == null) {
        throw const ApiException(500, 'The render failed');
      }
      return ShootRender(
        image: job.outputUrl!,
        title: title,
        scene: label,
        score: fit.rate,
        fellBack: job.fellBack,
      );
    });
    if (!ref.mounted) return;
    state = state.copyWith(render: result);
  }

  Future<GenJob> _start(StudioRepository repo, String fitId) async {
    try {
      return await repo.startGen(
        fitId: fitId,
        sceneId: state.sceneId == 'custom' ? null : state.sceneId,
        mode: state.mode,
      );
    } on ApiException catch (e) {
      if (e.isRateLimited && e.message.toLowerCase().contains('quota')) {
        throw const GenCreditsUsedUp();
      }
      rethrow;
    }
  }

  void clearRender() => state = state.copyWith(render: const AsyncData(null));
}

final photoshootProvider =
    NotifierProvider<PhotoshootController, PhotoshootState>(
      PhotoshootController.new,
    );

/// Renders saved to the profile "PHOTOS" tab: finished Gen jobs from the
/// library, plus real-look photos kept on this device this session.
class MyPhotosController extends Notifier<List<String>> {
  @override
  List<String> build() => const [];

  void add(String image) {
    if (!state.contains(image)) state = [image, ...state];
  }
}

final myPhotosProvider = NotifierProvider<MyPhotosController, List<String>>(
  MyPhotosController.new,
);

/// Everything for the PHOTOS tab, newest first.
final photosProvider = Provider<List<String>>((ref) {
  final local = ref.watch(myPhotosProvider);
  final gen = ref.watch(libraryProvider).value?.gen ?? const [];
  return [
    ...local,
    for (final g in gen)
      if (g.outputUrl != null && !local.contains(g.outputUrl)) g.outputUrl!,
  ];
});
