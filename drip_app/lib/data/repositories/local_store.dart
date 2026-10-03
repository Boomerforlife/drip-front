import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/drip_skin.dart';
import '../models/settings.dart';

/// Thin typed wrapper over [SharedPreferences]. This is *device-local*
/// persistence (onboarding picks, settings, recent searches, follow list,
/// wardrobe rotation). The session itself lives in Supabase auth.
class LocalStore {
  LocalStore(this._prefs);

  final SharedPreferences _prefs;

  static const _onboarded = 'session.onboarded';
  static const _prefsPending = 'onboarding.pending';
  static const _rotation = 'wardrobe.rotation';
  static const _flow = 'onboarding.flow';
  static const _moods = 'onboarding.moods';
  static const _palette = 'onboarding.palette';
  static const _following = 'social.following';
  static const _recents = 'search.recents';

  bool get onboarded => _prefs.getBool(_onboarded) ?? false;
  Future<void> setOnboarded(bool v) => _prefs.setBool(_onboarded, v);

  /// Onboarding picks made before sign-in, not yet sent with `PATCH /me`.
  bool get prefsPending => _prefs.getBool(_prefsPending) ?? false;
  Future<void> setPrefsPending(bool v) => _prefs.setBool(_prefsPending, v);

  /// Where the user placed each piece on a Studio fit saved by an older build,
  /// before the API kept placement. Canvas key → [x, y, w, h] fractions.
  /// Read until the fit is saved again (see [forgetStudioFit]).
  Map<String, List<double>>? studioPositions(String fitId) {
    final raw = _prefs.getString('studio.positions.$fitId');
    if (raw == null) return null;
    try {
      final m = (jsonDecode(raw) as Map).cast<String, dynamic>();
      return {
        for (final e in m.entries)
          e.key: [for (final v in e.value as List) (v as num).toDouble()],
      };
    } catch (_) {
      return null;
    }
  }

  /// Extra accessories on a Studio fit saved by an older build, which sent
  /// the API only one: canvas key → piece JSON (`StudioPiece.fromJson`).
  Map<String, Map<String, dynamic>>? studioExtras(String fitId) {
    final raw = _prefs.getString('studio.extras.$fitId');
    if (raw == null) return null;
    try {
      return {
        for (final e in (jsonDecode(raw) as Map).entries)
          '${e.key}': (e.value as Map).cast<String, dynamic>(),
      };
    } catch (_) {
      return null;
    }
  }

  /// Drops what an older build kept for a Studio fit, once the server has it.
  Future<void> forgetStudioFit(String fitId) async {
    await _prefs.remove('studio.positions.$fitId');
    await _prefs.remove('studio.extras.$fitId');
  }

  /// Wardrobe items marked "in rotation" (no backend field for this yet).
  Set<String> get rotation => _prefs.getStringList(_rotation)?.toSet() ?? {};
  Future<void> setRotation(Set<String> ids) =>
      _prefs.setStringList(_rotation, ids.toList());

  /// All onboarding picks as one JSON document (see `OnboardingState`).
  String? get flowJson => _prefs.getString(_flow);
  Future<void> setFlowJson(String v) => _prefs.setString(_flow, v);

  Set<String>? get moodIds => _prefs.getStringList(_moods)?.toSet();
  Future<void> setMoodIds(Set<String> ids) =>
      _prefs.setStringList(_moods, ids.toList());

  Set<String>? get paletteIds => _prefs.getStringList(_palette)?.toSet();
  Future<void> setPaletteIds(Set<String> ids) =>
      _prefs.setStringList(_palette, ids.toList());

  Set<String>? get following => _prefs.getStringList(_following)?.toSet();
  Future<void> setFollowing(Set<String> handles) =>
      _prefs.setStringList(_following, handles.toList());

  List<String>? get recentSearches => _prefs.getStringList(_recents);
  Future<void> setRecentSearches(List<String> v) =>
      _prefs.setStringList(_recents, v);

  UserSettings loadSettings() {
    const d = UserSettings();
    return UserSettings(
      username: _prefs.getString('settings.username') ?? d.username,
      email: _prefs.getString('settings.email') ?? d.email,
      privateAccount: _prefs.getBool('settings.private') ?? d.privateAccount,
      whoCanInteract:
          InteractAudience.values.asNameMap()[_prefs.getString(
            'settings.interact',
          )] ??
          d.whoCanInteract,
      ootdVisibility:
          OotdVisibility.values.asNameMap()[_prefs.getString(
            'settings.visibility',
          )] ??
          d.ootdVisibility,
      pushNotifications: _prefs.getBool('settings.push') ?? d.pushNotifications,
      styleMatchAlerts:
          _prefs.getBool('settings.styleAlerts') ?? d.styleMatchAlerts,
      skin: DripSkin.fromId(_prefs.getString('settings.skin')),
      matchAppIcon: _prefs.getBool('settings.matchIcon') ?? d.matchAppIcon,
    );
  }

  Future<void> saveSettings(UserSettings s) async {
    await _prefs.setString('settings.username', s.username);
    await _prefs.setString('settings.email', s.email);
    await _prefs.setBool('settings.private', s.privateAccount);
    await _prefs.setString('settings.interact', s.whoCanInteract.name);
    await _prefs.setString('settings.visibility', s.ootdVisibility.name);
    await _prefs.setBool('settings.push', s.pushNotifications);
    await _prefs.setBool('settings.styleAlerts', s.styleMatchAlerts);
    await _prefs.setString('settings.skin', s.skin.id);
    await _prefs.setBool('settings.matchIcon', s.matchAppIcon);
  }

  /// Wipes everything tied to the signed-in account (logout).
  Future<void> clearAccount() async {
    for (final k in _prefs.getKeys().toList()) {
      await _prefs.remove(k);
    }
  }
}
