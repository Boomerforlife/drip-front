import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../repositories/auth_repository.dart';

/// A failed API call. [status] is the HTTP status (0 for "never reached the
/// server"); [message] is the backend's `{ error }` text when there is one.
class ApiException implements Exception {
  const ApiException(
    this.status,
    this.message, {
    this.details = const [],
    this.retryAfter,
  });

  final int status;
  final String message;
  final List<String> details;

  /// From the `Retry-After` header on a 429.
  final Duration? retryAfter;

  bool get isNetwork => status == 0;
  bool get isUnauthorized => status == 401;
  bool get isNotFound => status == 404;
  bool get isRateLimited => status == 429;

  /// Short, human copy for toasts and error states.
  String get friendly => switch (status) {
    0 => "Can't reach Drip. Check your connection.",
    401 => 'Your session ended. Sign in again.',
    429 => 'Slow down a little, try again in a moment.',
    >= 500 => 'Something went wrong on our side. Try again.',
    _ => message,
  };

  @override
  String toString() => 'ApiException($status): $message';
}

/// The one door to the Drip API (`docs/API.md` in Backend_app).
///
/// - Adds `Authorization: Bearer <jwt>` to every call except `/healthz` and
///   `/meta`.
/// - On a 401 it refreshes the session once and retries; if that fails too,
///   it signs out (the router then returns to the welcome screen).
/// - On a 429 it waits out a short `Retry-After` once, else surfaces it.
/// - Errors come back as `{ "error": "...", "details"?: [...] }`.
class ApiClient {
  ApiClient({
    required String baseUrl,
    required this._auth,
    http.Client? client,
    this.timeout = const Duration(seconds: 20),
    this.uploadHeaders = const {},
  }) : _base = Uri.parse(baseUrl.endsWith('/') ? baseUrl : '$baseUrl/'),
       _http = client ?? http.Client();

  final Uri _base;
  final AuthRepository _auth;
  final http.Client _http;
  final Duration timeout;

  /// Extra headers for direct-to-storage uploads (the Supabase `apikey`).
  final Map<String, String> uploadHeaders;

  static const _publicPaths = {'/healthz', '/meta'};

  /// Longest `Retry-After` worth waiting for silently before giving up.
  static const _maxSilentWait = Duration(seconds: 4);

  Future<dynamic> get(String path, {Map<String, String>? query}) =>
      _send('GET', path, query: query);

  Future<dynamic> post(String path, [Object? body]) =>
      _send('POST', path, body: body);

  Future<dynamic> put(String path, [Object? body]) =>
      _send('PUT', path, body: body);

  Future<dynamic> patch(String path, [Object? body]) =>
      _send('PATCH', path, body: body);

  Future<dynamic> delete(String path, [Object? body]) =>
      _send('DELETE', path, body: body);

  /// PUTs raw bytes to a one-time signed upload URL the API handed out. The
  /// image never passes through the API server.
  Future<void> upload(
    String uploadUrl,
    Uint8List bytes, {
    required String contentType,
  }) async {
    final http.Response res;
    try {
      res = await _http
          .put(
            Uri.parse(uploadUrl),
            headers: {...uploadHeaders, 'Content-Type': contentType},
            body: bytes,
          )
          .timeout(const Duration(seconds: 60));
    } on TimeoutException {
      throw const ApiException(0, 'Upload timed out');
    } on SocketException {
      throw const ApiException(0, 'No connection');
    } on http.ClientException catch (e) {
      throw ApiException(0, e.message);
    }
    if (res.statusCode >= 300) {
      throw ApiException(res.statusCode, 'Upload failed (${res.statusCode})');
    }
  }

  Uri _uri(String path, Map<String, String>? query) {
    final rel = path.startsWith('/') ? path.substring(1) : path;
    final uri = _base.resolve(rel);
    return query == null || query.isEmpty
        ? uri
        : uri.replace(queryParameters: query);
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    bool retried = false,
    bool waited = false,
  }) async {
    final needsAuth = !_publicPaths.contains(path);
    final token = _auth.accessToken;
    if (needsAuth && token == null) {
      throw const ApiException(401, 'Not signed in');
    }

    final req = http.Request(method, _uri(path, query))
      ..headers['Accept'] = 'application/json';
    if (needsAuth) req.headers['Authorization'] = 'Bearer $token';
    if (body != null) {
      req.headers['Content-Type'] = 'application/json';
      req.body = jsonEncode(body);
    }

    final http.Response res;
    try {
      res = await http.Response.fromStream(
        await _http.send(req).timeout(timeout),
      ).timeout(timeout);
    } on TimeoutException {
      throw const ApiException(0, 'Request timed out');
    } on SocketException {
      throw const ApiException(0, 'No connection');
    } on http.ClientException catch (e) {
      throw ApiException(0, e.message);
    }

    if (res.statusCode == 401 && needsAuth && !retried) {
      if (await _auth.refresh()) {
        return _send(method, path, query: query, body: body, retried: true);
      }
      await _auth.signOut();
      throw _error(res);
    }
    if (res.statusCode == 401 && needsAuth) {
      await _auth.signOut();
      throw _error(res);
    }
    if (res.statusCode == 429 && !waited) {
      final wait = _retryAfter(res);
      if (wait != null && wait <= _maxSilentWait) {
        await Future<void>.delayed(wait);
        return _send(
          method,
          path,
          query: query,
          body: body,
          retried: retried,
          waited: true,
        );
      }
    }
    if (res.statusCode >= 400) throw _error(res);
    if (res.statusCode == 204 || res.body.isEmpty) return null;
    try {
      return jsonDecode(utf8.decode(res.bodyBytes));
    } on FormatException {
      throw ApiException(res.statusCode, 'Unexpected response from the API');
    }
  }

  static Duration? _retryAfter(http.Response res) {
    final v = int.tryParse(res.headers['retry-after'] ?? '');
    return v == null ? null : Duration(seconds: v);
  }

  static ApiException _error(http.Response res) {
    var message = 'Request failed (${res.statusCode})';
    var details = const <String>[];
    try {
      final json = jsonDecode(utf8.decode(res.bodyBytes));
      if (json is Map) {
        final e = json['error'];
        if (e is String && e.isNotEmpty) message = e;
        final d = json['details'];
        if (d is List) details = [for (final x in d) '$x'];
      }
    } on FormatException {
      // Not JSON (a proxy error page): keep the generic message.
    }
    if (kDebugMode) {
      debugPrint('[api] ${res.request?.method} ${res.request?.url.path} '
          '→ ${res.statusCode}: $message');
    }
    return ApiException(
      res.statusCode,
      message,
      details: details,
      retryAfter: _retryAfter(res),
    );
  }
}
