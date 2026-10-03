import 'package:drip/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fakes.dart';
import '../test_fonts.dart';

/// Every onboarding step (resumed straight into it) must lay out without
/// overflow on the smallest phone we support, a common phone and a tablet.
const _steps = [
  'welcome',
  'dressFor',
  'eras',
  'colours',
  'labels',
  'selfie',
  'name',
  'ticket',
];

const _sizes = <String, Size>{
  'small android 320x568': Size(320, 568),
  'iPhone 390x844': Size(390, 844),
  'tablet 768x1024': Size(768, 1024),
};

Future<void> _settle(WidgetTester t, int ms) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(loadAppFonts);

  for (final size in _sizes.entries) {
    testWidgets('onboarding lays out cleanly on ${size.key}', (t) async {
      t.view.physicalSize = size.value * 2;
      t.view.devicePixelRatio = 2;
      addTearDown(t.view.reset);

      for (final step in _steps) {
        SharedPreferences.setMockInitialValues({
          'onboarding.step': step,
          'onboarding.flow':
              '{"gender":"female","occasions":["concert","clubs"],'
              '"moods":["minimal","y2k"],"colours":["cream","red"],'
              '"genres":["Gorpcore"],"clothes":["Cargos"],"name":"Alexandria"}',
        });
        final sp = await SharedPreferences.getInstance();
        await t.pumpWidget(
          ProviderScope(
            key: UniqueKey(),
            overrides: testOverrides(sp),
            retry: (_, _) => null,
            child: const DripApp(),
          ),
        );
        await _settle(t, 4200);
        expect(t.takeException(), isNull, reason: '$step on ${size.key}');
      }
    });
  }
}
