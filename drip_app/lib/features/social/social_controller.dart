import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/mock/mock_content.dart';
import '../../data/models/user.dart';
import '../../data/providers.dart';
import '../../data/repositories/social_repository.dart';
import '../onboarding/onboarding_data.dart';
import '../outfits/outfit_controller.dart';
import '../session/session_controller.dart';

/// Handles the signed-in user follows.
class FollowingController extends AsyncNotifier<Set<String>> {
  @override
  Future<Set<String>> build() =>
      ref.watch(socialRepositoryProvider).followingHandles();

  bool isFollowing(String handle) => state.value?.contains(handle) ?? false;

  Future<void> toggle(String handle) async {
    final current = state.value ?? <String>{};
    final follow = !current.contains(handle);
    final next = {...current};
    follow ? next.add(handle) : next.remove(handle);
    state = AsyncData(next);
    await ref
        .read(socialRepositoryProvider)
        .setFollowing(handle, follow: follow);
  }

  /// Applies a batch of follow / unfollow changes (onboarding "SYNC ALL").
  Future<void> apply({
    required Iterable<String> follow,
    Iterable<String> unfollow = const [],
  }) async {
    final repo = ref.read(socialRepositoryProvider);
    var next = await repo.followMany(follow);
    for (final h in unfollow) {
      next = await repo.setFollowing(h, follow: false);
    }
    state = AsyncData(next);
  }
}

final followingSetProvider =
    AsyncNotifierProvider<FollowingController, Set<String>>(
      FollowingController.new,
    );

final followersPageProvider = FutureProvider<UserPage>(
  (ref) => ref.watch(socialRepositoryProvider).followers(),
);

final followingPageProvider = FutureProvider<UserPage>(
  (ref) => ref.watch(socialRepositoryProvider).following(),
);

final suggestedCreatorsProvider = FutureProvider<List<DripUser>>(
  (ref) => ref.watch(socialRepositoryProvider).suggestedCreators(),
);

final userProvider = FutureProvider.family<DripUser?, String>(
  (ref, handle) => ref.watch(socialRepositoryProvider).user(handle),
);

/// The signed-in user's profile, built from their Google identity and
/// onboarding picks. There's no profile endpoint beyond `/me` in v1 (no social
/// layer), so followers are zero and editing waits for after the beta.
class MyProfileController extends AsyncNotifier<DripUser> {
  @override
  Future<DripUser> build() async {
    final user = ref.watch(sessionProvider.select((s) => s.user));
    if (user == null) throw StateError('Not signed in');
    final picks = ref.watch(onboardingProvider);
    final saved = ref.watch(libraryProvider).value?.saved ?? const [];
    return DripUser(
      id: user.id,
      name: user.name ?? handleFor(user.email),
      handle: handleFor(user.email),
      avatar: user.avatarUrl ?? '',
      styleScore: saved.isEmpty
          ? 0
          : (saved.fold<int>(0, (s, o) => s + o.rate) / saved.length).round(),
      styleDna: [
        for (final m in MockContent.moods)
          if (picks.moodIds.contains(m.id)) m.label.toUpperCase(),
      ],
      palette: [
        for (final c in OnboardingData.colours)
          if (picks.paletteIds.contains(c.id)) c.color,
        for (final c in picks.customColours)
          if (picks.paletteIds.contains(c.id)) Color(c.hex),
      ],
    );
  }
}

final myProfileProvider = AsyncNotifierProvider<MyProfileController, DripUser>(
  MyProfileController.new,
);

/// `vighnesh.s+drip@gmail.com` → `vighnesh.s`.
String handleFor(String email) {
  final local = email.split('@').first.split('+').first.toLowerCase();
  final clean = local.replaceAll(RegExp(r'[^a-z0-9._]'), '');
  return clean.isEmpty ? 'me' : clean;
}
