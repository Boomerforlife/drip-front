import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/providers.dart';

/// The selfie from onboarding: **local media, not profile data**.
///
/// It lives as a file on this device (the path is kept in `LocalStore`, the
/// bytes in memory while shown) and is used only here: on the user's ticket
/// and pass. It is never uploaded, never sent to the account, never handed
/// to Gen. The Selfie Coordinator (`/selfie`), which uploads a photo for Gen
/// photoshoots, is a separate, explicit action with its own consent.
///
/// Removing it (or logging out) deletes the file.
class LocalSelfie extends AsyncNotifier<Uint8List?> {
  @override
  Future<Uint8List?> build() async {
    final path = ref.watch(localStoreProvider).selfiePath;
    if (path == null) return null;
    try {
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
    final old = ref.read(localStoreProvider).selfiePath;
    await ref.read(localStoreProvider).setSelfiePath(file.path);
    if (old != null && old != file.path) deleteFile(old);
    state = AsyncData(bytes);
    return true;
  }

  /// Forgets the selfie and deletes its file.
  Future<void> remove() async {
    final path = ref.read(localStoreProvider).selfiePath;
    await ref.read(localStoreProvider).setSelfiePath(null);
    if (path != null) deleteFile(path);
    state = const AsyncData(null);
  }

  /// Deletes a selfie file (best effort).
  static void deleteFile(String path) {
    if (kIsWeb) return;
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
