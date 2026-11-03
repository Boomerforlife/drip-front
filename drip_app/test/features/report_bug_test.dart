import 'dart:convert';

import 'package:drip/app.dart';
import 'package:drip/data/api/api_client.dart';
import 'package:drip/data/repositories/local_store.dart';
import 'package:drip/data/repositories/report_repository.dart';
import 'package:drip/routing/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fakes.dart';
import '../test_fonts.dart';

const _report = BugReport(
  kind: 'broken',
  message: 'The save button did nothing',
  screen: 'scroll',
  fitId: 'f1',
  appVersion: '1.0.0+1',
  platform: 'android 14',
);

void main() {
  setUpAll(loadAppFonts);

  group('ApiReportRepository', () {
    late LocalStore store;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      store = LocalStore(await SharedPreferences.getInstance());
    });

    ApiReportRepository repo(MockClientHandler handler) => ApiReportRepository(
      ApiClient(
        baseUrl: 'https://api.test',
        auth: FakeAuthRepository(signedIn: true),
        client: MockClient(handler),
      ),
      store,
    );

    test('sends the report with its context', () async {
      late Map<String, dynamic> body;
      final outcome = await repo((req) async {
        expect(req.url.path, '/reports');
        body = jsonDecode(req.body) as Map<String, dynamic>;
        return http.Response('{}', 201);
      }).submit(_report);
      expect(outcome, ReportOutcome.sent);
      expect(body['kind'], 'broken');
      expect(body['fitId'], 'f1');
      expect(body['screen'], 'scroll');
      expect(body['platform'], 'android 14');
      expect(store.queuedReports, isEmpty);
    });

    test(
      'keeps it on the phone until /reports exists, then sends it',
      () async {
        final down = repo(
          (_) async => http.Response('{"error":"Not found"}', 404),
        );
        expect(await down.submit(_report), ReportOutcome.queued);
        expect(store.queuedReports, hasLength(1));

        final paths = <String>[];
        final up = repo((req) async {
          paths.add(jsonDecode(req.body)['message'] as String);
          return http.Response('{}', 201);
        });
        expect(
          await up.submit(
            const BugReport(
              kind: 'other',
              message: 'Second one',
              screen: 'scroll',
              appVersion: '1.0.0+1',
              platform: 'android 14',
            ),
          ),
          ReportOutcome.sent,
        );
        expect(paths, ['The save button did nothing', 'Second one']);
        expect(store.queuedReports, isEmpty);
      },
    );

    test(
      'over the hourly limit (429), reports wait instead of being lost',
      () async {
        final limited = repo(
          (_) async => http.Response(
            '{"error":"Too many reports"}',
            429,
            headers: {'retry-after': '1800'},
          ),
        );
        expect(await limited.submit(_report), ReportOutcome.queued);
        await limited.flush();
        expect(store.queuedReports, hasLength(1));
      },
    );

    test('a refused report is not retried forever', () async {
      await store.setQueuedReports([jsonEncode(_report.toJson())]);
      await repo((_) async => http.Response('{"error":"Bad"}', 400)).flush();
      expect(store.queuedReports, isEmpty);
    });
  });

  testWidgets('the feed has Report a bug below Share; it sends with the fit', (
    t,
  ) async {
    SharedPreferences.setMockInitialValues({'session.onboarded': true});
    final sp = await SharedPreferences.getInstance();
    t.view.physicalSize = const Size(390, 844) * 2;
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    final reports = MockReportRepository();
    await t.pumpWidget(
      ProviderScope(
        overrides: testOverrides(sp, signedIn: true, reports: reports),
        retry: (_, _) => null,
        child: const DripApp(),
      ),
    );
    final container = ProviderScope.containerOf(
      t.element(find.byType(MaterialApp)),
    );
    for (var i = 0; i < 16; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    container.read(routerProvider).go('/scroll?id=o_gray');
    for (var i = 0; i < 10; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }

    final share = t.getRect(find.byIcon(Icons.ios_share_rounded));
    final bug = t.getRect(find.byIcon(Icons.bug_report_outlined));
    expect(bug.top, greaterThan(share.bottom), reason: 'below Share');

    await t.tap(find.byIcon(Icons.bug_report_outlined));
    for (var i = 0; i < 6; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('REPORT A BUG'), findsOneWidget);

    await t.tap(find.text('Wrong piece or link'));
    await t.enterText(find.byType(TextField), 'The shoes link opens a hat');
    await t.pump();
    await t.tap(find.text('SEND REPORT'));
    for (var i = 0; i < 8; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }

    expect(reports.sent, hasLength(1));
    final r = reports.sent.single;
    expect(r.kind, 'wrong_piece');
    expect(r.message, 'The shoes link opens a hat');
    expect(r.fitId, 'o_gray');
    expect(r.screen, 'scroll');
    expect(find.text('REPORT A BUG'), findsNothing);
  });
}
