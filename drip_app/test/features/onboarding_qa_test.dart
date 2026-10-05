import 'package:drip/app.dart';
import 'package:drip/core/widgets/tap.dart';
import 'package:drip/data/providers.dart';
import 'package:drip/features/onboarding/local_selfie.dart';
import 'package:drip/features/onboarding/onboarding_flow.dart';
import 'package:drip/features/onboarding/onboarding_steps.dart';
import 'package:drip/features/session/session_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fakes.dart';
import '../test_fonts.dart';

/// Google opens, but the user never comes back signed in (closed the tab).
class _StalledAuth extends FakeAuthRepository {
  @override
  Future<void> signInWithGoogle() async {}
}

/// Google can't be opened at all (no browser, no network).
class _BrokenAuth extends FakeAuthRepository {
  @override
  Future<void> signInWithGoogle() async => throw Exception('offline');
}

const _full =
    '{"gender":"male","moods":["minimal"],"colours":["cream"],'
    '"clothes":["Cargos"],"occasions":["concert"],"name":"Taylor"}';

/// Picks that get past every required step, nothing optional.
const _basics = '{"gender":"male","moods":["minimal"],"colours":["cream"]}';

Future<void> _settle(WidgetTester t, [int ms = 700]) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

late ProviderContainer _c;

Future<void> _boot(
  WidgetTester t, {
  Map<String, Object> prefs = const {},
  Size size = const Size(390, 844),
  FakeAuthRepository? auth,
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final sp = await SharedPreferences.getInstance();
  t.view.physicalSize = size * 2;
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: testOverrides(sp, auth: auth),
      retry: (_, _) => null,
      child: const DripApp(),
    ),
  );
  _c = ProviderScope.containerOf(t.element(find.byType(MaterialApp)));
  await _settle(t, 3200);
}

String? _savedStep() =>
    _c.read(sharedPreferencesProvider).getString('onboarding.step');

Finder _back() =>
    find.byWidgetPredicate((w) => w is Tap && w.semanticLabel == 'Back');

/// Two taps 50ms apart on the same spot: a nervous double-tap. The second
/// lands on whatever is there by then, as a real finger would.
Future<void> _doubleTap(WidgetTester t, Finder f) async {
  final at = t.getCenter(f.first);
  await t.tapAt(at);
  await t.pump(const Duration(milliseconds: 50));
  await t.tapAt(at);
  await _settle(t);
}

void main() {
  setUpAll(loadAppFonts);

  group('rapid taps never advance twice', () {
    testWidgets('get started', (t) async {
      await _boot(t);
      await _doubleTap(t, find.text('GET STARTED →'));
      expect(find.text('DRESS ME FOR'), findsOneWidget);
      expect(_savedStep(), 'dressFor');
    });

    testWidgets('a double-tapped "dress me for" card moves on once', (t) async {
      await _boot(t, prefs: {'onboarding.step': 'dressFor'});
      await _doubleTap(t, find.text('MALE'));
      await _settle(t, 900);
      expect(find.text('YOUR VIBE'), findsOneWidget);
      expect(_c.read(onboardingProvider).gender, 'male');
    });

    testWidgets('printing the ticket does not skip the build', (t) async {
      await _boot(
        t,
        prefs: {'onboarding.step': 'name', 'onboarding.flow': _full},
      );
      await _doubleTap(t, find.text('PRINT MY TICKET →'));
      expect(find.byType(BuildStep), findsOneWidget);
      expect(_c.read(sessionProvider).signedIn, isFalse);
    });

    testWidgets('"I already have an account" opens sign-in once', (t) async {
      await _boot(t);
      await _doubleTap(t, find.text('I ALREADY HAVE AN ACCOUNT'));
      expect(find.text('ONE TAP AND YOU’RE IN.'), findsOneWidget);
      await t.tap(_back());
      await _settle(t, 900);
      expect(find.text('OVERDRESSED'), findsOneWidget);
    });

    testWidgets('back', (t) async {
      // Saved by an older build on the (removed) selfie step: resumes at
      // the name, and back goes to the labels.
      await _boot(
        t,
        prefs: {'onboarding.step': 'selfie', 'onboarding.flow': _full},
      );
      await _doubleTap(t, _back());
      expect(find.text('LABELS'), findsOneWidget);
    });
  });

  testWidgets('back walks every step to welcome, never replaying the build', (
    t,
  ) async {
    await _boot(
      t,
      prefs: {'onboarding.step': 'ticket', 'onboarding.flow': _full},
    );
    const expected = [
      ('name', 'WHAT DO WE\nCALL YOU?'),
      ('labels', 'LABELS'),
      ('colours', 'COLOUR THEORY'),
      ('eras', 'YOUR VIBE'),
      ('dressFor', 'DRESS ME FOR'),
      ('welcome', 'OVERDRESSED'),
    ];
    for (final (step, text) in expected) {
      await t.tap(_back());
      await _settle(t);
      expect(find.text(text), findsOneWidget, reason: step);
      expect(find.byType(BuildStep), findsNothing);
      expect(_savedStep(), step);
    }
    // Picks survive the whole walk back.
    expect(_c.read(onboardingProvider).moodIds, {'minimal'});
    expect(_c.read(onboardingProvider).occasions, {'concert'});
    expect(_c.read(onboardingProvider).gender, 'male');
    expect(_back().hitTestable(), findsNothing);
  });

  group('relaunch', () {
    testWidgets('mid-build reopens the name step with the name kept', (
      t,
    ) async {
      // The build beat never saves itself: the last saved step is the name.
      await _boot(
        t,
        prefs: {'onboarding.step': 'name', 'onboarding.flow': _full},
      );
      await t.tap(find.text('PRINT MY TICKET →'));
      // Mid-transition each page keeps its own content: the name leaves as
      // the build arrives (the outgoing page used to repaint as the new one).
      await t.pump(const Duration(milliseconds: 100));
      expect(find.byType(NameStep), findsOneWidget);
      expect(find.byType(BuildStep), findsOneWidget);
      await t.pump(const Duration(milliseconds: 500));
      expect(find.byType(BuildStep), findsOneWidget);
      expect(_savedStep(), 'name');
    });

    testWidgets('a saved step past an unmet requirement falls back to it', (
      t,
    ) async {
      await _boot(
        t,
        prefs: {
          'onboarding.step': 'ticket',
          'onboarding.flow': '{"name":"Taylor"}',
        },
      );
      expect(find.text('DRESS ME FOR'), findsOneWidget);
    });

    testWidgets('an unknown saved step starts at welcome', (t) async {
      await _boot(t, prefs: {'onboarding.step': 'nonsense'});
      expect(find.text('OVERDRESSED'), findsOneWidget);
    });
  });

  testWidgets('"add own" brings the colour mixer into view', (t) async {
    await _boot(
      t,
      size: const Size(375, 667),
      prefs: {'onboarding.step': 'colours', 'onboarding.flow': _basics},
    );
    final add = find.byWidgetPredicate(
      (w) => w is Tap && w.semanticLabel == 'Add your own colour',
    );
    await t.ensureVisible(add);
    await _settle(t, 300);
    await t.tap(add);
    await _settle(t, 1200);
    // Down to its button, without the user scrolling: fully above the
    // footer, and on screen.
    final button = t.getRect(find.text('ADD TO MY PALETTE'));
    final footer = t.getRect(find.text('SAVE 1 COLOUR →'));
    expect(button.bottom, lessThanOrEqualTo(footer.top));
    expect(button.top, greaterThan(0));
    // And it works from there.
    await t.tap(find.text('ADD TO MY PALETTE'));
    await _settle(t);
    expect(_c.read(onboardingProvider).customColours, hasLength(1));
    expect(_c.read(onboardingProvider).paletteIds, hasLength(2));
  });

  testWidgets('optional steps skip with nothing picked', (t) async {
    await _boot(
      t,
      prefs: {'onboarding.step': 'labels', 'onboarding.flow': _basics},
    );
    for (final (button, next) in [('CONTINUE →', 'WHAT DO WE\nCALL YOU?')]) {
      await t.tap(find.text(button));
      await _settle(t);
      expect(find.text(next), findsOneWidget);
    }
    final p = _c.read(onboardingProvider);
    expect([p.occasions, p.brands], everyElement(isEmpty));
    expect(_c.read(localSelfieProvider).value, isNull);
    expect(find.text('SEE YOURSELF IN THE FIT'), findsNothing);
  });

  group('name', () {
    testWidgets('punctuation alone is not a name', (t) async {
      await _boot(
        t,
        prefs: {'onboarding.step': 'name', 'onboarding.flow': _basics},
      );
      await t.enterText(find.byType(TextField), '!!');
      await t.pump();
      expect(find.text('ADD YOUR NAME TO CONTINUE'), findsOneWidget);
      await t.enterText(find.byType(TextField), ' A ');
      await t.pump();
      await t.tap(find.text('ADD YOUR NAME TO CONTINUE'));
      await _settle(t, 300);
      expect(find.text('YOUR NAME NEEDS TWO LETTERS OR MORE'), findsOneWidget);
      expect(find.text('WHAT DO WE\nCALL YOU?'), findsOneWidget);
    });

    testWidgets('done on an empty field keeps the keyboard up', (t) async {
      await _boot(
        t,
        prefs: {'onboarding.step': 'name', 'onboarding.flow': _basics},
      );
      await t.showKeyboard(find.byType(TextField));
      await t.testTextInput.receiveAction(TextInputAction.done);
      await _settle(t, 300);
      expect(find.text('TYPE YOUR FIRST NAME ABOVE'), findsOneWidget);
      expect(t.testTextInput.isVisible, isTrue);
      // A valid name submits from the keyboard.
      await t.enterText(find.byType(TextField), 'Taylor');
      await t.testTextInput.receiveAction(TextInputAction.done);
      await t.pump(const Duration(milliseconds: 600));
      expect(find.byType(BuildStep), findsOneWidget);
    });

    testWidgets('with the keyboard up on a small phone, field and CTA show', (
      t,
    ) async {
      await _boot(
        t,
        size: const Size(320, 568),
        prefs: {'onboarding.step': 'name', 'onboarding.flow': _basics},
      );
      t.view.viewInsets = const FakeViewPadding(bottom: 260 * 2);
      await _settle(t, 500);
      expect(t.takeException(), isNull);
      final cta = t.getRect(find.text('ADD YOUR NAME TO CONTINUE'));
      final field = t.getRect(find.byType(TextField));
      expect(cta.bottom, lessThanOrEqualTo(568 - 260));
      expect(field.top, greaterThanOrEqualTo(0));
      expect(field.bottom, lessThanOrEqualTo(cta.top));
      // The handle preview under the field stays readable above the button.
      await t.showKeyboard(find.byType(TextField));
      await _settle(t, 500);
      final handle = t.getRect(find.text('@yourname_77'));
      expect(
        handle.bottom,
        lessThanOrEqualTo(
          t.getRect(find.text('ADD YOUR NAME TO CONTINUE')).top,
        ),
      );
    });
  });

  group('Google sign-in', () {
    testWidgets('stalled: waiting note, and back leaves no spinner behind', (
      t,
    ) async {
      await _boot(
        t,
        auth: _StalledAuth(),
        prefs: {'onboarding.step': 'ticket', 'onboarding.flow': _full},
      );
      await t.tap(find.text('SAVE MY DRIP WITH GOOGLE'));
      await _settle(t, 300);
      expect(
        find.text('FINISH SIGNING IN WITH GOOGLE, THEN COME BACK HERE'),
        findsOneWidget,
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // A second tap while waiting does nothing.
      await t.tap(find.byType(CircularProgressIndicator));
      await _settle(t, 300);
      await t.tap(_back());
      await _settle(t);
      expect(find.text('PRINT MY TICKET →'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        find.text('FINISH SIGNING IN WITH GOOGLE, THEN COME BACK HERE'),
        findsNothing,
      );
    });

    testWidgets('failure: says so above the button, and can retry', (t) async {
      await _boot(
        t,
        auth: _BrokenAuth(),
        prefs: {'onboarding.step': 'ticket', 'onboarding.flow': _full},
      );
      await t.tap(find.text('SAVE MY DRIP WITH GOOGLE'));
      await _settle(t, 300);
      expect(
        find.text("COULDN'T OPEN GOOGLE SIGN-IN. TRY AGAIN."),
        findsOneWidget,
      );
      final msg = t.getRect(
        find.text("COULDN'T OPEN GOOGLE SIGN-IN. TRY AGAIN."),
      );
      final btn = t.getRect(find.text('SAVE MY DRIP WITH GOOGLE'));
      expect(msg.bottom, lessThanOrEqualTo(btn.top));
      expect(_c.read(sessionProvider).signedIn, isFalse);
      // Picks are kept for the next try.
      expect(
        _c.read(sharedPreferencesProvider).getBool('onboarding.pending'),
        isTrue,
      );
    });
  });

  testWidgets('returning user: sign-in from welcome restores nothing locally', (
    t,
  ) async {
    await _boot(t);
    await t.tap(find.text('I ALREADY HAVE AN ACCOUNT'));
    await _settle(t, 900);
    await t.tap(find.text('CONTINUE WITH GOOGLE'));
    await _settle(t, 1500);
    expect(_c.read(sessionProvider).signedIn, isTrue);
    expect(find.byType(OnboardingFlow), findsNothing);
  });

  testWidgets('reduced motion: steps fade, they do not slide', (t) async {
    t.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(t.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await _boot(t);
    await t.tap(find.text('GET STARTED →'));
    await t.pump(const Duration(milliseconds: 100));
    expect(
      find.descendant(
        of: find.byType(OnboardingFlow),
        matching: find.byType(SlideTransition),
      ),
      findsNothing,
    );
    await _settle(t);
    expect(find.text('DRESS ME FOR'), findsOneWidget);
  });

  testWidgets('screen readers get labels, state and announcements', (t) async {
    final sem = t.ensureSemantics();
    await _boot(
      t,
      prefs: {
        'onboarding.step': 'eras',
        'onboarding.flow': '{"gender":"male","moods":["y2k"]}',
      },
    );
    // One clean label per control: name, then state. Nothing read twice, and
    // no "active" badge announced on a tile that isn't picked.
    expect(find.bySemanticsLabel('Y2K, picked'), findsOneWidget);
    expect(find.bySemanticsLabel('Minimal'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('ACTIVE')), findsNothing);
    expect(find.bySemanticsLabel('LOCK IN 1 VIBE'), findsOneWidget);
    expect(find.bySemanticsLabel('Screen 2 of 6'), findsOneWidget);
    // Picking changes the label the reader hears.
    await t.tap(find.text('Minimal'));
    await _settle(t, 300);
    expect(find.bySemanticsLabel('Minimal, picked'), findsOneWidget);
    expect(find.bySemanticsLabel('LOCK IN 2 VIBES'), findsOneWidget);
    // A note about the button is announced as it appears.
    await t.tap(find.text('Minimal'));
    await t.tap(find.text('Y2K'));
    await _settle(t, 300);
    await t.tap(find.text('PICK AN ERA TO CONTINUE'));
    await _settle(t, 300);
    expect(
      t.getSemantics(find.text('TAP AN ERA, OR HIT SURPRISE ME')),
      matchesSemantics(
        label: 'TAP AN ERA, OR HIT SURPRISE ME',
        isLiveRegion: true,
      ),
    );
    expect(
      t.getSemantics(find.text('YOUR VIBE')),
      matchesSemantics(label: 'YOUR VIBE', isHeader: true),
    );
    sem.dispose();
  });

  // Every step at the widths we design for, plus a tablet, a desktop window
  // and large text: no overflow, and no clipped text.
  const sizes = <String, (Size, double)>{
    '320x568': (Size(320, 568), 1),
    '375x667': (Size(375, 667), 1),
    '430x932': (Size(430, 932), 1),
    'tablet 768x1024': (Size(768, 1024), 1),
    'desktop 1280x800': (Size(1280, 800), 1),
    '375x667 @ 1.3x text': (Size(375, 667), 1.3),
  };
  const steps = [
    'welcome',
    'dressFor',
    'eras',
    'colours',
    'labels',
    'name',
    'ticket',
  ];
  for (final s in sizes.entries) {
    testWidgets('no clipped text on ${s.key}', (t) async {
      t.platformDispatcher.textScaleFactorTestValue = s.value.$2;
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      final clipped = <String>[];
      for (final step in steps) {
        await _boot(
          t,
          size: s.value.$1,
          prefs: {
            'onboarding.step': step,
            'onboarding.flow':
                '{"gender":"unspecified","occasions":["late-night-dinner",'
                '"family-events","wedding","concert"],"brands":["New Balance",'
                '"Indie labels","Sneaker drops","Levi’s"],'
                '"moods":["streetwear","techwear"],"colours":["burnt","cream"],'
                '"genres":["Dark academia"],"accessories":["Chains","Rings",'
                '"Caps","Beanies","Shades","Watches","Belts","Bags","Scarves",'
                '"Bracelets","Earrings"],"budget":15000,"fit":"oversized",'
                '"name":"Alexandria-Rose","customColours":[]}',
          },
        );
        await _settle(t, 3000);
        if (step == 'colours') {
          await t.tap(
            find.byWidgetPredicate(
              (w) => w is Tap && w.semanticLabel == 'Add your own colour',
            ),
          );
          await _settle(t);
        }
        expect(t.takeException(), isNull, reason: '$step on ${s.key}');
        for (final p in t.allRenderObjects.whereType<RenderParagraph>()) {
          if (p.didExceedMaxLines) {
            clipped.add('$step: "${p.text.toPlainText()}"');
          }
        }
      }
      expect(clipped, isEmpty, reason: clipped.join('\n'));
    });
  }
}
