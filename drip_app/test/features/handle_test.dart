import 'package:drip/features/onboarding/handle.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final valid = RegExp(r'^[a-z0-9_]{3,24}$');

  group('names become deliberate, usable handles', () {
    const cases = {
      // Latin, plain and accented.
      'Taylor': 'taylor_77',
      'José Álvarez': 'jose_alvarez_77',
      'Zoë': 'zoe_77',
      'Łukasz Żółć': 'lukasz_zolc_77',
      'Søren Ærø': 'soren_aero_77',
      'Straße': 'strasse_77',
      // Cyrillic.
      'Дмитрий': 'dmitriy_77',
      'Олена Шевченко': 'olena_shevchenko_77',
      // Korean: surname spelt as people spell it, then the given name.
      '이민호': 'lee_minho_77',
      '김지수': 'kim_jisu_77',
      // Japanese kana.
      'さくら': 'sakura_77',
      'ケンタ': 'kenta_77',
      'しょうた': 'shouta_77',
      // Devanagari.
      'राहुल': 'rahul_77',
      'प्रिया': 'priya_77',
      // Greek.
      'Νίκος': 'nikos_77',
      // Spaces, emoji, short.
      'Mary Jane': 'mary_jane_77',
      'Taylor 🔥': 'taylor_77',
      'Jo': 'jo_77',
    };
    for (final c in cases.entries) {
      test(c.key, () {
        expect(Handles.forName(c.key), c.value);
        expect(Handles.forName(c.key), matches(valid));
      });
    }
  });

  test('scripts that need a dictionary get a handle from the name itself', () {
    for (final name in ['李明', '王芳', '山田太郎', 'محمد', 'فاطمة', 'דוד']) {
      final h = Handles.forName(name);
      expect(h, matches(RegExp(r'^drip_[a-z0-9]{6}$')), reason: name);
      // Same name, same handle; never the generic placeholder.
      expect(Handles.forName(name), h);
      expect(h, isNot('yourname_77'));
    }
    expect(Handles.forName('李明'), isNot(Handles.forName('王芳')));
    expect(Handles.forName('محمد'), isNot(Handles.forName('فاطمة')));
  });

  test('mixed scripts keep whatever reads in Latin letters', () {
    expect(Handles.forName('李明 Lee'), 'lee_77');
    expect(Handles.forName('Ana 山田'), 'ana_77');
  });

  test('very long names stay a readable length', () {
    final h = Handles.forName('Alexandria-Rose Montgomery-Smythe');
    expect(h, matches(valid));
    expect(h, startsWith('alexandria_rose'));
  });

  test('no name yet: the placeholder the field shows', () {
    expect(Handles.forName(''), 'yourname_77');
    expect(Handles.forName('   '), 'yourname_77');
  });
}
