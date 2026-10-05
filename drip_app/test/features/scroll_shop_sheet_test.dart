import 'package:drip/app.dart';
import 'package:drip/core/widgets/drip_image.dart';
import 'package:drip/data/mock/mock_content.dart';
import 'package:drip/data/models/outfit.dart';
import 'package:drip/data/repositories/feed_repository.dart';
import 'package:drip/features/scroll/fashion_scroll_screen.dart';
import 'package:drip/features/studio/studio_controller.dart';
import 'package:drip/features/wardrobe/wardrobe_controller.dart';
import 'package:drip/routing/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fakes.dart';
import '../test_fonts.dart';

/// Shop the look in the Scroll: tap a garment in a collage and the sheet
/// slides up with the fit's pieces, store and price, BUY, and saving a piece
/// to the Studio canvas or the wardrobe.
void main() {
  setUpAll(loadAppFonts);

  late ProviderContainer container;

  Future<void> settle(WidgetTester t, [int ms = 900]) async {
    for (var i = 0; i < ms ~/ 100; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  String imageOf(String id) =>
      MockContent.studioPieces.firstWhere((p) => p.id == id).image;

  Outfit collage() {
    final base = MockContent.outfits.firstWhere((o) => o.id == 'o_gray');
    return Outfit(
      id: 'o_shop',
      title: 'Hoodie and boots',
      image: base.image,
      price: 4998,
      rate: 88,
      creatorHandle: 'drip',
      kind: 'collage',
      pieces: [
        OutfitPiece(
          slot: 'TOP',
          name: 'Vintage Hoodie',
          brand: 'Snitch',
          price: 1999,
          image: imageOf('sp_hoodie'),
          buyUrl: 'https://shop.test/hoodie',
        ),
        OutfitPiece(
          slot: 'SHOES',
          name: 'Platform Boots',
          brand: '',
          price: 2999,
          image: imageOf('sp_boots'),
        ),
      ],
      hotspots: const [
        Hotspot(label: 'VINTAGE HOODIE', x: 0.5, y: 0.3, slot: 'top'),
        Hotspot(label: 'PLATFORM BOOTS', x: 0.5, y: 0.9, slot: 'shoes'),
      ],
    );
  }

  Future<void> openFit(WidgetTester t) async {
    SharedPreferences.setMockInitialValues({'session.onboarded': true});
    final sp = await SharedPreferences.getInstance();
    t.view.physicalSize = const Size(390, 844) * 2;
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    final fit = collage();
    await t.pumpWidget(
      ProviderScope(
        overrides: testOverrides(
          sp,
          signedIn: true,
          feed: MockFeedRepository(outfits: [fit]),
        ),
        retry: (_, _) => null,
        child: const DripApp(),
      ),
    );
    container = ProviderScope.containerOf(t.element(find.byType(MaterialApp)));
    await settle(t, 1600);
    await t.runAsync(
      () => precacheImage(
        dripImageProvider(fit.image),
        t.element(find.byType(MaterialApp)),
      ),
    );
    container.read(routerProvider).go('/scroll?id=o_shop');
    await settle(t, 1000);
  }

  /// Taps the collage at ([x], [y]) fractions of it.
  Future<void> tapCollage(WidgetTester t, double x, double y) async {
    final collage = t.getRect(
      find
          .descendant(
            of: find.byType(FashionScrollScreen),
            matching: find.byType(DripImage),
          )
          .first,
    );
    await t.tapAt(
      Offset(
        collage.left + collage.width * x,
        collage.top + collage.height * y,
      ),
    );
    await settle(t);
  }

  testWidgets('tapping a garment slides up its piece, with BUY', (t) async {
    await openFit(t);
    expect(find.text('SHOP THE LOOK'), findsNothing);

    await tapCollage(t, 0.5, 0.3);
    expect(find.text('SHOP THE LOOK'), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.text('Vintage Hoodie'), findsOneWidget);
    expect(find.text('BUY ON SNITCH'), findsOneWidget);

    // Swiping shows the fit's other pieces.
    await t.drag(find.byType(PageView).last, const Offset(-240, 0));
    await settle(t);
    expect(find.text('2 / 2'), findsOneWidget);
    expect(find.text('Platform Boots'), findsOneWidget);
    expect(find.text('NO STORE LINK YET'), findsOneWidget);

    // Tapping the dimmed fit closes it.
    await t.tapAt(const Offset(195, 140));
    await settle(t);
    expect(find.text('SHOP THE LOOK'), findsNothing);
  });

  testWidgets('a tap on the shoes opens on the shoes', (t) async {
    await openFit(t);
    await tapCollage(t, 0.5, 0.9);
    expect(find.text('2 / 2'), findsOneWidget);
    expect(find.text('Platform Boots'), findsOneWidget);
  });

  testWidgets('+ STUDIO puts it on the canvas; + WARDROBE saves it', (t) async {
    await openFit(t);
    await tapCollage(t, 0.5, 0.3);

    await t.tap(find.text('+ STUDIO'));
    await settle(t);
    expect(container.read(studioProvider).worn['TOPS']?.id, 'sp_hoodie');
    expect(find.text('OPEN CANVAS →'), findsOneWidget);

    await t.tap(find.text('+ WARDROBE'));
    await settle(t);
    final items = container.read(wardrobeProvider).value ?? const [];
    expect(items.any((i) => i.garmentId == 'sp_hoodie'), isTrue);
    expect(find.text('IN WARDROBE ✓'), findsOneWidget);
  });
}
