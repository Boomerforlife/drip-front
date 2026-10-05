import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/repositories/auth_repository.dart';
import '../onboarding/local_selfie.dart';

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
    // Picks that didn't reach the account last time (offline at sign-in):
    // try again now rather than waiting for the next sign-in.
    if (signedIn && store.prefsPending) {
      Future.microtask(_afterSignIn);
    }
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

  /// First moments of a session: reconcile this device's picks with the
  /// account's.
  ///
  /// The account is the source of truth. If it already holds picks (a
  /// returning user, even one who just went through onboarding again), they
  /// are kept and this device takes them: a repeat onboarding never silently
  /// overwrites someone's saved personalization. Only an account with no
  /// picks yet takes the ones made here.
  Future<void> _afterSignIn() async {
    final store = ref.read(localStoreProvider);
    final accounts = ref.read(accountRepositoryProvider);
    final sync = ref.read(picksSyncProvider.notifier);
    await store.setOnboarded(true);
    final pending = store.prefsPending;
    sync.set(PicksSync.syncing);
    try {
      final me = await accounts.me();
      if (me.onboardingPrefs.isNotEmpty && pending) {
        // A returning user who just went through onboarding again: their
        // saved Drip stays exactly as it is until they say otherwise.
        sync.set(PicksSync.conflict);
      } else if (me.onboardingPrefs.isNotEmpty) {
        await ref.read(onboardingProvider.notifier).restore(me.onboardingPrefs);
        sync.set(PicksSync.idle);
      } else if (pending) {
        final picks = ref.read(onboardingProvider);
        await accounts.updateProfile(
          onboardingPrefs: picks.toPrefs(),
          // Scroll ranking prefers fits whose style tags overlap these.
          styleTags: picks.styleTags,
        );
        await store.setPrefsPending(false);
        await store.setTouchedFields(const {});
        sync.set(PicksSync.saved);
      } else {
        sync.set(PicksSync.idle);
      }
    } catch (e) {
      // Not fatal: picks stay pending and are retried at the next launch.
      // Nothing is written without first reading the account, so a retry
      // can't overwrite either.
      debugPrint('[session] syncing onboarding picks failed: $e');
      sync.set(pending ? PicksSync.failed : PicksSync.idle);
    }
    ref.invalidate(accountProvider);
  }

  /// A returning user's answer to "update your Drip with these picks?".
  ///
  /// [update]: only the fields changed in this run replace the saved ones;
  /// everything else on the account (and its Colour Theory season) stays.
  /// Otherwise the saved Drip wins and this device takes it.
  Future<void> resolvePicks({required bool update}) async {
    final store = ref.read(localStoreProvider);
    final accounts = ref.read(accountRepositoryProvider);
    final onboarding = ref.read(onboardingProvider.notifier);
    final me = await accounts.me();
    if (update) {
      final mine = ref.read(onboardingProvider).toPrefs();
      final merged = {
        ...me.onboardingPrefs,
        for (final f in onboarding.touched)
          if (mine.containsKey(f)) f: mine[f],
        // A custom colour only means something with its definition.
        if (onboarding.touched.contains('colours'))
          'customColours': mine['customColours'],
      };
      await accounts.updateProfile(
        onboardingPrefs: merged,
        styleTags: OnboardingState.fromPrefs(merged).styleTags,
      );
      await onboarding.restore(merged);
    } else {
      await onboarding.restore(me.onboardingPrefs);
    }
    await store.setPrefsPending(false);
    await store.setFirstRunPending(false);
    ref.read(picksSyncProvider.notifier).set(PicksSync.idle);
    ref.invalidate(accountProvider);
  }

  /// Finishes onboarding ("ENTER DRIP"): the picks wait for the account, and
  /// the next sign-in opens on the "your Drip is ready" moment.
  Future<void> completeOnboarding() async {
    final store = ref.read(localStoreProvider);
    await ref.read(onboardingProvider.notifier).saveAll();
    await store.setPrefsPending(true);
    await store.setFirstRunPending(true);
    if (state.signedIn) await _afterSignIn();
  }

  /// Saves picks edited after onboarding (Settings → Your style) to the
  /// account. Merged into what the account already holds, so other things
  /// kept there (the colour season picked in Colour Theory) survive.
  Future<void> savePicks() async {
    final accounts = ref.read(accountRepositoryProvider);
    final picks = ref.read(onboardingProvider);
    final me = await accounts.me();
    await accounts.updateProfile(
      onboardingPrefs: {...me.onboardingPrefs, ...picks.toPrefs()},
      styleTags: picks.styleTags,
    );
    await ref.read(onboardingProvider.notifier).saveAll();
    await ref.read(localStoreProvider).setPrefsPending(false);
    await ref.read(localStoreProvider).setTouchedFields(const {});
    ref.invalidate(accountProvider);
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).signOut();
    // Selfies only ever lived on this device: they go too.
    await ref.read(selfieGalleryProvider.notifier).deleteAll();
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

/// Where this device's onboarding picks stand against the account's, after
/// a sign-in.
enum PicksSync {
  /// Nothing to reconcile.
  idle,

  /// Reading (and maybe writing) the account.
  syncing,

  /// A new account took the picks made in onboarding.
  saved,

  /// The account already had picks and onboarding made new ones: the user
  /// chooses (update with what they changed, or keep what's saved).
  conflict,

  /// Couldn't reach the account; the picks wait on the device.
  failed,
}

class PicksSyncController extends Notifier<PicksSync> {
  @override
  PicksSync build() => PicksSync.idle;

  void set(PicksSync v) => state = v;
}

final picksSyncProvider = NotifierProvider<PicksSyncController, PicksSync>(
  PicksSyncController.new,
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
    this.gender,
    this.occasions = const {},
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

  /// Whose clothes lead the feed: 'male', 'female' or 'unspecified' (the
  /// user's own pick, never inferred), or null before it's asked.
  final String? gender;

  /// Occasion ids (see `Occasions`): what the user dresses for most.
  final Set<String> occasions;

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
    String? gender,
    Set<String>? occasions,
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
    gender: gender ?? this.gender,
    occasions: occasions ?? this.occasions,
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
    'gender': ?gender,
    'occasions': occasions.toList(),
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
      gender: m['gender'] as String?,
      occasions: set(m['occasions']),
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

  void _set(OnboardingState next, [String? field]) {
    state = next;
    final store = ref.read(localStoreProvider);
    unawaited(store.setFlowJson(jsonEncode(next.toPrefs())));
    if (field != null && !store.touchedFields.contains(field)) {
      unawaited(store.setTouchedFields({...store.touchedFields, field}));
    }
  }

  /// The prefs fields the user changed since the device last matched the
  /// account (a returning user updating their Drip changes only these).
  Set<String> get touched => ref.read(localStoreProvider).touchedFields;

  Set<String> _toggled(Set<String> from, String id) =>
      from.contains(id) ? ({...from}..remove(id)) : {...from, id};

  void toggleMood(String id) =>
      _set(state.copyWith(moodIds: _toggled(state.moodIds, id)), 'moods');
  void setMoods(Set<String> ids) => _set(state.copyWith(moodIds: ids), 'moods');
  void togglePalette(String id) => _set(
    state.copyWith(paletteIds: _toggled(state.paletteIds, id)),
    'colours',
  );
  void toggleGenre(String g) =>
      _set(state.copyWith(genres: _toggled(state.genres, g)), 'genres');
  void toggleCloth(String c) =>
      _set(state.copyWith(clothes: _toggled(state.clothes, c)), 'clothes');
  void toggleAccessory(String a) => _set(
    state.copyWith(accessories: _toggled(state.accessories, a)),
    'accessories',
  );
  void toggleBrand(String b) =>
      _set(state.copyWith(brands: _toggled(state.brands, b)), 'brands');
  void toggleOccasion(String id) => _set(
    state.copyWith(occasions: _toggled(state.occasions, id)),
    'occasions',
  );
  void setGender(String v) => _set(state.copyWith(gender: v), 'gender');
  void setFit(String id) => _set(state.copyWith(fit: id), 'fit');
  void setBudget(int v) => _set(state.copyWith(budget: v), 'budget');
  void setName(String v) => _set(state.copyWith(name: v), 'name');

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
      'colours',
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
    'colours',
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
  /// The device now matches the account, so nothing counts as changed.
  Future<void> restore(Map<String, dynamic> prefs) async {
    state = OnboardingState.fromPrefs(prefs);
    await saveAll();
    await ref.read(localStoreProvider).setTouchedFields(const {});
  }
}

final onboardingProvider =
    NotifierProvider<OnboardingController, OnboardingState>(
      OnboardingController.new,
    );
