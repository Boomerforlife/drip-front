import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/motion.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/drip_image.dart';
import '../../core/widgets/tap.dart';
import '../../data/models/stylist.dart';
import 'studio_layouts.dart';

/// The visible part of a garment image: its opaque pixels' bounds as
/// fractions of the image, and that region's pixel aspect (w / h). A cut-out
/// PNG usually has transparent margins; a photo is its whole frame.
class _Content {
  const _Content(this.bounds, this.aspect);
  final Rect bounds;
  final double aspect;
}

/// Measured once per image URL, shared by every canvas.
final _measured = <String, _Content>{};
final _measuring = <String>{};

/// The Studio canvas: a flat-lay on the same light backdrop as the Scroll's
/// collages. Each worn piece starts in the box its layout gives it (top over
/// the bottoms, shoes below, accessories in their column), so a fresh build
/// already looks like a real Drip fit. When a new piece changes the layout,
/// the others glide to their new places.
///
/// Interactive: drag any piece anywhere and pinch to resize it; the one you
/// touch comes to the front. A piece's touch area is the garment itself (its
/// opaque pixels), not the whole box around it, and pieces always stay inside
/// the canvas. Moved pieces stay where you put them ([placed]) until "snap
/// back". Required boxes still empty show an "add" outline and [selected] is
/// ringed. With [compact] it's a plain thumbnail (saved fits).
class FitCanvas extends StatefulWidget {
  const FitCanvas({
    super.key,
    required this.worn,
    this.placed = const {},
    this.stack = const [],
    this.selected,
    this.onSlotTap,
    this.onMoveStart,
    this.onMove,
    this.onAdd,
    this.onBackgroundTap,
    this.onSwap,
    this.onRemove,
    this.compact = false,
    this.radius = 22,
  });

  /// Canvas key (a Studio category, or `ACCESSORIES:n` for extra
  /// accessories) → piece.
  final Map<String, StudioPiece> worn;

  /// Pieces the user moved: key → the garment's box in canvas fractions.
  final Map<String, Rect> placed;

  /// Back-to-front order (later = on top). Unlisted pieces go underneath.
  final List<String> stack;

  /// The key being edited (ringed on the canvas).
  final String? selected;

  /// A piece (or, without [onAdd], an empty box) was tapped: its key.
  final ValueChanged<String>? onSlotTap;

  /// An empty "+" box was tapped: the Studio category to add. With this set,
  /// the canvas also offers a "+ EXTRAS" box while accessories can be added.
  final ValueChanged<String>? onAdd;

  /// The canvas itself (no piece) was tapped.
  final VoidCallback? onBackgroundTap;

  /// From the [selected] piece's side bar: swap it for another, or take it
  /// off. The bar's slider resizes it through [onMoveStart] / [onMove].
  final ValueChanged<String>? onSwap;
  final ValueChanged<String>? onRemove;

  /// A drag or pinch began on a piece.
  final ValueChanged<String>? onMoveStart;

  /// A piece moved or resized: its new box in canvas fractions.
  final void Function(String key, Rect box)? onMove;
  final bool compact;
  final double radius;

  /// Where a piece with no layout slot (and not yet moved) starts.
  static const _loose = Rect.fromLTWH(0.3, 0.36, 0.4, 0.26);

  @override
  State<FitCanvas> createState() => _FitCanvasState();
}

class _FitCanvasState extends State<FitCanvas> {
  /// Measures [url]'s visible region once, then repaints.
  void _measure(String url) {
    if (url.isEmpty || _measured.containsKey(url) || !_measuring.add(url)) {
      return;
    }
    final stream = dripImageProvider(url).resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) async {
        stream.removeListener(listener);
        final content = await _contentOf(info.image);
        _measuring.remove(url);
        _measured[url] = content;
        if (mounted) setState(() {});
      },
      onError: (_, _) {
        stream.removeListener(listener);
        _measuring.remove(url);
      },
    );
    stream.addListener(listener);
  }

  /// Bounds of the pixels that aren't (nearly) transparent, sampled on a grid
  /// so even a large cut-out takes a few milliseconds.
  static Future<_Content> _contentOf(ui.Image image) async {
    final w = image.width, h = image.height;
    final whole = _Content(const Rect.fromLTWH(0, 0, 1, 1), w / h);
    final data = await image.toByteData();
    if (data == null) return whole;
    final step = math.max(1, math.min(w, h) ~/ 160);
    var minX = w, minY = h, maxX = -1, maxY = -1;
    for (var y = 0; y < h; y += step) {
      for (var x = 0; x < w; x += step) {
        if (data.getUint8((y * w + x) * 4 + 3) > 24) {
          if (x < minX) minX = x;
          if (x > maxX) maxX = x;
          if (y < minY) minY = y;
          if (y > maxY) maxY = y;
        }
      }
    }
    if (maxX < 0) return whole;
    maxX = math.min(w - 1, maxX + step);
    maxY = math.min(h - 1, maxY + step);
    final cw = (maxX - minX + 1).toDouble(), ch = (maxY - minY + 1).toDouble();
    return _Content(Rect.fromLTWH(minX / w, minY / h, cw / w, ch / h), cw / ch);
  }

  /// The largest box of [aspect] inside [box], placed by [anchor].
  static Rect _fitIn(Rect box, double aspect, Alignment anchor) {
    var w = box.width, h = w / aspect;
    if (h > box.height) {
      h = box.height;
      w = h * aspect;
    }
    final dx = (box.width - w) * (anchor.x + 1) / 2;
    final dy = (box.height - h) * (anchor.y + 1) / 2;
    return Rect.fromLTWH(box.left + dx, box.top + dy, w, h);
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final plan = FitLayouts.plan(w.worn);
    final order = [
      for (final c in w.worn.keys)
        if (!w.stack.contains(c)) c,
      for (final c in w.stack)
        if (w.worn.containsKey(c)) c,
    ];
    for (final p in w.worn.values) {
      _measure(p.image);
    }
    return AspectRatio(
      aspectRatio: FitLayout.aspect,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(w.radius),
        child: ColoredBox(
          color: FitLayout.background,
          child: LayoutBuilder(
            builder: (context, box) {
              final size = box.biggest;
              Rect px(Rect f) => Rect.fromLTWH(
                f.left * size.width,
                f.top * size.height,
                f.width * size.width,
                f.height * size.height,
              );

              // Where the layout puts a piece's visible garment, in canvas
              // pixels (ignoring any move).
              Rect layoutRect(String key) {
                final slot = plan.placed[key];
                final boxPx = px(
                  slot == null
                      ? FitCanvas._loose
                      : Rect.fromLTWH(slot.x, slot.y, slot.w, slot.h),
                );
                final content = _measured[w.worn[key]!.image];
                if (content == null) return boxPx;
                return _fitIn(
                  boxPx,
                  content.aspect,
                  slot?.anchor ?? Alignment.center,
                );
              }

              // Where a piece's visible garment sits, in canvas pixels.
              Rect garmentRect(String key) {
                final moved = w.placed[key];
                return moved != null ? px(moved) : layoutRect(key);
              }

              final add = w.onAdd ?? w.onSlotTap;
              // One "+ EXTRAS" box in the layout's first free accessory spot.
              final extra = w.onAdd == null || w.compact
                  ? null
                  : _freeAccessorySlot(plan, w.worn);
              final selected = w.selected;
              final editing =
                  !w.compact &&
                  w.onMove != null &&
                  selected != null &&
                  w.worn.containsKey(selected);

              return Stack(
                children: [
                  if (w.onBackgroundTap != null)
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: w.onBackgroundTap,
                      ),
                    ),
                  if (!w.compact)
                    for (final slot in [...plan.missing, ?extra])
                      _layoutBox(
                        key: ValueKey('empty-${slot.slot}'),
                        rect: slot.rectIn(size),
                        child: _AddOutline(
                          label: slot == extra
                              ? 'EXTRAS'
                              : _slotLabel(slot.slot),
                          selected:
                              w.selected == categoryForLayoutSlot(slot.slot),
                          onTap: add == null
                              ? null
                              : () => add(categoryForLayoutSlot(slot.slot)),
                        ),
                      ),
                  for (final key in order)
                    _pieceBox(
                      key: key,
                      rect: garmentRect(key),
                      moved: w.placed.containsKey(key),
                      size: size,
                      child: _Piece(
                        piece: w.worn[key]!,
                        content: _measured[w.worn[key]!.image],
                        selected: !w.compact && w.selected == key,
                        shadow: !w.compact,
                      ),
                    ),
                  if (editing)
                    _ResizeBar(
                      key: ValueKey('resize-$selected'),
                      canvas: size,
                      rect: garmentRect(selected),
                      base: layoutRect(selected),
                      onStart: () => w.onMoveStart?.call(selected),
                      onResize: (r) => w.onMove!(
                        selected,
                        Rect.fromLTWH(
                          r.left / size.width,
                          r.top / size.height,
                          r.width / size.width,
                          r.height / size.height,
                        ),
                      ),
                      onSwap: w.onSwap == null
                          ? null
                          : () => w.onSwap!(selected),
                      onRemove: w.onRemove == null
                          ? null
                          : () => w.onRemove!(selected),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _layoutBox({
    required Key key,
    required Rect rect,
    required Widget child,
  }) {
    return AnimatedPositioned(
      key: key,
      duration: widget.compact ? Duration.zero : Motion.content,
      curve: Motion.out,
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
      child: child,
    );
  }

  Widget _pieceBox({
    required String key,
    required Rect rect,
    required bool moved,
    required Size size,
    required Widget child,
  }) {
    final w = widget;
    final interactive = !w.compact && w.onMove != null;
    final body = interactive
        ? _Movable(
            rect: rect,
            canvas: size,
            onTap: () => w.onSlotTap?.call(key),
            onStart: () => w.onMoveStart?.call(key),
            onMove: (r) => w.onMove!(
              key,
              Rect.fromLTWH(
                r.left / size.width,
                r.top / size.height,
                r.width / size.width,
                r.height / size.height,
              ),
            ),
            child: child,
          )
        : child;
    // A piece under the finger follows it exactly; one the layout moves
    // glides there.
    return AnimatedPositioned(
      key: ValueKey('piece-$key'),
      duration: w.compact || moved ? Duration.zero : Motion.content,
      curve: Motion.out,
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
      child: body,
    );
  }

  /// The layout's first empty accessory spot, while one more fits.
  static LayoutSlot? _freeAccessorySlot(
    LayoutPlan plan,
    Map<String, StudioPiece> worn,
  ) {
    if (worn.keys.where(isAccessoryKey).length >= maxStudioAccessories) {
      return null;
    }
    final used = {for (final s in plan.placed.values) s.slot};
    for (final s in plan.layout.slots) {
      if (s.optional && !used.contains(s.slot)) return s;
    }
    return null;
  }

  static String _slotLabel(String slot) => switch (slot) {
    'top' => 'TOP',
    'bottom' => 'BOTTOMS',
    'shoes' => 'SHOES',
    'dress' => 'DRESS',
    'outer' => 'LAYER',
    _ => slot.toUpperCase(),
  };
}

/// Drag to move, pinch to resize (both in one gesture), tap to select. The
/// piece keeps its proportions and never leaves the canvas.
class _Movable extends StatefulWidget {
  const _Movable({
    required this.rect,
    required this.canvas,
    required this.onTap,
    required this.onStart,
    required this.onMove,
    required this.child,
  });

  /// The garment's box, in canvas pixels.
  final Rect rect;
  final Size canvas;
  final VoidCallback onTap;
  final VoidCallback onStart;
  final ValueChanged<Rect> onMove;
  final Widget child;

  @override
  State<_Movable> createState() => _MovableState();
}

class _MovableState extends State<_Movable> {
  Rect? _start;
  Offset _focal = Offset.zero;
  bool _started = false;

  void _begin(ScaleStartDetails d) {
    _start = widget.rect;
    _focal = d.focalPoint;
    _started = false;
  }

  void _update(ScaleUpdateDetails d) {
    final start = _start;
    if (start == null) return;
    if (!_started) {
      _started = true;
      widget.onStart();
    }
    final canvas = widget.canvas;
    // Resize around the centre, keeping proportions: at least 24px on the
    // short side, never larger than the canvas.
    var scale = d.pointerCount < 2 ? 1.0 : d.scale;
    final minScale = 24 / math.min(start.width, start.height);
    final maxScale = math.min(
      canvas.width / start.width,
      canvas.height / start.height,
    );
    scale = scale.clamp(math.min(minScale, 1.0), math.max(maxScale, 1.0));
    final w = math.min(start.width * scale, canvas.width);
    final h = math.min(start.height * scale, canvas.height);
    final c = start.center + (d.focalPoint - _focal);
    // Keep the whole garment on the canvas.
    final left = (c.dx - w / 2).clamp(0.0, canvas.width - w);
    final top = (c.dy - h / 2).clamp(0.0, canvas.height - h);
    widget.onMove(Rect.fromLTWH(left, top, w, h));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onScaleStart: _begin,
      onScaleUpdate: _update,
      onScaleEnd: (_) => _start = null,
      child: Semantics(
        button: true,
        label: 'Piece on the canvas. Drag to move, pinch to resize.',
        child: widget.child,
      ),
    );
  }
}

/// The selected piece's side bar: swap, take off, and a slider that grows or
/// shrinks it around its centre (relative to its size in the layout). It sits
/// on the side of the canvas away from the piece, so it never covers it.
class _ResizeBar extends StatelessWidget {
  const _ResizeBar({
    super.key,
    required this.canvas,
    required this.rect,
    required this.base,
    required this.onStart,
    required this.onResize,
    this.onSwap,
    this.onRemove,
  });

  final Size canvas;

  /// The piece now and in the layout, in canvas pixels.
  final Rect rect;
  final Rect base;
  final VoidCallback onStart;
  final ValueChanged<Rect> onResize;
  final VoidCallback? onSwap;
  final VoidCallback? onRemove;

  static const _ink = Color(0xFF0E1018);

  @override
  Widget build(BuildContext context) {
    // Scale against the layout size: at least 24px on the short side, never
    // past the canvas.
    final min = math.max(0.3, 24 / math.min(base.width, base.height));
    final max = math.max(
      min + 0.1,
      math.min(
        2.5,
        math.min(canvas.width / base.width, canvas.height / base.height),
      ),
    );
    final value = (rect.width / base.width).clamp(min, max).toDouble();
    final onLeft = rect.center.dx > canvas.width * 0.55;
    final height = math.min(canvas.height * 0.52, 260.0);

    void resize(double scale) {
      final w = math.min(base.width * scale, canvas.width);
      final h = math.min(base.height * scale, canvas.height);
      final c = rect.center;
      onResize(
        Rect.fromLTWH(
          (c.dx - w / 2).clamp(0.0, canvas.width - w),
          (c.dy - h / 2).clamp(0.0, canvas.height - h),
          w,
          h,
        ),
      );
    }

    Widget action(IconData icon, String label, VoidCallback? onTap, Color c) =>
        Tap(
          onTap: onTap,
          scale: 0.9,
          semanticLabel: label,
          child: SizedBox(
            width: 44,
            height: 40,
            child: Icon(icon, size: 19, color: c),
          ),
        );

    final bar = Container(
      width: 44,
      height: height,
      decoration: BoxDecoration(
        color: _ink.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          if (onSwap != null)
            action(
              Icons.swap_horiz_rounded,
              'Swap this piece',
              onSwap,
              const Color(0xFFF4F4F2),
            ),
          if (onRemove != null)
            action(
              Icons.delete_outline_rounded,
              'Take this piece off',
              onRemove,
              const Color(0xFFFF6B5E),
            ),
          Container(
            width: 18,
            height: 1,
            margin: const EdgeInsets.symmetric(vertical: 4),
            color: const Color(0x33F4F4F2),
          ),
          const Icon(Icons.add_rounded, size: 14, color: Color(0xB3F4F4F2)),
          Expanded(
            child: RotatedBox(
              quarterTurns: 3,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  activeTrackColor: const Color(0xFFF4F4F2),
                  inactiveTrackColor: const Color(0x40F4F4F2),
                  thumbColor: const Color(0xFFF4F4F2),
                  overlayColor: const Color(0x22F4F4F2),
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 8,
                  ),
                ),
                child: Slider(
                  value: value,
                  min: min,
                  max: max,
                  semanticFormatterCallback: (v) => '${(v * 100).round()}%',
                  onChangeStart: (_) {
                    Haptics.tick();
                    onStart();
                  },
                  onChanged: resize,
                ),
              ),
            ),
          ),
          const Icon(Icons.remove_rounded, size: 14, color: Color(0xB3F4F4F2)),
          const SizedBox(height: 10),
        ],
      ),
    );

    return Positioned.fill(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: AnimatedAlign(
          duration: Motion.dur(context, Motion.content),
          curve: Motion.out,
          alignment: onLeft ? Alignment.centerLeft : Alignment.centerRight,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: Motion.dur(context, Motion.quick),
            curve: Motion.out,
            builder: (context, t, child) => Opacity(
              opacity: t,
              child: Transform.translate(
                offset: Offset((onLeft ? -1 : 1) * 14 * (1 - t), 0),
                child: child,
              ),
            ),
            child: Semantics(
              container: true,
              label: 'Resize the piece',
              child: bar,
            ),
          ),
        ),
      ),
    );
  }
}

/// A garment filling its box: the image is drawn so its visible region (the
/// [content] bounds) fills the box exactly, with the soft studio shadow.
class _Piece extends StatelessWidget {
  const _Piece({
    required this.piece,
    required this.content,
    required this.selected,
    required this.shadow,
  });

  final StudioPiece piece;
  final _Content? content;
  final bool selected;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final b = content?.bounds ?? const Rect.fromLTWH(0, 0, 1, 1);
        // The whole image, scaled so its visible part covers this box; the
        // transparent margins hang outside it (and can't be touched).
        final fw = box.maxWidth / b.width, fh = box.maxHeight / b.height;
        Widget image = DripImage(
          piece.image,
          fit: content == null ? BoxFit.contain : BoxFit.fill,
          backdrop: false,
          semanticLabel: piece.name,
        );
        image = content == null
            ? SizedBox.expand(child: image)
            : OverflowBox(
                alignment: Alignment.topLeft,
                maxWidth: fw,
                maxHeight: fh,
                minWidth: fw,
                minHeight: fh,
                child: Transform.translate(
                  offset: Offset(-b.left * fw, -b.top * fh),
                  child: image,
                ),
              );
        Widget body = Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: [
            if (shadow)
              // The studio flat-lay shadow: the cut-out itself, darkened,
              // blurred and dropped a little.
              Transform.translate(
                offset: const Offset(0, 4),
                child: ImageFiltered(
                  imageFilter: ui.ImageFilter.compose(
                    outer: ColorFilter.mode(
                      Colors.black.withValues(alpha: 0.22),
                      BlendMode.srcIn,
                    ),
                    inner: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                  ),
                  child: image,
                ),
              ),
            image,
          ],
        );
        body = AnimatedSwitcher(
          duration: Motion.content,
          switchInCurve: Curves.easeOutBack,
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: ScaleTransition(
              scale: Tween(begin: 0.85, end: 1.0).animate(anim),
              child: child,
            ),
          ),
          child: KeyedSubtree(key: ValueKey(piece.id), child: body),
        );
        if (selected) {
          body = DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0x590E1018), width: 1.2),
            ),
            child: body,
          );
        }
        return body;
      },
    );
  }
}

/// An empty required box: "add a top here".
class _AddOutline extends StatelessWidget {
  const _AddOutline({required this.label, required this.selected, this.onTap});
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF0E1018);
    final body = CustomPaint(
      painter: _DashedRect(
        color: ink.withValues(alpha: selected ? 0.55 : 0.22),
      ),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '+',
                  style: AppText.inter(
                    22,
                    color: ink.withValues(alpha: selected ? 0.7 : 0.35),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: AppText.mono(
                    10,
                    color: ink.withValues(alpha: selected ? 0.75 : 0.42),
                    letterSpacing: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return onTap == null
        ? body
        : Tap(
            onTap: onTap,
            scale: 0.97,
            semanticLabel: 'Add $label',
            child: body,
          );
  }
}

class _DashedRect extends CustomPainter {
  _DashedRect({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(3),
      const Radius.circular(12),
    );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    for (final m in (Path()..addRRect(rrect)).computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 9) {
        canvas.drawPath(m.extractPath(d, d + 5), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRect old) => old.color != color;
}
