import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/motion.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/drip_image.dart';
import '../../core/widgets/overlays.dart';
import '../../data/models/outfit.dart';
import '../bag/bag_controller.dart';
import '../outfits/shop_sheet.dart';

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

/// Tap-to-shop over a collage, the Pinterest way. Tapping a garment dims the
/// collage and lifts that garment into the hero spot above it. Swiping carries
/// the hero off and brings the next piece in, cycling through them; the
/// collage behind never moves. Tapping anywhere puts it back. The page shows the [ShopPieceBar] for [selected].
class ShopTheLook extends StatefulWidget {
  const ShopTheLook({
    super.key,
    required this.spots,
    required this.open,
    required this.selected,
    required this.onOpen,
    required this.onClose,
    required this.onSelect,
    required this.child,
  });

  final List<ShopSpot> spots;
  final bool open;
  final int selected;

  /// Called with the piece nearest the tap. Null while a tap shouldn't open
  /// it (details open, nothing to shop).
  final ValueChanged<int>? onOpen;
  final VoidCallback onClose;
  final ValueChanged<int> onSelect;
  final Widget child;

  @override
  State<ShopTheLook> createState() => _ShopTheLookState();
}

class _ShopTheLookState extends State<ShopTheLook> {
  PageController? _wheel;

  /// Once someone has swiped, the hint has done its job for this session.
  static bool _swiped = false;

  /// The wheel never ends: its pages run on without limit and map onto the
  /// pieces in turn, starting this far in so it turns either way.
  int get _start => widget.spots.length * 1000 + widget.selected;

  @override
  void didUpdateWidget(ShopTheLook old) {
    super.didUpdateWidget(old);
    if (widget.open && !old.open) {
      _wheel?.dispose();
      _wheel = PageController(initialPage: _start);
    }
  }

  @override
  void dispose() {
    _wheel?.dispose();
    super.dispose();
  }

  void _tapped(TapUpDetails d, Size size) {
    final open = widget.onOpen;
    if (open == null || widget.spots.isEmpty) return;
    final p = d.localPosition;
    var best = 0;
    var bestDist = double.infinity;
    for (final (i, s) in widget.spots.indexed) {
      final dx = s.x * size.width - p.dx;
      final dy = s.y * size.height - p.dy;
      final dist = dx * dx + dy * dy;
      if (dist < bestDist) {
        bestDist = dist;
        best = i;
      }
    }
    open(best);
  }

  @override
  Widget build(BuildContext context) {
    final dur = Motion.dur(context, Motion.content);
    return LayoutBuilder(
      builder: (context, c) {
        final size = c.biggest;
        final wheel = _wheel;
        return Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              onTapUp: widget.open || widget.onOpen == null
                  ? null
                  : (d) => _tapped(d, size),
              child: widget.child,
            ),
            IgnorePointer(
              ignoring: !widget.open,
              child: AnimatedOpacity(
                opacity: widget.open ? 1 : 0,
                duration: dur,
                curve: Motion.out,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      const ColoredBox(color: _dim),
                      if (wheel != null) ...[
                        IgnorePointer(
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(end: widget.open ? 1 : 0),
                            duration: Motion.dur(context, Motion.content),
                            curve: Motion.out,
                            builder: (context, lift, _) => AnimatedBuilder(
                              animation: wheel,
                              builder: (context, _) => _Ring(
                                spots: widget.spots,
                                page:
                                    wheel.hasClients &&
                                        wheel.position.haveDimensions
                                    ? wheel.page ?? _start.toDouble()
                                    : _start.toDouble(),
                                lift: lift,
                                size: size,
                              ),
                            ),
                          ),
                        ),
                        // Invisible pages: only the swipe and the snapping.
                        GestureDetector(
                          key: const ValueKey('shop-the-look-scrim'),
                          onTap: widget.onClose,
                          behavior: HitTestBehavior.opaque,
                          child: PageView.builder(
                            controller: wheel,
                            onPageChanged: (i) {
                              Haptics.tick();
                              widget.onSelect(i % widget.spots.length);
                              if (!_swiped) setState(() => _swiped = true);
                            },
                            itemBuilder: (_, _) => const SizedBox.expand(),
                          ),
                        ),
                        if (widget.spots.length > 1)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 14,
                            child: IgnorePointer(
                              child: AnimatedOpacity(
                                opacity: _swiped ? 0 : 1,
                                duration: Motion.dur(context, Motion.content),
                                child: const Center(child: _SwipeHint()),
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// How dark the collage goes behind the piece in focus: subdued, still legible.
const _dim = Color(0x9E0E1018);

/// "‹ SWIPE ›", small and quiet at the foot of the collage, drifting a few
/// pixels side to side a few times so it reads as a gesture, then resting.
/// Still when motion is reduced.
class _SwipeHint extends StatefulWidget {
  const _SwipeHint();

  @override
  State<_SwipeHint> createState() => _SwipeHintState();
}

class _SwipeHintState extends State<_SwipeHint>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _drift.stop();
    } else if (!_drift.isAnimating && _drift.value == 0) {
      _drift.repeat(reverse: true, count: 6);
    }
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ink = AppColors.cream.withValues(alpha: 0.7);
    return AnimatedBuilder(
      animation: _drift,
      builder: (context, child) => Transform.translate(
        offset: Offset(
          4 * (Curves.easeInOut.transform(_drift.value) * 2 - 1),
          0,
        ),
        child: child,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text('‹  SWIPE  ›', style: AppText.mono(9, color: ink)),
      ),
    );
  }
}

/// Where and how big a piece sits when it is the hero, as fractions of the
/// collage: the box it is fitted into (never stretched; its own aspect ratio
/// decides which side fills) and the optical centre's height. Boxes are set
/// per kind of garment so every hero carries about the same visual weight:
/// jeans tall, tops broad, sunglasses wide and low, small jewellery small.
class HeroFrame {
  const HeroFrame(this.width, this.height, this.centreY);
  final double width;
  final double height;
  final double centreY;
}

final _kinds = <(RegExp, HeroFrame)>[
  (
    RegExp(r'\b(sun ?glass(es)?|glasses|shades|eyewear|spectacles)\b'),
    HeroFrame(0.62, 0.22, 0.46),
  ),
  (
    RegExp(r'\b(cap|hat|beanie|bucket hat|snapback|beret)\b'),
    HeroFrame(0.48, 0.30, 0.43),
  ),
  (RegExp(r'\b(necklace|chain|pendant|choker)\b'), HeroFrame(0.46, 0.42, 0.46)),
  (
    RegExp(r'\b(ring|rings|bracelet|bangle|cuff|earrings?|watch|anklet)\b'),
    HeroFrame(0.40, 0.26, 0.46),
  ),
  (
    RegExp(r'\b(bag|tote|backpack|sling|clutch|wallet)\b'),
    HeroFrame(0.52, 0.42, 0.47),
  ),
  (RegExp(r'\bbelt\b'), HeroFrame(0.60, 0.22, 0.47)),
];

HeroFrame heroFrame(OutfitPiece piece) {
  final name = piece.name.toLowerCase();
  for (final (pattern, frame) in _kinds) {
    if (pattern.hasMatch(name)) return frame;
  }
  return switch (piece.slot) {
    'BOTTOM' => const HeroFrame(0.50, 0.62, 0.44),
    'TOP' || 'OUTER' => const HeroFrame(0.66, 0.50, 0.45),
    'DRESS' => const HeroFrame(0.52, 0.66, 0.45),
    'SHOES' => const HeroFrame(0.62, 0.30, 0.52),
    'ACCESSORY' => const HeroFrame(0.42, 0.30, 0.46),
    _ => const HeroFrame(0.60, 0.48, 0.46),
  };
}

/// The hero, lifted off the dimmed collage, which never moves. Swiping carries
/// it with the finger: the hero drifts in the swipe's direction, easing down
/// and darkening as it leaves, while the next piece comes in from the other
/// side, slightly small, and settles into the hero spot. Further pieces stay
/// in the collage. [lift] (0–1) opens it: the piece rises from its own place
/// in the collage into the hero spot.
class _Ring extends StatelessWidget {
  const _Ring({
    required this.spots,
    required this.page,
    required this.lift,
    required this.size,
  });

  final List<ShopSpot> spots;
  final double page;
  final double lift;
  final Size size;

  @override
  Widget build(BuildContext context) {
    final n = spots.length;
    final near = [
      for (var i = 0; i < n; i++)
        if (_offset(i, n).abs() < 1) i,
    ]..sort((a, b) => _offset(b, n).abs().compareTo(_offset(a, n).abs()));
    return Stack(children: [for (final i in near) _place(i, _offset(i, n))]);
  }

  /// How many steps piece [i] is from the hero spot, the short way round.
  double _offset(int i, int n) {
    var d = (i - page) % n;
    if (d > n / 2) d -= n;
    return d;
  }

  Widget _place(int i, double d) {
    final w = size.width;
    final h = size.height;
    final spot = spots[i];
    final frame = heroFrame(spot.piece);
    final away = d.abs().clamp(0.0, 1.0);
    // Prominence: 1 in the hero spot, falling smoothly as it moves off.
    final focus = Curves.easeOut.transform(1 - away);

    // In the hero spot, following the finger (most of the way, so it reads
    // as being carried) and easing down to 0.86 as it leaves.
    final heroW = w * frame.width * (0.86 + 0.14 * focus);
    final heroH = h * frame.height * (0.86 + 0.14 * focus);
    final heroX = w / 2 + d * w * 0.72;
    final heroY = h * frame.centreY;
    // In the collage, where it rises from as the carousel opens.
    final homeSide = (w < h ? w : h) * 0.4;
    final cx = ui.lerpDouble(spot.x * w, heroX, lift)!;
    final cy = ui.lerpDouble(spot.y * h, heroY, lift)!;
    final bw = ui.lerpDouble(homeSide, heroW, lift)!;
    final bh = ui.lerpDouble(homeSide, heroH, lift)!;

    // Fully there in the hero spot, gone by the time it is a whole step away,
    // so at rest only the hero is lifted and every other piece stays in the
    // collage.
    final opacity = (1 - away * away).clamp(0.0, 1.0);
    final depth = focus * lift;
    final image = DripImage(
      spot.piece.image!,
      fit: BoxFit.contain,
      backdrop: false,
      semanticLabel: spot.piece.name,
    );
    return Positioned(
      left: cx - bw / 2,
      top: cy - bh / 2,
      width: bw,
      height: bh,
      child: Opacity(
        opacity: opacity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Depth: the cutout's own silhouette, soft and faint, just under
            // it, so the hero reads as lifted off the board.
            if (depth > 0.01)
              Transform.translate(
                offset: Offset(0, 6 + 6 * depth),
                child: ImageFiltered(
                  imageFilter: ui.ImageFilter.blur(sigmaX: 9, sigmaY: 9),
                  child: ColorFiltered(
                    colorFilter: ColorFilter.mode(
                      Colors.black.withValues(alpha: 0.32 * depth),
                      BlendMode.srcIn,
                    ),
                    child: image,
                  ),
                ),
              ),
            // Leaving the hero spot it takes on the collage's dim.
            ColorFiltered(
              colorFilter: ColorFilter.mode(
                _dim.withValues(alpha: _dim.a * (1 - depth)),
                BlendMode.srcATop,
              ),
              child: image,
            ),
          ],
        ),
      ),
    );
  }
}

/// The piece in focus, where the fit's info usually sits:
/// what it is, where it's from, and VISIT (the store, through Drip's affiliate
/// link) or SAVE (into the bag). Cross-fades as the focus changes.
class ShopPieceBar extends StatelessWidget {
  const ShopPieceBar({super.key, required this.piece, this.bottom = 0});

  final OutfitPiece piece;

  /// Room left for the floating nav.
  final double bottom;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, bottom + 10),
      child: SizedBox(
        height: 132,
        child: AnimatedSwitcher(
          duration: Motion.dur(context, Motion.quick),
          child: _PieceCard(key: ValueKey(piece), piece: piece),
        ),
      ),
    );
  }
}

class _PieceCard extends ConsumerWidget {
  const _PieceCard({super.key, required this.piece});
  final OutfitPiece piece;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(bagProvider).any((l) => l.name == piece.name);
    final store = piece.brand.isEmpty ? '' : piece.brand.toUpperCase();
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.elevated,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 104,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.cream.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
            ),
            child: piece.image == null
                ? const SizedBox.expand()
                : DripImage(piece.image!, fit: BoxFit.contain, backdrop: false),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  [
                    if (store.isNotEmpty) store,
                    if (piece.price > 0) formatPrice(piece.price),
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.mono(9, color: AppColors.cyan),
                ),
                const SizedBox(height: 4),
                Text(
                  piece.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.manrope(13, lineHeight: 17),
                ),
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: 'VISIT',
                        style: AppButtonStyle.outline,
                        height: 36,
                        onPressed: () => openProductPage(context, piece),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AppButton(
                        label: saved ? 'SAVED' : 'SAVE',
                        height: 36,
                        onPressed: saved
                            ? null
                            : () {
                                Haptics.commit();
                                ref.read(bagProvider.notifier).addAll([
                                  BagLine(
                                    name: piece.name,
                                    subtitle: store.isEmpty
                                        ? piece.slot
                                        : '${piece.slot} · BY $store',
                                    price: piece.price,
                                  ),
                                ]);
                                showDripToast(context, 'Saved to your bag');
                              },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
