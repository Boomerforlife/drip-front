import 'package:drip/app.dart';
import 'package:drip/core/widgets/brand.dart';
import 'package:drip/core/widgets/tap.dart';
import 'package:drip/data/providers.dart';
import 'package:drip/features/home/feed_controller.dart';
import 'package:drip/features/outfits/outfit_controller.dart';
import 'package:drip/features/session/session_controller.dart';
import 'package:drip/features/settings/settings_controller.dart';
import 'package:drip/routing/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fakes.dart';
import 'test_fonts.dart';

/// Pumps in small steps: the app has looping animations, so `pumpAndSettle`
/// would never return.
Future<void> settle(WidgetTester t, [int ms = 700]) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<void> tapText(WidgetTester t, String text, {bool warn = true}) async {
  final f = find.text(text);
  expect(f, findsWidgets, reason: 'expected to find "$text"');
  await t.ensureVisible(f.first);
  await t.pump();
  await t.tap(f.first, warnIfMissed: warn);
  await settle(t);
}

void main() {
  late ProviderContainer container;

  setUpAll(loadAppFonts);

  Future<void> boot(
    WidgetTester t, {
    Map<String, Object> prefs = const {},
    bool signedIn = false,
  }) async {
    SharedPreferences.setMockInitialValues(prefs);
    final sp = await SharedPreferences.getInstance();
    t.view.physicalSize = const Size(780, 1688);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      ProviderScope(
        overrides: testOverrides(sp, signedIn: signedIn),
        retry: (_, _) => null,
        child: const DripApp(),
      ),
    );
    container = ProviderScope.containerOf(t.element(find.byType(MaterialApp)));
  }

  testWidgets('onboarding → sign in → home → like → settings → logout', (
    t,
  ) async {
    await boot(t);

    // Splash runs its launch sequence, then lands on the welcome step.
    expect(find.byType(DripWordmark), findsOneWidget);
    await settle(t, 3200);
    expect(find.text('THE FIT\nFINDS YOU.'), findsOneWidget);

    // Onboarding: welcome → hard truth → what is Drip → vibe.
    await tapText(t, 'GET STARTED →');
    await settle(t, 600);
    expect(find.text('HARD TRUTH №1'), findsOneWidget);
    await tapText(t, 'HELP ME →');
    expect(find.text('WHAT IS DRIP?'), findsOneWidget);
    await tapText(t, 'UNDERSTOOD. NEXT →');
    expect(find.text('YOUR VIBE'), findsOneWidget);

    // No era yet → the button refuses to continue.
    expect(container.read(onboardingProvider).moodIds, isEmpty);
    await tapText(t, 'CONFIRM VIBE →');
    expect(find.text('Pick at least one era'), findsOneWidget);
    expect(find.text('YOUR VIBE'), findsOneWidget);
    await tapText(t, 'Minimal');
    expect(container.read(onboardingProvider).moodIds, {'minimal'});
    await tapText(t, 'LOCK IN 1 VIBES →');

    // Colours: at least one, then the optional steps can be skipped.
    expect(find.text('COLOUR THEORY'), findsOneWidget);
    await tapText(t, 'CALIBRATE SPECTRUM →');
    expect(find.text('Wear at least one colour'), findsOneWidget);
    await tapText(t, 'Cream');
    await tapText(t, 'CALIBRATE SPECTRUM →');
    for (final step in ['YOUR PIECES', 'ACCESSORIES', 'LABELS', 'FIT & BUDGET']) {
      expect(find.text(step), findsOneWidget);
      await tapText(t, 'SKIP FOR NOW');
    }

    // Name, then the build animation, then the ticket.
    await t.enterText(find.byType(TextField), 'Taylor');
    await t.pump();
    expect(find.text('@taylor_77'), findsOneWidget);
    await tapText(t, 'PRINT MY TICKET →');
    await settle(t, 4200);
    expect(find.text('YOUR DRIP TICKET.'), findsOneWidget);
    expect(find.text('Taylor'), findsWidgets);
    await tapText(t, 'CLAIM YOUR TICKET →');

    // Last step: Google sign-in, straight into the app, with every pick sent
    // to the account.
    expect(find.text('CONTINUE WITH GOOGLE'), findsOneWidget);
    expect(container.read(sessionProvider).signedIn, isFalse);
    await tapText(t, 'CONTINUE WITH GOOGLE');
    await settle(t, 1500);
    expect(container.read(sessionProvider).signedIn, isTrue);
    final account = await container.read(accountRepositoryProvider).me();
    expect(account.onboardingPrefs['moods'], ['minimal']);
    expect(account.onboardingPrefs['colours'], ['cream']);
    expect(account.onboardingPrefs['name'], 'Taylor');
    expect(account.styleTags, ['minimal']);

    // Home feed.
    expect(find.text('Your story'), findsOneWidget);
    expect(find.text('FRESH FITS'), findsOneWidget);
    expect(find.text('ASK TAYLOR  →'), findsOneWidget);

    // Like the first fit in the Fashion Scroll, then come back Home.
    final first = container.read(feedProvider).requireValue.items.first;
    final wasLiked = container.read(fitMarksProvider).isLiked(first.id);
    container.read(routerProvider).go('/scroll');
    await settle(t, 900);
    await t.tap(
      find
          .byWidgetPredicate(
            (w) => w is Tap && w.semanticLabel == (wasLiked ? 'Unlike' : 'Like'),
          )
          .first,
    );
    await settle(t);
    expect(container.read(fitMarksProvider).isLiked(first.id), !wasLiked);
    container.read(routerProvider).go('/home');
    await settle(t, 900);

    // Discover and search have no backend yet: they say so.
    await tapText(t, 'SEARCH & DISCOVER  →');
    expect(
      find.text('SEARCH & DISCOVER IS COMING AFTER BETA ✦'),
      findsOneWidget,
    );
    await settle(t, 2400); // the toast times out

    // Settings: toggles persist, skin recolours, logout returns to welcome.
    container.read(routerProvider).go('/settings');
    await settle(t, 1200);
    expect(find.text('SETTINGS'), findsOneWidget);
    final push = container.read(settingsProvider).pushNotifications;
    await t.scrollUntilVisible(
      find.text('Push Notifications'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await t.tap(find.text('Push Notifications'));
    // Tapping the label does nothing: only the switch toggles.
    await settle(t);
    expect(container.read(settingsProvider).pushNotifications, push);
    await container.read(settingsProvider.notifier).setPush(!push);
    expect(
      container.read(sharedPreferencesProvider).getBool('settings.push'),
      !push,
    );

    await t.scrollUntilVisible(
      find.text('LOG OUT OF DRIP'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tapText(t, 'LOG OUT OF DRIP');
    expect(find.text('LOG OUT?'), findsOneWidget);
    await tapText(t, 'LOG OUT');
    await settle(t, 1200);
    expect(container.read(sessionProvider).signedIn, isFalse);
    expect(find.text('THE FIT\nFINDS YOU.'), findsOneWidget);
    expect(container.read(sharedPreferencesProvider).getKeys(), isEmpty);
  });

  testWidgets('signed-in users skip onboarding; guards protect app routes', (
    t,
  ) async {
    await boot(t, signedIn: true, prefs: {'session.onboarded': true});
    await settle(t, 3200);
    expect(find.text('Your story'), findsOneWidget);
  });

  testWidgets(
    'signed-out users are redirected to welcome from protected routes',
    (t) async {
      await boot(t);
      await settle(t, 3200);
      container.read(routerProvider).go('/wardrobe');
      await settle(t, 800);
      expect(find.text('THE FIT\nFINDS YOU.'), findsOneWidget);
    },
  );
}
