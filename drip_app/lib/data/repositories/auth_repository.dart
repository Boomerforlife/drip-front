import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../core/config/env.dart';

/// Who is signed in, as far as the app needs to know: the Google identity
/// Supabase hands back. The backend keys everything off the JWT, never these.
class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    this.name,
    this.avatarUrl,
  });

  final String id;
  final String email;
  final String? name;
  final String? avatarUrl;
}

/// Sign-in and the session token. Supabase is used **only** for auth: every
/// read and write goes through the Drip API.
abstract interface class AuthRepository {
  AuthUser? get currentUser;
  bool get isSignedIn;

  /// The bearer token for API calls, or null when signed out.
  String? get accessToken;

  /// Emits whenever the user signs in or out (including token-expiry sign-outs).
  Stream<AuthUser?> get changes;

  /// Opens Google's sign-in page. Completes when the browser was launched; the
  /// signed-in user arrives later on [changes] (after the deep link returns).
  Future<void> signInWithGoogle();

  /// Refreshes the session once. False when it can't be refreshed.
  Future<bool> refresh();

  Future<void> signOut();
}

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._auth);

  final sb.GoTrueClient _auth;

  static AuthUser? _toUser(sb.User? u) {
    if (u == null) return null;
    final meta = u.userMetadata ?? const {};
    String? str(String k) {
      final v = meta[k];
      return v is String && v.trim().isNotEmpty ? v.trim() : null;
    }

    return AuthUser(
      id: u.id,
      email: u.email ?? str('email') ?? '',
      name: str('full_name') ?? str('name'),
      avatarUrl: str('avatar_url') ?? str('picture'),
    );
  }

  @override
  AuthUser? get currentUser =>
      _auth.currentSession == null ? null : _toUser(_auth.currentUser);

  @override
  bool get isSignedIn => _auth.currentSession != null;

  @override
  String? get accessToken => _auth.currentSession?.accessToken;

  @override
  Stream<AuthUser?> get changes => _auth.onAuthStateChange
      .where(
        (s) =>
            s.event == sb.AuthChangeEvent.signedIn ||
            s.event == sb.AuthChangeEvent.signedOut ||
            s.event == sb.AuthChangeEvent.userUpdated ||
            s.event == sb.AuthChangeEvent.initialSession,
      )
      .map((s) => _toUser(s.session?.user));

  @override
  Future<void> signInWithGoogle() async {
    final launched = await _auth.signInWithOAuth(
      sb.OAuthProvider.google,
      redirectTo: Env.authRedirect,
    );
    if (!launched) {
      throw const AuthFailure("Couldn't open Google sign-in");
    }
  }

  @override
  Future<bool> refresh() async {
    if (_auth.currentSession == null) return false;
    try {
      final res = await _auth.refreshSession();
      return res.session != null;
    } on sb.AuthException {
      return false;
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } on sb.AuthException {
      // Already invalid on the server: the local session is cleared anyway.
    }
  }
}

class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;

  @override
  String toString() => message;
}
