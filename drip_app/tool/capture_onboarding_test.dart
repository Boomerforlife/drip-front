// Dev tool: screenshots of every onboarding step and the new Home.
//
//   flutter test tool/capture_onboarding_test.dart --dart-define=OUT=C:/dir
import 'dart:io';
import 'dart:ui' as ui;

import 'package:drip/app.dart';
import 'package:drip/core/widgets/tap.dart';
import 'package:drip/features/onboarding/onboarding_data.dart';
import 'package:drip/features/session/session_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/support/fakes.dart';
import '../test/test_fonts.dart';

const _out = String.fromEnvironment('OUT', defaultValue: 'build/shots');
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

Future<void> _tap(WidgetTester t, String text) async {
  final f = find.text(text);
  await t.ensureVisible(f.first);
  await t.pump();
  await t.tap(f.first, warnIfMissed: false);
  await _settle(t, ms: 700);
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets('onboarding steps', (t) async {
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    final sp = await SharedPreferences.getInstance();
    t.view.physicalSize = const Size(390, 844) * 2;
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      RepaintBoundary(
        key: _key,
        child: ProviderScope(
          overrides: testOverrides(sp),
          retry: (_, _) => null,
          child: const DripApp(),
        ),
      ),
    );
    final c = ProviderScope.containerOf(t.element(find.byType(MaterialApp)));
    await _settle(t, ms: 3200);
    var n = 0;
    Future<void> snap(String name, {int ms = 2400}) async {
      await _settle(t, ms: ms);
      await _shot(t, 'ob_${(n++).toString().padLeft(2, '0')}_$name');
    }

    await snap('welcome');
    await _tap(t, 'GET STARTED →');
    await snap('statement', ms: 3000);
    await _tap(t, 'HELP ME →');
    await snap('intro');
    await _tap(t, 'UNDERSTOOD. NEXT →');
    final o = c.read(onboardingProvider.notifier);
    o.toggleMood('y2k');
    o.toggleMood('minimal');
    o.toggleGenre('Gorpcore');
    await snap('eras');
    await t.drag(find.byType(SingleChildScrollView).last, const Offset(0, -700));
    await snap('genres', ms: 1200);
    await _tap(t, 'LOCK IN 3 VIBES →');
    o.togglePalette('cream');
    o.togglePalette('cobalt');
    o.togglePalette('blush');
    await snap('colours');
    await _tap(t, 'CALIBRATE SPECTRUM →');
    o.toggleCloth('Hoodies');
    o.toggleCloth('Cargos');
    await snap('clothes');
    await _tap(t, 'SAVE 2 PIECES →');
    o.toggleAccessory('Chains');
    await snap('accessories');
    await _tap(t, 'STACK 1 →');
    o.toggleBrand('Snitch');
    await snap('brands');
    await _tap(t, 'SAVE 1 LABELS →');
    await snap('fit');
    await _tap(t, 'BUILD MY DRIP →');
    o.setName('Taylor');
    await snap('name');
    await _tap(t, 'PRINT MY TICKET →');
    await snap('build', ms: 1800);
    await snap('ticket', ms: 4500);
    await _tap(t, 'CLAIM YOUR TICKET →');
    await snap('join');
    expect(find.byType(Tap), findsWidgets);
    expect(OnboardingData.eras.length, 7);
  });

  testWidgets('home', (t) async {
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
    await _settle(t, ms: 3500);
    await _shot(t, 'home_new');
  });
}
