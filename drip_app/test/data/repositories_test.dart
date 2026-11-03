import 'dart:typed_data';

import 'package:drip/core/utils/format.dart';
import 'package:drip/data/mock/mock_users.dart';
import 'package:drip/data/models/account.dart';
import 'package:drip/data/models/outfit.dart';
import 'package:drip/data/models/wardrobe.dart';
import 'package:drip/data/repositories/local_store.dart';
import 'package:drip/data/repositories/outfit_repository.dart';
import 'package:drip/data/repositories/social_repository.dart';
import 'package:drip/data/repositories/stylist_repository.dart';
import 'package:drip/data/repositories/wardrobe_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<LocalStore> _store() async {
  SharedPreferences.setMockInitialValues({});
  return LocalStore(await SharedPreferences.getInstance());
}

void main() {
  group('OutfitRepository', () {
    test('discover filters by category', () async {
      final repo = MockOutfitRepository();
      final y2k = await repo.discover(category: 'Y2K');
      expect(y2k, isNotEmpty);
      expect(y2k.every((o) => o.categories.contains('Y2K')), isTrue);
      final vintage = await repo.discover(category: 'VINTAGE');
      expect(vintage.map((o) => o.id), isNot(equals(y2k.map((o) => o.id))));
    });

    test('search matches fits and creators; blank query is empty', () async {
      final repo = MockOutfitRepository();
      final r = await repo.search('cyberpunk techwear');
      expect(r.fits, isNotEmpty);
      expect(r.creatorHandles, isNotEmpty);
      final none = await repo.search('   ');
      expect(none.fits, isEmpty);
      final miss = await repo.search('zzzzqqqq');
      expect(miss.total, 0);
    });

    test('search finds accounts by name', () async {
      final r = await MockOutfitRepository().search('sofia');
      expect(r.creatorHandles, contains('sofiamae'));
    });

    test('save toggles the saved list in the library', () async {
      final repo = MockOutfitRepository();
      final before = (await repo.library()).saved.length;
      await repo.setSaved('o_baggy', saved: true);
      expect((await repo.library()).saved.length, before + 1);
      await repo.setSaved('o_baggy', saved: false);
      expect((await repo.library()).saved.length, before);
    });
  });

  group('SocialRepository', () {
    test('follow state persists to the local store', () async {
      final store = await _store();
      final repo = MockSocialRepository(store);
      expect(await repo.followingHandles(), isNot(contains('lxna.fits')));
      await repo.setFollowing('lxna.fits', follow: true);
      expect(await repo.followingHandles(), contains('lxna.fits'));
      // A new repository (app restart) reads the persisted set.
      final reborn = MockSocialRepository(store);
      expect(await reborn.followingHandles(), contains('lxna.fits'));
    });

    test('resolves users and reports unknown handles as null', () async {
      final repo = MockSocialRepository(await _store());
      expect((await repo.user('sofiamae'))?.name, 'Sofia Mae');
      expect(await repo.user('nobody_here'), isNull);
      expect((await repo.user(MockUsers.meHandle))?.name, 'Taylor Vance');
    });
  });

  group('WardrobeRepository', () {
    test('upload, retag and remove', () async {
      final repo = MockWardrobeRepository();
      final start = (await repo.items()).length;
      final item = await repo.upload(
        Uint8List.fromList([1]),
        contentType: 'image/jpeg',
      );
      expect(item.isProcessing, isTrue);
      final ready = (await repo.items()).first;
      expect(ready.id, item.id);
      expect(ready.isReady, isTrue);
      await repo.update(item.id, slot: 'shoes');
      expect((await repo.items()).first.category, 'Shoes');
      await repo.remove(item.id);
      expect((await repo.items()).length, start);
    });

    test('API items read status, tags and a readable name', () {
      final item = WardrobeItem.fromJson({
        'id': 'w1',
        'origin': 'saved',
        'status': 'ready',
        'garmentId': 'g1',
        'image': 'https://cdn.test/w1.png',
        'category': 'bottom',
        'colour': 'navy',
        'formality': 2,
        'season': ['summer', 'all-season'],
        'styleTags': ['streetwear'],
        'addedAt': '2026-09-27T10:00:00Z',
      });
      expect(item.name, 'Navy Bottoms');
      expect(item.category, 'Bottoms');
      expect(item.status, 'SAVED FROM DRIP');
      expect(item.tags, ['#STREETWEAR', 'SUMMER']);
      expect(item.section, 'BOTTOMS');
    });
  });

  group('StylistRepository', () {
    test('restricts to wardrobe pieces when asked', () async {
      final wardrobe = await MockWardrobeRepository().items();
      final bp = await MockStylistRepository().generateBlueprint(
        occasion: 'Concert',
        vibe: 'Experimental Cyber',
        restrictToWardrobe: true,
        wardrobe: wardrobe,
      );
      expect(
        bp.pieces.map((p) => p.name),
        everyElement(isIn(wardrobe.map((w) => w.name))),
      );
      expect(bp.drip, inInclusiveRange(90, 98));
    });
  });

  group('formatting', () {
    test('prices are rupees with Indian grouping', () {
      expect(formatPrice(999), '₹999');
      expect(formatPrice(1499), '₹1,499');
      expect(formatPrice(149999), '₹1,49,999');
      expect(formatPrice(12345678), '₹1,23,45,678');
    });

    test('/me parses credits, prefs and signed avatar URLs', () {
      final a = Account.fromJson({
        'user': {
          'id': 'u1',
          'onboarding_prefs': {
            'moods': ['y2k'],
          },
          'skin_tone': null,
          'style_tags': ['y2k'],
          'gen_credits_used': 1,
          'created_at': '2026-09-27T10:00:00Z',
        },
        'genCreditsRemaining': 2,
        'avatarUrls': ['https://storage.test/a.jpg?sig'],
      });
      expect(a.genCreditsRemaining, 2);
      expect(a.hasAvatar, isTrue);
      expect(a.onboardingPrefs['moods'], ['y2k']);
    });
  });

  test('a Scroll fit carries its budget band when the server sends one', () {
    Outfit fit(Map<String, dynamic> extra) =>
        Outfit.fromJson({'id': 'f1', 'kind': 'collage', ...extra});
    expect(fit({'budgetBand': 'in'}).budgetBand, 'in');
    expect(
      fit({'budgetBand': 'over'}).copyWith(isLiked: true).budgetBand,
      'over',
    );
    expect(fit({}).budgetBand, isNull);
  });
}
