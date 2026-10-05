import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/providers.dart';

/// The user's selfie in use: **local media, not profile data**.
///
/// Every selfie lives as a file on this device, in the app's own folder
/// (which the OS doesn't clear like the camera's cache), and is never
/// uploaded: not to the account, not to Gen. Each one saved stays in
/// [SelfieGallery]; the one in use (its path kept in `LocalStore`, the bytes
/// in memory while shown) is the newest unless the user picks another. The
/// Selfie Coordinator (`/selfie`) and the Studio shot write here. Since
/// 2026-10-05 the backend no longer accepts selfies at all; Gen will be
/// reworked to use them on the device. Logging out deletes them all.
class LocalSelfie extends AsyncNotifier<Uint8List?> {
  @override
  Future<Uint8List?> build() async {
    final path = ref.watch(localStoreProvider).selfiePath;
    if (path == null) return null;
    try {
      if (path.startsWith('data:')) return UriData.parse(path).contentAsBytes();
      return await XFile(path).readAsBytes();
    } catch (_) {
      // The OS cleared it (a cache file): forget it quietly.
      await ref.read(localStoreProvider).setSelfiePath(null);
      return null;
    }
  }

  /// Opens the camera (front-facing) or the gallery. Returns false when the
  /// user cancelled; throws [SelfieUnavailable] when the source can't open.
  Future<bool> pick(ImageSource source) async {
    final XFile? file;
    try {
      file = await ref.read(selfiePickerProvider)(source);
    } on PlatformException catch (e) {
      throw SelfieUnavailable(source, e.code);
    }
    if (file == null) return false;
    final bytes = await file.readAsBytes();
    await _store(bytes, from: file.path);
    return true;
  }

  /// Keeps a photo taken in the app (the Selfie Coordinator's camera) as the
  /// selfie in use, and in the gallery. Stays on the device.
  Future<void> save(Uint8List bytes, {String contentType = 'image/jpeg'}) =>
      _store(bytes, ext: contentType == 'image/png' ? 'png' : 'jpg');

  Future<void> _store(
    Uint8List bytes, {
    String? from,
    String ext = 'jpg',
  }) async {
    final dir = await ref.read(selfieFolderProvider)();
    final String path;
    if (dir != null) {
      final f = File(
        '$dir${Platform.pathSeparator}selfie_${DateTime.now().millisecondsSinceEpoch}.$ext',
      );
      await f.writeAsBytes(bytes, flush: true);
      path = f.path;
    } else {
      // No app folder (web, tests): keep the picker's file, or the bytes.
      path =
          from ??
          UriData.fromBytes(
            bytes,
            mimeType: ext == 'png' ? 'image/png' : 'image/jpeg',
          ).toString();
    }
    // The one it replaces stays in the gallery.
    await ref.read(localStoreProvider).setSelfiePath(path);
    state = AsyncData(bytes);
    ref.invalidate(selfieGalleryProvider);
  }

  /// Makes a selfie from the gallery the one in use.
  Future<void> use(String path) async {
    await ref.read(localStoreProvider).setSelfiePath(path);
    ref.invalidateSelf();
  }

  /// Stops using a selfie (its file stays in the gallery).
  Future<void> clear() async {
    await ref.read(localStoreProvider).setSelfiePath(null);
    state = const AsyncData(null);
  }

  /// Forgets the selfie in use and deletes its file.
  Future<void> remove() async {
    final path = ref.read(localStoreProvider).selfiePath;
    await clear();
    if (path != null) deleteFile(path);
    ref.invalidate(selfieGalleryProvider);
  }

  /// Deletes a selfie file (best effort).
  static void deleteFile(String path) {
    if (kIsWeb || path.startsWith('data:')) return;
    try {
      final f = File(path);
      if (f.existsSync()) f.deleteSync();
    } catch (_) {
      // Already gone, or not ours to delete: either way, nothing to keep.
    }
  }
}

final localSelfieProvider = AsyncNotifierProvider<LocalSelfie, Uint8List?>(
  LocalSelfie.new,
);

/// Every selfie kept on this phone, newest first: the files in the selfie
/// folder (where there's no folder, just the one in use). Paths are file
/// paths, or `data:` URIs on web and in tests.
class SelfieGallery extends AsyncNotifier<List<String>> {
  @override
  Future<List<String>> build() async {
    final inUse = ref.watch(localStoreProvider).selfiePath;
    final dir = await ref.read(selfieFolderProvider)();
    if (dir == null) return [?inUse];
    try {
      final files = await Directory(dir)
          .list()
          .where((e) => e is File && _isSelfie(e.path))
          .map((e) => e.path)
          .toList();
      // Named by the time they were taken: newest first.
      files.sort((a, b) => b.compareTo(a));
      return files;
    } catch (_) {
      return [?inUse];
    }
  }

  static bool _isSelfie(String path) {
    final name = path.split(Platform.pathSeparator).last;
    return name.startsWith('selfie_') &&
        (name.endsWith('.jpg') || name.endsWith('.png'));
  }

  /// Deletes one selfie. If it was in use, the newest one left takes over.
  Future<void> delete(String path) async {
    final store = ref.read(localStoreProvider);
    LocalSelfie.deleteFile(path);
    final left = [
      for (final p in state.value ?? const <String>[])
        if (p != path) p,
    ];
    state = AsyncData(left);
    if (store.selfiePath == path) {
      if (left.isEmpty) {
        await ref.read(localSelfieProvider.notifier).clear();
      } else {
        await ref.read(localSelfieProvider.notifier).use(left.first);
      }
    }
  }

  /// Deletes them all (logging out).
  Future<void> deleteAll() async {
    final dir = await ref.read(selfieFolderProvider)();
    final inUse = ref.read(localStoreProvider).selfiePath;
    if (inUse != null) LocalSelfie.deleteFile(inUse);
    if (dir != null) {
      try {
        await Directory(dir).delete(recursive: true);
      } catch (_) {
        // Already gone.
      }
    }
    await ref.read(localStoreProvider).setSelfiePath(null);
    ref.invalidate(localSelfieProvider);
    ref.invalidateSelf();
  }
}

final selfieGalleryProvider =
    AsyncNotifierProvider<SelfieGallery, List<String>>(SelfieGallery.new);

/// The folder selfies are copied into, or null to keep them where they were
/// picked (web has no app folder; tests replace it).
final selfieFolderProvider = Provider<Future<String?> Function()>(
  (ref) => () async {
    if (kIsWeb) return null;
    try {
      final dir = Directory(
        '${(await getApplicationSupportDirectory()).path}/selfie',
      );
      await dir.create(recursive: true);
      return dir.path;
    } catch (_) {
      return null;
    }
  },
);

/// Camera or gallery, as one call (tests replace it). A reasonably small,
/// front-camera image: it's shown on a ticket, not printed.
typedef SelfiePicker = Future<XFile?> Function(ImageSource source);

final selfiePickerProvider = Provider<SelfiePicker>(
  (ref) =>
      (source) => ImagePicker().pickImage(
        source: source,
        preferredCameraDevice: CameraDevice.front,
        maxWidth: 1080,
        imageQuality: 85,
      ),
);

/// The camera or gallery couldn't open (permission denied, no camera…).
class SelfieUnavailable implements Exception {
  const SelfieUnavailable(this.source, this.code);
  final ImageSource source;
  final String code;

  /// What to tell the user, and what to try instead.
  String get message => source == ImageSource.camera
      ? 'Drip can’t open the camera. Allow it in Settings, or choose from '
            'your gallery'
      : 'Drip can’t open your photos. Allow access in Settings, or take one '
            'now';
}
