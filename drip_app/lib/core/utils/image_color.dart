import 'dart:math' as math;
import 'dart:ui' as ui;

/// The colour of a picture's background, read from its border: the median of
/// pixels sampled all the way round the edge, so a garment touching one side
/// doesn't tint the result. Null when the border is mostly transparent (a
/// cut-out), where there is no background to match.
///
/// The picture is first shrunk to a small thumbnail, so this stays cheap on
/// full-resolution photos.
Future<ui.Color?> edgeColor(ui.Image image, {int samples = 24}) async {
  if (image.width < 2 || image.height < 2) return null;
  const longest = 64.0;
  final scale = math.min(1.0, longest / math.max(image.width, image.height));
  final w = math.max(2, (image.width * scale).round());
  final h = math.max(2, (image.height * scale).round());

  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawImageRect(
    image,
    ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
    ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    ui.Paint()..filterQuality = ui.FilterQuality.medium,
  );
  final thumb = await recorder.endRecording().toImage(w, h);
  final data = await thumb.toByteData(format: ui.ImageByteFormat.rawRgba);
  thumb.dispose();
  if (data == null) return null;

  final r = <int>[];
  final g = <int>[];
  final b = <int>[];
  void at(int x, int y) {
    final i = (y * w + x) * 4;
    if (data.getUint8(i + 3) < 200) return; // see-through: not a background
    r.add(data.getUint8(i));
    g.add(data.getUint8(i + 1));
    b.add(data.getUint8(i + 2));
  }

  for (var k = 0; k < samples; k++) {
    final t = k / (samples - 1);
    final x = (t * (w - 1)).round();
    final y = (t * (h - 1)).round();
    at(x, 0);
    at(x, h - 1);
    at(0, y);
    at(w - 1, y);
  }
  if (r.length < samples * 2) return null; // under half the border is opaque

  int median(List<int> v) => (v..sort())[v.length ~/ 2];
  return ui.Color.fromARGB(255, median(r), median(g), median(b));
}
