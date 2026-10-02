import 'dart:typed_data';
import 'dart:ui' show Rect;

/// Photographic measurements of one frame (live preview or a finished still).
/// Nothing in here describes the person, only light, focus and framing.
class FrameStats {
  const FrameStats({
    required this.meanLuma,
    required this.lightBias,
    required this.highlightClip,
    required this.shadowClip,
    required this.sharpness,
    required this.backgroundBusy,
    this.motion = 0,
  });

  /// Average brightness, 0 (black) … 1 (white).
  final double meanLuma;

  /// −1 … 1. Positive: the right half of the frame is brighter than the left.
  final double lightBias;

  /// Share of the frame that is blown out, 0 … 1.
  final double highlightClip;

  /// Share of the frame that is crushed to black, 0 … 1.
  final double shadowClip;

  /// Fine detail relative to coarse detail. Roughly 1 is crisp, near 0 is soft.
  final double sharpness;

  /// Share of the side margins that carry strong detail, 0 … 1.
  final double backgroundBusy;

  /// Frame-to-frame change, 0 … 1 (live frames only). High means shake.
  final double motion;
}

/// Where the head sits in the frame, when a face detector is plugged in.
///
/// Coordinates follow the picture as displayed. [yawDeg] is positive when the
/// face is turned toward the right side of the screen.
class FaceGeometry {
  const FaceGeometry({
    required this.box,
    this.rollDeg = 0,
    this.yawDeg = 0,
  });

  /// Face bounding box, normalised to 0 … 1 of the frame.
  final Rect box;
  final double rollDeg;
  final double yawDeg;

  double get headroom => box.top;
  double get faceHeight => box.height;
  double get centerX => box.center.dx;
}

/// One analysed frame handed to the guidance engine.
class FrameObservation {
  const FrameObservation(this.stats, {this.face});
  final FrameStats stats;

  /// Null when no detector is installed or no face was found.
  final FaceGeometry? face;
}

/// A raw luma (Y) plane from the camera stream, free of plugin types so the
/// analysis stays plain Dart.
class SelfieFrame {
  const SelfieFrame({
    required this.luma,
    required this.width,
    required this.height,
    required this.rowStride,
    this.raw,
  });
  final Uint8List luma;
  final int width;
  final int height;
  final int rowStride;

  /// The original platform frame, for a face detector that needs every plane.
  final Object? raw;
}

enum GuidanceTone {
  /// The opening tip before live guidance starts.
  setup,

  /// A small correction ("Move back a little.").
  adjust,

  /// Confirmation ("Perfect. Hold there.").
  good,

  /// A pose idea once the framing is right.
  pose,
}

/// One short, human line to show the user.
class Guidance {
  const Guidance(this.id, this.text, this.tone);
  final String id;
  final String text;
  final GuidanceTone tone;
}
