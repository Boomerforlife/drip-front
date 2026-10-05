import 'package:drip/app.dart';
import 'package:drip/data/repositories/account_repository.dart';
import 'package:drip/features/home/occasion_card.dart';
import 'package:drip/features/onboarding/local_selfie.dart';
import 'package:drip/features/onboarding/onboarding_ticket.dart';
import 'package:drip/features/session/session_controller.dart';
import 'package:drip/routing/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fakes.dart';
import '../test_fonts.dart';

/// Records every way the account could have received the selfie (the only
/// image upload left on the account is the profile photo).
class _WatchedAccount extends MockAccountRepository {
  int get uploads => photoUploads;
}

const _basics =
    '{"gender":"female","moods":["minimal"],"colours":["cream"],'
    '"name":"Taylor"}';

late ProviderContainer _c;

Future<void> _settle(WidgetTester t, [int ms = 700]) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

/// [picks]: what the camera/gallery hands back, in order (null = the user
/// cancelled; an exception = it couldn't open).
Future<void> _boot(
  WidgetTester t, {
  Map<String, Object> prefs = const {},
  AccountRepository? account,
  bool signedIn = false,
  List<Object?> picks = const [],
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final sp = await SharedPreferences.getInstance();
  t.view.physicalSize = const Size(390, 844) * 2;
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);
  final queue = [...picks];
  await t.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        ...testOverrides(sp, account: account, signedIn: signedIn),
        selfiePickerProvider.overrideWithValue((source) async {
          final next = queue.isEmpty ? null : queue.removeAt(0);
          if (next is Exception) throw next;
          if (next is Uint8List) {
            return XFile.fromData(
              next,
              path: 'selfie_a.jpg',
            );
          }
          return null;
        }),
      ],
      retry: (_, _) => null,
      child: const DripApp(),
    ),
  );
  _c = ProviderScope.containerOf(t.element(find.byType(MaterialApp)));
  await _settle(t, 3200);
}

Future<void> _tapText(WidgetTester t, String text) async {
  await t.ensureVisible(find.text(text).first);
  await t.pump();
  await t.tap(find.text(text).first);
  await _settle(t);
}

void main() {
  setUpAll(loadAppFonts);

  group('selfie: local media, never account data', () {
    testWidgets('onboarding asks for none; an old selfie step resumes at '
        'the name', (t) async {
      await _boot(
        t,
        prefs: {'onboarding.step': 'selfie', 'onboarding.flow': _basics},
      );
      expect(find.text('SEE YOURSELF IN THE FIT'), findsNothing);
      expect(find.text('WHAT DO WE\nCALL YOU?'), findsOneWidget);
    });

    testWidgets('the ticket carries no photo, and saving sends none', (
      t,
    ) async {
      final account = _WatchedAccount();
      await _boot(
        t,
        account: account,
        prefs: {
          'onboarding.step': 'name',
          'onboarding.flow': _basics,
          // A selfie from the Selfie Coordinator, already on the phone.
          'media.selfie': 'selfie_a.jpg',
        },
      );
      await _tapText(t, 'PRINT MY TICKET →');
      await _settle(t, 4200);
      expect(find.byType(DripTicket), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(DripTicket),
          matching: find.byType(Image),
        ),
        findsNothing,
      );
      await _tapText(t, 'SAVE MY DRIP WITH GOOGLE');
      await _settle(t, 1500);
      expect(_c.read(sessionProvider).signedIn, isTrue);
      expect(account.uploads, 0);
      final me = await account.me();
      expect(me.hasAvatar, isFalse);
      expect(me.onboardingPrefs.keys, isNot(contains('selfie')));
    });
  });

  testWidgets('"more like you" offers genres for the eras picked', (t) async {
    await _boot(
      t,
      prefs: {
        'onboarding.step': 'eras',
        'onboarding.flow': '{"gender":"male"}',
      },
    );
    expect(find.text('MORE LIKE YOU · OPTIONAL'), findsNothing);
    await _tapText(t, 'Streetwear');
    expect(find.text('MORE LIKE YOU · OPTIONAL'), findsOneWidget);
    expect(find.text('Skater'), findsOneWidget);
    expect(find.text('Coquette'), findsNothing);
    await _tapText(t, 'SHOW 11 MORE ↓');
    expect(find.text('Coquette'), findsOneWidget);
  });

  testWidgets('Home leads "shop by occasion" with the ones picked', (t) async {
    await _boot(
      t,
      signedIn: true,
      prefs: {
        'session.onboarded': true,
        'onboarding.flow': '{"occasions":["clubs","golf"]}',
      },
    );
    _c.read(routerProvider).go('/home');
    await _settle(t, 1500);
    final cards = t.widgetList<OccasionCard>(find.byType(OccasionCard));
    expect(
      {
        for (final c in cards)
          if (c.forYou) c.occasion.id,
      },
      {'clubs', 'golf'},
    );
    // The two picked lead the wall: the first row, left then right.
    Rect at(String id) => t.getRect(
      find.byWidgetPredicate((w) => w is OccasionCard && w.occasion.id == id),
    );
    final clubs = at('clubs'), golf = at('golf'), date = at('date-night');
    expect(clubs.top, lessThan(date.top));
    expect(clubs.left, lessThan(golf.left));
    expect(golf.top, lessThan(at('concert').top));
    expect(find.text('YOURS FIRST'), findsOneWidget);
  });

  testWidgets('occasions and "dress me for" stay editable in Your style', (
    t,
  ) async {
    final account = MockAccountRepository(
      onboardingPrefs: const {
        'moods': ['minimal'],
        'colours': ['cream'],
        'gender': 'male',
      },
    );
    await _boot(
      t,
      account: account,
      signedIn: true,
      prefs: {
        'session.onboarded': true,
        'onboarding.flow':
            '{"gender":"male","moods":["minimal"],"colours":["cream"]}',
      },
    );
    _c.read(routerProvider).go('/style/occasions');
    await _settle(t, 1200);
    await _tapText(t, 'CLUBS');
    await _tapText(t, 'SAVE');
    await _settle(t, 900);
    expect((await account.me()).onboardingPrefs['occasions'], ['clubs']);

    _c.read(routerProvider).go('/style/dressFor');
    await _settle(t, 1200);
    await _tapText(t, 'PREFER NOT TO SAY');
    await _tapText(t, 'SAVE');
    await _settle(t, 900);
    expect((await account.me()).onboardingPrefs['gender'], 'unspecified');
  });
}
