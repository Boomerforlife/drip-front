import 'package:drip/app.dart';
import 'package:drip/core/widgets/tap.dart';
import 'package:drip/data/providers.dart';
import 'package:drip/data/repositories/account_repository.dart';
import 'package:drip/features/home/home_screen.dart';
import 'package:drip/features/onboarding/onboarding_flow.dart';
import 'package:drip/features/onboarding/ready_screen.dart';
import 'package:drip/features/session/session_controller.dart';
import 'package:drip/routing/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fakes.dart';
import '../test_fonts.dart';

/// The account can't be reached (offline at sign-in).
class _OfflineAccount extends MockAccountRepository {
  @override
  Future<Never> me() async => throw Exception('offline');
}

const _saved = {
  'moods': ['minimal'],
  'colours': ['cream'],
  'brands': ['Zara'],
  'name': 'Sam',
  // Picked in Colour Theory, kept in the same prefs: must survive edits.
  'season': 'soft-summer',
};

const _fresh =
    '{"gender":"female","moods":["y2k","streetwear"],"colours":["red"],'
    '"brands":["Nike"],"occasions":["concert"],"name":"Taylor"}';

late ProviderContainer _c;

Future<void> _settle(WidgetTester t, [int ms = 700]) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _boot(
  WidgetTester t, {
  Map<String, Object> prefs = const {},
  AccountRepository? account,
  bool signedIn = false,
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final sp = await SharedPreferences.getInstance();
  t.view.physicalSize = const Size(390, 844) * 2;
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: testOverrides(sp, account: account, signedIn: signedIn),
      retry: (_, _) => null,
      child: const DripApp(),
    ),
  );
  _c = ProviderScope.containerOf(t.element(find.byType(MaterialApp)));
  await _settle(t, 3200);
}

Future<void> _signInFromTicket(WidgetTester t) async {
  expect(find.byType(OnboardingFlow), findsOneWidget);
  await t.tap(find.text('SAVE MY DRIP WITH GOOGLE'));
  await _settle(t, 1500);
}

Finder _tap(String label) =>
    find.byWidgetPredicate((w) => w is Tap && w.semanticLabel == label);

void main() {
  setUpAll(loadAppFonts);

  testWidgets('new user: picks saved, a one-time "ready" moment, then Home', (
    t,
  ) async {
    final account = MockAccountRepository();
    await _boot(
      t,
      account: account,
      prefs: {'onboarding.step': 'ticket', 'onboarding.flow': _fresh},
    );
    await _signInFromTicket(t);
    expect(find.byType(ReadyScreen), findsOneWidget);
    expect(find.text('YOUR DRIP\nIS READY.'), findsOneWidget);
    expect(
      find.text('Your picks are saved. Change them any time in Settings.'),
      findsOneWidget,
    );
    final me = await account.me();
    expect(me.onboardingPrefs['moods'], ['y2k', 'streetwear']);

    await t.tap(find.text('EXPLORE DRIP →'));
    await _settle(t, 1200);
    expect(find.byType(HomeScreen), findsOneWidget);
    // Shown once: signing in again goes straight Home.
    expect(
      _c.read(sharedPreferencesProvider).getBool('onboarding.firstRun'),
      isFalse,
    );
  });

  group('returning user going through onboarding again', () {
    // This run changed only the eras (everything else came from defaults or
    // was left alone).
    Future<MockAccountRepository> signIn(WidgetTester t) async {
      final account = MockAccountRepository(onboardingPrefs: _saved);
      await _boot(
        t,
        account: account,
        prefs: {
          'onboarding.step': 'ticket',
          'onboarding.flow': _fresh,
          'onboarding.touched': ['moods'],
        },
      );
      await _signInFromTicket(t);
      // Nothing on the account has changed yet: they're asked first.
      expect((await account.me()).onboardingPrefs, _saved);
      expect(_c.read(picksSyncProvider), PicksSync.conflict);
      expect(find.text('YOU ALREADY\nHAVE A DRIP.'), findsOneWidget);
      expect(find.text('YOUR DRIP\nIS READY.'), findsNothing);
      return account;
    }

    testWidgets('"update" changes only what they changed', (t) async {
      final account = await signIn(t);
      await t.tap(find.text('UPDATE MY DRIP'));
      await _settle(t, 1500);
      final me = await account.me();
      expect(me.onboardingPrefs['moods'], ['y2k', 'streetwear']);
      // Untouched in this run, so exactly as saved.
      expect(me.onboardingPrefs['colours'], ['cream']);
      expect(me.onboardingPrefs['brands'], ['Zara']);
      expect(me.onboardingPrefs['name'], 'Sam');
      expect(me.onboardingPrefs['season'], 'soft-summer');
      expect(_c.read(onboardingProvider).moodIds, {'y2k', 'streetwear'});
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('YOUR DRIP IS UPDATED'), findsOneWidget);
    });

    testWidgets('"keep" leaves the saved Drip exactly as it was', (t) async {
      final account = await signIn(t);
      await t.tap(find.text('KEEP MY SAVED DRIP'));
      await _settle(t, 1500);
      expect((await account.me()).onboardingPrefs, _saved);
      expect(_c.read(onboardingProvider).moodIds, {'minimal'});
      expect(_c.read(onboardingProvider).brands, {'Zara'});
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(
        find.text('WELCOME BACK. YOUR SAVED DRIP IS UNCHANGED'),
        findsOneWidget,
      );
    });
  });

  testWidgets('offline at sign-in: nothing overwritten, honest message', (
    t,
  ) async {
    final account = _OfflineAccount();
    await _boot(
      t,
      account: account,
      prefs: {'onboarding.step': 'ticket', 'onboarding.flow': _fresh},
    );
    await _signInFromTicket(t);
    expect(find.byType(ReadyScreen), findsOneWidget);
    expect(
      find.text(
        'Your picks are on this phone and sync when you’re back online.',
      ),
      findsOneWidget,
    );
    expect(
      _c.read(sharedPreferencesProvider).getBool('onboarding.pending'),
      isTrue,
    );
  });

  testWidgets('a relaunch before answering still asks, still protected', (
    t,
  ) async {
    final account = MockAccountRepository(onboardingPrefs: _saved);
    await _boot(
      t,
      account: account,
      signedIn: true,
      prefs: {
        'session.onboarded': true,
        'onboarding.pending': true,
        'onboarding.firstRun': true,
        'onboarding.flow': _fresh,
      },
    );
    await _settle(t, 800);
    expect((await account.me()).onboardingPrefs, _saved);
    expect(find.text('YOU ALREADY\nHAVE A DRIP.'), findsOneWidget);
  });

  group('editing your style', () {
    Future<MockAccountRepository> open(WidgetTester t) async {
      final account = MockAccountRepository(onboardingPrefs: _saved);
      await _boot(
        t,
        account: account,
        signedIn: true,
        prefs: {
          'session.onboarded': true,
          'onboarding.flow':
              '{"moods":["minimal"],"colours":["cream"],"brands":["Zara"],'
              '"name":"Sam"}',
        },
      );
      _c.read(routerProvider).go('/settings');
      await _settle(t, 900);
      await t.tap(find.text('Style, colours & more'));
      await _settle(t, 900);
      expect(find.text('YOUR STYLE'), findsOneWidget);
      return account;
    }

    testWidgets('from Settings: change, save, seen everywhere', (t) async {
      final account = await open(t);
      await t.ensureVisible(find.text('Labels'));
      await t.pump();
      await t.tap(find.text('Labels'));
      await _settle(t, 900);
      // A step skipped in onboarding is fillable here, with the same tiles.
      await t.tap(_tap('Nike'));
      await _settle(t, 300);
      await t.tap(find.text('SAVE'));
      await _settle(t, 900);

      final me = await account.me();
      expect(me.onboardingPrefs['brands'], unorderedEquals(['Zara', 'Nike']));
      // Merged, not replaced: the Colour Theory season is still there.
      expect(me.onboardingPrefs['season'], 'soft-summer');
      expect(_c.read(onboardingProvider).brands, {'Zara', 'Nike'});
      expect(find.text('YOUR STYLE'), findsOneWidget);
      expect(find.text('Nike, Zara'), findsOneWidget);
    });

    testWidgets('leaving with changes asks, and discarding restores', (
      t,
    ) async {
      final account = await open(t);
      await t.ensureVisible(find.text('Eras'));
      await t.pump();
      await t.tap(find.text('Eras'));
      await _settle(t, 900);
      await t.tap(_tap('Minimal, picked'));
      await _settle(t, 300);
      // Nothing left picked: the button says what's needed.
      expect(find.text('PICK AN ERA TO SAVE'), findsOneWidget);
      await t.tap(_tap('Back'));
      await _settle(t, 600);
      expect(find.text('DISCARD CHANGES?'), findsOneWidget);
      await t.tap(find.text('DISCARD'));
      await _settle(t, 900);
      expect(_c.read(onboardingProvider).moodIds, {'minimal'});
      expect((await account.me()).onboardingPrefs, _saved);
    });

    testWidgets('the profile links to it too', (t) async {
      await _boot(
        t,
        account: MockAccountRepository(onboardingPrefs: _saved),
        signedIn: true,
        prefs: {'session.onboarded': true},
      );
      _c.read(routerProvider).go('/me');
      await _settle(t, 1200);
      await t.ensureVisible(_tap('Edit your style'));
      await t.tap(_tap('Edit your style'));
      await _settle(t, 900);
      expect(find.text('YOUR STYLE'), findsOneWidget);
    });
  });

  // The new screens at the widths we design for: nothing overflows, nothing
  // is clipped, the CTA is on screen.
  const sizes = {
    '320x568': Size(320, 568),
    '375x667': Size(375, 667),
    '430x932': Size(430, 932),
    'tablet': Size(768, 1024),
    'desktop': Size(1280, 800),
  };
  for (final size in sizes.entries) {
    testWidgets('ready + your style lay out on ${size.key}', (t) async {
      for (final route in ['/ready', '/me/style', '/style/labels']) {
        SharedPreferences.setMockInitialValues({
          'session.onboarded': true,
          'onboarding.firstRun': true,
          'onboarding.flow': _fresh,
        });
        final sp = await SharedPreferences.getInstance();
        t.view.physicalSize = size.value * 2;
        t.view.devicePixelRatio = 2;
        addTearDown(t.view.reset);
        await t.pumpWidget(
          ProviderScope(
            key: UniqueKey(),
            overrides: testOverrides(sp, signedIn: true),
            retry: (_, _) => null,
            child: const DripApp(),
          ),
        );
        _c = ProviderScope.containerOf(t.element(find.byType(MaterialApp)));
        await _settle(t, 3200);
        _c.read(routerProvider).go(route);
        await _settle(t, 1800);
        expect(t.takeException(), isNull, reason: '$route on ${size.key}');
        final clipped = [
          for (final p in t.allRenderObjects.whereType<RenderParagraph>())
            if (p.didExceedMaxLines) p.text.toPlainText(),
        ];
        expect(clipped, isEmpty, reason: '$route on ${size.key}');
        if (route == '/ready') {
          final cta = t.getRect(find.text('EXPLORE DRIP →'));
          expect(cta.bottom, lessThanOrEqualTo(size.value.height));
        }
      }
    });
  }
}
