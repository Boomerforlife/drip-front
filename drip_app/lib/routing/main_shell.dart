import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:go_router/go_router.dart';

import '../core/motion.dart';
import '../core/tab_direction.dart';
import '../core/widgets/bottom_nav.dart';

export '../core/tab_direction.dart';

/// Which tab lights up for each route (the create button is an action, so
/// screens reached from it show no active tab).
NavTab? navTabFor(String path) {
  bool starts(String p) => path == p || path.startsWith('$p/');

  if (starts('/home') ||
      starts('/discover') ||
      starts('/search') ||
      starts('/photoshoot')) {
    return NavTab.home;
  }
  if (starts('/scroll')) return NavTab.scroll;
  if (starts('/studio')) return NavTab.studio;
  if (starts('/wardrobe') || starts('/saved') || starts('/outfit')) {
    return NavTab.wardrobe;
  }
  if (starts('/me') ||
      starts('/u') ||
      starts('/followers') ||
      starts('/following') ||
      starts('/activity') ||
      starts('/settings')) {
    return NavTab.you;
  }
  return null;
}

/// Tab roots draw *under* the floating glass bar (so it has real content to
/// blur). Every other shell route stops above the bar.
bool _extendsUnderNav(String path) =>
    path == '/home' ||
    path == '/scroll' ||
    path == '/studio' ||
    path == '/wardrobe' ||
    path == '/me';

/// Hosts every screen that shows the bottom navigation bar.
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.child, required this.path});

  final Widget child;
  final String path;

  static const _tabRoutes = {
    NavTab.home: '/home',
    NavTab.scroll: '/scroll',
    NavTab.studio: '/studio',
    NavTab.wardrobe: '/wardrobe',
    NavTab.you: '/me',
  };

  void _goTab(BuildContext context, NavTab tab, NavTab? from) {
    final target = _tabRoutes[tab]!;
    // Tapping the tab you're on from deeper in it returns to its root.
    if (path == target) return;
    TabDirection.value = (tab.index - (from ?? tab).index).sign;
    context.go(target);
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final keyboardOpen = mq.viewInsets.bottom > 0;
    final extent = NavMetrics.extent(context);
    final under = _extendsUnderNav(path);
    final active = navTabFor(path);

    // Tab roots get the nav height added to their bottom padding so scroll
    // views can clear the glass; other routes are simply inset above it.
    Widget body = child;
    if (keyboardOpen) {
      // Nav hidden: nothing to clear.
    } else if (under) {
      body = MediaQuery(
        data: mq.copyWith(
          padding: mq.padding.copyWith(
            bottom: math.max(mq.padding.bottom, extent),
          ),
        ),
        child: child,
      );
    } else {
      body = Padding(
        padding: EdgeInsets.only(bottom: extent),
        child: child,
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: true,
      extendBody: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Swipe sideways anywhere on a tab root to move to the next tab.
          _TabSwipe(
            tab: under ? active : null,
            // Like Instagram: swipe right past Home to reach the camera.
            onPastStart: path == '/home'
                ? () => context.push('/wardrobe/capture')
                : null,
            onSwipe: (dir) {
              final next = active!.index + dir;
              if (next < 0 || next >= NavTab.values.length) return;
              _goTab(context, NavTab.values[next], active);
            },
            child: body,
          ),
          if (!keyboardOpen)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: DripBottomNav(
                active: active,
                onTab: (tab) => _goTab(context, tab, active),
              ),
            ),
        ],
      ),
    );
  }
}

/// Screen body used inside the shell: transparent (the themed backdrop shows
/// through) with top safe-area padding.
class ShellPage extends StatelessWidget {
  const ShellPage({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(bottom: false, child: child);
  }
}

/// Swipe left/right anywhere on a tab root to change tab, like paging through
/// Instagram: swipe left from Home and you're in the Fashion Scroll.
///
/// The screen follows the finger with resistance (and rubber-bands at the
/// first/last tab), a haptic ticks when the swipe is far enough to commit, and
/// a quick flick counts even if it's short. Horizontal scrollables inside a
/// screen (stories, the theme bar, carousels) claim their own drags first, so
/// this only fires where nothing else wants the swipe.
class _TabSwipe extends StatefulWidget {
  const _TabSwipe({
    required this.tab,
    required this.onSwipe,
    required this.child,
    this.onPastStart,
  });

  /// The active tab when swiping is allowed here, else null (detail screens).
  final NavTab? tab;

  /// -1 = towards the previous tab, +1 = towards the next.
  final ValueChanged<int> onSwipe;
  final Widget child;

  /// A swipe right on the first tab (nothing before it) commits to this.
  final VoidCallback? onPastStart;

  @override
  State<_TabSwipe> createState() => _TabSwipeState();
}

class _TabSwipeState extends State<_TabSwipe>
    with SingleTickerProviderStateMixin {
  final _dx = ValueNotifier<double>(0);
  late final AnimationController _settle = AnimationController.unbounded(
    vsync: this,
  )..addListener(() => _dx.value = _settle.value);

  double _raw = 0;
  bool _armed = false;

  @override
  void dispose() {
    _settle.dispose();
    _dx.dispose();
    super.dispose();
  }

  bool _hasTab(int dir) {
    final t = widget.tab;
    if (t == null) return false;
    final next = t.index + dir;
    return next >= 0 && next < NavTab.values.length;
  }

  double _threshold(BuildContext context) =>
      MediaQuery.sizeOf(context).width * 0.22;

  void _onStart(DragStartDetails d) {
    _settle.stop();
    _raw = _dx.value;
    _armed = false;
  }

  void _onUpdate(DragUpdateDetails d) {
    _raw += d.delta.dx;
    final dir = _raw < 0 ? 1 : -1; // swiping left goes to the next tab
    // Follow the finger, but heavier than 1:1 so it reads as a nudge, and much
    // heavier where there's nowhere to go.
    final width = MediaQuery.sizeOf(context).width;
    final gain = _hasTab(dir) ? 0.42 : 0.14;
    _dx.value = (_raw * gain).clamp(-width * 0.3, width * 0.3);

    final armed = _hasTab(dir) && _raw.abs() >= _threshold(context);
    if (armed != _armed) {
      _armed = armed;
      if (armed) Haptics.tick();
    }
  }

  void _onEnd(DragEndDetails d) {
    final v = d.velocity.pixelsPerSecond.dx;
    // Where the flick would coast to, so a quick short swipe still counts.
    final projected = _raw + v * 0.10;
    final dir = projected < 0 ? 1 : -1;
    final far = projected.abs() >= _threshold(context);
    final quick = v.abs() > 700 && _raw.abs() > 16;
    if (_hasTab(dir) && (far || quick) && (_raw.sign == projected.sign)) {
      Haptics.commit();
      widget.onSwipe(dir);
    } else if (dir == -1 &&
        !_hasTab(dir) &&
        widget.onPastStart != null &&
        (far || quick) &&
        _raw.sign == projected.sign) {
      Haptics.commit();
      widget.onPastStart!();
    }
    _springHome(v * 0.42);
  }

  void _springHome(double velocity) {
    if (Motion.reduced(context)) {
      _settle.stop();
      _dx.value = 0;
      return;
    }
    _settle.value = _dx.value;
    _settle.animateWith(SpringSimulation(Motion.snap, _dx.value, 0, velocity));
  }

  @override
  Widget build(BuildContext context) {
    // Always the same widget structure (handlers are just switched off on
    // detail screens) so navigating never rebuilds the screen underneath.
    final on = widget.tab != null;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: on ? _onStart : null,
      onHorizontalDragUpdate: on ? _onUpdate : null,
      onHorizontalDragEnd: on ? _onEnd : null,
      onHorizontalDragCancel: on ? () => _springHome(0) : null,
      child: ValueListenableBuilder<double>(
        valueListenable: _dx,
        child: RepaintBoundary(child: widget.child),
        builder: (context, dx, child) =>
            Transform.translate(offset: Offset(dx, 0), child: child),
      ),
    );
  }
}
