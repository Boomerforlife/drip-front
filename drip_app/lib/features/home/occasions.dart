import 'package:flutter/painting.dart';

import '../../data/models/outfit.dart';

/// Something to get dressed for. Home lists these; tapping one opens the
/// Scroll on fits that suit it.
///
/// Suitability is the fit's formality (1 casual … 5 formal, set on every
/// banked fit) falling inside [minFormality]..[maxFormality]. The backend has
/// no occasion filter on `/scroll` yet, so the app filters the ranked feed
/// itself; a server-side `?occasion=` would make this exact.
class Occasion {
  const Occasion(
    this.id,
    this.label,
    this.line,
    this.minFormality,
    this.maxFormality,
    this.tint, {
    this.image,
  });

  final String id;
  final String label;

  /// A short line under the name.
  final String line;
  final int minFormality;
  final int maxFormality;

  /// Card colour until a background photo is added.
  final Color tint;

  /// Background photo (an asset or URL), added later.
  final String? image;

  bool suits(Outfit o) {
    final f = o.formality;
    return f != null && f >= minFormality && f <= maxFormality;
  }
}

abstract final class Occasions {
  static const all = [
    Occasion(
      'date-night',
      'Date night',
      'Dinner, drinks, a little shine',
      2,
      4,
      Color(0xFF5A2A4F),
    ),
    Occasion(
      'concert',
      'Concerts',
      'Loud, sweaty, unforgettable',
      1,
      3,
      Color(0xFF1F2C5C),
    ),
    Occasion(
      'late-night-dinner',
      'Late-night dinner',
      'Low light, sharp lines',
      3,
      4,
      Color(0xFF3B2A1E),
    ),
    Occasion(
      'university',
      'University',
      'Lectures to the canteen',
      1,
      2,
      Color(0xFF24513A),
    ),
    Occasion(
      'parties',
      'Parties',
      'House parties and birthdays',
      1,
      3,
      Color(0xFF6B1F2A),
    ),
    Occasion(
      'clubs',
      'Clubs',
      'Dark rooms, bright fits',
      2,
      4,
      Color(0xFF14161F),
    ),
    Occasion(
      'picnics',
      'Picnics',
      'Sun, grass, easy layers',
      1,
      2,
      Color(0xFF6B7048),
    ),
    Occasion(
      'derbies',
      'Derbies',
      'Race day, dressed up',
      4,
      5,
      Color(0xFF2F4BD6),
    ),
    Occasion('golf', 'Golf', 'Clubhouse-ready', 2, 3, Color(0xFF2E5D3A)),
    Occasion(
      'sports',
      'Sports',
      'Match day and the stands',
      1,
      2,
      Color(0xFFD2601F),
    ),
    Occasion(
      'family-events',
      'Family events',
      'Smart enough for everyone',
      2,
      4,
      Color(0xFF8A6E4B),
    ),
    Occasion(
      'wedding',
      'Weddings',
      'The big day, your best fit',
      4,
      5,
      Color(0xFF7A5C2E),
    ),
  ];

  static Occasion? byId(String? id) {
    for (final o in all) {
      if (o.id == id) return o;
    }
    return null;
  }
}
