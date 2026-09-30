import 'dart:typed_data';

import '../api/api_client.dart';
import '../models/account.dart';
import '../models/meta.dart';

/// The caller's own backend profile (`/me`) and the server-owned lists
/// (`/meta`).
abstract interface class AccountRepository {
  Future<Account> me();

  /// `PATCH /me`: only these three fields are writable.
  Future<void> updateProfile({
    Map<String, dynamic>? onboardingPrefs,
    List<String>? styleTags,
    String? skinTone,
  });

  /// Signed upload → PUT bytes → confirm. Returns how many avatars are kept.
  Future<int> uploadAvatar(Uint8List bytes, {required String contentType});

  /// `DELETE /me`: removes the account, its rows and private files.
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
  Future<int> uploadAvatar(
    Uint8List bytes, {
    required String contentType,
  }) async {
    final slot = (await _api.post('/me/avatar/upload-url', {
      'contentType': contentType,
    }) as Map);
    await _api.upload(
      slot['uploadUrl'] as String,
      bytes,
      contentType: contentType,
    );
    final res = await _api.post('/me/avatar', {'path': slot['path']}) as Map;
    return (res['avatarCount'] as num?)?.toInt() ?? 1;
  }

  @override
  Future<void> deleteAccount() => _api.delete('/me', {'confirm': 'DELETE'});

  @override
  Future<AppMeta> meta() async =>
      AppMeta.fromJson((await _api.get('/meta') as Map).cast<String, dynamic>());
}

/// In-memory stand-in for tests.
class MockAccountRepository implements AccountRepository {
  Account _me = const Account(id: 'me', genCreditsRemaining: 3);
  bool deleted = false;

  @override
  Future<Account> me() async => _me;

  @override
  Future<void> updateProfile({
    Map<String, dynamic>? onboardingPrefs,
    List<String>? styleTags,
    String? skinTone,
  }) async {
    _me = Account(
      id: _me.id,
      onboardingPrefs: onboardingPrefs ?? _me.onboardingPrefs,
      styleTags: styleTags ?? _me.styleTags,
      skinTone: skinTone ?? _me.skinTone,
      genCreditsRemaining: _me.genCreditsRemaining,
      avatarUrls: _me.avatarUrls,
    );
  }

  @override
  Future<int> uploadAvatar(
    Uint8List bytes, {
    required String contentType,
  }) async {
    _me = Account(
      id: _me.id,
      onboardingPrefs: _me.onboardingPrefs,
      styleTags: _me.styleTags,
      genCreditsRemaining: _me.genCreditsRemaining,
      avatarUrls: ['assets/images/avatar_taylor_vance.jpg', ..._me.avatarUrls],
    );
    return _me.avatarUrls.length;
  }

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
