import 'package:drip/data/models/outfit.dart';
import 'package:drip/data/repositories/feed_repository.dart';
import 'package:drip/features/home/feed_controller.dart';
import 'package:drip/features/home/occasions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fakes.dart';

Outfit _fit(String id, int? formality) => Outfit(
  id: id,
  title: id,
  image: 'assets/images/piece_bomber.jpg',
  price: 0,
  rate: 80,
  creatorHandle: 'drip',
  formality: formality,
);

void main() {
  test('an occasion suits fits inside its formality band', () {
    final wedding = Occasions.byId('wedding')!;
    expect(wedding.suits(_fit('a', 5)), isTrue);
    expect(wedding.suits(_fit('b', 2)), isFalse);
    expect(wedding.suits(_fit('c', null)), isFalse);
    expect(Occasions.all.length, 12);
  });

  test('an occasion feed reads ahead and keeps only fits that suit', () async {
    SharedPreferences.setMockInitialValues({});
    final sp = await SharedPreferences.getInstance();
    final fits = [for (var i = 0; i < 20; i++) _fit('f$i', i.isEven ? 5 : 1)];
    final c = ProviderContainer(
      overrides: testOverrides(
        sp,
        signedIn: true,
        feed: MockFeedRepository(outfits: fits, pageSize: 3),
      ),
    );
    addTearDown(c.dispose);

    final weddings = await c.read(scrollFeedProvider('wedding').future);
    expect(weddings.items, isNotEmpty);
    expect(weddings.items.every((o) => o.formality == 5), isTrue);
    expect(weddings.items.length, greaterThanOrEqualTo(8));

    final all = await c.read(feedProvider.future);
    expect(all.items.length, 3, reason: 'the full feed is unfiltered');
  });
}
