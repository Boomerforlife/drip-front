/// Turns the name typed in onboarding into the handle shown on the ticket.
///
/// Handles stay ASCII (`a–z`, `0–9`, `_`), matching the handles the rest of
/// the app derives from email addresses. There's no backend handle field in
/// v1, so this is presentation only, but it never produces something the
/// app couldn't show or a future username couldn't take.
///
/// Every script that can be written in Latin letters *reliably* is:
/// accented Latin is folded (José → jose), Cyrillic, Greek and Devanagari are
/// transliterated letter by letter, Hangul is romanized from its syllable
/// structure (이민호 → lee_minho) and kana by Hepburn (さくら → sakura).
/// Scripts that can't be without a dictionary (Chinese characters, kanji,
/// Arabic, Hebrew…) get a handle derived from the name itself, so the same
/// name always gets the same handle and different names get different ones
/// (李明 → drip_…), never a generic placeholder.
abstract final class Handles {
  /// The handle for [name], without the `@`.
  static String forName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'yourname_77';
    final slug = _slug(_latin(trimmed));
    if (RegExp('[a-z]').allMatches(slug).length >= 2) return '${slug}_77';
    return 'drip_${_digest(trimmed)}';
  }

  static String _slug(String s) {
    var out = s
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    if (out.length > 20) {
      // Cut at a word boundary where there is one.
      final cut = out.substring(0, 20);
      final at = cut.lastIndexOf('_');
      out = at >= 8 ? cut.substring(0, at) : cut;
    }
    return out;
  }

  /// Six base-36 characters from a 32-bit FNV-1a hash of the name: stable
  /// across launches and devices, and different for different names.
  static String _digest(String s) {
    var h = 0x811C9DC5;
    for (final r in s.runes) {
      h ^= r;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return h.toRadixString(36).padLeft(6, '0').substring(0, 6);
  }

  // ─────────────────────────────────────────────────────── transliteration

  static String _latin(String name) {
    final out = StringBuffer();
    final runes = name.toLowerCase().runes.toList();
    for (var i = 0; i < runes.length; i++) {
      final r = runes[i];
      if (r >= 0xAC00 && r <= 0xD7A3) {
        // A Hangul word: romanize it as a whole (surname, then given name).
        var j = i;
        while (j < runes.length && runes[j] >= 0xAC00 && runes[j] <= 0xD7A3) {
          j++;
        }
        out
          ..write(' ')
          ..write(_hangulWord(runes.sublist(i, j)))
          ..write(' ');
        i = j - 1;
      } else if (_isKana(r)) {
        var j = i;
        while (j < runes.length && (_isKana(runes[j]) || runes[j] == 0x30FC)) {
          j++;
        }
        out.write(_kana(runes.sublist(i, j)));
        i = j - 1;
      } else if (r >= 0x0900 && r <= 0x097F) {
        var j = i;
        while (j < runes.length && runes[j] >= 0x0900 && runes[j] <= 0x097F) {
          j++;
        }
        out.write(_devanagari(runes.sublist(i, j)));
        i = j - 1;
      } else {
        final c = String.fromCharCode(r);
        out.write(_fold[c] ?? _cyrillic[c] ?? _greek[c] ?? c);
      }
    }
    return out.toString();
  }

  static const _fold = {
    'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a', 'ā': 'a', //
    'ă': 'a', 'ą': 'a', 'æ': 'ae', 'ç': 'c', 'ć': 'c', 'ĉ': 'c', 'ċ': 'c',
    'č': 'c', 'ď': 'd', 'đ': 'd', 'ð': 'd', 'è': 'e', 'é': 'e', 'ê': 'e',
    'ë': 'e', 'ē': 'e', 'ĕ': 'e', 'ė': 'e', 'ę': 'e', 'ě': 'e', 'ĝ': 'g',
    'ğ': 'g', 'ġ': 'g', 'ģ': 'g', 'ĥ': 'h', 'ħ': 'h', 'ì': 'i', 'í': 'i',
    'î': 'i', 'ï': 'i', 'ĩ': 'i', 'ī': 'i', 'ĭ': 'i', 'į': 'i', 'ı': 'i',
    'ĵ': 'j', 'ķ': 'k', 'ĺ': 'l', 'ļ': 'l', 'ľ': 'l', 'ŀ': 'l', 'ł': 'l',
    'ñ': 'n', 'ń': 'n', 'ņ': 'n', 'ň': 'n', 'ò': 'o', 'ó': 'o', 'ô': 'o',
    'õ': 'o', 'ö': 'o', 'ø': 'o', 'ō': 'o', 'ŏ': 'o', 'ő': 'o', 'œ': 'oe',
    'ŕ': 'r', 'ŗ': 'r', 'ř': 'r', 'ś': 's', 'ŝ': 's', 'ş': 's', 'š': 's',
    'ș': 's', 'ß': 'ss', 'ţ': 't', 'ť': 't', 'ŧ': 't', 'ț': 't', 'ù': 'u',
    'ú': 'u', 'û': 'u', 'ü': 'u', 'ũ': 'u', 'ū': 'u', 'ŭ': 'u', 'ů': 'u',
    'ű': 'u', 'ų': 'u', 'ŵ': 'w', 'ý': 'y', 'ÿ': 'y', 'ŷ': 'y', 'ź': 'z',
    'ż': 'z', 'ž': 'z', 'þ': 'th',
  };

  static const _cyrillic = {
    'а': 'a', 'б': 'b', 'в': 'v', 'г': 'g', 'д': 'd', 'е': 'e', 'ё': 'yo', //
    'ж': 'zh', 'з': 'z', 'и': 'i', 'й': 'y', 'к': 'k', 'л': 'l', 'м': 'm',
    'н': 'n', 'о': 'o', 'п': 'p', 'р': 'r', 'с': 's', 'т': 't', 'у': 'u',
    'ф': 'f', 'х': 'kh', 'ц': 'ts', 'ч': 'ch', 'ш': 'sh', 'щ': 'shch',
    'ъ': '', 'ы': 'y', 'ь': '', 'э': 'e', 'ю': 'yu', 'я': 'ya', 'і': 'i',
    'ї': 'yi', 'є': 'ye', 'ґ': 'g', 'ў': 'u', 'ђ': 'dj', 'ј': 'j', 'љ': 'lj',
    'њ': 'nj', 'ћ': 'c', 'џ': 'dz',
  };

  static const _greek = {
    'α': 'a', 'ά': 'a', 'β': 'v', 'γ': 'g', 'δ': 'd', 'ε': 'e', 'έ': 'e', //
    'ζ': 'z', 'η': 'i', 'ή': 'i', 'θ': 'th', 'ι': 'i', 'ί': 'i', 'ϊ': 'i',
    'κ': 'k', 'λ': 'l', 'μ': 'm', 'ν': 'n', 'ξ': 'x', 'ο': 'o', 'ό': 'o',
    'π': 'p', 'ρ': 'r', 'σ': 's', 'ς': 's', 'τ': 't', 'υ': 'y', 'ύ': 'y',
    'φ': 'f', 'χ': 'ch', 'ψ': 'ps', 'ω': 'o', 'ώ': 'o',
  };

  // Hangul: Revised Romanization from the syllable's jamo, with the usual
  // spellings for the common surnames (Kim, Lee, Park…).
  static const _initials = [
    'g', 'kk', 'n', 'd', 'tt', 'r', 'm', 'b', 'pp', 's', 'ss', '', 'j', //
    'jj', 'ch', 'k', 't', 'p', 'h',
  ];
  static const _medials = [
    'a', 'ae', 'ya', 'yae', 'eo', 'e', 'yeo', 'ye', 'o', 'wa', 'wae', 'oe', //
    'yo', 'u', 'wo', 'we', 'wi', 'yu', 'eu', 'ui', 'i',
  ];
  static const _finals = [
    '', 'k', 'k', 'k', 'n', 'n', 'n', 't', 'l', 'k', 'm', 'p', 'l', 'l', //
    'p', 'l', 'm', 'p', 'p', 't', 't', 'ng', 't', 't', 'k', 't', 'p', 't',
  ];
  static const _surnames = {
    '김': 'kim', '이': 'lee', '박': 'park', '최': 'choi', '정': 'jung', //
    '강': 'kang', '조': 'cho', '윤': 'yoon', '장': 'jang', '임': 'lim',
    '한': 'han', '오': 'oh', '서': 'seo', '신': 'shin', '권': 'kwon',
    '황': 'hwang', '안': 'ahn', '송': 'song', '류': 'ryu', '전': 'jeon',
  };

  static String _syllable(int r) {
    final i = r - 0xAC00;
    return _initials[i ~/ 588] + _medials[(i % 588) ~/ 28] + _finals[i % 28];
  }

  static String _hangulWord(List<int> word) {
    final first = String.fromCharCode(word.first);
    if (word.length >= 2 && word.length <= 4 && _surnames.containsKey(first)) {
      return '${_surnames[first]} ${word.skip(1).map(_syllable).join()}';
    }
    return word.map(_syllable).join();
  }

  // Kana: Hepburn. Katakana is read as hiragana; small ya/yu/yo combine,
  // a small tsu doubles the next consonant, the long-vowel mark is dropped.
  static bool _isKana(int r) =>
      (r >= 0x3041 && r <= 0x3096) || (r >= 0x30A1 && r <= 0x30F6);

  static const _hira = {
    'あ': 'a', 'い': 'i', 'う': 'u', 'え': 'e', 'お': 'o', 'か': 'ka', //
    'き': 'ki', 'く': 'ku', 'け': 'ke', 'こ': 'ko', 'が': 'ga', 'ぎ': 'gi',
    'ぐ': 'gu', 'げ': 'ge', 'ご': 'go', 'さ': 'sa', 'し': 'shi', 'す': 'su',
    'せ': 'se', 'そ': 'so', 'ざ': 'za', 'じ': 'ji', 'ず': 'zu', 'ぜ': 'ze',
    'ぞ': 'zo', 'た': 'ta', 'ち': 'chi', 'つ': 'tsu', 'て': 'te', 'と': 'to',
    'だ': 'da', 'ぢ': 'ji', 'づ': 'zu', 'で': 'de', 'ど': 'do', 'な': 'na',
    'に': 'ni', 'ぬ': 'nu', 'ね': 'ne', 'の': 'no', 'は': 'ha', 'ひ': 'hi',
    'ふ': 'fu', 'へ': 'he', 'ほ': 'ho', 'ば': 'ba', 'び': 'bi', 'ぶ': 'bu',
    'べ': 'be', 'ぼ': 'bo', 'ぱ': 'pa', 'ぴ': 'pi', 'ぷ': 'pu', 'ぺ': 'pe',
    'ぽ': 'po', 'ま': 'ma', 'み': 'mi', 'む': 'mu', 'め': 'me', 'も': 'mo',
    'や': 'ya', 'ゆ': 'yu', 'よ': 'yo', 'ら': 'ra', 'り': 'ri', 'る': 'ru',
    'れ': 're', 'ろ': 'ro', 'わ': 'wa', 'を': 'o', 'ん': 'n', 'ぁ': 'a',
    'ぃ': 'i', 'ぅ': 'u', 'ぇ': 'e', 'ぉ': 'o', 'ゔ': 'vu',
  };
  static const _smallY = {'ゃ': 'a', 'ゅ': 'u', 'ょ': 'o'};

  static String _kana(List<int> run) {
    final out = StringBuffer();
    var double = false;
    for (var i = 0; i < run.length; i++) {
      var r = run[i];
      if (r == 0x30FC) continue;
      if (r >= 0x30A1 && r <= 0x30F6) r -= 0x60;
      final c = String.fromCharCode(r);
      if (c == 'っ') {
        double = true;
        continue;
      }
      var syl = _hira[c] ?? '';
      // きゃ → kya, しょ → sho, ちゅ → chu.
      if (i + 1 < run.length) {
        var n = run[i + 1];
        if (n >= 0x30A1 && n <= 0x30F6) n -= 0x60;
        final y = _smallY[String.fromCharCode(n)];
        if (y != null && syl.endsWith('i') && syl.length > 1) {
          final stem = syl.substring(0, syl.length - 1);
          syl = stem.endsWith('sh') || stem.endsWith('ch') || stem == 'j'
              ? '$stem$y'
              : '${stem}y$y';
          i++;
        }
      }
      if (double && syl.isNotEmpty) {
        out.write(syl.startsWith('ch') ? 't' : syl[0]);
        double = false;
      }
      out.write(syl);
    }
    return out.toString();
  }

  // Devanagari: letter by letter, with the inherent "a" dropped before a
  // vowel sign or virama, and at the end of the word (राहुल → rahul).
  static const _consonants = {
    'क': 'k', 'ख': 'kh', 'ग': 'g', 'घ': 'gh', 'ङ': 'n', 'च': 'ch', //
    'छ': 'chh', 'ज': 'j', 'झ': 'jh', 'ञ': 'n', 'ट': 't', 'ठ': 'th',
    'ड': 'd', 'ढ': 'dh', 'ण': 'n', 'त': 't', 'थ': 'th', 'द': 'd',
    'ध': 'dh', 'न': 'n', 'प': 'p', 'फ': 'ph', 'ब': 'b', 'भ': 'bh',
    'म': 'm', 'य': 'y', 'र': 'r', 'ल': 'l', 'व': 'v', 'श': 'sh',
    'ष': 'sh', 'स': 's', 'ह': 'h',
  };
  static const _vowels = {
    'अ': 'a', 'आ': 'a', 'इ': 'i', 'ई': 'i', 'उ': 'u', 'ऊ': 'u', //
    'ए': 'e', 'ऐ': 'ai', 'ओ': 'o', 'औ': 'au', 'ऋ': 'ri',
  };
  static const _signs = {
    'ा': 'a', 'ि': 'i', 'ी': 'i', 'ु': 'u', 'ू': 'u', 'े': 'e', //
    'ै': 'ai', 'ो': 'o', 'ौ': 'au', 'ृ': 'ri',
  };

  static String _devanagari(List<int> run) {
    final out = StringBuffer();
    final chars = [for (final r in run) String.fromCharCode(r)];
    for (var i = 0; i < chars.length; i++) {
      final c = chars[i];
      final cons = _consonants[c];
      if (cons != null) {
        out.write(cons);
        var j = i + 1;
        while (j < chars.length && chars[j] == '़') {
          j++;
        }
        final next = j < chars.length ? chars[j] : null;
        final last = next == null || next == ' ';
        if (next != null && (_signs.containsKey(next) || next == '्')) {
          continue;
        }
        if (!last) out.write('a');
      } else if (_vowels[c] != null) {
        out.write(_vowels[c]);
      } else if (_signs[c] != null) {
        out.write(_signs[c]);
      } else if (c == 'ं' || c == 'ँ') {
        out.write('n');
      } else if (c == 'ः') {
        out.write('h');
      }
    }
    return out.toString();
  }
}
