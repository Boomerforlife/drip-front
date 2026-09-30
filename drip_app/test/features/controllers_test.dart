import 'dart:typed_data';

import 'package:drip/core/theme/drip_skin.dart';
import 'package:drip/data/api/api_client.dart';
import 'package:drip/data/mock/mock_content.dart';
import 'package:drip/data/models/settings.dart';
import 'package:drip/data/providers.dart';
import 'package:drip/data/repositories/account_repository.dart';
import 'package:drip/data/repositories/outfit_repository.dart';
import 'package:drip/features/bag/bag_controller.dart';
import 'package:drip/features/create/create_ootd_controller.dart';
import 'package:drip/features/home/feed_controller.dart';
import 'package:drip/features/outfits/outfit_controller.dart';
import 'package:drip/features/search/search_controller.dart';
import 'package:drip/features/session/session_controller.dart';
import 'package:drip/features/settings/settings_controller.dart';
import 'package:drip/features/social/social_controller.dart';
import 'package:drip/features/studio/studio_controller.dart';
import 'package:drip/features/wardrobe/wardrobe_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fakes.dart';

Future<ProviderContainer> _container({bool signedIn = false}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final c = ProviderContainer(
    overrides: testOverrides(prefs, signedIn: signedIn),
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('the feed pages through the cursor and stops at the end', () async {
    final c = await _container(signedIn: true);
    final first = await c.read(feedProvider.future);
    expect(first.items, hasLength(3));
    expect(first.hasMore, isTrue);
    while (c.read(feedProvider).requireValue.hasMore) {
      await c.read(feedProvider.notifier).loadMore();
    }
    final all = c.read(feedProvider).requireValue.items;
    expect(all.length, MockContent.outfits.length);
    expect(all.map((o) => o.id).toSet().length, all.length, reason: 'no dupes');
  });

  test('likes and saves are optimistic and land in the library', () async {
    final c = await _container(signedIn: true);
    final fit = (await c.read(feedProvider.future)).items.first;
    await c.read(libraryProvider.future);
    final marks = c.read(fitMarksProvider.notifier);
    final wasLiked = c.read(fitMarksProvider).isLiked(fit.id);
    final wasSaved = c.read(fitMarksProvider).isSaved(fit.id);

    expect(await marks.toggleLike(fit.id), !wasLiked);
    expect(c.read(fitMarksProvider).isLiked(fit.id), !wasLiked);

    await marks.toggleSave(fit.id);
    expect(c.read(fitMarksProvider).isSaved(fit.id), !wasSaved);
    final lib = await c.read(libraryProvider.future);
    expect(lib.saved.any((o) => o.id == fit.id), !wasSaved);
  });

  test('a failed save reverts and rethrows', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: testOverrides(
        prefs,
        signedIn: true,
        outfits: _FailingOutfits(),
      ),
    );
    addTearDown(c.dispose);
    await expectLater(
      c.read(fitMarksProvider.notifier).toggleSave('f1'),
      throwsA(isA<ApiException>()),
    );
    expect(c.read(fitMarksProvider).isSaved('f1'), isFalse);
  });

  test('settings persist across container restarts', () async {
    final c = await _container();
    await c.read(settingsProvider.notifier).setUsername('new_handle');
    await c.read(settingsProvider.notifier).setPrivate(true);
    await c.read(settingsProvider.notifier).setSkin(DripSkin.auroraCyan);
    await c
        .read(settingsProvider.notifier)
        .setWhoCanInteract(InteractAudience.nobody);

    final prefs = c.read(sharedPreferencesProvider);
    final c2 = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(c2.dispose);
    final s = c2.read(settingsProvider);
    expect(s.username, 'new_handle');
    expect(s.privateAccount, isTrue);
    expect(s.skin, DripSkin.auroraCyan);
    expect(s.whoCanInteract, InteractAudience.nobody);
  });

  test('onboarding picks toggle and session lifecycle works', () async {
    final c = await _container();
    expect(c.read(sessionProvider).signedIn, isFalse);
    final before = c.read(onboardingProvider).moodIds.length;
    c.read(onboardingProvider.notifier).toggleMood('preppy');
    expect(c.read(onboardingProvider).moodIds.length, before + 1);
    c.read(onboardingProvider.notifier).toggleMood('preppy');
    expect(c.read(onboardingProvider).moodIds.length, before);

    // Picks made before sign-in wait on the device…
    c.read(onboardingProvider.notifier)
      ..toggleMood('preppy')
      ..toggleGenre('Gorpcore')
      ..setName('Taylor');
    await c.read(sessionProvider.notifier).completeOnboarding();
    expect(c.read(sessionProvider).signedIn, isFalse);
    expect(c.read(localStoreProvider).prefsPending, isTrue);

    // …and reach the account once Google sign-in completes.
    await c.read(sessionProvider.notifier).signInWithGoogle();
    await pumpEventQueue();
    expect(c.read(sessionProvider).signedIn, isTrue);
    expect(c.read(sessionProvider).user?.email, testUser.email);
    expect(c.read(localStoreProvider).prefsPending, isFalse);
    final me = await c.read(accountRepositoryProvider).me();
    expect(me.onboardingPrefs['moods'], ['preppy']);
    expect(me.onboardingPrefs['genres'], ['Gorpcore']);
    expect(me.onboardingPrefs['name'], 'Taylor');
    expect(me.styleTags, ['preppy', 'gorpcore']);

    await c.read(sessionProvider.notifier).logout();
    expect(c.read(sessionProvider).signedIn, isFalse);
    expect(c.read(sharedPreferencesProvider).getKeys(), isEmpty);
  });

  test('a signed-in profile comes from the Google account', () async {
    final c = await _container(signedIn: true);
    final me = await c.read(myProfileProvider.future);
    expect(me.name, 'Taylor Vance');
    expect(me.handle, 'taylor.vance');
    expect(me.followers, 0);
  });

  test('deleting the account signs out', () async {
    final c = await _container(signedIn: true);
    await c.read(sessionProvider.notifier).deleteAccount();
    final repo = c.read(accountRepositoryProvider) as MockAccountRepository;
    expect(repo.deleted, isTrue);
    expect(c.read(sessionProvider).signedIn, isFalse);
  });

  test('following toggles', () async {
    final c = await _container();
    await c.read(followingSetProvider.future);
    await c.read(followingSetProvider.notifier).toggle('lxna.fits');
    expect(c.read(followingSetProvider).requireValue, contains('lxna.fits'));
    await c.read(followingSetProvider.notifier).toggle('lxna.fits');
    expect(
      c.read(followingSetProvider).requireValue,
      isNot(contains('lxna.fits')),
    );
  });

  test('recent searches: add, de-dupe, cap, remove, persist', () async {
    final c = await _container();
    final n = c.read(recentSearchesProvider.notifier);
    await n.add('Tokyo');
    await n.add('tokyo'); // case-insensitive de-dupe
    expect(
      c.read(recentSearchesProvider).where((e) => e.toLowerCase() == 'tokyo'),
      hasLength(1),
    );
    expect(c.read(recentSearchesProvider).first, 'tokyo');
    for (var i = 0; i < 12; i++) {
      await n.add('q$i');
    }
    expect(c.read(recentSearchesProvider).length, lessThanOrEqualTo(8));
    await n.remove('q11');
    expect(c.read(recentSearchesProvider), isNot(contains('q11')));
    expect(
      c.read(sharedPreferencesProvider).getStringList('search.recents'),
      isNotNull,
    );
  });

  test('bag de-dupes lines and totals', () async {
    final c = await _container();
    final bag = c.read(bagProvider.notifier);
    const a = BagLine(name: 'A', subtitle: 'x', price: 100);
    const b = BagLine(name: 'B', subtitle: 'y', price: 50);
    expect(bag.addAll([a, b]), 2);
    expect(bag.addAll([a]), 0);
    expect(bag.total, 150);
    bag.remove('A');
    expect(bag.total, 50);
  });

  test('studio: select, undo, reset, randomize, save', () async {
    final c = await _container(signedIn: true);
    final s = c.read(studioProvider.notifier)..setCategory('OUTERWEAR');
    final pieces = await c.read(
      studioPiecesProvider(('OUTERWEAR', false)).future,
    );
    s.select(pieces[0]);
    s.select(pieces[1]);
    expect(c.read(studioProvider).worn['OUTERWEAR']!.id, pieces[1].id);
    s.undo();
    expect(c.read(studioProvider).worn['OUTERWEAR']!.id, pieces[0].id);
    s.reset();
    expect(c.read(studioProvider).worn, isEmpty);

    await s.randomize();
    expect(c.read(studioProvider).worn, isNotEmpty);
    expect(c.read(studioProvider).dripRate, isNull, reason: 'unsaved');

    // Saving asks the server for the score; changing the canvas clears it.
    s
      ..setCategory('OUTERWEAR')
      ..select(pieces[0])
      ..setCategory('TOPS');
    final tops = await c.read(studioPiecesProvider(('TOPS', false)).future);
    s.select(tops.first);
    final fit = await s.save();
    expect(c.read(studioProvider).dripRate, fit.dripRate);
    expect(fit.dripRate, inInclusiveRange(84, 98));
    s.select(tops.last);
    expect(c.read(studioProvider).dripRate, isNull);
  });

  test('wardrobe uploads start processing and poll until ready', () async {
    final c = await _container(signedIn: true);
    await c.read(wardrobeProvider.future);
    final item = await c
        .read(wardrobeProvider.notifier)
        .upload(Uint8List.fromList([1]), contentType: 'image/jpeg');
    expect(item.isProcessing, isTrue);
    expect(c.read(wardrobeProvider).requireValue.first.isProcessing, isTrue);
    await Future<void>.delayed(
      WardrobeController.pollEvery + const Duration(milliseconds: 600),
    );
    final now = c.read(wardrobeProvider).requireValue.first;
    expect(now.id, item.id);
    expect(now.isReady, isTrue);
    expect(now.name, 'Black Jacket');
  });

  test('create OOTD tags normalise and a post lands in the posts', () async {
    final c = await _container();
    await c.read(postsProvider.future);
    final n = c.read(createOotdProvider.notifier);
    n.addTag('tech wear');
    expect(c.read(createOotdProvider).tags, contains('#TECHWEAR'));
    n.addTag('#techwear'); // duplicate ignored
    expect(
      c.read(createOotdProvider).tags.where((t) => t == '#TECHWEAR'),
      hasLength(1),
    );
    n.removeTag('#Y2K');
    expect(c.read(createOotdProvider).tags, isNot(contains('#Y2K')));

    final before = c.read(postsProvider).requireValue.length;
    final post = await n.post();
    expect(post, isNotNull);
    final feed = c.read(postsProvider).requireValue;
    expect(feed.length, before + 1);
    expect(feed.first.creatorHandle, 'taylor_drip');
  });
}

class _FailingOutfits extends MockOutfitRepository {
  @override
  Future<void> setSaved(String id, {required bool saved}) async =>
      throw const ApiException(500, 'boom');
}
