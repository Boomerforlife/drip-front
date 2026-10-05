import 'package:drip/app.dart';
import 'package:drip/data/mock/mock_content.dart';
import 'package:drip/features/studio/fit_canvas.dart';
import 'package:drip/features/studio/studio_controller.dart';
import 'package:drip/routing/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fakes.dart';
import '../test_fonts.dart';

void main() {
  setUpAll(loadAppFonts);

  late ProviderContainer container;

  Future<void> settle(WidgetTester t, [int ms = 1200]) async {
    for (var i = 0; i < ms ~/ 100; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> openCanvas(WidgetTester t) async {
    SharedPreferences.setMockInitialValues({'session.onboarded': true});
    final sp = await SharedPreferences.getInstance();
    t.view.physicalSize = const Size(390, 844) * 2;
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      ProviderScope(
        overrides: testOverrides(sp, signedIn: true),
        retry: (_, _) => null,
        child: const DripApp(),
      ),
    );
    container = ProviderScope.containerOf(t.element(find.byType(MaterialApp)));
    await settle(t, 3400);
    container.read(routerProvider).go('/studio/builder');
    await settle(t);
  }

  /// Taps the middle of the canvas's top box (where the top sits).
  Future<void> tapTopPiece(WidgetTester t) async {
    final canvas = t.getRect(find.byType(FitCanvas));
    await t.tapAt(
      Offset(
        canvas.left + canvas.width * 0.5,
        canvas.top + canvas.height * 0.3,
      ),
    );
    await settle(t, 600);
  }

  testWidgets('the canvas fills the screen: no piece tray under it', (t) async {
    await openCanvas(t);
    expect(find.text('DRIP CATALOGUE'), findsNothing);
    expect(find.text('+ ADD'), findsOneWidget);
    expect(find.text('EXTRAS'), findsOneWidget);
  });

  testWidgets('a + box opens the picker; PUT ON CANVAS wears the piece', (
    t,
  ) async {
    await openCanvas(t);
    await t.tap(find.text('TOP'));
    await settle(t);
    expect(find.text('ADD TOPS'), findsOneWidget);
    expect(find.byType(PageView), findsOneWidget);

    await t.tap(find.text('PUT ON CANVAS'));
    await settle(t);
    final top = container.read(studioProvider).worn['TOPS'];
    expect(top, isNotNull);
    expect(top!.category, 'TOPS');
    expect(find.text('ADD TOPS'), findsNothing, reason: 'the sheet closes');
  });

  testWidgets('tapping a piece shows the side bar: resize, then take off', (
    t,
  ) async {
    await openCanvas(t);
    final hoodie = MockContent.studioPieces.firstWhere(
      (p) => p.id == 'sp_hoodie',
    );
    container.read(studioProvider.notifier)
      ..setCategory('TOPS')
      ..select(hoodie);
    await settle(t, 600);

    await tapTopPiece(t);
    expect(find.byType(Slider), findsOneWidget);

    await t.drag(find.byType(Slider), const Offset(0, -80));
    await settle(t, 400);
    expect(container.read(studioProvider).placed['TOPS'], isNotNull);

    await t.tap(find.byIcon(Icons.delete_outline_rounded));
    await settle(t, 600);
    expect(container.read(studioProvider).worn, isEmpty);
    expect(find.byType(Slider), findsNothing);
  });

  testWidgets('swap from the side bar replaces the piece in place', (t) async {
    await openCanvas(t);
    final hoodie = MockContent.studioPieces.firstWhere(
      (p) => p.id == 'sp_hoodie',
    );
    container.read(studioProvider.notifier)
      ..setCategory('TOPS')
      ..select(hoodie);
    await settle(t, 600);

    await tapTopPiece(t);
    await t.tap(find.byIcon(Icons.swap_horiz_rounded));
    await settle(t);
    expect(find.text('SWAP TOPS'), findsOneWidget);
    // It opens on the worn piece; swipe to another.
    expect(find.text('TAKE OFF'), findsOneWidget);
    await t.drag(find.byType(PageView), const Offset(-240, 0));
    await settle(t);
    await t.tap(find.text('SWAP IN'));
    await settle(t);

    final worn = container.read(studioProvider).worn;
    expect(worn.keys, ['TOPS']);
    expect(worn['TOPS']!.id, isNot('sp_hoodie'));
  });
}
