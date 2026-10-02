import 'dart:math' as math;
import 'dart:typed_data';

import 'guidance_models.dart';

/// Measures light, focus and shake from a luma (brightness) plane.
///
/// Cheap by design: it samples a coarse grid (~96 columns) instead of touching
/// every pixel, so it can run on live camera frames on a mid-range phone. The
/// same measurements are used for the finished still, so what the guidance says
/// live and what the review says afterwards agree.
class LumaAnalyzer {
  static const columns = 96;

  Float32List? _previous;

  /// Frame-to-frame shake is only known for live frames; a still has none.
  FrameStats analyze(
    Uint8List luma,
    int width,
    int height,
    int rowStride, {
    bool live = false,

    /// The plane is landscape while the screen is portrait (the usual phone
    /// camera), so the screen's left/right runs down the plane's rows.
    bool rotated = false,
  }) {
    final step = math.max(1, width ~/ columns);
    final cols = width ~/ step;
    final rows = height ~/ step;
    if (cols < 4 || rows < 4) {
      return const FrameStats(
        meanLuma: 0.5,
        lightBias: 0,
        highlightClip: 0,
        shadowClip: 0,
        sharpness: 1,
        backgroundBusy: 0,
      );
    }

    final grid = Float32List(cols * rows);
    var sum = 0.0, left = 0.0, right = 0.0;
    var leftN = 0, rightN = 0, hi = 0, lo = 0;
    var fine = 0.0, fineN = 0;

    for (var r = 0; r < rows; r++) {
      final rowBase = r * step * rowStride;
      for (var c = 0; c < cols; c++) {
        final x = c * step;
        final i = rowBase + x;
        final v = luma[i] / 255.0;
        grid[r * cols + c] = v;
        sum += v;
        final sx = rotated ? r / rows : c / cols;
        if (sx < 0.5) {
          left += v;
          leftN++;
        } else {
          right += v;
          rightN++;
        }
        if (v > 0.96) hi++;
        if (v < 0.04) lo++;
        if (x + 1 < width) {
          fine += (luma[i + 1] - luma[i]).abs() / 255.0;
          fineN++;
        }
      }
    }

    final n = cols * rows;
    final mean = sum / n;
    final lMean = leftN == 0 ? mean : left / leftN;
    final rMean = rightN == 0 ? mean : right / rightN;

    // Coarse gradient across the grid, and the same measure over the side
    // margins only (where a busy background shows up around a centred person).
    var coarse = 0.0, coarseN = 0, busy = 0, busyN = 0;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols - 1; c++) {
        final d = (grid[r * cols + c + 1] - grid[r * cols + c]).abs();
        coarse += d;
        coarseN++;
        final sx = rotated ? r / rows : c / cols;
        if (sx < 0.18 || sx > 0.82) {
          busyN++;
          if (d > 0.055) busy++;
        }
      }
    }
    final coarseMean = coarseN == 0 ? 0.0 : coarse / coarseN;
    final fineMean = fineN == 0 ? 0.0 : fine / fineN;
    // A flat scene has no detail to be soft about, so call it neutral.
    final sharpness = coarseMean < 0.012
        ? 1.0
        : (fineMean / (coarseMean * 0.55)).clamp(0.0, 1.5);

    var motion = 0.0;
    final prev = _previous;
    if (live && prev != null && prev.length == grid.length) {
      var d = 0.0;
      for (var i = 0; i < grid.length; i++) {
        d += (grid[i] - prev[i]).abs();
      }
      motion = d / grid.length;
    }
    if (live) _previous = grid;

    return FrameStats(
      meanLuma: mean,
      lightBias: mean < 0.02 ? 0 : ((rMean - lMean) / (mean * 2)).clamp(-1, 1),
      highlightClip: hi / n,
      shadowClip: lo / n,
      sharpness: sharpness,
      backgroundBusy: busyN == 0 ? 0 : busy / busyN,
      motion: motion,
    );
  }

  void reset() => _previous = null;

  /// Converts tightly-packed RGBA to a luma plane (Rec. 601 weights).
  static Uint8List lumaFromRgba(Uint8List rgba, int width, int height) {
    final out = Uint8List(width * height);
    for (var i = 0, p = 0; i < out.length; i++, p += 4) {
      out[i] = (rgba[p] * 77 + rgba[p + 1] * 150 + rgba[p + 2] * 29) >> 8;
    }
    return out;
  }
}
