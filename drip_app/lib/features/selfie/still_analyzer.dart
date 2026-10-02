import 'dart:typed_data';
import 'dart:ui' as ui;

import 'guidance_models.dart';
import 'luma_analyzer.dart';

/// Measures a finished photo (JPEG/PNG bytes). Returns null when the image
/// can't be decoded, in which case the review falls back to a neutral note.
typedef StillAnalyzer = Future<FrameStats?> Function(Uint8List bytes);

/// Decodes at a small width, since light and focus don't need full resolution
/// and a 12 MP photo shouldn't cost the UI thread a second.
Future<FrameStats?> analyzeStill(Uint8List bytes) async {
  try {
    final codec = await ui.instantiateImageCodec(bytes, targetWidth: 480);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final w = image.width, h = image.height;
    image.dispose();
    codec.dispose();
    if (data == null) return null;
    final luma = LumaAnalyzer.lumaFromRgba(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      w,
      h,
    );
    return LumaAnalyzer().analyze(luma, w, h, w);
  } catch (_) {
    return null;
  }
}
