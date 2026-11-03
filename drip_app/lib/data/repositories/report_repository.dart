import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

import '../api/api_client.dart';
import 'local_store.dart';

/// A bug report from the app: what kind of problem, what happened, and the
/// context needed to find it (the screen, the fit, the app and OS version).
/// Never photos, never the account's content.
class BugReport {
  const BugReport({
    required this.kind,
    required this.message,
    required this.screen,
    required this.appVersion,
    required this.platform,
    this.fitId,
    this.createdAt,
  });

  /// `broken | wrong_piece | image | slow | other`.
  final String kind;
  final String message;

  /// Where it happened (`scroll`).
  final String screen;

  /// The fit on screen, when the user chose to attach it.
  final String? fitId;
  final String appVersion;

  /// `android 14`, `ios 18.1`.
  final String platform;
  final DateTime? createdAt;

  /// What this phone is, for [platform].
  static String thisPlatform() {
    if (kIsWeb) return 'web';
    return '${Platform.operatingSystem} ${Platform.operatingSystemVersion}'
        .trim();
  }

  Map<String, dynamic> toJson() => {
    'kind': kind,
    'message': message,
    'screen': screen,
    'fitId': ?fitId,
    'appVersion': appVersion,
    'platform': platform,
    'createdAt': (createdAt ?? DateTime.now()).toUtc().toIso8601String(),
  };
}

/// Whether a report reached Drip, or is waiting on this phone to be sent.
enum ReportOutcome { sent, queued }

abstract interface class ReportRepository {
  /// Sends [report], and any sent earlier that couldn't go yet.
  Future<ReportOutcome> submit(BugReport report);

  /// Tries again to send reports waiting on this phone.
  Future<void> flush();
}

/// `POST /reports` (Backend_app docs/API.md "Reports"). While Drip can't be
/// reached (offline, a 5xx, or over the hourly limit), reports wait in
/// [LocalStore] and go with the next one.
class ApiReportRepository implements ReportRepository {
  ApiReportRepository(this._api, this._store);
  final ApiClient _api;
  final LocalStore _store;

  /// Most reports kept waiting on the phone; the oldest go first.
  static const _maxQueued = 20;

  @override
  Future<ReportOutcome> submit(BugReport report) async {
    final body = report.toJson();
    await flush();
    try {
      await _api.post('/reports', body);
      return ReportOutcome.sent;
    } on ApiException catch (e) {
      if (_retryLater(e)) {
        await _queue(body);
        return ReportOutcome.queued;
      }
      rethrow;
    }
  }

  @override
  Future<void> flush() async {
    final waiting = _store.queuedReports;
    if (waiting.isEmpty) return;
    final left = <String>[];
    for (final (i, raw) in waiting.indexed) {
      try {
        await _api.post('/reports', jsonDecode(raw) as Map<String, dynamic>);
      } on ApiException catch (e) {
        if (_retryLater(e)) {
          // Still can't send: keep this one and the rest for later.
          left.addAll(waiting.skip(i));
          break;
        }
        // Refused for good (400, 413): drop it rather than retry forever.
      } on FormatException {
        // A corrupt entry: drop it.
      }
    }
    await _store.setQueuedReports(left);
  }

  /// Worth sending again later: offline, the server down, over the hourly
  /// limit (429), or an older backend without /reports (404).
  static bool _retryLater(ApiException e) =>
      e.isNetwork || e.isRateLimited || e.status == 404 || e.status >= 500;

  Future<void> _queue(Map<String, dynamic> body) async {
    final next = [..._store.queuedReports, jsonEncode(body)];
    await _store.setQueuedReports(
      next.length > _maxQueued ? next.sublist(next.length - _maxQueued) : next,
    );
  }
}

/// Fixture reports for tests: kept in memory.
class MockReportRepository implements ReportRepository {
  final sent = <BugReport>[];

  @override
  Future<ReportOutcome> submit(BugReport report) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    sent.add(report);
    return ReportOutcome.sent;
  }

  @override
  Future<void> flush() async {}
}
