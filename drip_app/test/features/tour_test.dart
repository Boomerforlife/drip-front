import 'package:drip/app.dart';
import 'package:drip/features/scroll/fashion_scroll_screen.dart';
import 'package:drip/features/studio/studio_home_screen.dart';
import 'package:drip/features/tour/tour.dart';
import 'package:drip/features/tour/tour_overlay.dart';
import 'package:drip/routing/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fakes.dart';
import '../test_fonts.dart';

/// The first-run tour: it starts once by itself on Home, walks the tabs with
/// a spotlight on each feature, ends with what's coming after the beta, and
/// can be replayed from Settings.
void main() {
  setUpAll(loadAppFonts);

  late ProviderContainer container;
  late SharedPreferences prefs;

  /// Text on the tour's card (Home has a "SHOP BY OCCASION" of its own).
  Finder onCard(String text) =>
      find.descendant(of: find.byType(TourOverlay), matching: find.text(text));

  Future<void> settle(WidgetTester t, [int ms = 1000]) async {
    for (var i = 0; i < ms ~/ 100; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> boot(
    WidgetTester t, {
    bool seen = false,
    bool autoStart = true,
  }) async {
    SharedPreferences.setMockInitialValues({
      'session.onboarded': true,
      if (seen) 'tour.seen': true,
    });
    prefs = await SharedPreferences.getInstance();
    t.view.physicalSize = const Size(390, 844) * 2;
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      ProviderScope(
        overrides: testOverrides(
          prefs,
          signedIn: true,
          tourAutoStart: autoStart,
        ),
        retry: (_, _) => null,
        child: const DripApp(),
      ),
    );
    container = ProviderScope.containerOf(t.element(find.byType(MaterialApp)));
  }

  testWidgets('it starts by itself on Home the first time, and only then', (
    t,
  ) async {
    await boot(t);
    await settle(t, 3600);
    expect(find.text('WELCOME TO DRIP'), findsOneWidget);

    await t.tap(find.text('SKIP TOUR'));
    await settle(t, 600);
    expect(find.text('WELCOME TO DRIP'), findsNothing);
    expect(prefs.getBool('tour.seen'), isTrue);

    // Back on Home later: it doesn't come back.
    container.read(routerProvider).go('/scroll');
    await settle(t, 600);
    container.read(routerProvider).go('/home');
    await settle(t, 2400);
    expect(find.text('WELCOME TO DRIP'), findsNothing);
  });

  testWidgets('a returning user who has seen it is left alone', (t) async {
    await boot(t, seen: true);
    await settle(t, 3600);
    expect(find.text('WELCOME TO DRIP'), findsNothing);
  });

  testWidgets('it walks every tab, then shows what comes after beta', (
    t,
  ) async {
    await boot(t, autoStart: false);
    await settle(t, 2000);
    container.read(tourProvider.notifier).start();
    await settle(t);

    final seen = <String>[];
    for (var i = 0; i < tourSteps.length; i++) {
      final step = tourSteps[i];
      expect(onCard(step.title), findsOneWidget, reason: 'step $i');
      seen.add(step.title);
      if (step.route == '/scroll') {
        expect(find.byType(FashionScrollScreen), findsOneWidget);
      }
      if (step.route == '/studio') {
        expect(find.byType(StudioHomeScreen), findsOneWidget);
      }
      if (step.art == TourArt.afterBeta) {
        expect(find.text('Comments & sharing'), findsOneWidget);
        expect(find.text('AI photoshoots of your fits'), findsOneWidget);
      }
      await t.tap(
        find.text(
          i == tourSteps.length - 1
              ? 'START EXPLORING'
              : i == 0
              ? 'SHOW ME'
              : 'NEXT',
        ),
      );
      await settle(t);
    }
    expect(seen, hasLength(tourSteps.length));
    expect(container.read(tourProvider), isNull);
    expect(prefs.getBool('tour.seen'), isTrue);
  });

  testWidgets('BACK steps back a tab', (t) async {
    await boot(t, autoStart: false);
    await settle(t, 2000);
    final tour = container.read(tourProvider.notifier)..start();
    await settle(t);
    for (var i = 0; i < 5; i++) {
      tour.next();
      await settle(t);
    }
    expect(find.byType(FashionScrollScreen), findsOneWidget);
    await t.tap(find.text('BACK'));
    await settle(t);
    expect(onCard(tourSteps[4].title), findsOneWidget);
    expect(find.byType(FashionScrollScreen), findsNothing);
  });

  testWidgets('Settings → Take the Tour replays it', (t) async {
    await boot(t, seen: true, autoStart: false);
    await settle(t, 2000);
    container.read(routerProvider).go('/settings');
    await settle(t, 800);
    await t.scrollUntilVisible(
      find.text('Take the Tour'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await t.tap(find.text('Take the Tour'));
    await settle(t);
    expect(find.text('WELCOME TO DRIP'), findsOneWidget);
  });
}
