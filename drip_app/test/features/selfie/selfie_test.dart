import 'dart:typed_data';

import 'package:drip/features/selfie/guidance_engine.dart';
import 'package:drip/features/selfie/guidance_models.dart';
import 'package:drip/features/selfie/luma_analyzer.dart';
import 'package:drip/features/selfie/selfie_controller.dart';
import 'package:drip/features/selfie/selfie_intent.dart';
import 'package:drip/features/selfie/shot_review.dart';
import 'package:drip/features/selfie/selfie_camera.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const good = FrameStats(
  meanLuma: 0.5, lightBias: 0, highlightClip: 0, shadowClip: 0,
  sharpness: 1, backgroundBusy: 0,
);
const dark = FrameStats(
  meanLuma: 0.1, lightBias: 0, highlightClip: 0, shadowClip: 0.5,
  sharpness: 1, backgroundBusy: 0,
);
FaceGeometry face({double top = 0.15, double h = 0.36, double cx = 0.5}) =>
    FaceGeometry(box: Rect.fromLTWH(cx - 0.15, top, 0.3, h));

void main() {
  final t0 = DateTime(2026);
  DateTime at(int ms) => t0.add(Duration(milliseconds: ms));

  group('guidance engine', () {
    test('opens with the setup tip, then says nothing wrong when all is well', () {
      final e = PhotographerGuidanceEngine(intent: SelfieIntent.instagram);
      expect(e.update(const FrameObservation(good), at(0))!.tone,
          GuidanceTone.setup);
      e.update(const FrameObservation(good), at(2500));
      final g = e.update(const FrameObservation(good), at(3200));
      expect(g!.tone, GuidanceTone.good);
      expect(g.text, contains('Hold there'));
      expect(e.ready, isTrue);
    });

    test('a brief glitch does not change the line; a persistent issue does', () {
      final e = PhotographerGuidanceEngine(intent: SelfieIntent.instagram);
      e.update(const FrameObservation(good), at(0));
      e.update(const FrameObservation(good), at(2500));
      e.update(const FrameObservation(good), at(3200));
      // 300ms of darkness: still the old line.
      var g = e.update(const FrameObservation(dark), at(3300));
      expect(g?.tone == GuidanceTone.adjust, isFalse);
      g = e.update(const FrameObservation(dark), at(3600));
      g = e.update(const FrameObservation(dark), at(4100));
      expect(g!.text, 'Find a little more light.');
      expect(e.ready, isFalse);
    });

    test('face geometry gives photographer-style framing advice', () {
      final e = PhotographerGuidanceEngine(intent: SelfieIntent.instagram);
      Guidance? g;
      for (var ms = 0; ms <= 4000; ms += 250) {
        g = e.update(FrameObservation(good, face: face(top: 0.01)), at(ms));
      }
      expect(g!.text, 'Bring the camera slightly higher.');
      for (var ms = 4000; ms <= 8000; ms += 250) {
        g = e.update(FrameObservation(good, face: face(h: 0.7)), at(ms));
      }
      expect(g!.text, 'Move back a little.');
    });

    test('guidance clears once achieved and pose tips follow, then pause', () {
      final e = PhotographerGuidanceEngine(intent: SelfieIntent.dating);
      final seen = <String?>[];
      for (var ms = 0; ms <= 12000; ms += 250) {
        seen.add(e.update(FrameObservation(good, face: face()), at(ms))?.text);
      }
      expect(seen, contains('Perfect. Hold there.'));
      expect(seen, contains(SelfieIntent.dating.poseTips.first));
      expect(seen, contains(null)); // quiet gaps
    });
  });

  group('luma analyzer', () {
    test('measures brightness, light side and flat focus', () {
      final y = Uint8List(200 * 100);
      for (var r = 0; r < 100; r++) {
        for (var c = 0; c < 200; c++) {
          y[r * 200 + c] = c >= 100 ? 220 : 60;
        }
      }
      final s = LumaAnalyzer().analyze(y, 200, 100, 200);
      expect(s.meanLuma, closeTo(0.55, 0.03));
      expect(s.lightBias, greaterThan(0.3));
    });
  });

  group('shot review', () {
    test('never comments on appearance and prefers the better composition', () {
      final a = reviewShot(dark);
      final b = reviewShot(good);
      expect(a.notes.join(' '), contains('dark'));
      expect(bestShotIndex([a, b]), 1);
      expect(
        reviewShot(good, face: face(top: 0.01)).notes.join(' '),
        contains('too close to the top edge'),
      );
    });
  });

  group('session controller', () {
    ProviderContainer make() => ProviderContainer(overrides: [
          selfieStillAnalyzerProvider.overrideWithValue((_) async => good),
        ]);

    test('shots, review, retake and another angle', () async {
      final c = make();
      addTearDown(c.dispose);
      final sub = c.listen(selfieProvider, (_, _) {});
      final n = c.read(selfieProvider.notifier);
      n.chooseIntent(SelfieIntent.fashion);
      expect(sub.read().step, SelfieStep.camera);
      await n.addShot(Uint8List(4));
      await n.addShot(Uint8List(4));
      n.showReview();
      expect(sub.read().step, SelfieStep.review);
      n.retake();
      expect(sub.read().shots.length, 1);
      expect(sub.read().step, SelfieStep.camera);
      n.anotherAngle();
      expect(sub.read().angleTip, isNotNull);
      expect(sub.read().shots.length, 1);
    });
  });
}
