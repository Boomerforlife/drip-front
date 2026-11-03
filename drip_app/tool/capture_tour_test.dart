// Dev tool: a screenshot of every step of the first-run tour.
//
//   flutter test tool/capture_tour_test.dart --dart-define=OUT=C:/dir
import 'dart:io';
import 'dart:ui' as ui;

import 'package:drip/app.dart';
import 'package:drip/features/tour/tour.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/support/fakes.dart';
import '../test/test_fonts.dart';

const _out = String.fromEnvironment('OUT', defaultValue: 'build/shots/tour');
final _key = GlobalKey();

Future<void> _settle(WidgetTester t, {int ms = 900}) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _shot(WidgetTester t, String name) async {
  await t.runAsync(() async {
    final b = _key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await b.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final f = File('$_out/$name.png');
    await f.create(recursive: true);
    await f.writeAsBytes(data!.buffer.asUint8List());
  });
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets('tour steps', (t) async {
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({'session.onboarded': true});
    final sp = await SharedPreferences.getInstance();
    t.view.physicalSize = const Size(390, 844) * 2;
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      RepaintBoundary(
        key: _key,
        child: ProviderScope(
          overrides: testOverrides(sp, signedIn: true),
          retry: (_, _) => null,
          child: const DripApp(),
        ),
      ),
    );
    final c = ProviderScope.containerOf(t.element(find.byType(MaterialApp)));
    await _settle(t, ms: 3000);
    final tour = c.read(tourProvider.notifier)..start();
    for (var i = 0; i < tourSteps.length; i++) {
      // Long enough for the tab to change and the pen to finish drawing.
      await _settle(t, ms: 2000);
      await _shot(t, i.toString().padLeft(2, '0'));
      tour.next();
    }
  });
}
