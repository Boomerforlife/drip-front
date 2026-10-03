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
    this.credit,
  });

  final String id;
  final String label;

  /// A short line under the name.
  final String line;
  final int minFormality;
  final int maxFormality;

  /// The card's colour: behind the photo while it loads, and the whole card
  /// if there's no photo.
  final Color tint;

  /// Background photo: an asset (`assets/occasions/<id>.jpg`) or a URL.
  /// Swap the file to change it; nothing else references it.
  final String? image;

  /// Who took [image] (Unsplash, free licence; credit is courtesy).
  final String? credit;

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
      image: 'assets/occasions/date-night.jpg',
      credit: 'Yianni Mathioudakis / Unsplash',
    ),
    Occasion(
      'concert',
      'Concerts',
      'Loud, sweaty, unforgettable',
      1,
      3,
      Color(0xFF1F2C5C),
      image: 'assets/occasions/concert.jpg',
      credit: 'Tijs van Leur / Unsplash',
    ),
    Occasion(
      'late-night-dinner',
      'Late-night dinner',
      'Low light, sharp lines',
      3,
      4,
      Color(0xFF3B2A1E),
      image: 'assets/occasions/late-night-dinner.jpg',
      credit: 'Berkay Samiloglu / Unsplash',
    ),
    Occasion(
      'university',
      'University',
      'Lectures to the canteen',
      1,
      2,
      Color(0xFF24513A),
      image: 'assets/occasions/university.jpg',
      credit: 'Joshua Song / Unsplash',
    ),
    Occasion(
      'parties',
      'Parties',
      'House parties and birthdays',
      1,
      3,
      Color(0xFF6B1F2A),
      image: 'assets/occasions/parties.jpg',
      credit: 'OurWhisky Foundation / Unsplash',
    ),
    Occasion(
      'clubs',
      'Clubs',
      'Dark rooms, bright fits',
      2,
      4,
      Color(0xFF14161F),
      image: 'assets/occasions/clubs.jpg',
      credit: 'Ramin Talebi / Unsplash',
    ),
    Occasion(
      'picnics',
      'Picnics',
      'Sun, grass, easy layers',
      1,
      2,
      Color(0xFF6B7048),
      image: 'assets/occasions/picnics.jpg',
      credit: 'Mason Dahl / Unsplash',
    ),
    Occasion(
      'derbies',
      'Derbies',
      'Race day, dressed up',
      4,
      5,
      Color(0xFF2F4BD6),
      image: 'assets/occasions/derbies.jpg',
      credit: 'Daniel Sánchez / Unsplash',
    ),
    Occasion(
      'golf',
      'Golf',
      'Clubhouse-ready',
      2,
      3,
      Color(0xFF2E5D3A),
      image: 'assets/occasions/golf.jpg',
      credit: 'Randy Kinne / Unsplash',
    ),
    Occasion(
      'sports',
      'Sports',
      'Match day and the stands',
      1,
      2,
      Color(0xFFD2601F),
      image: 'assets/occasions/sports.jpg',
      credit: 'Igor Batista / Unsplash',
    ),
    Occasion(
      'family-events',
      'Family events',
      'Smart enough for everyone',
      2,
      4,
      Color(0xFF8A6E4B),
      image: 'assets/occasions/family-events.jpg',
      credit: 'krakenimages / Unsplash',
    ),
    Occasion(
      'wedding',
      'Weddings',
      'The big day, your best fit',
      4,
      5,
      Color(0xFF7A5C2E),
      image: 'assets/occasions/wedding.jpg',
      credit: 'sammy swae / Unsplash',
    ),
  ];

  /// [all], with the ones in [picked] first (in their usual order).
  static List<Occasion> pickedFirst(Set<String> picked) => [
    for (final o in all)
      if (picked.contains(o.id)) o,
    for (final o in all)
      if (!picked.contains(o.id)) o,
  ];

  static Occasion? byId(String? id) {
    for (final o in all) {
      if (o.id == id) return o;
    }
    return null;
  }
}
