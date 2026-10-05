import 'dart:typed_data';

import 'package:drip/data/api/api_client.dart';
import 'package:drip/data/models/account.dart';
import 'package:drip/data/models/product.dart';
import 'package:drip/data/providers.dart';
import 'package:drip/data/repositories/account_repository.dart';
import 'package:drip/data/repositories/discovery_repository.dart';
import 'package:drip/features/onboarding/local_selfie.dart';
import 'package:drip/features/search/search_controller.dart';
import 'package:drip/features/selfie/selfie_camera.dart';
import 'package:drip/features/selfie/selfie_controller.dart';
import 'package:drip/features/selfie/shot_review.dart';
import 'package:drip/features/social/social_controller.dart';
// fake_async ships with flutter_test.
// ignore: depend_on_referenced_packages
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fakes.dart';

Future<ProviderContainer> _container({
  AccountRepository? account,
  DiscoveryRepository? discovery,
  bool signedIn = true,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final c = ProviderContainer(
    overrides: [
      ...testOverrides(
        prefs,
        signedIn: signedIn,
        account: account,
        discovery: discovery,
      ),
      selfieStillAnalyzerProvider.overrideWithValue((_) async => null),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('discovered products', () {
    test(
      'parse the API shape: ready cut-out vs processing, facts never invented',
      () {
        final ready = DripProduct.fromJson({
          'id': 'g1',
          'status': 'ready',
          'title': 'Boxy Tee',
          'brand': 'Snitch',
          'retailer': 'Snitch',
          'source': 'shopify',
          'price': {'amount': 1299, 'currency': 'INR'},
          'originalPrice': {'amount': 1799, 'currency': 'INR'},
          'image': 'https://cdn/cutouts/g1.png',
          'cutout': true,
          'category': 'top',
          'subcategory': 't-shirt',
          'colour': 'black',
          'fit': 'oversized',
          'pattern': null,
          'styleTags': ['streetwear'],
          'sizes': ['M', 'L'],
          'availability': 'in_stock',
          'confidence': 0.91,
        });
        expect(ready.ready, isTrue);
        expect(ready.onSale, isTrue);
        expect(ready.facts, ['T-shirt', 'Oversized', 'Black']);
        expect(ready.price, 1299);
        final processing = DripProduct.fromJson({
          'id': 'g2',
          'status': 'processing',
          'title': 'Tee',
          'image': 'https://store/x.jpg',
        });
        expect(processing.ready, isFalse);
        expect(processing.cutout, isFalse);
        expect(processing.facts, isEmpty);
      },
    );

    test('a search shows what is ready, then polls while Drip is still cutting pieces out', () {
      fakeAsync((async) {
        late ProviderContainer c;
        final repo = MockDiscoveryRepository();
        _container(discovery: repo).then((x) => c = x);
        async.flushMicrotasks();
        final sub = c.listen(productSearchProvider('black tee'), (_, _) {});
        async.flushMicrotasks();
        final first = sub.read().requireValue;
        expect(first.pending, isTrue);
        expect(first.products.where((p) => !p.ready).map((p) => p.id), [
          'p-new',
        ]);

        async.elapse(ProductSearchController.pollEvery);
        async.flushMicrotasks();
        final next = sub.read().requireValue;
        expect(repo.searches, 2);
        expect(next.pending, isFalse);
        expect(
          next.products.every((p) => p.ready),
          isTrue,
          reason: 'the processing piece swapped to its cut-out',
        );

        // Nothing pending: no more polling.
        async.elapse(ProductSearchController.pollEvery * 3);
        async.flushMicrotasks();
        expect(repo.searches, 2);
      });
    });

    test('importing a link: blocked stores give their reason', () async {
      final repo = MockDiscoveryRepository();
      await expectLater(
        repo.importLink('https://www.myntra.com/p/1'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            contains('refused automated access'),
          ),
        ),
      );
      final p = await repo.importLink('https://store.test/products/x');
      expect(p.ready, isFalse);
      expect(repo.imported, ['https://store.test/products/x']);
    });
  });

  group('selfies stay on the phone', () {
    test(
      'the Selfie Coordinator keeps the photo locally and uploads nothing',
      () async {
        final account = MockAccountRepository();
        final c = await _container(account: account);
        final sub = c.listen(selfieProvider, (_, _) {});
        final n = c.read(selfieProvider.notifier);
        await n.addShot(Uint8List.fromList([1, 2, 3, 4]));
        expect(sub.read().current?.review, isA<ShotReview>());
        await n.useSelected();
        expect(c.read(localSelfieProvider).value, [1, 2, 3, 4]);
        expect(
          c.read(localStoreProvider).selfiePath,
          startsWith('data:image/jpeg'),
        );
        expect(account.photoUploads, 0);
        expect((await account.me()).hasAvatar, isFalse);

        // It survives a restart (read back from the device), and removing it forgets it.
        c.invalidate(localSelfieProvider);
        expect(await c.read(localSelfieProvider.future), [1, 2, 3, 4]);
        await c.read(localSelfieProvider.notifier).remove();
        expect(c.read(localStoreProvider).selfiePath, isNull);
      },
    );
  });

  group('profile: photo, name, username', () {
    test('the account carries username, name, photo and admin flag', () {
      final a = Account.fromJson({
        'user': {'id': 'u1'},
        'username': 'asha.k',
        'displayName': 'Asha',
        'photoUrl': 'https://cdn/p.png',
        'isAdmin': true,
      });
      expect(
        [a.username, a.displayName, a.photoUrl, a.isAdmin],
        ['asha.k', 'Asha', 'https://cdn/p.png', true],
      );
    });

    test(
      'usernames follow the API rules, and a taken one is refused',
      () async {
        expect(usernameProblem('asha.k_99'), isNull);
        expect(usernameProblem('ab'), contains('3–24'));
        expect(usernameProblem('Has Caps'), isNotNull);
        expect(usernameProblem('admin'), contains('reserved'));

        final repo = MockAccountRepository(takenUsernames: {'taken_name'});
        expect((await repo.usernameAvailable('taken_name')).available, isFalse);
        expect((await repo.usernameAvailable('free_name')).available, isTrue);
        await expectLater(
          repo.setUsername('taken_name'),
          throwsA(isA<ApiException>().having((e) => e.status, 'status', 409)),
        );
        expect((await repo.setUsername('Free_Name')).username, 'free_name');
      },
    );

    test(
      'the profile shows what the user set, over the Google identity',
      () async {
        final account = MockAccountRepository();
        final c = await _container(account: account);
        // Watched, as the profile and settings screens do (unwatched providers pause).
        c.listen(myProfileProvider, (_, _) {});
        final google = await c.read(myProfileProvider.future);
        expect(google.handle, 'taylor.vance');
        expect(google.name, 'Taylor Vance');

        await account.setUsername('tay.v');
        await account.setDisplayName('Tay');
        await account.uploadPhoto(Uint8List(4), contentType: 'image/jpeg');
        c.invalidate(accountProvider);
        await c.read(accountProvider.future);
        final mine = await c.read(myProfileProvider.future);
        expect([mine.handle, mine.name], ['tay.v', 'Tay']);
        expect(mine.avatar, isNotEmpty);
        expect(account.photoUploads, 1);

        await account.removePhoto();
        expect((await account.me()).photoUrl, isNull);
      },
    );
  });
}
