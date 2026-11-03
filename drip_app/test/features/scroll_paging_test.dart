import 'package:drip/app.dart';
import 'package:drip/features/scroll/fashion_scroll_screen.dart';
import 'package:drip/routing/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fakes.dart';
import '../test_fonts.dart';

/// One swipe, one fit: the Scroll turns the page on any deliberate swipe (a
/// relaxed drag of an eighth of the screen, a short flick, a thumb's arc)
/// and never needs a second go.
void main() {
  setUpAll(loadAppFonts);

  late ProviderContainer container;

  Future<void> settle(WidgetTester t, [int ms = 900]) async {
    for (var i = 0; i < ms ~/ 100; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  double page(WidgetTester t) =>
      t.widget<PageView>(find.byType(PageView)).controller!.page!;

  Future<void> openScroll(WidgetTester t) async {
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
    await settle(t, 1600);
    container.read(routerProvider).go('/scroll');
    await settle(t, 1200);
    expect(find.byType(FashionScrollScreen), findsOneWidget);
    expect(page(t), 0);
  }

  /// A drag along [steps], then the finger rests before lifting (no fling).
  Future<void> slowDrag(WidgetTester t, List<Offset> steps) async {
    final g = await t.startGesture(const Offset(195, 500));
    for (final s in steps) {
      await g.moveBy(s);
      await t.pump(const Duration(milliseconds: 16));
    }
    await t.pump(const Duration(milliseconds: 200));
    await g.up();
    await settle(t);
  }

  testWidgets('a relaxed drag of an eighth of the screen turns the page', (
    t,
  ) async {
    await openScroll(t);
    await slowDrag(t, List.filled(12, const Offset(0, -10))); // ~100 of 844
    expect(page(t), 1);
  });

  testWidgets('a nudge that barely moves springs back', (t) async {
    await openScroll(t);
    await slowDrag(t, List.filled(5, const Offset(0, -10))); // 50 of 844
    expect(page(t), 0);
  });

  testWidgets('a short quick flick turns it, and back down returns', (t) async {
    await openScroll(t);
    await t.flingFrom(const Offset(195, 500), const Offset(0, -60), 900);
    await settle(t);
    expect(page(t), 1);
    await t.flingFrom(const Offset(195, 500), const Offset(0, 60), 900);
    await settle(t);
    expect(page(t), 0);
  });

  testWidgets('a hard flick moves one fit, never two', (t) async {
    await openScroll(t);
    await t.flingFrom(const Offset(195, 700), const Offset(0, -600), 6000);
    await settle(t);
    expect(page(t), 1);
  });

  testWidgets("a thumb's arcing swipe up pages the feed, not the tabs", (
    t,
  ) async {
    await openScroll(t);
    // Sideways past the touch slop before it's past it upwards (which a
    // plain horizontal recognizer takes as a tab swipe), then up.
    await slowDrag(t, const [
      Offset(10, -6),
      Offset(10, -8),
      Offset(4, -10),
      Offset(2, -30),
      Offset(0, -40),
      Offset(0, -30),
    ]);
    expect(page(t), 1);
    expect(
      container
          .read(routerProvider)
          .routerDelegate
          .currentConfiguration
          .uri
          .path,
      '/scroll',
    );
  });
}
