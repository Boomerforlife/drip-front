import 'dart:typed_data';

import '../api/api_client.dart';
import '../models/account.dart';
import '../models/meta.dart';

/// The caller's own backend profile (`/me`) and the server-owned lists
/// (`/meta`). Selfies never go through here: they stay on the device
/// (`LocalSelfie`).
abstract interface class AccountRepository {
  Future<Account> me();

  /// `PATCH /me`: onboarding picks, style tags, skin tone.
  Future<void> updateProfile({
    Map<String, dynamic>? onboardingPrefs,
    List<String>? styleTags,
    String? skinTone,
  });

  /// `PATCH /me { username }`. Throws [ApiException] 409 when it's taken,
  /// 400 when it isn't a valid handle.
  Future<Account> setUsername(String username);

  /// `PATCH /me { displayName }` (null clears it, back to the Google name).
  Future<Account> setDisplayName(String? name);

  Future<UsernameCheck> usernameAvailable(String username);

  /// The public profile photo: signed upload → PUT bytes → confirm. Returns
  /// its URL.
  Future<String> uploadPhoto(Uint8List bytes, {required String contentType});
  Future<void> removePhoto();

  /// `DELETE /me`: removes the account, its rows and its files.
  Future<void> deleteAccount();

  Future<AppMeta> meta();
}

class ApiAccountRepository implements AccountRepository {
  ApiAccountRepository(this._api);
  final ApiClient _api;

  @override
  Future<Account> me() async =>
      Account.fromJson((await _api.get('/me') as Map).cast<String, dynamic>());

  @override
  Future<void> updateProfile({
    Map<String, dynamic>? onboardingPrefs,
    List<String>? styleTags,
    String? skinTone,
  }) async {
    await _api.patch('/me', {
      'onboardingPrefs': ?onboardingPrefs,
      'styleTags': ?styleTags,
      'skinTone': ?skinTone,
    });
  }

  @override
  Future<Account> setUsername(String username) async => Account.fromJson(
    (await _api.patch('/me', {'username': username}) as Map)
        .cast<String, dynamic>(),
  );

  @override
  Future<Account> setDisplayName(String? name) async => Account.fromJson(
    (await _api.patch('/me', {'displayName': name}) as Map)
        .cast<String, dynamic>(),
  );

  @override
  Future<UsernameCheck> usernameAvailable(String username) async {
    final res =
        await _api.get('/me/username-available', query: {'u': username}) as Map;
    return UsernameCheck(
      res['username'] as String? ?? username,
      available: res['available'] as bool? ?? false,
      reason: res['reason'] as String?,
    );
  }

  @override
  Future<String> uploadPhoto(
    Uint8List bytes, {
    required String contentType,
  }) async {
    final slot = (await _api.post('/me/photo/upload-url', {
      'contentType': contentType,
    }) as Map);
    await _api.upload(
      slot['uploadUrl'] as String,
      bytes,
      contentType: contentType,
    );
    final res = await _api.post('/me/photo', {'path': slot['path']}) as Map;
    return res['photoUrl'] as String;
  }

  @override
  Future<void> removePhoto() => _api.delete('/me/photo');

  @override
  Future<void> deleteAccount() => _api.delete('/me', {'confirm': 'DELETE'});

  @override
  Future<AppMeta> meta() async => AppMeta.fromJson(
    (await _api.get('/meta') as Map).cast<String, dynamic>(),
  );
}

/// Same rules as the API (`usernameProblem` in Backend_app `src/api/me.ts`),
/// so the sheet can say what's wrong before asking the server.
String? usernameProblem(String u) {
  if (!RegExp(r'^[a-z0-9._]{3,24}$').hasMatch(u)) {
    return '3–24 characters: letters, numbers, dots and underscores';
  }
  if (!RegExp('[a-z0-9]').hasMatch(u)) {
    return 'Needs at least one letter or number';
  }
  const reserved = {
    'drip', 'admin', 'support', 'help', 'official', 'team', 'taylor', //
    'staff', 'me', 'settings', 'api',
  };
  if (reserved.contains(u)) return 'That username is reserved';
  return null;
}

/// In-memory stand-in for tests.
class MockAccountRepository implements AccountRepository {
  /// [onboardingPrefs]: picks the account already holds (a returning user).
  MockAccountRepository({
    Map<String, dynamic> onboardingPrefs = const {},
    Set<String> takenUsernames = const {'taken_name'},
  }) : _taken = {...takenUsernames},
       _me = Account(
         id: 'me',
         genCreditsRemaining: 3,
         onboardingPrefs: onboardingPrefs,
       );

  Account _me;
  final Set<String> _taken;
  bool deleted = false;

  /// Profile photos uploaded (tests check what reached the "server").
  int photoUploads = 0;

  @override
  Future<Account> me() async => _me;

  @override
  Future<void> updateProfile({
    Map<String, dynamic>? onboardingPrefs,
    List<String>? styleTags,
    String? skinTone,
  }) async {
    _me = _me.copyWith(
      onboardingPrefs: onboardingPrefs,
      styleTags: styleTags,
      skinTone: skinTone,
    );
  }

  @override
  Future<Account> setUsername(String username) async {
    final u = username.trim().toLowerCase();
    final problem = usernameProblem(u);
    if (problem != null) throw ApiException(400, problem);
    if (_taken.contains(u)) {
      throw const ApiException(409, 'That username is taken');
    }
    return _me = _me.copyWith(username: u);
  }

  @override
  Future<Account> setDisplayName(String? name) async => _me = Account(
    id: _me.id,
    onboardingPrefs: _me.onboardingPrefs,
    styleTags: _me.styleTags,
    skinTone: _me.skinTone,
    genCreditsRemaining: _me.genCreditsRemaining,
    username: _me.username,
    displayName: name,
    photoUrl: _me.photoUrl,
  );

  @override
  Future<UsernameCheck> usernameAvailable(String username) async {
    final u = username.trim().toLowerCase();
    final problem = usernameProblem(u);
    if (problem != null) {
      return UsernameCheck(u, available: false, reason: problem);
    }
    final free = !_taken.contains(u) || _me.username == u;
    return UsernameCheck(
      u,
      available: free,
      reason: free ? null : 'That username is taken',
    );
  }

  @override
  Future<String> uploadPhoto(
    Uint8List bytes, {
    required String contentType,
  }) async {
    photoUploads++;
    const url = 'assets/images/avatar_taylor_vance.jpg';
    _me = _me.copyWith(photoUrl: url);
    return url;
  }

  @override
  Future<void> removePhoto() async => _me = _me.copyWith(clearPhoto: true);

  @override
  Future<void> deleteAccount() async => deleted = true;

  @override
  Future<AppMeta> meta() async => const AppMeta(
    occasions: [
      MetaOption('concert', 'Concert'),
      MetaOption('date-night', 'Date Night'),
      MetaOption('wedding', 'Wedding'),
    ],
    vibes: [
      MetaOption('y2k-goth', 'Y2K Goth'),
      MetaOption('experimental-cyber', 'Experimental Cyber'),
    ],
    moods: [MetaOption('y2k', 'Y2K'), MetaOption('streetwear', 'Streetwear')],
    discoverCategories: [MetaOption('y2k', 'Y2K')],
    slots: ['top', 'bottom', 'outer', 'dress', 'shoes', 'accessory'],
    colourFamilies: ['black', 'white', 'blue'],
    seasons: ['summer', 'winter', 'all-season'],
    scenes: [MetaOption('studio', 'STUDIO'), MetaOption('tokyo', 'TOKYO')],
    currency: 'INR',
    genCreditsPerUser: 3,
  );
}
