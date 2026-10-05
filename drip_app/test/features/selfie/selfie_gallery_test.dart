import 'dart:io';
import 'dart:typed_data';

import 'package:drip/data/providers.dart';
import 'package:drip/features/onboarding/local_selfie.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory dir;
  late ProviderContainer c;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('drip_selfies_');
    SharedPreferences.setMockInitialValues({});
    final sp = await SharedPreferences.getInstance();
    c = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sp),
        selfieFolderProvider.overrideWithValue(() async => dir.path),
      ],
    );
  });

  tearDown(() {
    c.dispose();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  Future<void> save(int b) async {
    await c
        .read(localSelfieProvider.notifier)
        .save(Uint8List.fromList([b, b, b]));
    // Distinct file names (they're timestamped).
    await Future<void>.delayed(const Duration(milliseconds: 3));
  }

  test(
    'every selfie saved stays on the phone, newest first and in use',
    () async {
      await save(1);
      await save(2);
      final gallery = await c.read(selfieGalleryProvider.future);
      expect(gallery, hasLength(2));
      expect(File(gallery.first).readAsBytesSync(), [2, 2, 2]);
      expect(c.read(localStoreProvider).selfiePath, gallery.first);
    },
  );

  test('any selfie can be put back in use', () async {
    await save(1);
    await save(2);
    final gallery = await c.read(selfieGalleryProvider.future);
    await c.read(localSelfieProvider.notifier).use(gallery.last);
    expect(c.read(localStoreProvider).selfiePath, gallery.last);
    expect(await c.read(localSelfieProvider.future), [1, 1, 1]);
  });

  test('deleting the one in use hands over to the newest left', () async {
    await save(1);
    await save(2);
    final gallery = await c.read(selfieGalleryProvider.future);
    await c.read(selfieGalleryProvider.notifier).delete(gallery.first);
    expect(File(gallery.first).existsSync(), isFalse);
    expect(c.read(localStoreProvider).selfiePath, gallery.last);
    await c.read(selfieGalleryProvider.notifier).delete(gallery.last);
    expect(c.read(localStoreProvider).selfiePath, isNull);
    expect(await c.read(selfieGalleryProvider.future), isEmpty);
  });

  test('logging out deletes them all', () async {
    await save(1);
    await save(2);
    await c.read(selfieGalleryProvider.notifier).deleteAll();
    expect(dir.existsSync(), isFalse);
    expect(c.read(localStoreProvider).selfiePath, isNull);
  });
}
