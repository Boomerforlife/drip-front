import 'package:drip/app.dart';
import 'package:drip/routing/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fakes.dart';
import 'test_fonts.dart';

/// Every screen must lay out without overflow or errors on small phones,
/// large phones and tablets.
const _routes = [
  '/home',
  '/scroll',
  '/scroll?id=o_gray',
  '/themes',
  '/ootd/ootd_moto',
  '/create',
  '/discover',
  '/search',
  '/search/results?q=cyber',
  '/outfit/o_cyber_flare',
  '/studio',
  '/studio/builder',
  '/stylist',
  '/signin',
  '/wardrobe',
  '/wardrobe/capture',
  '/wardrobe/item/w_biker',
  '/saved',
  '/me',
  '/me/colour-theory',
  '/u/sofiamae',
  '/u/ghost_tech',
  '/followers',
  '/following',
  '/activity',
  '/settings',
  '/privacy',
  '/photoshoot',
];

const _sizes = <String, Size>{
  'small android 320x568': Size(320, 568),
  'android 360x740': Size(360, 740),
  'iPhone 390x844': Size(390, 844),
  'large phone 430x932': Size(430, 932),
  'tablet 768x1024': Size(768, 1024),
};

void main() {
  setUpAll(loadAppFonts);

  for (final entry in _sizes.entries) {
    testWidgets('all screens lay out cleanly on ${entry.key}', (t) async {
      SharedPreferences.setMockInitialValues({'session.onboarded': true});
      final sp = await SharedPreferences.getInstance();
      t.view.physicalSize = entry.value * 2;
      t.view.devicePixelRatio = 2;
      addTearDown(t.view.reset);

      await t.pumpWidget(
        ProviderScope(
          overrides: testOverrides(sp, signedIn: true),
          retry: (_, _) => null,
          child: const DripApp(),
        ),
      );
      final container = ProviderScope.containerOf(
        t.element(find.byType(MaterialApp)),
      );
      for (var i = 0; i < 34; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }

      final router = container.read(routerProvider);
      final issues = <String>{};
      var current = '';
      final previous = FlutterError.onError;
      FlutterError.onError = (details) {
        final e = details.exception;
        final text = e is FlutterError
            ? e.diagnostics.take(4).map((n) => n.toString()).join(' ')
            : e.toString();
        final where =
            RegExp(r'lib/[\w/.]+\.dart:\d+').firstMatch(text)?.group(0) ?? '?';
        final what = text.split('\n').first;
        issues.add('$current: $what @ $where');
      };

      for (final route in _routes) {
        current = route;
        router.go(route);
        for (var i = 0; i < 12; i++) {
          await t.pump(const Duration(milliseconds: 100));
        }
      }
      FlutterError.onError = previous;
      expect(issues, isEmpty, reason: '${entry.key}\n${issues.join('\n')}');
    });
  }
}
