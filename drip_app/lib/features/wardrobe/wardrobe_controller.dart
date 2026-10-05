import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/wardrobe.dart';
import '../../data/providers.dart';

/// The user's wardrobe. While an upload is being cut out and tagged on the
/// server, the list refreshes itself every few seconds until it settles.
class WardrobeController extends AsyncNotifier<List<WardrobeItem>> {
  static const pollEvery = Duration(seconds: 4);

  /// Stop polling after this long; a pull-to-refresh or revisit picks it up.
  static const pollFor = Duration(minutes: 5);

  /// Upload photos are 1-hour signed URLs: refetch before they expire.
  static const freshFor = Duration(minutes: 45);

  Timer? _poll;
  DateTime? _pollingSince;
  DateTime? _fetchedAt;

  @override
  Future<List<WardrobeItem>> build() async {
    ref.onDispose(() => _poll?.cancel());
    final items = await ref.watch(wardrobeRepositoryProvider).items();
    _fetchedAt = DateTime.now();
    _schedulePoll(items);
    return items;
  }

  /// Refetches if the image links may have expired (call when showing it).
  void refreshIfStale() {
    final at = _fetchedAt;
    if (at != null && DateTime.now().difference(at) > freshFor) _refresh();
  }

  void _schedulePoll(List<WardrobeItem> items) {
    _poll?.cancel();
    if (!items.any((i) => i.isProcessing)) {
      _pollingSince = null;
      return;
    }
    _pollingSince ??= DateTime.now();
    if (DateTime.now().difference(_pollingSince!) > pollFor) return;
    _poll = Timer(pollEvery, _refresh);
  }

  Future<void> _refresh() async {
    try {
      final items = await ref.read(wardrobeRepositoryProvider).items();
      if (!ref.mounted) return;
      _fetchedAt = DateTime.now();
      state = AsyncData(items);
      _schedulePoll(items);
    } catch (_) {
      // Keep what's on screen; try again on the next tick.
      if (ref.mounted) _schedulePoll(state.value ?? const []);
    }
  }

  /// Uploads a garment photo. It appears straight away as "processing".
  Future<WardrobeItem> upload(
    Uint8List bytes, {
    required String contentType,
  }) async {
    final item = await ref
        .read(wardrobeRepositoryProvider)
        .upload(bytes, contentType: contentType);
    final next = [item, ...?state.value];
    state = AsyncData(next);
    _schedulePoll(next);
    return item;
  }

  /// Saves a catalogue garment into the wardrobe (its cut-out and tags come
  /// with it), unless it's already there.
  Future<WardrobeItem> saveGarment(String garmentId) async {
    final have = state.value ?? await future;
    for (final i in have) {
      if (i.garmentId == garmentId) return i;
    }
    final item = await ref
        .read(wardrobeRepositoryProvider)
        .saveGarment(garmentId);
    state = AsyncData([item, ...?state.value]);
    return item;
  }

  /// Corrects an item's category ([slot]) or colour.
  Future<void> retag(String id, {String? slot, String? colour}) async {
    await ref
        .read(wardrobeRepositoryProvider)
        .update(id, slot: slot, colour: colour);
    await _refresh();
  }

  Future<void> remove(String id) async {
    await ref.read(wardrobeRepositoryProvider).remove(id);
    state = AsyncData([
      for (final i in state.value ?? const <WardrobeItem>[])
        if (i.id != id) i,
    ]);
    ref.invalidate(rotationProvider);
  }
}

final wardrobeProvider =
    AsyncNotifierProvider<WardrobeController, List<WardrobeItem>>(
      WardrobeController.new,
    );

final wardrobeItemProvider = Provider.family<WardrobeItem?, String>((ref, id) {
  final list = ref.watch(wardrobeProvider).value;
  if (list == null) return null;
  for (final i in list) {
    if (i.id == id) return i;
  }
  return null;
});

final rotationProvider = FutureProvider<List<String>>(
  (ref) => ref.watch(wardrobeRepositoryProvider).rotationIds(),
);

/// The garment-capture flow: a picked photo, then its upload.
class CaptureState {
  const CaptureState({this.imagePath, this.upload = const AsyncData(null)});
  final String? imagePath;
  final AsyncValue<WardrobeItem?> upload;
}

class CaptureController extends Notifier<CaptureState> {
  @override
  CaptureState build() => const CaptureState();

  void pick(String imagePath) => state = CaptureState(imagePath: imagePath);

  /// Sends the photo. The item then processes in the background.
  Future<WardrobeItem?> send(Uint8List bytes, String contentType) async {
    final path = state.imagePath;
    state = CaptureState(imagePath: path, upload: const AsyncLoading());
    final result = await AsyncValue.guard(
      () => ref
          .read(wardrobeProvider.notifier)
          .upload(bytes, contentType: contentType),
    );
    if (!ref.mounted) return null;
    state = CaptureState(imagePath: path, upload: result);
    return result.value;
  }

  void reset() => state = const CaptureState();
}

final captureProvider =
    NotifierProvider.autoDispose<CaptureController, CaptureState>(
      CaptureController.new,
    );

/// `photo.jpg` → `image/jpeg`. Null for types the API won't take.
String? imageContentType(String path) {
  final ext = path.split('.').last.toLowerCase();
  return switch (ext) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'webp' => 'image/webp',
    _ => null,
  };
}
