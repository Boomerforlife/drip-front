import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/mock/mock_content.dart';
import '../../data/models/account.dart';
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

/// The signed-in user's profile: the name, username and photo they set on
/// their account (`GET /me`), falling back to their Google identity, plus
/// their onboarding picks. There's no social layer in v1, so followers are
/// zero.
class MyProfileController extends AsyncNotifier<DripUser> {
  @override
  Future<DripUser> build() async {
    final user = ref.watch(sessionProvider.select((s) => s.user));
    if (user == null) throw StateError('Not signed in');
    final picks = ref.watch(onboardingProvider);
    final saved = ref.watch(libraryProvider).value?.saved ?? const [];
    // Offline (or no profile yet): the Google identity stands in.
    Account? account;
    try {
      account = await ref.watch(accountProvider.future);
    } catch (_) {
      account = null;
    }
    final handle = account?.username ?? handleFor(user.email);
    return DripUser(
      id: user.id,
      name: account?.displayName ?? user.name ?? handle,
      handle: handle,
      avatar: account?.photoUrl ?? user.avatarUrl ?? '',
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
