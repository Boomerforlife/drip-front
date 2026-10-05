import 'package:drip/data/models/outfit.dart';
import 'package:drip/features/scroll/shop_the_look.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

OutfitPiece _piece(
  String name,
  String slot, {
  String? image = 'https://x/p.png',
}) => OutfitPiece(
  slot: slot,
  name: name,
  brand: 'Snitch',
  price: 999,
  image: image,
);

void main() {
  heroFrames();
  swipes();
  group('shopSpots', () {
    test('pairs hotspots with pieces by title, then slot, then order', () {
      final outfit = Outfit(
        id: 'f1',
        title: 'Fit',
        image: 'https://x/c.png',
        price: 0,
        rate: 90,
        creatorHandle: 'drip',
        kind: 'collage',
        pieces: [
          _piece('Black Tee', 'TOP'),
          _piece('Cargo Jeans', 'BOTTOM'),
          _piece('Runner', 'SHOES'),
        ],
        hotspots: const [
          Hotspot(label: 'CARGO JEANS', x: 0.5, y: 0.7),
          Hotspot(label: 'SOMETHING ELSE', x: 0.3, y: 0.2, slot: 'top'),
          Hotspot(label: '?', x: 0.8, y: 1.4),
        ],
      );
      final spots = shopSpots(outfit);
      expect(spots.map((s) => s.piece.name), [
        'Cargo Jeans',
        'Black Tee',
        'Runner',
      ]);
      expect(spots.last.y, 1); // clamped into the collage
    });

    test('skips pieces without a cutout', () {
      final outfit = Outfit(
        id: 'f2',
        title: 'Fit',
        image: 'https://x/c.png',
        price: 0,
        rate: 90,
        creatorHandle: 'drip',
        pieces: [_piece('Black Tee', 'TOP', image: null)],
        hotspots: const [Hotspot(label: 'BLACK TEE', x: 0.5, y: 0.5)],
      );
      expect(shopSpots(outfit), isEmpty);
    });
  });
}

OutfitPiece _named(String name, String slot) => OutfitPiece(
  slot: slot,
  name: name,
  brand: 'Store',
  price: 999,
  image: 'https://x/$slot.png',
);

void heroFrames() {
  group('heroFrame', () {
    test('gives each kind of garment its own footprint', () {
      final shades = heroFrame(_named('Round Sunglasses', 'ACCESSORY'));
      final cap = heroFrame(_named('Monogram Cap', 'ACCESSORY'));
      final jeans = heroFrame(_named('Baggy Cargo Jeans', 'BOTTOM'));
      final necklace = heroFrame(_named('Silver Chain Necklace', 'ACCESSORY'));
      final ring = heroFrame(_named('Black Steel Ring', 'ACCESSORY'));
      final hoodie = heroFrame(_named('Navy Oversized Hoodie', 'TOP'));
      final shoes = heroFrame(_named('Runner', 'SHOES'));

      expect(shades.width, greaterThan(shades.height * 2)); // wide and low
      expect(jeans.height, greaterThan(jeans.width)); // tall
      expect(
        hoodie.width * hoodie.height,
        greaterThan(cap.width * cap.height),
      ); // tops outweigh caps
      expect(
        ring.width * ring.height,
        lessThan(necklace.width * necklace.height),
      ); // small stays small
      expect(cap.centreY, lessThan(0.46)); // hats sit a little high
      expect(jeans.centreY, lessThan(0.46)); // so do jeans
      expect(shoes.centreY, greaterThan(0.46)); // shoes a little low
    });

    test('matches whole words only', () {
      // "capri" is not a cap; it falls back to its slot.
      expect(heroFrame(_named('Capri Trousers', 'BOTTOM')).height, 0.62);
    });
  });
}

void swipes() {
  group('swiping the carousel', () {
    final spots = [
      for (final (i, n) in ['Shades', 'Cap', 'Jeans', 'Necklace'].indexed)
        ShopSpot(_named(n, 'ACCESSORY'), 0.2 + 0.2 * i, 0.5),
    ];

    Future<List<int>> pump(WidgetTester tester) async {
      final picked = <int>[];
      var open = false;
      late StateSetter set;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: StatefulBuilder(
              builder: (context, s) {
                set = s;
                return ShopTheLook(
                  spots: spots,
                  open: open,
                  selected: 1,
                  onOpen: (_) {},
                  onClose: () {},
                  onSelect: picked.add,
                  child: const ColoredBox(color: Colors.teal),
                );
              },
            ),
          ),
        ),
      );
      set(() => open = true);
      await tester.pumpAndSettle();
      return picked;
    }

    Finder pages() => find.byType(PageView);

    testWidgets('a short drag springs back to the same piece', (tester) async {
      final picked = await pump(tester);
      // The swipe hint shows until the first real swipe.
      expect(find.text('‹  SWIPE  ›'), findsOneWidget);
      await tester.drag(pages(), const Offset(-80, 0));
      await tester.pumpAndSettle();
      expect(picked, isEmpty);
    });

    testWidgets('a full swipe moves on, and back', (tester) async {
      final picked = await pump(tester);
      await tester.fling(pages(), const Offset(-400, 0), 1500);
      await tester.pumpAndSettle();
      expect(picked, [2]);
      final hint = tester.widget<AnimatedOpacity>(
        find
            .ancestor(
              of: find.text('‹  SWIPE  ›'),
              matching: find.byType(AnimatedOpacity),
            )
            .first, // the nearest: the hint's own fade
      );
      expect(hint.opacity, 0);
      await tester.fling(pages(), const Offset(400, 0), 1500);
      await tester.pumpAndSettle();
      expect(picked, [2, 1]);
    });

    testWidgets('it cycles past the last piece', (tester) async {
      final picked = await pump(tester);
      for (var k = 0; k < 4; k++) {
        await tester.fling(pages(), const Offset(-400, 0), 1500);
        await tester.pumpAndSettle();
      }
      expect(picked, [2, 3, 0, 1]);
    });

    testWidgets('rapid swipes step through one piece at a time', (
      tester,
    ) async {
      final picked = await pump(tester);
      for (var k = 0; k < 4; k++) {
        await tester.fling(pages(), const Offset(-400, 0), 2500);
        await tester.pump(const Duration(milliseconds: 120));
      }
      await tester.pumpAndSettle();
      // A fling made while the last one is still settling joins it (as in any
      // pager), so rapid swipes move on one piece at a time, never skipping
      // or jumping back, and always settle on a piece.
      expect(picked.length, greaterThanOrEqualTo(2));
      var prev = 1;
      for (final p in picked) {
        expect(p, (prev + 1) % spots.length);
        prev = p;
      }
      final page = tester.widget<PageView>(pages()).controller!.page!;
      expect(page, page.roundToDouble());
    });
  });
}
