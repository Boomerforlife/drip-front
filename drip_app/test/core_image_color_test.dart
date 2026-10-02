import 'dart:ui' as ui;

import 'package:drip/core/utils/image_color.dart';
import 'package:flutter_test/flutter_test.dart';

Future<ui.Image> _paint(
  int w,
  int h,
  void Function(ui.Canvas canvas, ui.Size size) draw,
) async {
  final rec = ui.PictureRecorder();
  draw(ui.Canvas(rec), ui.Size(w.toDouble(), h.toDouble()));
  return rec.endRecording().toImage(w, h);
}

void main() {
  testWidgets('reads the background, ignoring what is in the middle', (
    t,
  ) async {
    final c = await t.runAsync(() async {
      final img = await _paint(200, 300, (canvas, size) {
        canvas.drawRect(
          ui.Offset.zero & size,
          ui.Paint()..color = const ui.Color(0xFFF2EBDD),
        );
        canvas.drawRect(
          const ui.Rect.fromLTWH(50, 80, 100, 140),
          ui.Paint()..color = const ui.Color(0xFFFF0000),
        );
      });
      return edgeColor(img);
    });
    expect(c, const ui.Color(0xFFF2EBDD));
  });

  testWidgets('a garment touching one edge does not tint it', (t) async {
    final c = await t.runAsync(() async {
      final img = await _paint(200, 300, (canvas, size) {
        canvas.drawRect(
          ui.Offset.zero & size,
          ui.Paint()..color = const ui.Color(0xFF101820),
        );
        // A sleeve running off the left edge.
        canvas.drawRect(
          const ui.Rect.fromLTWH(0, 100, 60, 40),
          ui.Paint()..color = const ui.Color(0xFFFFFFFF),
        );
      });
      return edgeColor(img);
    });
    expect(c, const ui.Color(0xFF101820));
  });

  testWidgets('a transparent cut-out has no background to match', (t) async {
    final c = await t.runAsync(() async {
      final img = await _paint(100, 100, (canvas, size) {
        canvas.drawRect(
          const ui.Rect.fromLTWH(30, 30, 40, 40),
          ui.Paint()..color = const ui.Color(0xFFFF0000),
        );
      });
      return edgeColor(img);
    });
    expect(c, isNull);
  });
}
