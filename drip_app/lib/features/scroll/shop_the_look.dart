import 'package:flutter/material.dart';

import '../../data/models/outfit.dart';

/// A piece of the collage and where it sits, as fractions of the collage.
class ShopSpot {
  const ShopSpot(this.piece, this.x, this.y);
  final OutfitPiece piece;
  final double x;
  final double y;
}

/// Pairs each hotspot with its piece: by title first (the hotspot label is the
/// garment's title), then by slot, then by order. Pieces without a cutout or
/// a position are left out; they are still in "Shop the look".
List<ShopSpot> shopSpots(Outfit outfit) {
  final left = [...outfit.pieces];
  final spots = <ShopSpot>[];
  for (final (i, h) in outfit.hotspots.indexed) {
    OutfitPiece? match;
    for (final p in left) {
      if (p.name.isNotEmpty && p.name.toUpperCase() == h.label) {
        match = p;
        break;
      }
    }
    if (match == null && h.slot.isNotEmpty) {
      for (final p in left) {
        if (p.slot == h.slot.toUpperCase()) {
          match = p;
          break;
        }
      }
    }
    match ??= i < outfit.pieces.length && left.contains(outfit.pieces[i])
        ? outfit.pieces[i]
        : null;
    if (match == null) continue;
    left.remove(match);
    if (match.image == null || match.image!.isEmpty) continue;
    spots.add(ShopSpot(match, h.x.clamp(0, 1), h.y.clamp(0, 1)));
  }
  return spots;
}

/// Tap-to-shop over a collage: a tap calls [onOpen] with the piece nearest
/// to it, and the page opens "shop the look" (a [SlideUpSheet] of the fit's
/// pieces) on that one. [onOpen] null turns it off (details open, nothing to
/// shop).
class ShopTheLook extends StatelessWidget {
  const ShopTheLook({
    super.key,
    required this.spots,
    required this.onOpen,
    required this.child,
  });

  final List<ShopSpot> spots;
  final ValueChanged<int>? onOpen;
  final Widget child;

  /// The spot nearest [p] in a collage of [size].
  static int nearest(List<ShopSpot> spots, Offset p, Size size) {
    var best = 0;
    var bestDist = double.infinity;
    for (final (i, s) in spots.indexed) {
      final dx = s.x * size.width - p.dx;
      final dy = s.y * size.height - p.dy;
      final dist = dx * dx + dy * dy;
      if (dist < bestDist) {
        bestDist = dist;
        best = i;
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final open = onOpen;
    if (open == null || spots.isEmpty) return child;
    return LayoutBuilder(
      builder: (context, c) => GestureDetector(
        onTapUp: (d) => open(nearest(spots, d.localPosition, c.biggest)),
        child: child,
      ),
    );
  }
}
