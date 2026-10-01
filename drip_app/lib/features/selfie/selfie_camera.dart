import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'guidance_engine.dart';
import 'guidance_models.dart';
import 'selfie_intent.dart';
import 'still_analyzer.dart';

/// How a camera start-up ended. Everything except [ready] sends the user to the
/// photo-upload fallback.
enum CameraOutcome {
  ready,

  /// The user (or the OS) refused camera access.
  denied,

  /// No camera, an unsupported platform, or the camera failed to start.
  unavailable,
}

/// The live camera, as the coordinator sees it. The UI never touches the
/// `camera` plugin directly, so tests can stand in a fake and a different
/// camera stack could replace this.
abstract interface class SelfieCameraService {
  Future<CameraOutcome> start();

  /// The live preview, uncropped. The stage sizes and crops it.
  Widget buildPreview();

  /// Preview width ÷ height in portrait (for example 0.75).
  double get previewAspect;

  /// Throttled luma frames, for the guidance engine.
  Stream<SelfieFrame> get frames;

  /// True when [SelfieFrame.luma] is landscape while the screen is portrait.
  bool get framesRotated;

  /// Takes a still and returns JPEG bytes.
  Future<Uint8List> capture();

  /// Releases the camera (app backgrounded). [start] brings it back.
  Future<void> suspend();

  Future<void> dispose();
}

typedef SelfieCameraFactory = SelfieCameraService Function();

final selfieCameraFactoryProvider = Provider<SelfieCameraFactory>(
  (ref) => DeviceSelfieCamera.new,
);

final selfieStillAnalyzerProvider = Provider<StillAnalyzer>(
  (ref) => analyzeStill,
);

/// Where guidance comes from. Replace this with an engine backed by a face
/// detector to get face-aware framing without touching the UI.
final selfieEngineFactoryProvider = Provider<GuidanceEngineFactory>(
  (ref) =>
      (SelfieIntent intent, {String? setupTip}) =>
          PhotographerGuidanceEngine(intent: intent, setupTip: setupTip),
);

/// The real camera: front lens, Android and iOS only. Web and desktop report
/// [CameraOutcome.unavailable] so they use the photo-upload path instead.
class DeviceSelfieCamera implements SelfieCameraService {
  static const _frameGap = Duration(milliseconds: 220);

  CameraController? _controller;
  final _frames = StreamController<SelfieFrame>.broadcast(sync: true);
  DateTime _lastFrame = DateTime.fromMillisecondsSinceEpoch(0);
  bool _disposed = false;

  static bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Stream<SelfieFrame> get frames => _frames.stream;

  @override
  bool get framesRotated => true;

  @override
  double get previewAspect {
    final a = _controller?.value.aspectRatio ?? (4 / 3);
    return a > 1 ? 1 / a : a;
  }

  @override
  Future<CameraOutcome> start() async {
    if (!_supported) return CameraOutcome.unavailable;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return CameraOutcome.unavailable;
      final lens = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        lens,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await controller.initialize();
      if (_disposed) {
        await controller.dispose();
        return CameraOutcome.unavailable;
      }
      _controller = controller;
      await _startStream();
      return CameraOutcome.ready;
    } on CameraException catch (e) {
      return _denied(e.code) ? CameraOutcome.denied : CameraOutcome.unavailable;
    } catch (_) {
      return CameraOutcome.unavailable;
    }
  }

  static bool _denied(String code) =>
      code == 'CameraAccessDenied' ||
      code == 'CameraAccessDeniedWithoutPrompt' ||
      code == 'CameraAccessRestricted' ||
      code == 'cameraPermission';

  Future<void> _startStream() async {
    final c = _controller;
    if (c == null || c.value.isStreamingImages) return;
    try {
      await c.startImageStream((image) {
        final now = DateTime.now();
        if (now.difference(_lastFrame) < _frameGap || _frames.isClosed) return;
        _lastFrame = now;
        final y = image.planes.first;
        _frames.add(
          SelfieFrame(
            luma: y.bytes,
            width: image.width,
            height: image.height,
            rowStride: y.bytesPerRow,
            raw: image,
          ),
        );
      });
    } catch (_) {
      // No frame stream on this device: capture still works, with no live
      // light guidance.
    }
  }

  @override
  Widget buildPreview() {
    final c = _controller;
    return c == null ? const SizedBox.shrink() : CameraPreview(c);
  }

  @override
  Future<Uint8List> capture() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) {
      throw StateError('Camera not ready');
    }
    // Some devices fail to take a still while the analysis stream is running.
    if (c.value.isStreamingImages) await c.stopImageStream();
    try {
      final file = await c.takePicture();
      return await file.readAsBytes();
    } finally {
      if (!_disposed) await _startStream();
    }
  }

  @override
  Future<void> suspend() async {
    final c = _controller;
    _controller = null;
    await c?.dispose();
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    await suspend();
    await _frames.close();
  }
}
