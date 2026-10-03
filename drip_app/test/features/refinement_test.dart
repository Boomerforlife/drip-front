import 'package:drip/app.dart';
import 'package:drip/core/platform/app_icon.dart';
import 'package:drip/core/theme/app_colors.dart';
import 'package:drip/core/theme/app_text.dart';
import 'package:drip/core/theme/drip_skin.dart';
import 'package:drip/core/widgets/fit_hero.dart';
import 'package:drip/core/widgets/tap.dart';
import 'package:drip/data/mock/mock_content.dart';
import 'package:drip/data/providers.dart';
import 'package:drip/data/repositories/feed_repository.dart';
import 'package:drip/features/outfits/outfit_controller.dart';
import 'package:drip/features/scroll/fashion_scroll_screen.dart';
import 'package:drip/features/settings/settings_controller.dart';
import 'package:drip/routing/app_router.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fakes.dart';
import '../test_fonts.dart';

/// Covers the refinement pass: floating nav (tap + swipe), Home → Fashion
/// Scroll, reel interactions, the theme system and the launch sequence.

Future<void> settle(WidgetTester t, [int ms = 700]) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Finder tapLabelled(String label) =>
    find.byWidgetPredicate((w) => w is Tap && w.semanticLabel == label);

String loc(ProviderContainer c) =>
    c.read(routerProvider).routeInformationProvider.value.uri.toString();

void main() {
  late ProviderContainer container;

  setUpAll(loadAppFonts);

  Future<void> boot(
    WidgetTester t, {
    bool signedIn = true,
    DripSkin? skin,
    FeedRepository? feed,
  }) async {
    SharedPreferences.setMockInitialValues({
      if (signedIn) 'session.onboarded': true,
      if (skin != null) 'settings.skin': skin.id,
    });
    final sp = await SharedPreferences.getInstance();
    t.view.physicalSize = const Size(780, 1688);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      ProviderScope(
        overrides: testOverrides(sp, signedIn: signedIn, feed: feed),
        retry: (_, _) => null,
        child: const DripApp(),
      ),
    );
    container = ProviderScope.containerOf(t.element(find.byType(MaterialApp)));
  }

  Future<void> openHome(WidgetTester t) async {
    await boot(t);
    await settle(t, 1600); // launch sequence, then Home
    expect(loc(container), '/home');
  }

  group('launch', () {
    testWidgets('launch sequence is short and hands off to Home', (t) async {
      await boot(t);
      await settle(t, 800);
      expect(loc(container), '/splash', reason: 'still playing at 0.8s');
      await settle(t, 600);
      expect(loc(container), '/home', reason: 'done by ~1.1s + transition');
      await settle(t, 500); // let Home's mock repositories finish
    });

    testWidgets('tapping the launch screen skips it', (t) async {
      await boot(t);
      await t.pump(const Duration(milliseconds: 200));
      await t.tap(find.byType(Scaffold).first);
      await settle(t, 500);
      expect(loc(container), '/home');
    });
  });

  group('floating navigation', () {
    testWidgets('tapping a tab moves there', (t) async {
      await openHome(t);
      final h = t.ensureSemantics();
      await t.tap(find.bySemanticsLabel('Fashion Scroll'));
      await settle(t);
      expect(loc(container), '/scroll');
      await t.tap(find.bySemanticsLabel('You'));
      await settle(t);
      expect(loc(container), '/me');
      await t.tap(find.bySemanticsLabel('Home'));
      await settle(t);
      expect(loc(container), '/home');
      h.dispose();
    });

    testWidgets('the bar is icons only: no text labels', (t) async {
      await openHome(t);
      for (final label in ['HOME', 'SCROLL', 'WARDROBE', 'YOU']) {
        expect(find.text(label), findsNothing);
      }
    });

    testWidgets('the centre star is the Studio tab', (t) async {
      await openHome(t);
      final h = t.ensureSemantics();
      expect(find.bySemanticsLabel('Create'), findsNothing);
      await t.tap(find.bySemanticsLabel('Studio'));
      await settle(t);
      expect(loc(container), '/studio');
      expect(find.text('DRIP STUDIO'), findsOneWidget);
      h.dispose();
    });

    testWidgets('the + on Home opens the camera', (t) async {
      await openHome(t);
      final h = t.ensureSemantics();
      await t.tap(find.bySemanticsLabel('Open the camera'));
      await settle(t);
      expect(find.text('GARMENT CAPTURE'), findsOneWidget);
      h.dispose();
    });

    testWidgets('dragging the bar scrubs the lens and lands on a tab', (
      t,
    ) async {
      await openHome(t);
      // Bar is 64 tall, floats ~18 above the bottom of an 844 screen.
      final g = await t.startGesture(const Offset(55, 794));
      for (var i = 0; i < 14; i++) {
        await g.moveBy(const Offset(15, 0));
        await t.pump(const Duration(milliseconds: 16));
      }
      await g.up();
      await settle(t, 900);
      expect(loc(container), '/wardrobe');
    });

    testWidgets('dragging back past the first tab does not navigate away', (
      t,
    ) async {
      await openHome(t);
      final g = await t.startGesture(const Offset(55, 794));
      for (var i = 0; i < 10; i++) {
        await g.moveBy(const Offset(-20, 0));
        await t.pump(const Duration(milliseconds: 16));
      }
      await g.up();
      await settle(t, 600);
      expect(loc(container), '/home', reason: 'rubber-bands back to Home');
    });

    testWidgets('vertical scrolling above the bar is not hijacked', (t) async {
      await openHome(t);
      await t.drag(find.byType(CustomScrollView).first, const Offset(0, -300));
      await settle(t, 400);
      expect(loc(container), '/home');
    });
  });

  group('swipe anywhere', () {
    Future<void> swipe(WidgetTester t, Offset from, double dx) async {
      final g = await t.startGesture(from);
      for (var i = 0; i < 12; i++) {
        await g.moveBy(Offset(dx / 12, 0));
        await t.pump(const Duration(milliseconds: 16));
      }
      await g.up();
      await settle(t, 900);
    }

    testWidgets('swipe left from the middle of Home opens the Scroll', (
      t,
    ) async {
      await openHome(t);
      await swipe(t, const Offset(280, 430), -260);
      expect(loc(container), '/scroll');
    });

    testWidgets('swipe walks the tabs in order and stops at the ends', (
      t,
    ) async {
      await openHome(t);
      await swipe(t, const Offset(280, 430), -260);
      expect(loc(container), '/scroll');
      // The order matches the bar: the Studio star sits between them.
      await swipe(t, const Offset(280, 430), -260);
      expect(loc(container), '/studio');
      await swipe(t, const Offset(280, 430), -260);
      expect(loc(container), '/wardrobe');
      await swipe(t, const Offset(280, 430), -260);
      expect(loc(container), '/me');
      // Last tab: nowhere further, the screen rubber-bands and stays.
      await swipe(t, const Offset(280, 430), -260);
      expect(loc(container), '/me');
      await swipe(t, const Offset(280, 430), 260);
      expect(loc(container), '/wardrobe');
    });

    testWidgets('a short quick flick counts', (t) async {
      await openHome(t);
      final g = await t.startGesture(const Offset(280, 430));
      await g.moveBy(
        const Offset(-30, 0),
        timeStamp: const Duration(milliseconds: 20),
      );
      await g.moveBy(
        const Offset(-40, 0),
        timeStamp: const Duration(milliseconds: 40),
      );
      await g.up(timeStamp: const Duration(milliseconds: 50));
      await settle(t, 900);
      expect(loc(container), '/scroll');
    });

    testWidgets('a small drag does not switch tabs', (t) async {
      await openHome(t);
      await swipe(t, const Offset(280, 430), -40);
      expect(loc(container), '/home');
    });

    testWidgets('swiping right on Home opens the camera', (t) async {
      await openHome(t);
      await swipe(t, const Offset(280, 430), 300);
      expect(find.text('GARMENT CAPTURE'), findsOneWidget);
    });

    testWidgets('only your own story circle is shown in v1', (t) async {
      await openHome(t);
      expect(find.text('Your story'), findsOneWidget);
      expect(find.text('@sofiamae'), findsNothing);
    });
  });

  group('home → fashion scroll', () {
    testWidgets('an occasion card opens the Scroll on fits for it', (t) async {
      await openHome(t);
      expect(find.text('SHOP BY OCCASION'), findsOneWidget);
      await t.ensureVisible(find.text('DATE NIGHT'));
      await settle(t, 300);
      await t.tap(find.text('DATE NIGHT'));
      await settle(t, 1200);
      expect(find.byType(FashionScrollScreen), findsOneWidget);
      expect(find.text('FITS FOR DATE NIGHT'), findsOneWidget);
      container.read(routerProvider).pop();
      await settle(t, 700);
      expect(loc(container), '/home');
    });

    testWidgets('opening on a specific fit starts there', (t) async {
      await boot(t);
      await settle(t, 1600);
      container.read(routerProvider).go('/scroll?id=o_gray');
      await settle(t, 900);
      expect(find.text('GRAY OVERCOAT'), findsOneWidget);
    });

    testWidgets('double-tap likes with feedback', (t) async {
      await boot(t);
      await settle(t, 1600);
      container.read(routerProvider).go('/scroll?id=o_gray');
      await settle(t, 900);
      expect(container.read(fitMarksProvider).isLiked('o_gray'), isFalse);
      final centre = t.getCenter(find.byType(FitHero));
      await t.tapAt(centre);
      await t.pump(const Duration(milliseconds: 60));
      await t.tapAt(centre);
      await settle(t, 300);
      expect(container.read(fitMarksProvider).isLiked('o_gray'), isTrue);
    });

    testWidgets('swiping up snaps to the next fit and reports the last', (
      t,
    ) async {
      await boot(t);
      await settle(t, 1600);
      container.read(routerProvider).go('/scroll');
      await settle(t, 900);
      await t.fling(find.byType(PageView), const Offset(0, -400), 1800);
      await settle(t, 900);
      // Near the end of a page, the next one is already loading in.
      final feed = container.read(feedRepositoryProvider) as MockFeedRepository;
      expect(feed.signals, contains(('o_baggy', 'skip')));
    });

    testWidgets('save gives feedback and lands in the library', (t) async {
      await boot(t);
      await settle(t, 1600);
      container.read(routerProvider).go('/scroll?id=o_gray');
      await settle(t, 900);
      await t.tap(tapLabelled('Save'));
      await settle(t, 400);
      expect(container.read(fitMarksProvider).isSaved('o_gray'), isTrue);
      expect(find.text('SAVED TO YOUR VAULT'), findsOneWidget);
      // The library refetches (with the saved fit) and the toast times out.
      await settle(t, 3000);
      final lib = container.read(libraryProvider).requireValue;
      expect(lib.saved.map((o) => o.id), contains('o_gray'));
    });

    testWidgets('comments and sharing say they come after the beta', (t) async {
      await boot(t);
      await settle(t, 1600);
      container.read(routerProvider).go('/scroll?id=o_gray');
      await settle(t, 900);
      await t.tap(tapLabelled('Share'));
      await settle(t, 300);
      expect(find.text('SHARING IS COMING AFTER BETA ✦'), findsOneWidget);
      expect(find.text('SHARE FIT'), findsNothing, reason: 'no sheet opened');
      await settle(t, 2600); // the toast times out
      await t.tap(tapLabelled('Comments'));
      await settle(t, 300);
      expect(find.text('COMMENTS IS COMING AFTER BETA ✦'), findsOneWidget);
      expect(find.text('COMMENTS'), findsNothing, reason: 'no sheet opened');
    });

    testWidgets('scrolling past the last loaded fit fetches the next page', (
      t,
    ) async {
      await boot(t);
      await settle(t, 1600);
      container.read(routerProvider).go('/scroll?id=o_gray');
      await settle(t, 900);
      await t.fling(find.byType(PageView), const Offset(0, -400), 1800);
      await settle(t, 1200);
      expect(find.text('TOKYO NEON GRID'), findsOneWidget);
    });

    testWidgets('the end of the feed is a caught-up card', (t) async {
      await boot(
        t,
        feed: MockFeedRepository(outfits: MockContent.outfits.take(2).toList()),
      );
      await settle(t, 1600);
      container.read(routerProvider).go('/scroll?id=o_pastel');
      await settle(t, 900);
      await t.fling(find.byType(PageView), const Offset(0, -400), 1800);
      await settle(t, 900);
      expect(find.text("YOU'RE ALL CAUGHT UP"), findsOneWidget);
    });

    testWidgets('an empty catalogue says fits are on their way', (t) async {
      await boot(t, feed: MockFeedRepository(outfits: const []));
      await settle(t, 1600);
      container.read(routerProvider).go('/scroll');
      await settle(t, 900);
      expect(find.text('FRESH FITS INCOMING'), findsOneWidget);
    });
  });

  group('themes', () {
    testWidgets('every skin has poster + backdrop art registered', (t) async {
      for (final s in DripSkin.values) {
        expect(s.posterAsset, startsWith('assets/themes/poster_'));
        expect(s.backdropAsset, startsWith('assets/themes/bg_'));
      }
      expect(DripSkin.values.length, greaterThanOrEqualTo(13));
      // Legacy ids still resolve so saved choices survive the upgrade.
      expect(DripSkin.fromId('retro-cyber'), DripSkin.retroCyber);
      expect(DripSkin.fromId('aurora-cyan'), DripSkin.auroraCyan);
      expect(DripSkin.fromId('vault-cream'), DripSkin.vaultCream);
      expect(DripSkin.fromId('nope'), DripSkin.retroCyber);
    });

    testWidgets('the theme bar switches the whole app and persists', (t) async {
      await boot(t);
      await settle(t, 1600);
      container.read(routerProvider).go('/me');
      await settle(t, 900);
      expect(container.read(savedSkinProvider), DripSkin.retroCyber);
      final target = tapLabelled('Aurora Cyan');
      await t.ensureVisible(target);
      await t.tap(target);
      await settle(t, 800);
      expect(container.read(savedSkinProvider), DripSkin.auroraCyan);
      expect(
        container.read(sharedPreferencesProvider).getString('settings.skin'),
        'aurora-cyan',
      );
      final theme = Theme.of(t.element(find.byType(Scaffold).first));
      expect(theme.colorScheme.primary, DripSkin.auroraCyan.accent);
    });

    testWidgets('a theme changes surfaces and headline typeface too', (
      t,
    ) async {
      await openHome(t);
      final defaultSurface = AppColors.surface;
      expect(AppText.face, DisplayFace.bungee);
      await container
          .read(settingsProvider.notifier)
          .setSkin(DripSkin.holoPink);
      await settle(t, 900);
      expect(AppText.face, DisplayFace.fredoka);
      expect(AppColors.surface, isNot(defaultSurface));
      // ...and back to the original values exactly.
      await container
          .read(settingsProvider.notifier)
          .setSkin(DripSkin.retroCyber);
      await settle(t, 900);
      expect(AppText.face, DisplayFace.bungee);
      expect(AppColors.surface, defaultSurface);
    });

    testWidgets('the picker previews live and reverts if you leave', (t) async {
      await boot(t);
      await settle(t, 1600);
      container.read(routerProvider).push('/themes');
      await settle(t, 900);
      expect(find.text('1 / 13'), findsOneWidget);
      await t.drag(find.byType(PageView), const Offset(-260, 0));
      await settle(t, 800);
      expect(container.read(previewSkinProvider), isNotNull);
      expect(container.read(skinProvider), isNot(DripSkin.retroCyber));
      // Saved choice is untouched until Apply.
      expect(container.read(savedSkinProvider), DripSkin.retroCyber);
      container.read(routerProvider).pop();
      await settle(t, 700);
      expect(container.read(previewSkinProvider), isNull);
      expect(container.read(skinProvider), DripSkin.retroCyber);
    });

    testWidgets('applying a previewed theme saves it', (t) async {
      await boot(t);
      await settle(t, 1600);
      container.read(routerProvider).push('/themes');
      await settle(t, 900);
      await t.drag(find.byType(PageView), const Offset(-260, 0));
      await settle(t, 800);
      final previewed = container.read(previewSkinProvider)!;
      await t.tap(find.text('APPLY THEME'));
      await settle(t, 600);
      expect(container.read(savedSkinProvider), previewed);
      expect(find.text('✓  IN USE'), findsOneWidget);
    });

    testWidgets('a saved skin loads on launch', (t) async {
      await boot(t, skin: DripSkin.holoPink);
      await settle(t, 1600);
      expect(container.read(skinProvider), DripSkin.holoPink);
    });
  });

  group('themed app icon', () {
    late _FakeIcons icons;

    Future<void> bootWithIcons(WidgetTester t, {DripSkin? skin}) async {
      icons = _FakeIcons();
      SharedPreferences.setMockInitialValues({
        'session.onboarded': true,
        if (skin != null) 'settings.skin': skin.id,
      });
      final sp = await SharedPreferences.getInstance();
      t.view.physicalSize = const Size(780, 1688);
      t.view.devicePixelRatio = 2;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            ...testOverrides(sp, signedIn: true),
            appIconServiceProvider.overrideWithValue(icons),
          ],
          retry: (_, _) => null,
          child: const DripApp(),
        ),
      );
      container = ProviderScope.containerOf(
        t.element(find.byType(MaterialApp)),
      );
    }

    Future<void> goToBackground(WidgetTester t) async {
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await t.pump();
    }

    Future<void> comeBack(WidgetTester t) async {
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pump();
    }

    testWidgets('the default theme (flare poster) is the default icon', (
      t,
    ) async {
      await bootWithIcons(t);
      await settle(t, 2400);
      await goToBackground(t);
      expect(icons.calls, [DripSkin.retroCyber]);
    });

    testWidgets('a saved theme sets its own icon on launch', (t) async {
      await bootWithIcons(t, skin: DripSkin.holoPink);
      await settle(t, 2400);
      await goToBackground(t);
      expect(icons.calls.last, DripSkin.holoPink);
    });

    testWidgets('on Android the icon never changes while the app is open (that '
        'restarted the app), only once you leave it', (t) async {
      await bootWithIcons(t);
      await settle(t, 2400);
      final settings = container.read(settingsProvider.notifier);
      // Flicking through the customization bar: three quick changes.
      await settings.setSkin(DripSkin.acidLime);
      await t.pump(const Duration(milliseconds: 300));
      await settings.setSkin(DripSkin.denimStars);
      await t.pump(const Duration(milliseconds: 300));
      await settings.setSkin(DripSkin.mossArchive);
      await settle(t, 3000);
      expect(icons.calls, isEmpty, reason: 'still in the foreground');
      await goToBackground(t);
      expect(icons.calls, [DripSkin.mossArchive]);
      // Coming back and leaving again with no change sends nothing new.
      await comeBack(t);
      await goToBackground(t);
      expect(icons.calls, [DripSkin.mossArchive]);
    });

    testWidgets('on iOS the icon changes once, shortly after you stop', (
      t,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        await bootWithIcons(t);
        await settle(t, 2400);
        icons.calls.clear();
        final settings = container.read(settingsProvider.notifier);
        await settings.setSkin(DripSkin.acidLime);
        await t.pump(const Duration(milliseconds: 300));
        await settings.setSkin(DripSkin.denimStars);
        await t.pump(const Duration(milliseconds: 300));
        await settings.setSkin(DripSkin.mossArchive);
        expect(icons.calls, isEmpty, reason: 'debounced while still changing');
        await settle(t, 1800);

        expect(icons.calls, [DripSkin.mossArchive]);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('previewing in the picker never touches the icon', (t) async {
      await bootWithIcons(t);
      await settle(t, 2400);
      icons.calls.clear();
      container.read(previewSkinProvider.notifier).set(DripSkin.violetBloom);
      await settle(t, 2400);
      await goToBackground(t);
      expect(icons.calls.where((c) => c == DripSkin.violetBloom), isEmpty);
      container.read(previewSkinProvider.notifier).set(null);
    });

    testWidgets('turning "match icon" off restores the default icon', (
      t,
    ) async {
      await bootWithIcons(t, skin: DripSkin.crimsonTeal);
      await settle(t, 2400);
      await goToBackground(t);
      expect(icons.calls.last, DripSkin.crimsonTeal);
      await comeBack(t);
      await container.read(settingsProvider.notifier).setMatchAppIcon(false);
      await settle(t, 500);
      await goToBackground(t);
      expect(icons.calls.last, DripSkin.retroCyber);
      // Off: later theme changes leave the icon alone.
      await comeBack(t);
      await container
          .read(settingsProvider.notifier)
          .setSkin(DripSkin.acidLime);
      await settle(t, 500);
      await goToBackground(t);
      expect(icons.calls.last, DripSkin.retroCyber);
      expect(
        container.read(sharedPreferencesProvider).getBool('settings.matchIcon'),
        isFalse,
      );
    });
  });
}

class _FakeIcons implements AppIconService {
  final calls = <DripSkin>[];

  @override
  Future<void> setIcon(DripSkin skin) async => calls.add(skin);
}
