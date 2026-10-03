import 'package:drip/core/theme/app_theme.dart';
import 'package:drip/core/theme/drip_skin.dart';
import 'package:drip/data/models/outfit.dart';
import 'package:drip/features/outfits/shop_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a piece keeps its store name and product link from the API', () {
    final p = OutfitPiece.fromJson({
      'name': 'Obsidian Black Sneakers',
      'category': 'shoes',
      'brand': 'Snitch',
      'price': {'amount': 1999, 'currency': 'INR'},
      'buyUrl': 'https://www.snitch.co.in/products/obsidian-black-sneakers',
    });
    expect(p.brand, 'Snitch');
    expect(p.slot, 'SHOES');
    expect(p.buyUrl, startsWith('https://www.snitch.co.in/'));
  });

  testWidgets('Shop the look lists each piece with a link to its store', (
    tester,
  ) async {
    const outfit = Outfit(
      id: 'f1',
      title: 'Fit',
      image: '',
      price: 3998,
      rate: 80,
      creatorHandle: 'drip',
      pieces: [
        OutfitPiece(
          slot: 'TOP',
          name: 'Divine Tee',
          brand: 'Capsul',
          price: 1999,
          buyUrl: 'https://shopcapsul.com/products/divine-tee',
        ),
        OutfitPiece(
          slot: 'SHOES',
          name: 'No Link Shoe',
          brand: '',
          price: 1999,
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.build(DripSkin.retroCyber),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showShopSheet(context, outfit),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('SHOP THE LOOK'), findsOneWidget);
    expect(find.text('VIEW ON CAPSUL ↗'), findsOneWidget);
    expect(find.text('SHOES · NO LINK YET'), findsOneWidget);
  });
}
