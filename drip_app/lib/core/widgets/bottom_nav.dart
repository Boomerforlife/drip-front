import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../constants/assets.dart';
import '../motion.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'glass.dart';
import 'nav_glyphs.dart';

/// The four primary destinations. The Studio star sits between them and is an
/// action (it opens Studio), not a tab.
enum NavTab { home, scroll, wardrobe, you }

/// Geometry shared by the bar and by screens that scroll underneath it.
abstract final class NavMetrics {
  static const height = 58.0;
  static const sideMargin = 14.0;
  static const floatGap = 10.0;

  /// Distance from the screen bottom to the bar's bottom edge.
  static double bottomInset(BuildContext context) =>
      math.max(MediaQuery.paddingOf(context).bottom, 8) + floatGap;

  /// Total height the bar occupies: what scrollables should pad by so their
  /// last item can clear the glass.
  static double extent(BuildContext context) =>
      height + bottomInset(context) + 6;
}

/// Slot layout: [home, scroll, STUDIO, wardrobe, you].
const _tabSlots = {
  NavTab.home: 0,
  NavTab.scroll: 1,
  NavTab.wardrobe: 3,
  NavTab.you: 4,
};
const _studioSlot = 2;
const _slotCount = 5;

/// Floating glass navigation.
///
/// Two ways to move, one mental model — "grab the lens":
///  * **Tap** a tab: the lens springs there and the route changes at once.
///  * **Drag** anywhere on the bar: the lens follows your finger 1:1, ticking a
///    haptic each time it crosses a tab. On release the flick is projected
///    forward and the lens settles on the nearest tab, carrying your velocity.
///
/// The gesture is scoped to the bar itself, so it can never fight the vertical
/// scroll of the feed above it.
class DripBottomNav extends StatefulWidget {
  const DripBottomNav({
    super.key,
    required this.active,
    required this.onTab,
    required this.onStudio,
  });

  final NavTab? active;
  final ValueChanged<NavTab> onTab;
  final VoidCallback onStudio;

  @override
  State<DripBottomNav> createState() => _DripBottomNavState();
}

class _DripBottomNavState extends State<DripBottomNav>
    with SingleTickerProviderStateMixin {
  /// Lens position in slot space (0…4), driven by drag or spring.
  late final AnimationController _lens = AnimationController.unbounded(
    vsync: this,
    value: _slotOf(widget.active).toDouble(),
  );

  bool _dragging = false;
  int _lastTick = -1;
  double _slotWidth = 60;

  static int _slotOf(NavTab? t) => t == null ? 0 : _tabSlots[t]!;

  static NavTab _tabAt(int slot) =>
      _tabSlots.entries.firstWhere((e) => e.value == slot).key;

  /// Snap a slot-space position to the nearest *tab* slot (skips create).
  static int _nearestTabSlot(double pos) {
    var best = 0;
    var bestD = double.infinity;
    for (final s in _tabSlots.values) {
      final d = (pos - s).abs();
      if (d < bestD) {
        bestD = d;
        best = s;
      }
    }
    return best;
  }

  @override
  void didUpdateWidget(DripBottomNav old) {
    super.didUpdateWidget(old);
    // Route changed from somewhere else (avatar tap, deep link): follow it.
    if (old.active != widget.active && !_dragging && widget.active != null) {
      _springTo(_slotOf(widget.active).toDouble());
    }
  }

  @override
  void dispose() {
    _lens.dispose();
    super.dispose();
  }

  void _springTo(double target, {double velocity = 0}) {
    if (Motion.reduced(context)) {
      _lens.stop();
      _lens.value = target;
      return;
    }
    _lens.animateWith(
      SpringSimulation(Motion.snap, _lens.value, target, velocity),
    );
  }

  void _onDragStart(DragStartDetails d) {
    _dragging = true;
    _lens.stop(); // grab it mid-flight
    _lastTick = _nearestTabSlot(_lens.value);
  }

  void _onDragUpdate(DragUpdateDetails d) {
    // 1:1 tracking, with rubber-band resistance beyond the first/last tab.
    var next = _lens.value + d.delta.dx / _slotWidth;
    if (next < 0) {
      next = _lens.value + d.delta.dx / _slotWidth * 0.35;
    } else if (next > _slotCount - 1) {
      next = _lens.value + d.delta.dx / _slotWidth * 0.35;
    }
    _lens.value = next;
    final near = _nearestTabSlot(next);
    if (near != _lastTick) {
      _lastTick = near;
      Haptics.tick();
    }
  }

  void _onDragEnd(DragEndDetails d) {
    _dragging = false;
    final v = d.velocity.pixelsPerSecond.dx / _slotWidth; // slots / second
    // Momentum projection: where would this flick coast to?
    const decel = 0.985;
    final projected = _lens.value + (v / 1000) * decel / (1 - decel);
    final slot = _nearestTabSlot(projected.clamp(0, _slotCount - 1).toDouble());
    _springTo(slot.toDouble(), velocity: v);
    final tab = _tabAt(slot);
    if (tab != widget.active) {
      Haptics.commit();
      widget.onTab(tab);
    }
  }

  void _onDragCancel() {
    _dragging = false;
    _springTo(_slotOf(widget.active).toDouble());
  }

  void _tapTab(NavTab tab) {
    if (tab == widget.active) return;
    _springTo(_tabSlots[tab]!.toDouble());
    Haptics.tick();
    widget.onTab(tab);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final width = MediaQuery.sizeOf(context).width;
    final barWidth = width - NavMetrics.sideMargin * 2;
    _slotWidth = (barWidth - 12) / _slotCount;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        NavMetrics.sideMargin,
        0,
        NavMetrics.sideMargin,
        NavMetrics.bottomInset(context),
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: _onDragStart,
        onHorizontalDragUpdate: _onDragUpdate,
        onHorizontalDragEnd: _onDragEnd,
        onHorizontalDragCancel: _onDragCancel,
        child: SizedBox(
          height: NavMetrics.height,
          child: Glass(
            radius: NavMetrics.height / 2,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: AnimatedBuilder(
              animation: _lens,
              builder: (context, _) {
                final pos = _lens.value;
                return Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    if (widget.active != null || _dragging)
                      _Lens(
                        left: (pos + 0.5) * _slotWidth - (_slotWidth - 6) / 2,
                        width: _slotWidth - 6,
                        accent: palette.accent,
                        radius: 22 * palette.roundness,
                      ),
                    Row(
                      children: [
                        for (var slot = 0; slot < _slotCount; slot++)
                          SizedBox(
                            width: _slotWidth,
                            child: slot == _studioSlot
                                ? _StudioButton(onTap: widget.onStudio)
                                : _TabButton(
                                    tab: _tabAt(slot),
                                    lit: (widget.active == null && !_dragging)
                                        ? 0
                                        : (1 - (pos - slot).abs()).clamp(0, 1),
                                    selected: widget.active == _tabAt(slot),
                                    onTap: () => _tapTab(_tabAt(slot)),
                                  ),
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// The moving selection: a quiet frosted capsule. Neutral, with only a
/// hairline of the skin accent, so it reads as "here" without shouting.
class _Lens extends StatelessWidget {
  const _Lens({
    required this.left,
    required this.width,
    required this.accent,
    required this.radius,
  });
  final double left;
  final double width;
  final Color accent;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      top: 6,
      bottom: 6,
      width: width,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withValues(alpha: 0.13),
                Colors.white.withValues(alpha: 0.05),
              ],
            ),
            border: Border.all(
              color: Color.alphaBlend(
                accent.withValues(alpha: 0.30),
                Colors.white.withValues(alpha: 0.08),
              ),
              width: 0.75,
            ),
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatefulWidget {
  const _TabButton({
    required this.tab,
    required this.lit,
    required this.selected,
    required this.onTap,
  });

  final NavTab tab;

  /// 0…1: how close the lens is (drives colour + scale live while scrubbing).
  final double lit;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_TabButton> createState() => _TabButtonState();
}

class _TabButtonState extends State<_TabButton> {
  bool _down = false;

  static String _label(NavTab t) => switch (t) {
    NavTab.home => 'Home',
    NavTab.scroll => 'Fashion Scroll',
    NavTab.wardrobe => 'Wardrobe',
    NavTab.you => 'You',
  };

  Widget _glyph(Color color, double lit) => switch (widget.tab) {
    NavTab.home => HomeGlyph(color: color, glow: lit, size: 24),
    NavTab.scroll => ReelGlyph(color: color, glow: lit, size: 32),
    NavTab.wardrobe => SvgPicture.asset(
      Assets.navBriefcase,
      width: 24,
      height: 24,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    ),
    NavTab.you => SvgPicture.asset(
      Assets.navUser,
      width: 24,
      height: 24,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    ),
  };

  @override
  Widget build(BuildContext context) {
    final lit = widget.lit.toDouble();
    final color = Color.lerp(AppColors.muted, AppColors.cream, lit)!;
    return Semantics(
      button: true,
      selected: widget.selected,
      label: _label(widget.tab),
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _down = true),
        onTapUp: (_) => setState(() => _down = false),
        onTapCancel: () => setState(() => _down = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _down ? 0.9 : 1 + 0.04 * lit,
          duration: const Duration(milliseconds: 90),
          curve: Motion.out,
          child: Center(child: _glyph(color, lit)),
        ),
      ),
    );
  }
}

class _StudioButton extends StatefulWidget {
  const _StudioButton({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_StudioButton> createState() => _StudioButtonState();
}

class _StudioButtonState extends State<_StudioButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final accent = context.palette.accent;
    return Semantics(
      button: true,
      label: 'Studio',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _down = true),
        onTapUp: (_) => setState(() => _down = false),
        onTapCancel: () => setState(() => _down = false),
        onTap: () {
          Haptics.commit();
          widget.onTap();
        },
        child: Center(
          child: AnimatedScale(
            scale: _down ? 0.9 : 1,
            duration: const Duration(milliseconds: 90),
            curve: Motion.out,
            // The STUDIO star, from the supplied artwork (angular "STAR" mark).
            child: SvgPicture.asset(
              Assets.navStudio,
              width: 36,
              height: 36 * 460 / 480,
              colorFilter: ColorFilter.mode(accent, BlendMode.srcIn),
            ),
          ),
        ),
      ),
    );
  }
}
