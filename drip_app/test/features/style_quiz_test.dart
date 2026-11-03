import 'package:drip/app.dart';
import 'package:drip/data/providers.dart';
import 'package:drip/data/repositories/account_repository.dart';
import 'package:drip/features/quiz/style_quiz.dart';
import 'package:drip/routing/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fakes.dart';
import '../test_fonts.dart';

/// The style quiz on Home: ten multiple-choice taps, each answer moving on by
/// itself, saved into the account's onboarding prefs without touching the
/// picks already there.
void main() {
  setUpAll(loadAppFonts);

  late ProviderContainer container;
  late MockAccountRepository account;

  Future<void> settle(WidgetTester t, [int ms = 900]) async {
    for (var i = 0; i < ms ~/ 100; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> boot(WidgetTester t, {Map<String, dynamic>? prefs}) async {
    SharedPreferences.setMockInitialValues({'session.onboarded': true});
    final sp = await SharedPreferences.getInstance();
    t.view.physicalSize = const Size(390, 844) * 2;
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    account = MockAccountRepository(
      onboardingPrefs: prefs ?? {'budget': 2500, 'fit': 'regular'},
    );
    await t.pumpWidget(
      ProviderScope(
        overrides: testOverrides(sp, signedIn: true, account: account),
        retry: (_, _) => null,
        child: const DripApp(),
      ),
    );
    container = ProviderScope.containerOf(t.element(find.byType(MaterialApp)));
    await settle(t, 1600);
  }

  Future<void> openFromHome(WidgetTester t) async {
    await t.scrollUntilVisible(
      find.text('Style Quiz'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await settle(t, 300);
    await t.tap(find.text('Style Quiz'));
    await settle(t);
    expect(find.byType(StyleQuizScreen), findsOneWidget);
  }

  testWidgets('Home opens it, a tap answers and moves on, and it saves', (
    t,
  ) async {
    await boot(t);
    expect(find.text('10 QUICK TAPS'), findsOneWidget);
    await openFromHome(t);

    for (final (i, q) in styleQuiz.indexed) {
      expect(find.text(q.question.toUpperCase()), findsOneWidget);
      expect(find.text('${i + 1}/${styleQuiz.length}'), findsOneWidget);
      await t.tap(find.text(q.options.first.label));
      await settle(t, 800);
    }

    expect(find.text('YOUR FEED IS TUNED'), findsOneWidget);
    final saved = (await account.me()).onboardingPrefs;
    // The onboarding picks are kept; the answers sit beside them.
    expect(saved['budget'], 2500);
    expect(saved['fit'], 'regular');
    final quiz = saved['quiz'] as Map;
    expect(quiz['v'], 1);
    for (final q in styleQuiz) {
      expect(quiz[q.id], q.options.first.id);
    }

    await t.tap(find.text('BACK TO HOME'));
    await settle(t);
    await t.scrollUntilVisible(
      find.text('Style Quiz'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('RETAKE'), findsOneWidget);
  });

  testWidgets('skip and back move between questions without answering', (
    t,
  ) async {
    await boot(t);
    container.read(routerProvider).push('/quiz');
    await settle(t);
    await t.tap(find.text('SKIP'));
    await settle(t);
    expect(find.text(styleQuiz[1].question.toUpperCase()), findsOneWidget);
    await t.tap(find.text('BACK'));
    await settle(t);
    expect(find.text(styleQuiz[0].question.toUpperCase()), findsOneWidget);
  });

  testWidgets('leaving halfway keeps what was answered, and picks up there', (
    t,
  ) async {
    await boot(t);
    container.read(routerProvider).push('/quiz');
    await settle(t);
    await t.tap(find.text(styleQuiz[0].options[2].label));
    await settle(t, 800);
    await t.tap(find.text(styleQuiz[1].options[1].label));
    await settle(t, 800);
    await t.tap(find.bySemanticsLabel('Close the quiz'));
    await settle(t);
    expect(find.byType(StyleQuizScreen), findsNothing);

    final quiz = (await account.me()).onboardingPrefs['quiz'] as Map;
    expect(quiz['spend'], styleQuiz[0].options[2].id);
    expect(quiz['buy'], styleQuiz[1].options[1].id);
    expect(quiz.containsKey('next'), isFalse);

    // Back in: it opens on the first unanswered question.
    container.invalidate(accountProvider);
    await settle(t, 300);
    container.read(routerProvider).push('/quiz');
    await settle(t);
    expect(find.text(styleQuiz[2].question.toUpperCase()), findsOneWidget);
  });
}
