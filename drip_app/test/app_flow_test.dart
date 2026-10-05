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

    // Splash runs its launch sequence, then lands on the welcome: the
    // brand's opening line, and the way in.
    expect(find.byType(DripWordmark), findsOneWidget);
    await settle(t, 3200);
    expect(find.text('OVERDRESSED'), findsOneWidget);
    await tapText(t, 'GET STARTED →');

    // Dress me for: one tap, and the flow moves on by itself.
    expect(find.text('DRESS ME FOR'), findsOneWidget);
    await tapText(t, 'PICK ONE TO CONTINUE');
    expect(find.text('TAP THE ONE THAT FITS'), findsOneWidget);
    await t.tap(find.text('FEMALE'));
    await settle(t, 1200);
    expect(container.read(onboardingProvider).gender, 'female');

    // Vibe: no era yet → the button says what it needs.
    expect(find.text('YOUR VIBE'), findsOneWidget);
    await tapText(t, 'PICK AN ERA TO CONTINUE');
    expect(find.text('TAP AN ERA, OR HIT SURPRISE ME'), findsOneWidget);
    // "More like you" only appears once there's an era to go on.
    expect(find.text('MORE LIKE YOU · OPTIONAL'), findsNothing);
    await tapText(t, 'Minimal');
    expect(container.read(onboardingProvider).moodIds, {'minimal'});
    expect(find.text('MORE LIKE YOU · OPTIONAL'), findsOneWidget);
    await tapText(t, 'LOCK IN 1 VIBE →');

    // Colours: at least one.
    expect(find.text('COLOUR THEORY'), findsOneWidget);
    await tapText(t, 'PICK A COLOUR TO CONTINUE');
    expect(find.text('TAP A COLOUR ABOVE TO ADD IT'), findsOneWidget);
    await tapText(t, 'Cream');
    await tapText(t, 'SAVE 1 COLOUR →');

    // Labels + spend: optional, pre-set spend, so it continues.
    expect(find.text('LABELS'), findsOneWidget);
    await tapText(t, 'CONTINUE →');

    // No selfie step: selfies are taken in the Selfie Coordinator.
    expect(find.text('SEE YOURSELF IN THE FIT'), findsNothing);

    // Name (no name, no ticket), then the build, then the ticket.
    await tapText(t, 'ADD YOUR NAME TO CONTINUE');
    expect(find.text('TYPE YOUR FIRST NAME ABOVE'), findsOneWidget);
    await t.enterText(find.byType(TextField), 'Taylor');
    await t.pump();
    expect(find.text('@taylor_77'), findsOneWidget);
    await tapText(t, 'PRINT MY TICKET →');
    await settle(t, 4200);
    expect(find.text('YOUR DRIP TICKET.'), findsOneWidget);
    expect(find.text('Taylor'), findsWidgets);

    // The ticket carries the save: Google, with every pick sent to the
    // account. Google only: no phone sign-in offered.
    expect(find.text('CONTINUE WITH PHONE'), findsNothing);
    expect(container.read(sessionProvider).signedIn, isFalse);
    await tapText(t, 'SAVE MY DRIP WITH GOOGLE');
    await settle(t, 1500);
    expect(container.read(sessionProvider).signedIn, isTrue);
    final account = await container.read(accountRepositoryProvider).me();
    expect(account.onboardingPrefs['moods'], ['minimal']);
    expect(account.onboardingPrefs['colours'], ['cream']);
    expect(account.onboardingPrefs['name'], 'Taylor');
    expect(account.onboardingPrefs['gender'], 'female');
    // Occasions aren't asked in onboarding (they're in Your style).
    expect(account.onboardingPrefs['occasions'], isEmpty);
    expect(account.styleTags, ['minimal']);

    // First run: the finished ticket and "your Drip is ready", then Home.
    expect(find.text('YOUR DRIP\nIS READY.'), findsOneWidget);
    await tapText(t, 'EXPLORE DRIP →');
    await settle(t, 900);

    // Home feed.
    expect(find.text('Your story'), findsOneWidget);
    expect(find.text('SHOP BY OCCASION'), findsOneWidget);
    expect(find.text('ASK TAYLOR  →'), findsOneWidget);

    // Like the first fit in the Fashion Scroll, then come back Home.
    final first = container.read(feedProvider).requireValue.items.first;
    final wasLiked = container.read(fitMarksProvider).isLiked(first.id);
    container.read(routerProvider).go('/scroll');
    await settle(t, 900);
    await t.tap(
      find
          .byWidgetPredicate(
            (w) =>
                w is Tap && w.semanticLabel == (wasLiked ? 'Unlike' : 'Like'),
          )
          .first,
    );
    await settle(t);
    expect(container.read(fitMarksProvider).isLiked(first.id), !wasLiked);
    container.read(routerProvider).go('/home');
    await settle(t, 900);

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
    expect(find.text('OVERDRESSED'), findsOneWidget);
    expect(container.read(sharedPreferencesProvider).getKeys(), isEmpty);
  });

  Future<void> back(WidgetTester t) async {
    await t.tap(
      find.byWidgetPredicate((w) => w is Tap && w.semanticLabel == 'Back'),
    );
    await settle(t);
  }

  testWidgets('a relaunch resumes onboarding where it left off', (t) async {
    await boot(
      t,
      prefs: {
        'onboarding.step': 'colours',
        'onboarding.flow':
            '{"gender":"male","moods":["minimal"],"colours":["cream"]}',
      },
    );
    await settle(t, 3200);
    expect(find.text('COLOUR THEORY'), findsOneWidget);
    // The eyebrow says why this is asked, not how many steps are left.
    expect(find.text('TAYLOR STYLES AROUND THESE'), findsOneWidget);
    expect(find.text('SAVE 1 COLOUR →'), findsOneWidget);

    // Back keeps what was picked.
    await back(t);
    expect(find.text('YOUR VIBE'), findsOneWidget);
    expect(find.text('LOCK IN 1 VIBE →'), findsOneWidget);
    expect(
      container.read(sharedPreferencesProvider).getString('onboarding.step'),
      'eras',
    );
  });

  testWidgets('back from the ticket skips the build beat', (t) async {
    await boot(
      t,
      prefs: {
        'onboarding.step': 'ticket',
        'onboarding.flow': '{"gender":"male","moods":["minimal"],"colours":["cream"],"name":"Taylor"}',
      },
    );
    await settle(t, 3200);
    expect(find.text('YOUR DRIP TICKET.'), findsOneWidget);
    await back(t);
    expect(find.text('WHAT DO WE\nCALL YOU?'), findsOneWidget);
    expect(find.text('PRINT MY TICKET →'), findsOneWidget);
  });

  testWidgets('a step saved by an older version still resumes', (t) async {
    // "join" no longer exists: the save is on the ticket now.
    await boot(
      t,
      prefs: {
        'onboarding.step': 'join',
        'onboarding.flow': '{"gender":"male","moods":["minimal"],"colours":["cream"],"name":"Taylor"}',
      },
    );
    await settle(t, 3200);
    expect(find.text('YOUR DRIP TICKET.'), findsOneWidget);
    expect(find.text('SAVE MY DRIP WITH GOOGLE'), findsOneWidget);
  });

  testWidgets('signing in without a name goes back for it', (t) async {
    await boot(
      t,
      prefs: {
        'onboarding.step': 'join',
        'onboarding.flow':
            '{"gender":"male","moods":["minimal"],"colours":["cream"]}',
      },
    );
    await settle(t, 3200);
    await tapText(t, 'SAVE MY DRIP WITH GOOGLE');
    expect(container.read(sessionProvider).signedIn, isFalse);
    expect(find.text('WHAT DO WE\nCALL YOU?'), findsOneWidget);
    expect(find.text('ADD YOUR NAME TO FINISH YOUR TICKET'), findsOneWidget);
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
      expect(find.text('OVERDRESSED'), findsOneWidget);
    },
  );
}
