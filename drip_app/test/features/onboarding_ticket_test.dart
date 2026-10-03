import 'package:drip/app.dart';
import 'package:drip/features/onboarding/onboarding_steps.dart';
import 'package:drip/features/onboarding/onboarding_ticket.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fakes.dart';
import '../test_fonts.dart';

const _picks =
    '{"gender":"male","moods":["streetwear","y2k"],"colours":["red","cream"],'
    '"brands":["Nike","Zara","Uniqlo","Snitch"],"fit":"oversized",'
    '"budget":3500,"name":"Taylor"}';

Future<void> _settle(WidgetTester t, [int ms = 700]) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _boot(WidgetTester t, String step, [String flow = _picks]) async {
  SharedPreferences.setMockInitialValues({
    'onboarding.step': step,
    'onboarding.flow': flow,
  });
  final sp = await SharedPreferences.getInstance();
  t.view.physicalSize = const Size(390, 844) * 2;
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: testOverrides(sp),
      retry: (_, _) => null,
      child: const DripApp(),
    ),
  );
  await _settle(t, 3200);
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets('labels fill with their colour: real logos, or a type mark', (
    t,
  ) async {
    await _boot(t, 'labels');
    // Every label with a logo draws it (seven of the fourteen).
    expect(find.byType(SvgPicture), findsNWidgets(7));
    // No logo for these: set as words, never an imitation mark.
    for (final mark in ['LEVI’S', 'bewakoof', 'SNITCH', 'THRIFTED']) {
      expect(find.text(mark), findsOneWidget, reason: mark);
    }
    expect(find.text('Nike'), findsNothing);
  });

  testWidgets('the ticket carries the picks, in one readable summary', (
    t,
  ) async {
    final sem = t.ensureSemantics();
    await _boot(t, 'ticket');
    await _settle(t, 1500);
    expect(find.text('Taylor'), findsWidgets);
    expect(find.text('Y2K + STREETWEAR'), findsOneWidget);
    expect(find.text('≤₹3,500 a piece'), findsOneWidget);
    expect(find.text('Nike · Zara · Uniqlo +1'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp(r'^Your Drip ticket, holder Taylor')),
      findsOneWidget,
    );
    sem.dispose();
  });

  testWidgets('the build prints the ticket, which then stays in place', (
    t,
  ) async {
    await _boot(t, 'name');
    await t.tap(find.text('PRINT MY TICKET →'));
    await t.pump(const Duration(milliseconds: 500));
    expect(find.byType(BuildStep), findsOneWidget);
    expect(find.byType(DripTicket), findsOneWidget);
    expect(find.textContaining('· '), findsWidgets);
    final during = t.getRect(find.byType(DripTicket));
    await _settle(t, 4000);
    // The finished ticket arrives without re-entering, in the same spot.
    final step = t.widget<TicketStep>(find.byType(TicketStep));
    expect(step.printed, isTrue);
    expect(t.getRect(find.byType(DripTicket)).top, during.top);
    expect(find.text('VERIFIED ✦'), findsOneWidget);
  });

  testWidgets('the pass on the name step takes the name as it is typed', (
    t,
  ) async {
    await _boot(
      t,
      'name',
      '{"gender":"male","moods":["y2k"],"colours":["red"]}',
    );
    expect(find.text('YOUR NAME'), findsOneWidget);
    await t.enterText(find.byType(TextField), 'Alex');
    await t.pump();
    expect(find.text('ALEX'), findsOneWidget);
  });
}
