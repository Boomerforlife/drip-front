import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/activity/activity_screen.dart';
import '../features/auth/sign_in_screen.dart';
import '../features/create/create_ootd_screen.dart';
import '../core/motion.dart';
import '../features/discover/discover_screen.dart';
import '../features/home/home_screen.dart';
import '../features/home/ootd_viewer_screen.dart';
import '../features/onboarding/onboarding_flow.dart';
import '../features/scroll/fashion_scroll_screen.dart';
import '../features/outfits/outfit_detail_screen.dart';
import '../features/photoshoot/photoshoot_result_screen.dart';
import '../features/photoshoot/photoshoot_screen.dart';
import '../features/profile/colour_theory_profile_screen.dart';
import '../features/profile/my_profile_screen.dart';
import '../features/profile/public_profile_screen.dart';
import '../features/search/search_results_screen.dart';
import '../features/search/search_screen.dart';
import '../features/session/session_controller.dart';
import '../features/settings/settings_screen.dart';
import '../features/settings/theme_picker_screen.dart';
import '../features/social/followers_screen.dart';
import '../features/splash/splash_screen.dart';
import '../features/studio/outfit_builder_screen.dart';
import '../features/studio/studio_home_screen.dart';
import '../features/stylist/taylor_result_screen.dart';
import '../features/stylist/taylor_screen.dart';
import '../features/wardrobe/add_to_wardrobe_screen.dart';
import '../features/wardrobe/item_detail_screen.dart';
import '../features/wardrobe/saved_outfits_screen.dart';
import '../features/wardrobe/wardrobe_screen.dart';
import 'main_shell.dart';

/// Route paths.
abstract final class Routes {
  static const splash = '/splash';
  static const welcome = '/welcome';
  static const signIn = '/signin';
  static const home = '/home';
}

/// Page with the app's standard transition: a short fade + rise, on the
/// shared motion tokens (a fade only under reduced motion).
CustomTransitionPage<void> dripPage(
  GoRouterState state,
  Widget child, {
  bool fade = false,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: Motion.nav,
    reverseTransitionDuration: Motion.quick + const Duration(milliseconds: 40),
    transitionsBuilder: (context, animation, secondary, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Motion.out,
        reverseCurve: Curves.easeInCubic,
      );
      if (Motion.reduced(context)) {
        return FadeTransition(opacity: curved, child: child);
      }
      if (fade) return FadeTransition(opacity: curved, child: child);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.03),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// The camera's page: slides in from the left edge and leaves the same way.
CustomTransitionPage<void> cameraPage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: Motion.page,
    reverseTransitionDuration: Motion.page,
    transitionsBuilder: (context, animation, secondary, child) {
      if (Motion.reduced(context)) {
        return FadeTransition(opacity: animation, child: child);
      }
      final curved = CurvedAnimation(
        parent: animation,
        curve: Motion.drawer,
        reverseCurve: Curves.easeInCubic,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(-1, 0),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      );
    },
  );
}

/// Tab-root transition: a plain sideways push. The incoming page slides in
/// from the side the lens moved towards while the outgoing one slides out the
/// other way, so the two travel together like pages of a pager.
///
/// It deliberately animates position only. Fading a whole screen means
/// rendering it to an offscreen layer every frame (and these screens hold blur
/// and many images), which is exactly what made tab changes stutter on
/// mid-range phones; a translation is just a compositor offset.
CustomTransitionPage<void> tabPage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: Motion.page,
    reverseTransitionDuration: Motion.page,
    transitionsBuilder: (context, animation, secondary, child) {
      // Not a tab move (opened from a card): the shared image carries the
      // transition, the page just fades in behind it.
      if (Motion.reduced(context) || TabDirection.value == 0) {
        return FadeTransition(opacity: animation, child: child);
      }
      final ease = CurvedAnimation(parent: animation, curve: Motion.drawer);
      final easeOut = CurvedAnimation(parent: secondary, curve: Motion.drawer);
      return AnimatedBuilder(
        animation: Listenable.merge([ease, easeOut]),
        child: child,
        builder: (context, child) {
          // Read the direction live: the outgoing page was built for an
          // earlier move, but must leave the way the *current* move goes.
          final dir = TabDirection.value.toDouble();
          // Entering runs 1 → 0 from the travel side; leaving (its animation
          // reverses) runs 0 → -1 the opposite way; a page covered by another
          // slides away via [secondary].
          final leaving = animation.status == AnimationStatus.reverse;
          final enter = (1 - ease.value) * (leaving ? -dir : dir);
          final covered = -dir * easeOut.value;
          return FractionalTranslation(
            translation: Offset(enter + covered, 0),
            child: child,
          );
        },
      );
    },
  );
}

class _SessionRefresh extends ChangeNotifier {
  _SessionRefresh(Ref ref) {
    ref.listen(sessionProvider, (_, _) => notifyListeners());
  }
}

GoRoute _page(
  String path,
  Widget Function(GoRouterState) build, {
  bool fade = false,
}) => GoRoute(
  path: path,
  pageBuilder: (context, state) => dripPage(state, build(state), fade: fade),
);

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _SessionRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    redirect: (context, state) {
      final signedIn = ref.read(sessionProvider).signedIn;
      final loc = state.matchedLocation;
      final public =
          loc == Routes.splash || loc == Routes.welcome || loc == Routes.signIn;
      if (!signedIn && !public) return Routes.welcome;
      // The session just arrived (back from Google): straight into the app.
      if (signedIn && (loc == Routes.welcome || loc == Routes.signIn)) {
        return Routes.home;
      }
      return null;
    },
    routes: [
      _page(Routes.splash, (_) => const SplashScreen(), fade: true),
      _page(Routes.welcome, (_) => const OnboardingFlow(), fade: true),
      _page(Routes.signIn, (_) => const SignInScreen()),

      // Full-screen (no bottom navigation).
      _page(
        '/ootd/:id',
        (s) => OotdViewerScreen(ootdId: s.pathParameters['id']!),
      ),
      _page('/themes', (_) => const ThemePickerScreen(), fade: true),
      _page('/stylist', (_) => const TaylorScreen()),
      _page('/stylist/result', (_) => const TaylorResultScreen()),
      // The camera sits to the left of Home: it slides in from the left and
      // swiping left closes it (like Instagram).
      GoRoute(
        path: '/wardrobe/capture',
        pageBuilder: (context, state) =>
            cameraPage(state, const AddToWardrobeScreen()),
      ),

      // Screens hosted inside the bottom-navigation shell.
      ShellRoute(
        builder: (context, state, child) =>
            MainShell(path: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: '/home',
            pageBuilder: (context, state) => tabPage(state, const HomeScreen()),
          ),
          GoRoute(
            path: '/scroll',
            pageBuilder: (context, state) => tabPage(
              state,
              FashionScrollScreen(startId: state.uri.queryParameters['id']),
            ),
          ),
          _page('/create', (_) => const CreateOotdScreen()),
          _page('/discover', (_) => const DiscoverScreen(), fade: true),
          _page('/search', (_) => const SearchScreen()),
          _page(
            '/search/results',
            (s) => SearchResultsScreen(query: s.uri.queryParameters['q'] ?? ''),
          ),
          _page(
            '/outfit/:id',
            (s) => OutfitDetailScreen(outfitId: s.pathParameters['id']!),
          ),
          _page('/studio', (_) => const StudioHomeScreen()),
          _page('/studio/builder', (_) => const OutfitBuilderScreen()),
          GoRoute(
            path: '/wardrobe',
            pageBuilder: (context, state) =>
                tabPage(state, const WardrobeScreen()),
          ),
          _page(
            '/wardrobe/item/:id',
            (s) => ItemDetailScreen(itemId: s.pathParameters['id']!),
          ),
          _page('/saved', (_) => const SavedOutfitsScreen()),
          GoRoute(
            path: '/me',
            pageBuilder: (context, state) =>
                tabPage(state, const MyProfileScreen()),
          ),
          _page('/me/colour-theory', (_) => const ColourTheoryProfileScreen()),
          _page(
            '/u/:handle',
            (s) => PublicProfileScreen(handle: s.pathParameters['handle']!),
          ),
          _page('/followers', (_) => const FollowersScreen()),
          _page('/following', (_) => const FollowingScreen()),
          _page('/activity', (_) => const ActivityScreen()),
          _page('/settings', (_) => const SettingsScreen()),
          _page('/photoshoot', (_) => const PhotoshootScreen()),
          _page('/photoshoot/result', (_) => const PhotoshootResultScreen()),
        ],
      ),
    ],
  );
});
