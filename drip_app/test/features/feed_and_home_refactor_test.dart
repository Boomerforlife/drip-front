import 'dart:async';
import 'dart:ui' as ui;

import 'package:drip/app.dart';
import 'package:drip/core/theme/app_colors.dart';
import 'package:drip/core/theme/app_theme.dart';
import 'package:drip/core/theme/contrast.dart';
import 'package:drip/core/theme/drip_skin.dart';
import 'package:drip/core/utils/image_color.dart';
import 'package:drip/core/widgets/drip_image.dart';
import 'package:drip/core/widgets/tap.dart';
import 'package:drip/data/mock/mock_content.dart';
import 'package:drip/data/models/outfit.dart';
import 'package:drip/data/repositories/feed_repository.dart';
import 'package:drip/features/home/home_screen.dart';
import 'package:drip/features/outfits/outfit_controller.dart';
import 'package:drip/features/outfits/outfit_detail_screen.dart';
import 'package:drip/features/scroll/fashion_scroll_screen.dart';
import 'package:drip/features/selfie/selfie_screen.dart';
import 'package:drip/routing/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fakes.dart';
import '../test_fonts.dart';

/// The feed's collapsed/expanded post, the collage framing, Home without
/// weather (date · time · day/night) and the theme-safe Selfie Coordinator
/// tile.

Future<void> settle(WidgetTester t, [int ms = 700]) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

final collageImage = find
    .descendant(
      of: find.byType(FashionScrollScreen),
      matching: find.byType(DripImage),
    )
    .first;

Finder tapLabelled(String label) =>
    find.byWidgetPredicate((w) => w is Tap && w.semanticLabel == label);

const _sizes = <String, Size>{
  'small android 320x568': Size(320, 568),
  'android 360x740': Size(360, 740),
  'iPhone 390x844': Size(390, 844),
  'tall phone 412x915': Size(412, 915),
  'large phone 430x932': Size(430, 932),
};

Outfit _collage() {
  final base = MockContent.outfits.firstWhere((o) => o.id == 'o_gray');
  return Outfit(
    id: 'o_collage',
    title: 'Gray Overcoat Flat-lay',
    image: base.image,
    price: base.price,
    rate: base.rate,
    creatorHandle: 'drip',
    kind: 'collage',
    tags: base.tags,
    pieces: base.pieces,
  );
}

void main() {
  late ProviderContainer container;

  setUpAll(loadAppFonts);
  tearDown(() => homeClock = DateTime.now);

  Future<void> boot(
    WidgetTester t, {
    Size size = const Size(390, 844),
    DripSkin? skin,
    FeedRepository? feed,
  }) async {
    SharedPreferences.setMockInitialValues({
      'session.onboarded': true,
      if (skin != null) 'settings.skin': skin.id,
    });
    final sp = await SharedPreferences.getInstance();
    t.view.physicalSize = size * 2;
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      ProviderScope(
        overrides: testOverrides(sp, signedIn: true, feed: feed),
        retry: (_, _) => null,
        child: const DripApp(),
      ),
    );
    container = ProviderScope.containerOf(t.element(find.byType(MaterialApp)));
    await settle(t, 1600);
  }

  Future<void> openScroll(WidgetTester t, String id, {Outfit? decode}) async {
    // Asset decoding needs real async: warm the cache so the collage's real
    // aspect ratio is known (as it is on a device) when it lays out.
    if (decode != null) {
      await t.runAsync(
        () => precacheImage(
          dripImageProvider(decode.image),
          t.element(find.byType(MaterialApp)),
        ),
      );
    }
    container.read(routerProvider).go('/scroll?id=$id');
    await settle(t, 1000);
  }

  group('feed post: collapsed → expanded → collapsed', () {
    testWidgets('rests clean, opens in place, closes again', (t) async {
      await boot(t);
      await openScroll(t, 'o_gray');

      // Collapsed: identity + a one-line caption + the rail. No metadata.
      expect(find.text('@drip'), findsOneWidget);
      expect(find.text('FOLLOW'), findsOneWidget);
      expect(find.text('MORE'), findsOneWidget);
      expect(find.textContaining('SHOP THE LOOK'), findsNothing);
      expect(find.textContaining('✦ DRIP'), findsNothing);
      expect(find.text('MINIMAL'), findsNothing);
      for (final l in ['Like', 'Comments', 'Save', 'Share']) {
        expect(tapLabelled(l), findsOneWidget, reason: '$l stays on the rail');
      }

      // Tap the caption: details open in place (still on the scroll route).
      await t.tap(find.text('MORE'));
      await settle(t, 500);
      expect(find.textContaining('SHOP THE LOOK'), findsOneWidget);
      expect(find.text('✦ DRIP 95'), findsOneWidget);
      expect(find.text('MINIMAL'), findsOneWidget);
      expect(find.text('LESS'), findsOneWidget);
      expect(find.textContaining(r'₹'), findsWidgets, reason: 'price shown');
      expect(find.byType(FashionScrollScreen), findsOneWidget);
      expect(find.byType(OutfitDetailScreen), findsNothing);

      // Collapse via the caption again.
      await t.tap(find.text('LESS'));
      await settle(t, 500);
      expect(find.textContaining('SHOP THE LOOK'), findsNothing);
      expect(find.text('MORE'), findsOneWidget);

      // Open, then close by tapping the picture.
      await t.tap(find.text('MORE'));
      await settle(t, 500);
      expect(find.textContaining('SHOP THE LOOK'), findsOneWidget);
      await t.tapAt(const Offset(195, 250));
      await settle(t, 500);
      expect(find.textContaining('SHOP THE LOOK'), findsNothing);
    });

    testWidgets('swiping to the next fit leaves its details closed', (t) async {
      await boot(t);
      await openScroll(t, 'o_gray');
      await t.tap(find.text('MORE'));
      await settle(t, 500);
      expect(find.textContaining('SHOP THE LOOK'), findsOneWidget);
      await t.fling(find.byType(PageView), const Offset(0, -500), 1800);
      await settle(t, 900);
      expect(find.textContaining('SHOP THE LOOK'), findsNothing);
      expect(find.text('MORE'), findsOneWidget);
    });

    testWidgets('actions still work from the collapsed rail', (t) async {
      await boot(t);
      await openScroll(t, 'o_gray');
      await t.tap(tapLabelled('Like'));
      await settle(t, 400);
      expect(container.read(fitMarksProvider).isLiked('o_gray'), isTrue);
      await settle(t, 3000);
      await t.tap(tapLabelled('Save'));
      await settle(t, 400);
      expect(container.read(fitMarksProvider).isSaved('o_gray'), isTrue);
      await settle(t, 3000);
      await t.tap(tapLabelled('Share'));
      await settle(t, 300);
      expect(find.text('SHARING IS COMING AFTER BETA ✦'), findsOneWidget);
    });

    testWidgets('the shop strip still opens the look', (t) async {
      await boot(t);
      await openScroll(t, 'o_gray');
      await t.tap(find.text('MORE'));
      await settle(t, 500);
      await t.tap(find.textContaining('SHOP THE LOOK'));
      await settle(t, 900);
      expect(find.byType(OutfitDetailScreen), findsOneWidget);
    });
  });

  group('collage framing', () {
    for (final entry in _sizes.entries) {
      testWidgets('whole, large and clear of the chrome on ${entry.key}', (
        t,
      ) async {
        final fit = _collage();
        final feed = MockFeedRepository(outfits: [fit]);
        await boot(t, size: entry.value, feed: feed);
        await openScroll(t, 'o_collage', decode: fit);

        final screen = entry.value;
        final collage = t.getRect(collageImage);
        final name = t.getRect(find.text('@drip'));
        final like = t.getRect(tapLabelled('Like'));

        // Whole: inside the screen, below the status bar, above the identity.
        expect(collage.left, greaterThanOrEqualTo(0));
        expect(collage.right, lessThanOrEqualTo(screen.width));
        expect(collage.top, greaterThanOrEqualTo(0));
        expect(collage.bottom, lessThanOrEqualTo(name.top));
        // Full width, centred: no gutter kept for the rail, which floats over
        // the corner collages leave empty (layout v3).
        expect(collage.left, greaterThanOrEqualTo(12 - 0.5));
        expect(screen.width - collage.right, closeTo(collage.left, 0.5));
        expect(like.right, greaterThan(collage.right - collage.width * 0.14));
        // Not tiny.
        expect(collage.width, greaterThan(screen.width * 0.5));

        // Opening the details shrinks it instead of covering it.
        await t.tap(find.text('MORE'));
        await settle(t, 600);
        final open = t.getRect(collageImage);
        final shop = t.getRect(find.textContaining('SHOP THE LOOK'));
        final nameOpen = t.getRect(find.text('@drip'));
        expect(open.bottom, lessThanOrEqualTo(nameOpen.top));
        expect(open.bottom, lessThanOrEqualTo(shop.top));
        expect(open.right, lessThanOrEqualTo(screen.width));
      });
    }

    testWidgets('the space around it takes the collage background colour', (
      t,
    ) async {
      final fit = _collage();
      final feed = MockFeedRepository(outfits: [fit]);
      await boot(t, feed: feed);
      await openScroll(t, 'o_collage', decode: fit);
      // Sampling the picture is real async work.
      await t.runAsync(() => Future<void>.delayed(const Duration(seconds: 1)));
      await settle(t, 600);

      final expected = await t.runAsync(() async {
        final stream = dripImageProvider(fit.image).resolve(
          ImageConfiguration.empty,
        );
        final done = Completer<ui.Image>();
        stream.addListener(
          ImageStreamListener((info, _) => done.complete(info.image)),
        );
        return edgeColor(await done.future);
      });
      expect(expected, isNotNull, reason: 'the test picture has a border');

      final page = t.widget<AnimatedContainer>(
        find
            .descendant(
              of: find.byType(FashionScrollScreen),
              matching: find.byType(AnimatedContainer),
            )
            .first,
      );
      expect((page.decoration! as BoxDecoration).color, expected);
    });
  });

  group('home without weather', () {
    testWidgets('shows date, time and night', (t) async {
      homeClock = () => DateTime(2026, 10, 2, 2, 58); // a Friday
      await boot(t);
      expect(find.text('FRI · 02 OCT'), findsOneWidget);
      expect(find.text('2:58'), findsOneWidget);
      expect(find.text('AM'), findsOneWidget);
      expect(find.text('NIGHT'), findsOneWidget);
      expect(find.text('DAY'), findsNothing);
      expect(find.textContaining('°'), findsNothing);
      expect(find.textContaining('COLOURS OF THE DAY'), findsNothing);
      expect(find.textContaining('Rain'), findsNothing);
      expect(find.text('ASK TAYLOR  →'), findsOneWidget);
    });

    testWidgets('shows day in the afternoon', (t) async {
      homeClock = () => DateTime(2026, 10, 2, 14, 5);
      await boot(t);
      expect(find.text('2:05'), findsOneWidget);
      expect(find.text('PM'), findsOneWidget);
      expect(find.text('DAY'), findsOneWidget);
    });

    testWidgets('noon and midnight read as 12', (t) async {
      homeClock = () => DateTime(2026, 10, 2, 0, 7);
      await boot(t);
      expect(find.text('12:07'), findsOneWidget);
      expect(find.text('AM'), findsOneWidget);
    });

    for (final entry in _sizes.entries) {
      testWidgets('lays out on ${entry.key}', (t) async {
        homeClock = () => DateTime(2026, 10, 2, 23, 59);
        await boot(t, size: entry.value);
        expect(find.text('NIGHT'), findsOneWidget);
        expect(find.text('11:59'), findsOneWidget);
      });
    }
  });

  group('selfie coordinator tile', () {
    testWidgets('is the entry to the guided selfie', (t) async {
      await boot(t);
      expect(find.text('Selfie Coordinator'), findsOneWidget);
      expect(find.text('GUIDED SELFIE'), findsOneWidget);
      await t.tap(tapLabelled('Selfie Coordinator'));
      await settle(t, 900);
      expect(find.byType(SelfieScreen), findsOneWidget);
    });

    testWidgets('paints the theme-safe outline', (t) async {
      for (final skin in [DripSkin.retroCyber, DripSkin.vaultCream]) {
        await boot(t, skin: skin);
        final box = t.widget<Container>(
          find
              .descendant(
                of: tapLabelled('Selfie Coordinator'),
                matching: find.byType(Container),
              )
              .first,
        );
        final deco = box.decoration! as BoxDecoration;
        final p = AppTheme.build(skin).extension<DripPalette>()!;
        expect(
          (deco.border! as Border).top.color,
          selfieCoordinatorBorderColor(p),
        );
      }
    });
  });

  group('contrast', () {
    DripPalette palette(Color accent, Color ground) => DripPalette(
      accent: accent,
      secondary: accent,
      wash: ground,
      ground: ground,
      clarity: 0.5,
      roundness: 1,
    );

    test('outline, icon and text hold their contrast on every skin', () {
      for (final skin in DripSkin.values) {
        final p = AppTheme.build(skin).extension<DripPalette>()!;
        final bg = featureTileBackdrop(p);
        final edge = selfieCoordinatorBorderColor(p);
        expect(
          contrastRatio(edge, bg),
          greaterThanOrEqualTo(3),
          reason: '${skin.label} outline',
        );
        final chip = Color.alphaBlend(p.accent.withValues(alpha: 0.16), bg);
        expect(
          contrastRatio(ensureContrast(p.accent, chip), chip),
          greaterThanOrEqualTo(3),
          reason: '${skin.label} icon',
        );
        expect(
          contrastRatio(ensureContrast(AppColors.cream, bg, minRatio: 4.5), bg),
          greaterThanOrEqualTo(4.5),
          reason: '${skin.label} label',
        );
      }
    });

    test('and on a light ground, where a fixed light accent would vanish', () {
      const light = Color(0xFFF4F1EA);
      for (final accent in [
        AppColors.red,
        AppColors.cream,
        const Color(0xFFF3C98B),
        const Color(0xFFB9F03C),
      ]) {
        final p = palette(accent, light);
        final bg = featureTileBackdrop(p);
        expect(
          contrastRatio(selfieCoordinatorBorderColor(p), bg),
          greaterThanOrEqualTo(3),
          reason: 'accent $accent on light',
        );
        final chip = Color.alphaBlend(accent.withValues(alpha: 0.16), bg);
        expect(
          contrastRatio(ensureContrast(accent, chip), chip),
          greaterThanOrEqualTo(3),
        );
        expect(
          contrastRatio(ensureContrast(AppColors.cream, bg, minRatio: 4.5), bg),
          greaterThanOrEqualTo(4.5),
        );
      }
    });

    test('a colour that already passes is left alone', () {
      const bg = Color(0xFF0E1018);
      expect(ensureContrast(AppColors.cream, bg), AppColors.cream);
    });

    test('dark red keeps its identity (hue is preserved)', () {
      final p = palette(AppColors.red, AppColors.base);
      final edge = selfieCoordinatorBorderColor(p);
      final hsl = HSLColor.fromColor(edge);
      final hue = HSLColor.fromColor(AppColors.red).hue;
      final gap = (hsl.hue - hue).abs();
      expect(gap > 180 ? 360 - gap : gap, lessThan(4));
    });
  });
}
