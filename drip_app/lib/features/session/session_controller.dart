import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/repositories/auth_repository.dart';

class SessionState {
  const SessionState({
    required this.signedIn,
    required this.onboarded,
    this.user,
  });
  final bool signedIn;
  final bool onboarded;

  /// The Google identity, while signed in.
  final AuthUser? user;

  SessionState copyWith({bool? signedIn, bool? onboarded, AuthUser? user}) =>
      SessionState(
        signedIn: signedIn ?? this.signedIn,
        onboarded: onboarded ?? this.onboarded,
        user: user ?? this.user,
      );
}

/// The signed-in state, driven by the Supabase session (Google sign-in).
///
/// Onboarding picks can be made before signing in: they're kept on the device
/// and sent with `PATCH /me` once a session exists. The first authenticated
/// request creates the user's row on the backend, so there's no sign-up call.
class SessionController extends Notifier<SessionState> {
  @override
  SessionState build() {
    final auth = ref.watch(authRepositoryProvider);
    final store = ref.watch(localStoreProvider);
    final sub = auth.changes.listen(_onAuthChanged);
    ref.onDispose(sub.cancel);
    final signedIn = auth.isSignedIn;
    return SessionState(
      signedIn: signedIn,
      onboarded: signedIn && store.onboarded,
      user: auth.currentUser,
    );
  }

  void _onAuthChanged(AuthUser? user) {
    final signedIn = user != null;
    final wasSignedIn = state.signedIn;
    if (!signedIn) {
      if (wasSignedIn) {
        state = const SessionState(signedIn: false, onboarded: false);
      }
      return;
    }
    state = SessionState(signedIn: true, onboarded: true, user: user);
    if (!wasSignedIn) unawaited(_afterSignIn());
  }

  /// Opens Google's sign-in. The session arrives later through the deep link.
  Future<void> signInWithGoogle() =>
      ref.read(authRepositoryProvider).signInWithGoogle();

  /// First moments of a session: send picks made before sign-in, or pull the
  /// ones saved on the account (a returning user on a fresh install).
  Future<void> _afterSignIn() async {
    final store = ref.read(localStoreProvider);
    final accounts = ref.read(accountRepositoryProvider);
    await store.setOnboarded(true);
    try {
      if (store.prefsPending) {
        final picks = ref.read(onboardingProvider);
        await accounts.updateProfile(
          onboardingPrefs: picks.toPrefs(),
          // Scroll ranking prefers fits whose style tags overlap these.
          styleTags: picks.styleTags,
        );
        await store.setPrefsPending(false);
      } else {
        final me = await accounts.me();
        if (me.onboardingPrefs.isNotEmpty) {
          await ref
              .read(onboardingProvider.notifier)
              .restore(me.onboardingPrefs);
        }
      }
    } catch (e) {
      // Not fatal: picks stay pending and are retried at the next sign-in.
      debugPrint('[session] syncing onboarding picks failed: $e');
    }
    ref.invalidate(accountProvider);
  }

  /// Finishes onboarding ("ENTER DRIP"): the picks wait for the account.
  Future<void> completeOnboarding() async {
    final store = ref.read(localStoreProvider);
    await ref.read(onboardingProvider.notifier).saveAll();
    await store.setPrefsPending(true);
    if (state.signedIn) await _afterSignIn();
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).signOut();
    await ref.read(localStoreProvider).clearAccount();
    state = const SessionState(signedIn: false, onboarded: false);
  }

  /// Deletes the account on the backend (irreversible), then signs out.
  Future<void> deleteAccount() async {
    await ref.read(accountRepositoryProvider).deleteAccount();
    await logout();
  }
}

final sessionProvider = NotifierProvider<SessionController, SessionState>(
  SessionController.new,
);

class CustomColour {
  const CustomColour(this.id, this.name, this.hex);
  final String id;
  final String name;
  final int hex;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'hex': hex};
}

/// Everything picked during onboarding (`Drip Onboarding.dc.html`): eras,
/// genres, colours (plus custom ones), pieces, accessories, labels, fit,
/// budget and a first name. Kept on the device until sign-in, then sent to the
/// account as `onboardingPrefs`.
class OnboardingState {
  const OnboardingState({
    this.moodIds = const {},
    this.paletteIds = const {},
    this.genres = const {},
    this.clothes = const {},
    this.accessories = const {},
    this.brands = const {},
    this.fit = 'regular',
    this.budget = 2500,
    this.name = '',
    this.customColours = const [],
  });

  /// Eras (y2k, streetwear, minimal…).
  final Set<String> moodIds;

  /// Colour ids: the bundled ones and custom ones.
  final Set<String> paletteIds;
  final Set<String> genres;
  final Set<String> clothes;
  final Set<String> accessories;
  final Set<String> brands;
  final String fit;
  final int budget;
  final String name;
  final List<CustomColour> customColours;

  OnboardingState copyWith({
    Set<String>? moodIds,
    Set<String>? paletteIds,
    Set<String>? genres,
    Set<String>? clothes,
    Set<String>? accessories,
    Set<String>? brands,
    String? fit,
    int? budget,
    String? name,
    List<CustomColour>? customColours,
  }) => OnboardingState(
    moodIds: moodIds ?? this.moodIds,
    paletteIds: paletteIds ?? this.paletteIds,
    genres: genres ?? this.genres,
    clothes: clothes ?? this.clothes,
    accessories: accessories ?? this.accessories,
    brands: brands ?? this.brands,
    fit: fit ?? this.fit,
    budget: budget ?? this.budget,
    name: name ?? this.name,
    customColours: customColours ?? this.customColours,
  );

  /// The wire/persisted shape (`PATCH /me { onboardingPrefs }`).
  Map<String, dynamic> toPrefs() => {
    'moods': moodIds.toList(),
    'colours': paletteIds.toList(),
    'customColours': [for (final c in customColours) c.toJson()],
    'genres': genres.toList(),
    'clothes': clothes.toList(),
    'accessories': accessories.toList(),
    'brands': brands.toList(),
    'fit': fit,
    'budget': budget,
    'name': name,
  };

  /// Style tags the feed ranks on: eras first, then genres (API max 20).
  List<String> get styleTags => [
    ...moodIds,
    for (final g in genres)
      g.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-'),
  ].take(20).toList();

  factory OnboardingState.fromPrefs(Map<String, dynamic> m) {
    Set<String> set(Object? v) => {
      for (final x in (v as List?) ?? const []) '$x',
    };
    return OnboardingState(
      moodIds: set(m['moods']),
      // Older accounts stored the colour picks under "palette".
      paletteIds: set(m['colours'] ?? m['palette']),
      genres: set(m['genres']),
      clothes: set(m['clothes']),
      accessories: set(m['accessories']),
      brands: set(m['brands']),
      fit: m['fit'] as String? ?? 'regular',
      budget: (m['budget'] as num?)?.toInt() ?? 2500,
      name: m['name'] as String? ?? '',
      customColours: [
        for (final c in (m['customColours'] as List?) ?? const [])
          if (c is Map)
            CustomColour(
              '${c['id']}',
              '${c['name']}',
              (c['hex'] as num?)?.toInt() ?? 0xFFE8DFC8,
            ),
      ],
    );
  }
}

/// Onboarding picks, saved on the device as they're made.
class OnboardingController extends Notifier<OnboardingState> {
  @override
  OnboardingState build() {
    final store = ref.watch(localStoreProvider);
    final json = store.flowJson;
    if (json != null) {
      try {
        return OnboardingState.fromPrefs(
          (jsonDecode(json) as Map).cast<String, dynamic>(),
        );
      } catch (_) {
        // Corrupt: start over.
      }
    }
    return OnboardingState(
      moodIds: store.moodIds ?? const {},
      paletteIds: store.paletteIds ?? const {},
    );
  }

  void _set(OnboardingState next) {
    state = next;
    unawaited(
      ref.read(localStoreProvider).setFlowJson(jsonEncode(next.toPrefs())),
    );
  }

  Set<String> _toggled(Set<String> from, String id) =>
      from.contains(id) ? ({...from}..remove(id)) : {...from, id};

  void toggleMood(String id) =>
      _set(state.copyWith(moodIds: _toggled(state.moodIds, id)));
  void setMoods(Set<String> ids) => _set(state.copyWith(moodIds: ids));
  void togglePalette(String id) =>
      _set(state.copyWith(paletteIds: _toggled(state.paletteIds, id)));
  void toggleGenre(String g) =>
      _set(state.copyWith(genres: _toggled(state.genres, g)));
  void toggleCloth(String c) =>
      _set(state.copyWith(clothes: _toggled(state.clothes, c)));
  void toggleAccessory(String a) =>
      _set(state.copyWith(accessories: _toggled(state.accessories, a)));
  void toggleBrand(String b) =>
      _set(state.copyWith(brands: _toggled(state.brands, b)));
  void setFit(String id) => _set(state.copyWith(fit: id));
  void setBudget(int v) => _set(state.copyWith(budget: v));
  void setName(String v) => _set(state.copyWith(name: v));

  /// Adds (and selects) a colour of the user's own. False at the six-colour cap.
  bool addCustomColour(String name, int hex) {
    if (state.customColours.length >= 6) return false;
    final id = 'c${DateTime.now().microsecondsSinceEpoch}';
    final label = name.trim().isEmpty
        ? '#${(hex & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}'
        : name.trim();
    _set(
      state.copyWith(
        customColours: [...state.customColours, CustomColour(id, label, hex)],
        paletteIds: {...state.paletteIds, id},
      ),
    );
    return true;
  }

  void removeCustomColour(String id) => _set(
    state.copyWith(
      customColours: [
        for (final c in state.customColours)
          if (c.id != id) c,
      ],
      paletteIds: {...state.paletteIds}..remove(id),
    ),
  );

  Future<void> saveMoods() =>
      ref.read(localStoreProvider).setMoodIds(state.moodIds);
  Future<void> savePalette() =>
      ref.read(localStoreProvider).setPaletteIds(state.paletteIds);

  Future<void> saveAll() async {
    await saveMoods();
    await savePalette();
    await ref.read(localStoreProvider).setFlowJson(jsonEncode(state.toPrefs()));
  }

  /// Replaces everything with the account's saved picks (returning user).
  Future<void> restore(Map<String, dynamic> prefs) async {
    state = OnboardingState.fromPrefs(prefs);
    await saveAll();
  }
}

final onboardingProvider =
    NotifierProvider<OnboardingController, OnboardingState>(
      OnboardingController.new,
    );
