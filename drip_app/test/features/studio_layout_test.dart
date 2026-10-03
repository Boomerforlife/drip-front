import 'dart:ui' show Rect;

import 'package:drip/data/models/stylist.dart';
import 'package:drip/data/providers.dart';
import 'package:drip/features/studio/studio_controller.dart';
import 'package:drip/features/studio/studio_layouts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fakes.dart';

StudioPiece _p(String id, String category, [String? name]) => StudioPiece(
  id: id,
  name: name ?? id,
  category: category,
  image: 'assets/images/piece_bomber.jpg',
);

void main() {
  group('FitLayouts.plan', () {
    test('a blank canvas is the street column with its three add boxes', () {
      final plan = FitLayouts.plan(const {});
      expect(plan.layout.id, 'street-column');
      expect(plan.missing.map((s) => s.slot), ['top', 'bottom', 'shoes']);
      expect(plan.placed, isEmpty);
    });

    test('top, bottoms and shoes each land in their own box', () {
      final worn = {
        'TOPS': _p('t', 'TOPS'),
        'BOTTOMS': _p('b', 'BOTTOMS'),
        'FOOTWEAR': _p('s', 'FOOTWEAR'),
      };
      final plan = FitLayouts.plan(worn);
      expect(plan.placed.keys, containsAll(['TOPS', 'BOTTOMS', 'FOOTWEAR']));
      expect(plan.missing, isEmpty);
      final top = plan.placed['TOPS']!, bottom = plan.placed['BOTTOMS']!;
      expect(
        top.y + top.h,
        lessThanOrEqualTo(bottom.y + 0.011),
        reason: 'the top sits above the bottoms',
      );
    });

    test('a layer switches to the one layout with room for it', () {
      final plan = FitLayouts.plan({
        'TOPS': _p('t', 'TOPS'),
        'BOTTOMS': _p('b', 'BOTTOMS'),
        'FOOTWEAR': _p('s', 'FOOTWEAR'),
        'OUTERWEAR': _p('o', 'OUTERWEAR'),
      });
      expect(plan.layout.id, 'split-column');
      expect(plan.placed.length, 4);
    });

    test('a dress uses the dress layout', () {
      final plan = FitLayouts.plan({
        'DRESSES': _p('d', 'DRESSES'),
        'FOOTWEAR': _p('s', 'FOOTWEAR'),
      });
      expect(plan.layout.id, 'dress-edit');
      expect(plan.missing, isEmpty);
    });

    test('an accessory goes to its kind’s slot, else the first free one', () {
      final bag = FitLayouts.plan({
        'TOPS': _p('t', 'TOPS'),
        'ACCESSORIES': _p('a', 'ACCESSORIES', 'Canvas tote bag'),
      });
      expect(bag.placed['ACCESSORIES']!.slot, 'bag');
      final shades = FitLayouts.plan({
        'TOPS': _p('t', 'TOPS'),
        'ACCESSORIES': _p('a', 'ACCESSORIES', 'Oval sunglasses'),
      });
      expect(shades.placed['ACCESSORIES']!.slot, 'eyewear');
      final mystery = FitLayouts.plan({
        'TOPS': _p('t', 'TOPS'),
        'ACCESSORIES': _p('a', 'ACCESSORIES', 'Lucky charm'),
      });
      expect(mystery.placed['ACCESSORIES'], isNotNull);
    });

    test('accessory kinds follow the backend rules', () {
      expect(FitLayouts.accessoryKind('Classic leather belt'), 'belt');
      expect(FitLayouts.accessoryKind('Chunky silver chain'), 'jewellery');
      expect(FitLayouts.accessoryKind('Bucket hat'), 'headwear');
      expect(FitLayouts.accessoryKind('Watch strap'), 'watch');
      expect(FitLayouts.accessoryKind('Linen shirt'), isNull);
    });

    test('every layout box stays on the canvas', () {
      for (final l in FitLayouts.all) {
        for (final s in l.slots) {
          expect(
            s.x + s.w,
            lessThanOrEqualTo(1.0001),
            reason: '${l.id}/${s.slot}',
          );
          expect(
            s.y + s.h,
            lessThanOrEqualTo(1.0001),
            reason: '${l.id}/${s.slot}',
          );
        }
      }
    });
  });

  group('StudioController', () {
    late ProviderContainer c;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final sp = await SharedPreferences.getInstance();
      c = ProviderContainer(overrides: testOverrides(sp, signedIn: true));
      addTearDown(c.dispose);
    });

    test('a dress replaces the top and bottoms, and back again', () {
      final s = c.read(studioProvider.notifier)
        ..setCategory('TOPS')
        ..select(_p('t', 'TOPS'))
        ..setCategory('BOTTOMS')
        ..select(_p('b', 'BOTTOMS'))
        ..setCategory('DRESSES');
      expect(s.select(_p('d', 'DRESSES')), isNotNull);
      expect(c.read(studioProvider).worn.keys, ['DRESSES']);
      s.setCategory('TOPS');
      expect(s.select(_p('t', 'TOPS')), isNotNull);
      expect(c.read(studioProvider).worn.keys, ['TOPS']);
    });

    test('tapping the worn piece, or TAKE OFF, removes it', () {
      final s = c.read(studioProvider.notifier)..setCategory('FOOTWEAR');
      final shoe = _p('s', 'FOOTWEAR');
      s.select(shoe);
      expect(c.read(studioProvider).worn, contains('FOOTWEAR'));
      s.select(shoe);
      expect(c.read(studioProvider).worn, isEmpty);
      s
        ..select(shoe)
        ..remove('FOOTWEAR');
      expect(c.read(studioProvider).worn, isEmpty);
      expect(s.canUndo, isTrue);
    });

    test('switching source keeps the canvas', () {
      final s = c.read(studioProvider.notifier)
        ..setCategory('TOPS')
        ..select(_p('t', 'TOPS'))
        ..setSource(wardrobe: true);
      expect(c.read(studioProvider).fromWardrobe, isTrue);
      expect(c.read(studioProvider).worn, contains('TOPS'));
      s.useSource(wardrobe: false);
      expect(
        c.read(studioProvider).worn,
        isEmpty,
        reason: 'a new fit starts blank',
      );
    });

    test('the pieces carousel loads per category', () async {
      final pieces = await c.read(
        studioPiecesProvider(('OUTERWEAR', false)).future,
      );
      expect(pieces, isNotEmpty);
      expect(c.read(studioRepositoryProvider), isNotNull);
    });

    test('pieces move freely, snap back, and undo steps back', () {
      final s = c.read(studioProvider.notifier)
        ..setCategory('TOPS')
        ..select(_p('t', 'TOPS'));
      const box = Rect.fromLTWH(0.5, 0.5, 0.3, 0.2);
      s
        ..beginMove('TOPS')
        ..move('TOPS', box);
      expect(c.read(studioProvider).placed['TOPS'], box);
      expect(c.read(studioProvider).stack.last, 'TOPS');
      s.undo();
      expect(c.read(studioProvider).placed, isEmpty);
      s
        ..beginMove('TOPS')
        ..move('TOPS', box)
        ..snapBack();
      expect(c.read(studioProvider).placed, isEmpty);
    });

    test('where pieces sit survives saving and reopening', () async {
      final s = c.read(studioProvider.notifier)
        ..setCategory('TOPS')
        ..select(_p('t', 'TOPS'));
      const box = Rect.fromLTWH(0.1, 0.2, 0.3, 0.4);
      s
        ..beginMove('TOPS')
        ..move('TOPS', box);
      final fit = await s.save(name: 'Mine');
      s.reset();
      expect(c.read(studioProvider).placed, isEmpty);
      s.load(fit);
      final r = c.read(studioProvider).placed['TOPS']!;
      expect(r.left, closeTo(0.1, 1e-9));
      expect(r.height, closeTo(0.4, 1e-9));
    });

    test(
      'several accessories can be worn; save keeps the extras here',
      () async {
        final s = c.read(studioProvider.notifier)..setCategory('ACCESSORIES');
        s
          ..select(_p('a1', 'ACCESSORIES', 'Canvas tote bag'))
          ..select(_p('a2', 'ACCESSORIES', 'Oval sunglasses'))
          ..select(_p('a3', 'ACCESSORIES', 'Silver chain'));
        final keys = c.read(studioProvider).worn.keys.where(isAccessoryKey);
        expect(keys.length, 3);
        final plan = FitLayouts.plan(c.read(studioProvider).worn);
        expect({
          for (final k in keys) plan.placed[k]?.slot,
        }, containsAll(['bag', 'eyewear', 'jewellery']));
        // Tapping a worn accessory takes just that one off.
        s.select(_p('a2', 'ACCESSORIES', 'Oval sunglasses'));
        expect(
          c.read(studioProvider).worn.keys.where(isAccessoryKey).length,
          2,
        );

        final fit = await s.save(name: 'Extras');
        s.reset();
        s.load(fit);
        final ids = {
          for (final e in c.read(studioProvider).worn.entries)
            if (isAccessoryKey(e.key)) e.value.id,
        };
        expect(ids, {'a1', 'a3'});
      },
    );
  });
}
