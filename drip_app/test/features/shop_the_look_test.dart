import 'package:drip/data/models/outfit.dart';
import 'package:drip/features/scroll/shop_the_look.dart';
import 'package:flutter/material.dart';
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
  group('tap to shop', () {
    testWidgets('a tap opens the piece nearest to it', (tester) async {
      final spots = [
        ShopSpot(_named('Cap', 'ACCESSORY'), 0.2, 0.2),
        ShopSpot(_named('Jeans', 'BOTTOM'), 0.5, 0.7),
        ShopSpot(_named('Runner', 'SHOES'), 0.8, 0.9),
      ];
      final opened = <int>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 200,
              height: 400,
              child: ShopTheLook(
                spots: spots,
                onOpen: opened.add,
                child: const ColoredBox(color: Colors.teal),
              ),
            ),
          ),
        ),
      );
      final box = tester.getRect(find.byType(ColoredBox).last);
      await tester.tapAt(box.topLeft + const Offset(95, 270));
      await tester.tapAt(box.topLeft + const Offset(30, 70));
      expect(opened, [1, 0]);
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
