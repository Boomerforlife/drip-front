import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../motion.dart';
import '../theme/app_colors.dart';

/// A sheet that springs up from the bottom over a dimmed page, the way
/// Pinterest opens a piece: Studio's piece picker and the Scroll's "shop the
/// look". [sheet] is its content while open; setting it to null slides it
/// away. Drag it down (anywhere on it, or on the dimmed page), tap the page
/// or press back to close: those call [onClose], and the owner clears
/// [sheet]. While it's open the page underneath doesn't scroll or swipe.
class SlideUpSheet extends StatefulWidget {
  const SlideUpSheet({
    super.key,
    required this.sheet,
    required this.onClose,
    required this.child,
    this.heightFactor = 0.7,
    this.bottomInset = 0,
  });

  final Widget? sheet;
  final VoidCallback onClose;
  final Widget child;

  /// Share of the page's height the sheet takes (360px at least).
  final double heightFactor;

  /// Room at the foot of the sheet for something floating over it (the nav);
  /// the sheet grows by this much and its content stays above it.
  final double bottomInset;

  @override
  State<SlideUpSheet> createState() => _SlideUpSheetState();
}

class _SlideUpSheetState extends State<SlideUpSheet>
    with SingleTickerProviderStateMixin {
  /// 0 down out of sight, 1 fully up.
  late final _slide = AnimationController(vsync: this);

  /// What's on the sheet: kept while it slides away after [sheet] clears.
  Widget? _shown;
  double _height = 1;

  /// A downward flick's speed, carried into the close.
  double _flick = 0;

  @override
  void initState() {
    super.initState();
    if (widget.sheet != null) {
      _shown = widget.sheet;
      WidgetsBinding.instance.addPostFrameCallback((_) => _settle(1));
    }
  }

  @override
  void didUpdateWidget(SlideUpSheet old) {
    super.didUpdateWidget(old);
    final sheet = widget.sheet;
    if (sheet != null) {
      _shown = sheet;
      if (old.sheet == null) _settle(1);
    } else if (old.sheet != null) {
      final velocity = _flick;
      _flick = 0;
      _settle(0, velocity).whenComplete(() {
        // Still closed (not reopened meanwhile): the spring rests within its
        // tolerance of 0, not exactly on it.
        if (mounted && widget.sheet == null && _slide.value < 0.02) {
          _slide.value = 0;
          setState(() => _shown = null);
        }
      });
    }
  }

  @override
  void dispose() {
    _slide.dispose();
    super.dispose();
  }

  /// Springs to [target] with no overshoot, carrying a flick's speed.
  TickerFuture _settle(double target, [double velocity = 0]) {
    if (!mounted) return TickerFuture.complete();
    if (Motion.reduced(context)) {
      _slide.value = target;
      return TickerFuture.complete();
    }
    return _slide.animateWith(
      SpringSimulation(Motion.snap, _slide.value, target, velocity)
        ..tolerance = const Tolerance(distance: 0.001, velocity: 0.01),
    );
  }

  void _drag(DragUpdateDetails d) {
    if (widget.sheet == null) return;
    _slide.stop();
    _slide.value = (_slide.value - d.delta.dy / _height).clamp(0.0, 1.0);
  }

  void _release(DragEndDetails d) {
    if (widget.sheet == null) return;
    final dy = d.velocity.pixelsPerSecond.dy;
    final velocity = -dy / _height;
    if (dy > 650 || (_slide.value < 0.6 && dy >= 0)) {
      _flick = velocity;
      widget.onClose();
    } else {
      _settle(1, velocity);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shown = _shown;
    return PopScope(
      canPop: widget.sheet == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) widget.onClose();
      },
      child: LayoutBuilder(
        builder: (context, box) {
          _height =
              (box.maxHeight * widget.heightFactor).clamp(
                360.0,
                box.maxHeight - 40,
              ) +
              widget.bottomInset;
          return Stack(
            children: [
              Positioned.fill(child: widget.child),
              if (shown != null) ...[
                // The dimmed page: tap to close, drag to move the sheet; it
                // keeps the page (and the tabs) from scrolling underneath.
                Positioned.fill(
                  child: GestureDetector(
                    key: const ValueKey('slide-up-sheet-scrim'),
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.onClose,
                    onVerticalDragUpdate: _drag,
                    onVerticalDragEnd: _release,
                    onHorizontalDragStart: (_) {},
                    child: FadeTransition(
                      opacity: _slide,
                      child: const ColoredBox(color: Color(0x8C05070C)),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: _height,
                  child: AnimatedBuilder(
                    animation: _slide,
                    builder: (context, child) => Transform.translate(
                      offset: Offset(0, (1 - _slide.value) * _height),
                      child: child,
                    ),
                    child: GestureDetector(
                      onVerticalDragUpdate: _drag,
                      onVerticalDragEnd: _release,
                      child: Container(
                        padding: EdgeInsets.only(bottom: widget.bottomInset),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(28),
                          ),
                          border: Border(
                            top: BorderSide(color: AppColors.elevated),
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x66000000),
                              blurRadius: 30,
                              offset: Offset(0, -6),
                            ),
                          ],
                        ),
                        child: shown,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// The sheet's grab handle.
class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 4,
      decoration: BoxDecoration(
        color: AppColors.cream.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
