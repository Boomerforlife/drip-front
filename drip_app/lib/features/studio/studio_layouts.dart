import 'package:flutter/painting.dart';

import '../../data/models/stylist.dart';

/// One garment's box on a layout: fractions (0–1) of the canvas.
class LayoutSlot {
  const LayoutSlot(
    this.slot,
    this.x,
    this.y,
    this.w,
    this.h, {
    this.anchor = Alignment.center,
    this.optional = false,
  });

  /// `top`, `bottom`, `outer`, `dress`, `shoes`, or an accessory kind
  /// (`bag`, `eyewear`, `watch`, `headwear`, `belt`, `jewellery`, `tech`).
  final String slot;
  final double x;
  final double y;
  final double w;
  final double h;

  /// Where the garment sits inside its box once scaled to fit: a top hangs
  /// from its box's bottom edge onto the bottoms, the bottoms from their top.
  final Alignment anchor;

  /// Accessory slots are filled when the fit has that piece, else left empty.
  final bool optional;

  Rect rectIn(Size canvas) => Rect.fromLTWH(
    x * canvas.width,
    y * canvas.height,
    w * canvas.width,
    h * canvas.height,
  );
}

/// A collage layout: the same data the backend composes fits with
/// (`Backend_app/src/domain/templates/*.json`), so a fit built here is laid
/// out exactly like the fits in the Scroll.
class FitLayout {
  const FitLayout(this.id, this.label, this.slots);
  final String id;
  final String label;
  final List<LayoutSlot> slots;

  LayoutSlot? slotFor(String slot) {
    for (final s in slots) {
      if (s.slot == slot) return s;
    }
    return null;
  }

  Set<String> get slotNames => {for (final s in slots) s.slot};

  /// Canvas aspect (width / height) and look, shared by every layout.
  static const aspect = 1080 / 1920;
  static const background = Color(0xFFF4F4F2);
}

const _hangDown = Alignment.bottomCenter; // a top meets the waistband
const _hangUp = Alignment.topCenter; // bottoms start at the waistband

/// The six reference layouts (founder's collages, 2026-09-28). Kept in step
/// with the backend's template JSON.
abstract final class FitLayouts {
  static const streetColumn = FitLayout('street-column', 'Street column', [
    LayoutSlot('headwear', 0.02, 0.03, 0.17, 0.10, optional: true),
    LayoutSlot('watch', 0.02, 0.16, 0.17, 0.10, optional: true),
    LayoutSlot('jewellery', 0.02, 0.29, 0.17, 0.10, optional: true),
    LayoutSlot('eyewear', 0.02, 0.42, 0.17, 0.07, optional: true),
    LayoutSlot('top', 0.21, 0.03, 0.58, 0.40, anchor: _hangDown),
    LayoutSlot('bottom', 0.21, 0.44, 0.58, 0.40, anchor: _hangUp),
    LayoutSlot('shoes', 0.26, 0.86, 0.48, 0.12),
    LayoutSlot('tech', 0.81, 0.03, 0.17, 0.12, optional: true),
    LayoutSlot('bag', 0.81, 0.20, 0.17, 0.20, optional: true),
    LayoutSlot('belt', 0.81, 0.45, 0.17, 0.06, optional: true),
  ]);

  static const splitColumn = FitLayout('split-column', 'Split column', [
    LayoutSlot('top', 0.04, 0.03, 0.50, 0.36, anchor: _hangDown),
    LayoutSlot('bottom', 0.04, 0.40, 0.50, 0.57, anchor: _hangUp),
    LayoutSlot('belt', 0.58, 0.03, 0.38, 0.06, optional: true),
    LayoutSlot('eyewear', 0.58, 0.11, 0.38, 0.07, optional: true),
    LayoutSlot('jewellery', 0.58, 0.20, 0.18, 0.09, optional: true),
    LayoutSlot('watch', 0.78, 0.20, 0.18, 0.09, optional: true),
    LayoutSlot('outer', 0.58, 0.31, 0.38, 0.30, optional: true),
    LayoutSlot('bag', 0.58, 0.63, 0.38, 0.19, optional: true),
    LayoutSlot('shoes', 0.58, 0.84, 0.38, 0.14),
  ]);

  static const minimal = FitLayout('minimal', 'Minimal', [
    LayoutSlot('top', 0.06, 0.04, 0.54, 0.38, anchor: _hangDown),
    LayoutSlot('bottom', 0.06, 0.43, 0.54, 0.54, anchor: _hangUp),
    LayoutSlot('eyewear', 0.64, 0.06, 0.32, 0.08, optional: true),
    LayoutSlot('tech', 0.64, 0.17, 0.32, 0.13, optional: true),
    LayoutSlot('bag', 0.64, 0.33, 0.32, 0.24, optional: true),
    LayoutSlot('shoes', 0.62, 0.62, 0.34, 0.20),
    LayoutSlot('jewellery', 0.64, 0.86, 0.30, 0.08, optional: true),
  ]);

  static const tuckBag = FitLayout('tuck-bag', 'Tuck & bag', [
    LayoutSlot('top', 0.05, 0.05, 0.55, 0.37, anchor: _hangDown),
    LayoutSlot('bottom', 0.05, 0.43, 0.55, 0.54, anchor: _hangUp),
    LayoutSlot('eyewear', 0.64, 0.07, 0.32, 0.08, optional: true),
    LayoutSlot('bag', 0.64, 0.19, 0.32, 0.27, optional: true),
    LayoutSlot('jewellery', 0.64, 0.50, 0.32, 0.09, optional: true),
    LayoutSlot('shoes', 0.62, 0.63, 0.34, 0.20),
    LayoutSlot('watch', 0.64, 0.86, 0.30, 0.09, optional: true),
  ]);

  static const layeredVest = FitLayout('layered-vest', 'Layered', [
    LayoutSlot('top', 0.05, 0.04, 0.55, 0.38, anchor: _hangDown),
    LayoutSlot('bottom', 0.05, 0.43, 0.55, 0.54, anchor: _hangUp),
    LayoutSlot('headwear', 0.64, 0.03, 0.32, 0.12, optional: true),
    LayoutSlot('eyewear', 0.64, 0.18, 0.32, 0.07, optional: true),
    LayoutSlot('jewellery', 0.64, 0.28, 0.32, 0.08, optional: true),
    LayoutSlot('bag', 0.64, 0.39, 0.32, 0.22, optional: true),
    LayoutSlot('shoes', 0.62, 0.64, 0.34, 0.20),
    LayoutSlot('belt', 0.64, 0.88, 0.32, 0.06, optional: true),
  ]);

  static const dressEdit = FitLayout('dress-edit', 'Dress edit', [
    LayoutSlot('dress', 0.05, 0.04, 0.58, 0.70, anchor: _hangUp),
    LayoutSlot('shoes', 0.10, 0.77, 0.48, 0.19),
    LayoutSlot('headwear', 0.67, 0.03, 0.30, 0.11, optional: true),
    LayoutSlot('eyewear', 0.67, 0.17, 0.30, 0.07, optional: true),
    LayoutSlot('jewellery', 0.67, 0.27, 0.30, 0.09, optional: true),
    LayoutSlot('bag', 0.67, 0.39, 0.30, 0.24, optional: true),
    LayoutSlot('belt', 0.67, 0.66, 0.30, 0.06, optional: true),
    LayoutSlot('watch', 0.67, 0.75, 0.30, 0.10, optional: true),
  ]);

  static const all = [
    streetColumn,
    splitColumn,
    minimal,
    tuckBag,
    layeredVest,
    dressEdit,
  ];

  /// Accessory kinds, in the order a spare accessory looks for a free slot.
  static const accessoryKinds = [
    'bag',
    'eyewear',
    'jewellery',
    'watch',
    'headwear',
    'belt',
    'tech',
  ];

  /// The layout for what's on the canvas, and where each piece goes.
  ///
  /// Like the backend's `templatesForSlots` / `bestCoveringTemplate`, but
  /// built for a canvas being filled in: it never refuses. The layout that
  /// places the most pieces wins; then the one with the fewest required slots
  /// still empty (shown as "add" outlines); then the fewest empty accessory
  /// slots. A blank canvas gets the street column.
  static LayoutPlan plan(Map<String, StudioPiece> worn) {
    if (worn.isEmpty) {
      return LayoutPlan(streetColumn, const {}, [
        for (final s in streetColumn.slots)
          if (!s.optional) s,
      ]);
    }
    LayoutPlan? best;
    var bestScore = -1 << 30;
    for (final layout in all) {
      final placed = <String, LayoutSlot>{};
      final used = <String>{};
      for (final e in worn.entries) {
        final slot = _place(layout, e.key, e.value, used);
        if (slot != null) {
          placed[e.key] = slot;
          used.add(slot.slot);
        }
      }
      final missing = [
        for (final s in layout.slots)
          if (!s.optional && !used.contains(s.slot)) s,
      ];
      final emptyOptional = layout.slots
          .where((s) => s.optional && !used.contains(s.slot))
          .length;
      final score = placed.length * 1000 - missing.length * 50 - emptyOptional;
      if (score > bestScore) {
        bestScore = score;
        best = LayoutPlan(layout, placed, missing);
      }
    }
    return best!;
  }

  /// Where a worn piece (keyed by Studio category) goes on [layout].
  static LayoutSlot? _place(
    FitLayout layout,
    String category,
    StudioPiece piece,
    Set<String> used,
  ) {
    final slot = StudioSlots.slot(baseCategory(category));
    if (slot != 'accessory') {
      final s = layout.slotFor(slot);
      return s != null && !used.contains(s.slot) ? s : null;
    }
    final kind = accessoryKind(piece.name);
    if (kind != null) {
      final s = layout.slotFor(kind);
      if (s != null && !used.contains(s.slot)) return s;
    }
    // Unknown kind (or its slot is taken): the first free accessory slot.
    for (final k in accessoryKinds) {
      final s = layout.slotFor(k);
      if (s != null && !used.contains(s.slot)) return s;
    }
    return null;
  }

  static final _patterns = <(String, RegExp)>[
    (
      'eyewear',
      RegExp(
        r'\b(sun ?glass(es)?|spectacles?|eye ?glass(es)?|glasses|frames?|shades|goggles)\b',
      ),
    ),
    ('watch', RegExp(r'\b(watch(es)?|smartwatch)\b')),
    (
      'bag',
      RegExp(
        r'\b(bags?|backpacks?|tote|sling|purse|clutch|handbag|duffle|messenger|pouch|wallet|carryall|satchel)\b',
      ),
    ),
    (
      'headwear',
      RegExp(r'\b(caps?|hats?|beanies?|bucket|snapback|beret|bandana)\b'),
    ),
    ('belt', RegExp(r'\bbelts?\b')),
    (
      'jewellery',
      RegExp(
        r'\b(rings?|necklaces?|chains?|pendants?|bracelets?|bangles?|earrings?|hoops?|studs?|anklets?|jewell?ery|kada)\b',
      ),
    ),
    ('tech', RegExp(r'\b(headphones?|earphones?|earbuds?|airpods|headset)\b')),
  ];

  /// An accessory's kind from its title (same rules as the backend's
  /// `accessoryKind`). Null when it can't tell.
  static String? accessoryKind(String title) {
    final t = title.toLowerCase();
    for (final (kind, re) in _patterns) {
      if (re.hasMatch(t)) return kind;
    }
    return null;
  }
}

/// A layout with the canvas's pieces assigned to its slots.
class LayoutPlan {
  const LayoutPlan(this.layout, this.placed, this.missing);
  final FitLayout layout;

  /// Studio category → its box.
  final Map<String, LayoutSlot> placed;

  /// Required boxes still empty (drawn as "add" outlines).
  final List<LayoutSlot> missing;

  /// Pieces worn but left off this layout (no slot for them).
  Iterable<String> unplaced(Map<String, StudioPiece> worn) =>
      worn.keys.where((k) => !placed.containsKey(k));
}

/// Studio category for a layout slot (for the "add" outlines).
String categoryForLayoutSlot(String slot) => switch (slot) {
  'top' => 'TOPS',
  'bottom' => 'BOTTOMS',
  'outer' => 'OUTERWEAR',
  'dress' => 'DRESSES',
  'shoes' => 'FOOTWEAR',
  _ => 'ACCESSORIES',
};

/// A canvas key's Studio category. Extra accessories are keyed
/// `ACCESSORIES:2`, `ACCESSORIES:3`… so several can be worn at once.
String baseCategory(String key) => key.split(':').first;

bool isAccessoryKey(String key) => baseCategory(key) == 'ACCESSORIES';
