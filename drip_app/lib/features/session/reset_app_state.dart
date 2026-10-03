import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../activity/activity_controller.dart';
import '../bag/bag_controller.dart';
import '../create/create_ootd_controller.dart';
import '../home/feed_controller.dart';
import '../onboarding/local_selfie.dart';
import '../outfits/outfit_controller.dart';
import '../photoshoot/photoshoot_controller.dart';
import '../profile/profile_controller.dart';
import '../search/search_controller.dart';
import '../settings/settings_controller.dart';
import '../social/social_controller.dart';
import '../studio/studio_controller.dart';
import '../stylist/stylist_controller.dart';
import '../wardrobe/wardrobe_controller.dart';
import 'session_controller.dart';

/// Clears every piece of per-account state (called on logout) so the next
/// session starts from a clean slate.
void resetAppState(WidgetRef ref) {
  // Data sources first so dependants rebuild from fresh repositories.
  ref
    ..invalidate(apiClientProvider)
    ..invalidate(feedRepositoryProvider)
    ..invalidate(outfitRepositoryProvider)
    ..invalidate(wardrobeRepositoryProvider)
    ..invalidate(studioRepositoryProvider)
    ..invalidate(postsRepositoryProvider)
    ..invalidate(socialRepositoryProvider)
    ..invalidate(activityRepositoryProvider)
    ..invalidate(localStoreProvider)
    ..invalidate(accountProvider)
    ..invalidate(feedProvider)
    ..invalidate(postsProvider)
    ..invalidate(storiesProvider)
    ..invalidate(libraryProvider)
    ..invalidate(fitMarksProvider)
    ..invalidate(outfitCatalogProvider)
    ..invalidate(wardrobeProvider)
    ..invalidate(rotationProvider)
    ..invalidate(followingSetProvider)
    ..invalidate(myProfileProvider)
    ..invalidate(activityProvider)
    ..invalidate(settingsProvider)
    ..invalidate(onboardingProvider)
    ..invalidate(localSelfieProvider)
    ..invalidate(recentSearchesProvider)
    ..invalidate(bagProvider)
    ..invalidate(studioProvider)
    ..invalidate(stylistProvider)
    ..invalidate(photoshootProvider)
    ..invalidate(myPhotosProvider)
    ..invalidate(createOotdProvider)
    ..invalidate(accessRequestsProvider)
    ..invalidate(connectedAccountsProvider);
}
