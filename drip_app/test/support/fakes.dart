import 'dart:async';

import 'package:drip/data/providers.dart';
import 'package:drip/data/repositories/account_repository.dart';
import 'package:drip/data/repositories/auth_repository.dart';
import 'package:drip/data/repositories/colour_repository.dart';
import 'package:drip/data/repositories/feed_repository.dart';
import 'package:drip/data/repositories/outfit_repository.dart';
import 'package:drip/data/repositories/studio_repository.dart';
import 'package:drip/data/repositories/stylist_repository.dart';
import 'package:drip/data/repositories/wardrobe_repository.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:shared_preferences/shared_preferences.dart';

/// A signed-in Google user for tests.
const testUser = AuthUser(
  id: 'u_test',
  email: 'taylor.vance@gmail.com',
  name: 'Taylor Vance',
);

/// Stands in for Supabase auth: sign-in completes at once (no browser).
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({bool signedIn = false})
    : _user = signedIn ? testUser : null;

  AuthUser? _user;
  final _changes = StreamController<AuthUser?>.broadcast();
  int refreshes = 0;

  /// What [refresh] reports (a refreshed token, or a dead session).
  bool refreshSucceeds = true;
  String token = 'test-token';

  @override
  AuthUser? get currentUser => _user;

  @override
  bool get isSignedIn => _user != null;

  @override
  String? get accessToken => _user == null ? null : token;

  @override
  Stream<AuthUser?> get changes => _changes.stream;

  @override
  Future<void> signInWithGoogle() async {
    _user = testUser;
    _changes.add(_user);
  }

  @override
  Future<bool> refresh() async {
    refreshes++;
    if (refreshSucceeds) token = 'refreshed-token';
    return refreshSucceeds;
  }

  @override
  Future<void> signOut() async {
    _user = null;
    _changes.add(null);
  }
}

/// Every backend seam replaced with its in-memory fixture.
/// Pass [feed] or [outfits] to swap in a different fixture (a provider can
/// only be overridden once per container).
List<Override> testOverrides(
  SharedPreferences prefs, {
  bool signedIn = false,
  FakeAuthRepository? auth,
  FeedRepository? feed,
  OutfitRepository? outfits,
}) => [
  sharedPreferencesProvider.overrideWithValue(prefs),
  authRepositoryProvider.overrideWithValue(
    auth ?? FakeAuthRepository(signedIn: signedIn),
  ),
  accountRepositoryProvider.overrideWith((_) => MockAccountRepository()),
  feedRepositoryProvider.overrideWith((_) => feed ?? MockFeedRepository()),
  outfitRepositoryProvider.overrideWith(
    (_) => outfits ?? MockOutfitRepository(),
  ),
  wardrobeRepositoryProvider.overrideWith((_) => MockWardrobeRepository()),
  studioRepositoryProvider.overrideWith((_) => MockStudioRepository()),
  stylistRepositoryProvider.overrideWith((_) => MockStylistRepository()),
  colourRepositoryProvider.overrideWith((_) => MockColourRepository()),
];
