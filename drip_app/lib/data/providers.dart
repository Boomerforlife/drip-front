import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

import '../core/config/env.dart';
import 'api/api_client.dart';
import 'models/account.dart';
import 'models/meta.dart';
import 'repositories/account_repository.dart';
import 'repositories/activity_repository.dart';
import 'repositories/auth_repository.dart';
import 'repositories/colour_repository.dart';
import 'repositories/feed_repository.dart';
import 'repositories/local_store.dart';
import 'repositories/outfit_repository.dart';
import 'repositories/posts_repository.dart';
import 'repositories/social_repository.dart';
import 'repositories/studio_repository.dart';
import 'repositories/stylist_repository.dart';
import 'repositories/wardrobe_repository.dart';

/// Overridden in `main()` once [SharedPreferences] has been loaded.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) =>
      throw UnimplementedError('sharedPreferencesProvider must be overridden'),
);

final localStoreProvider = Provider<LocalStore>(
  (ref) => LocalStore(ref.watch(sharedPreferencesProvider)),
);

// ------------------------------------------------------------------------
// Backend. Supabase is only used for sign-in; everything else goes through
// the Drip API (Backend_app/docs/API.md). Tests override these with fakes.
// ------------------------------------------------------------------------

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => SupabaseAuthRepository(Supabase.instance.client.auth),
);

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(
    baseUrl: Env.apiBaseUrl,
    auth: ref.watch(authRepositoryProvider),
    uploadHeaders: {'apikey': Env.supabasePublishableKey},
  ),
);

final accountRepositoryProvider = Provider<AccountRepository>(
  (ref) => ApiAccountRepository(ref.watch(apiClientProvider)),
);

/// The server-owned lists (occasions, vibes, slots…). Kept for the session.
final metaProvider = FutureProvider<AppMeta>((ref) {
  ref.keepAlive();
  return ref.watch(accountRepositoryProvider).meta();
});

/// The signed-in user's backend profile (`GET /me`). Invalidate after writes.
final accountProvider = FutureProvider<Account>(
  (ref) => ref.watch(accountRepositoryProvider).me(),
);

// ------------------------------------------------------------------------
// Repositories. The app talks to the Drip API; tests override these with
// the Mock* implementations. Social and posts have no backend in v1 (no
// social layer), so only their mocks exist, and the UI built on them says
// "coming after beta" when used.
// ------------------------------------------------------------------------

final feedRepositoryProvider = Provider<FeedRepository>(
  (ref) => ApiFeedRepository(ref.watch(apiClientProvider)),
);

final outfitRepositoryProvider = Provider<OutfitRepository>(
  (ref) => ApiOutfitRepository(ref.watch(apiClientProvider)),
);

final wardrobeRepositoryProvider = Provider<WardrobeRepository>(
  (ref) => ApiWardrobeRepository(
    ref.watch(apiClientProvider),
    ref.watch(localStoreProvider),
  ),
);

final stylistRepositoryProvider = Provider<StylistRepository>(
  (ref) => ApiStylistRepository(ref.watch(apiClientProvider)),
);

final studioRepositoryProvider = Provider<StudioRepository>(
  (ref) => ApiStudioRepository(ref.watch(apiClientProvider)),
);

final colourRepositoryProvider = Provider<ColourRepository>(
  (ref) => ApiColourRepository(ref.watch(apiClientProvider)),
);

final postsRepositoryProvider = Provider<PostsRepository>(
  (ref) => MockPostsRepository(),
);

final socialRepositoryProvider = Provider<SocialRepository>(
  (ref) => MockSocialRepository(ref.watch(localStoreProvider)),
);

final activityRepositoryProvider = Provider<ActivityRepository>(
  (ref) => MockActivityRepository(),
);
