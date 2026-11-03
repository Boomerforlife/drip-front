import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/assets.dart';
import '../../core/motion.dart';
import '../../core/tab_direction.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/tap.dart';
import 'tour.dart';

/// The first-run tour, drawn over the whole shell (the tabs and the nav).
/// Each step dims the screen except a spotlight on what it explains; a pen
/// loops the spotlight and draws an arrow to it, and a finger shows the
/// gesture. Steps with nothing to point at show a drawing in the card. It
/// moves between tabs by itself and blocks the app underneath until it ends.
class TourOverlay extends ConsumerStatefulWidget {
  const TourOverlay({super.key, required this.path});

  /// The shell's current location.
  final String path;

  @override
  ConsumerState<TourOverlay> createState() => _TourOverlayState();
}

class _TourOverlayState extends ConsumerState<TourOverlay>
    with TickerProviderStateMixin {
  final _root = GlobalKey();

  /// The pen: 0 → 1 draws the loop, then the arrow.
  late final _pen = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  /// The finger and the drawings, looping.
  late final _loop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1900),
  );

  /// Re-measures the spotlight every frame, so it follows scrolling, page
  /// transitions and images loading in.
  late final Ticker _follow = createTicker(_measure);

  Rect? _hole;
  bool _ready = false;

  /// The step the overlay was last asked to show.
  int _requested = -1;
  bool _autoTried = false;

  /// Bumped per step so a late reveal from an earlier step is ignored.
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _maybeAutoStart();
  }

  @override
  void didUpdateWidget(TourOverlay old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path) _maybeAutoStart();
  }

  @override
  void dispose() {
    _follow.dispose();
    _pen.dispose();
    _loop.dispose();
    super.dispose();
  }

  /// The first time Home shows, once the page has settled.
  void _maybeAutoStart() {
    if (_autoTried || widget.path != '/home') return;
    if (!ref.read(tourAutoStartProvider)) return;
    final tour = ref.read(tourProvider.notifier);
    if (tour.seen) return;
    _autoTried = true;
    Future<void>.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted || widget.path != '/home') return;
      if (ref.read(tourProvider) == null && !tour.seen) tour.start();
    });
  }

  Future<void> _show(int index) async {
    final step = tourSteps[index];
    final generation = ++_generation;
    setState(() => _ready = false);
    _pen.value = 0;
    final moving = widget.path != step.route;
    if (moving) {
      final from = _tabIndex(widget.path), to = _tabIndex(step.route);
      TabDirection.value = (to - from).sign;
      context.go(step.route);
    }
    // Let the tab arrive, then bring the anchor into view.
    await Future<void>.delayed(Duration(milliseconds: moving ? 520 : 140));
    if (!mounted || generation != _generation) return;
    final anchor = step.anchor;
    if (anchor != null) {
      await TourAnchor.reveal(anchor, Motion.dur(context, Motion.content));
      if (!mounted || generation != _generation) return;
    }
    _hole = null;
    _measure(Duration.zero);
    setState(() => _ready = true);
    if (Motion.reduced(context)) {
      _pen.value = 1;
    } else {
      _pen.forward(from: 0);
      if (!_loop.isAnimating) _loop.repeat();
    }
    if (!_follow.isActive) _follow.start();
  }

  static int _tabIndex(String path) => switch (path) {
    '/home' => 0,
    '/scroll' => 1,
    '/studio' => 2,
    '/wardrobe' => 3,
    _ => 4,
  };

  void _measure(Duration _) {
    final index = ref.read(tourProvider);
    final anchor = index == null ? null : tourSteps[index].anchor;
    final root = _root.currentContext?.findRenderObject();
    if (anchor == null || root is! RenderBox || !root.hasSize) {
      if (_hole != null) setState(() => _hole = null);
      return;
    }
    final found = TourAnchor.rectOf(anchor, root, Offset.zero & root.size);
    if (found == null) {
      if (_hole != null) setState(() => _hole = null);
      return;
    }
    // Room around it, but never past the screen's edge.
    final target = found
        .inflate(8)
        .intersect(Offset.zero & root.size)
        .deflate(0.5);
    final now = _hole;
    final next = now == null ? target : Rect.lerp(now, target, 0.25)!;
    if (now == null ||
        (next.topLeft - now.topLeft).distance > 0.3 ||
        (next.bottomRight - now.bottomRight).distance > 0.3) {
      setState(() => _hole = next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final index = ref.watch(tourProvider);
    if (index == null) {
      if (_follow.isActive) _follow.stop();
      _requested = -1;
      return const SizedBox.shrink();
    }
    if (index != _requested) {
      _requested = index;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && ref.read(tourProvider) == index) _show(index);
      });
    }
    final step = tourSteps[index];
    final tour = ref.read(tourProvider.notifier);
    final accent = context.palette.accent;
    final hole = step.anchor == null || !_ready ? null : _hole;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        index == 0 ? tour.finish() : tour.back();
      },
      child: LayoutBuilder(
        key: _root,
        builder: (context, box) {
          final size = box.biggest;
          final card = _CardPlacement.around(
            hole,
            size,
            MediaQuery.paddingOf(context),
          );
          return Stack(
            children: [
              // Dims everything but the spotlight, and keeps taps off the app.
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {},
                  onHorizontalDragStart: (_) {},
                  onVerticalDragStart: (_) {},
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: Motion.dur(context, Motion.content),
                    builder: (context, fade, _) => CustomPaint(
                      painter: _ScrimPainter(hole: hole, fade: fade),
                    ),
                  ),
                ),
              ),
              if (hole != null)
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: Listenable.merge([_pen, _loop]),
                      builder: (context, _) => CustomPaint(
                        painter: _PenPainter(
                          hole: hole,
                          progress: _pen.value,
                          arrowFrom: card.arrowFrom,
                          color: accent,
                          seed: index,
                        ),
                        foregroundPainter: _FingerPainter(
                          hole: hole,
                          gesture: step.gesture,
                          t: _loop.value,
                          visible: _pen.value > 0.55,
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned(
                left: 16,
                right: 16,
                top: card.top,
                bottom: card.bottom,
                child: Align(
                  alignment: card.alignment,
                  child: AnimatedOpacity(
                    opacity: _ready ? 1 : 0,
                    duration: Motion.dur(context, Motion.quick),
                    child: AnimatedSlide(
                      offset: _ready ? Offset.zero : const Offset(0, 0.04),
                      duration: Motion.dur(context, Motion.content),
                      curve: Motion.out,
                      child: _StepCard(
                        index: index,
                        step: step,
                        loop: _loop,
                        onSkip: tour.finish,
                        onBack: index == 0 ? null : tour.back,
                        onNext: tour.next,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Where the card sits: below the spotlight if there's room, else above,
/// else at the foot of the screen over it; centred when there's none.
class _CardPlacement {
  const _CardPlacement(this.top, this.bottom, this.alignment, this.arrowFrom);
  final double? top;
  final double? bottom;
  final Alignment alignment;

  /// Where the pen's arrow starts (the card's edge), or null for none.
  final Offset? arrowFrom;

  static const _gap = 60.0;
  static const _room = 250.0;

  factory _CardPlacement.around(Rect? hole, Size size, EdgeInsets pad) {
    final top = pad.top + 12;
    final bottom = pad.bottom + 12;
    if (hole == null) {
      return _CardPlacement(top, bottom, Alignment.center, null);
    }
    final below = size.height - bottom - (hole.bottom + _gap);
    final above = hole.top - _gap - top;
    if (below >= _room && below >= above) {
      final y = hole.bottom + _gap;
      return _CardPlacement(
        y,
        bottom,
        Alignment.topCenter,
        Offset(size.width / 2, y - 4),
      );
    }
    if (above >= _room) {
      final y = hole.top - _gap;
      return _CardPlacement(
        top,
        size.height - y,
        Alignment.bottomCenter,
        Offset(size.width / 2, y + 4),
      );
    }
    return _CardPlacement(top, bottom, Alignment.bottomCenter, null);
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.index,
    required this.step,
    required this.loop,
    required this.onSkip,
    required this.onBack,
    required this.onNext,
  });
  final int index;
  final TourStep step;
  final Animation<double> loop;
  final VoidCallback onSkip;
  final VoidCallback? onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final accent = context.palette.accent;
    final last = index == tourSteps.length - 1;
    final count = tourSteps.length.toString().padLeft(2, '0');
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.elevated),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 30,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '${(index + 1).toString().padLeft(2, '0')} / $count',
                  style: AppText.mono(9, color: accent, letterSpacing: 1.4),
                ),
                const Spacer(),
                if (!last)
                  Tap(
                    onTap: onSkip,
                    semanticLabel: 'Skip the tour',
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 6,
                      ),
                      child: Text(
                        'SKIP TOUR',
                        style: AppText.mono(
                          9,
                          color: AppColors.muted,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (step.art != TourArt.none) ...[
              _Art(art: step.art, loop: loop),
              const SizedBox(height: 12),
            ],
            Text(step.title, style: AppText.display(18)),
            const SizedBox(height: 6),
            Text(
              step.body,
              style: AppText.manrope(
                13,
                color: AppColors.muted,
                lineHeight: 19,
              ),
            ),
            if (step.art == TourArt.afterBeta) ...[
              const SizedBox(height: 10),
              const _AfterBetaList(),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                if (onBack != null) ...[
                  Expanded(
                    child: AppButton(
                      label: 'BACK',
                      style: AppButtonStyle.outline,
                      height: 42,
                      onPressed: onBack,
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  flex: 2,
                  child: AppButton(
                    label: last
                        ? 'START EXPLORING'
                        : index == 0
                        ? 'SHOW ME'
                        : 'NEXT',
                    height: 42,
                    onPressed: () {
                      Haptics.tick();
                      onNext();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AfterBetaList extends StatelessWidget {
  const _AfterBetaList();

  static const _icons = {
    'comments': Icons.mode_comment_outlined,
    'follow': Icons.person_add_alt_rounded,
    'post': Icons.add_a_photo_outlined,
    'mail': Icons.mail_outline_rounded,
    'camera': Icons.auto_awesome_outlined,
    'palette': Icons.palette_outlined,
    'quiz': Icons.quiz_outlined,
    'lock': Icons.lock_outline_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final (icon, label) in tourAfterBeta)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.base,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.elevated),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_icons[icon], size: 13, color: AppColors.cream),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: AppText.manrope(11, weight: FontWeight.w600),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────── drawings

/// The illustration for a step with nothing on screen to point at.
class _Art extends StatelessWidget {
  const _Art({required this.art, required this.loop});
  final TourArt art;
  final Animation<double> loop;

  @override
  Widget build(BuildContext context) {
    final accent = context.palette.accent;
    return SizedBox(
      height: art == TourArt.afterBeta ? 64 : 132,
      width: double.infinity,
      child: switch (art) {
        TourArt.welcome => _Welcome(loop: loop, color: accent),
        TourArt.canvas => AnimatedBuilder(
          animation: loop,
          builder: (context, _) => CustomPaint(
            painter: _CanvasDemoPainter(t: loop.value, accent: accent),
          ),
        ),
        TourArt.afterBeta => AnimatedBuilder(
          animation: loop,
          builder: (context, _) => CustomPaint(
            painter: _SoonStampPainter(t: loop.value, color: accent),
          ),
        ),
        TourArt.done => TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: Motion.dur(context, const Duration(milliseconds: 900)),
          builder: (context, t, _) => CustomPaint(
            painter: _DonePainter(t: t, color: accent),
          ),
        ),
        TourArt.none => const SizedBox.shrink(),
      },
    );
  }
}

/// The Studio star spinning in, with sparkles drawn around it.
class _Welcome extends StatelessWidget {
  const _Welcome({required this.loop, required this.color});
  final Animation<double> loop;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Motion.dur(context, const Duration(milliseconds: 900)),
      curve: Curves.easeOutBack,
      builder: (context, t, _) => AnimatedBuilder(
        animation: loop,
        builder: (context, _) => CustomPaint(
          painter: _SparklePainter(t: loop.value, color: color, grow: t),
          child: Center(
            child: Transform.rotate(
              angle: (1 - t) * -math.pi / 2,
              child: Transform.scale(
                scale: 0.4 + 0.6 * t,
                child: SvgPicture.asset(
                  Assets.navStudio,
                  height: 92,
                  colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SparklePainter extends CustomPainter {
  _SparklePainter({required this.t, required this.color, required this.grow});
  final double t;
  final Color color;
  final double grow;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    const spots = [
      Offset(-96, -34),
      Offset(92, -40),
      Offset(-78, 38),
      Offset(104, 30),
      Offset(0, -60),
    ];
    for (final (i, o) in spots.indexed) {
      final phase = (t + i / spots.length) % 1;
      final s = math.sin(phase * math.pi) * 7 * grow;
      if (s < 0.5) continue;
      final p = c + o;
      canvas
        ..drawLine(p - Offset(s, 0), p + Offset(s, 0), paint)
        ..drawLine(p - Offset(0, s), p + Offset(0, s), paint);
    }
  }

  @override
  bool shouldRepaint(_SparklePainter old) => old.t != t || old.grow != grow;
}

/// A tiny canvas: a dashed "+" box, a piece rising from a sheet into it,
/// then the side bar's slider growing it. Loops.
class _CanvasDemoPainter extends CustomPainter {
  _CanvasDemoPainter({required this.t, required this.accent});
  final double t;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    final w = h * 0.62;
    final board = Rect.fromLTWH((size.width - w) / 2, 0, w, h);
    canvas.drawRRect(
      RRect.fromRectAndRadius(board, const Radius.circular(12)),
      Paint()..color = const Color(0xFFF4F4F2),
    );
    final ink = Paint()
      ..color = const Color(0xFF0E1018).withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final box = Rect.fromCenter(
      center: board.center.translate(0, -h * 0.12),
      width: w * 0.56,
      height: h * 0.42,
    );
    // Phase 1 (0–0.3): the empty box with its "+".
    // Phase 2 (0.3–0.6): a piece rises from the sheet into the box.
    // Phase 3 (0.6–1): the slider grows it.
    final rise = Curves.easeOutCubic.transform(((t - 0.3) / 0.3).clamp(0, 1));
    final grow = Curves.easeInOut.transform(((t - 0.6) / 0.3).clamp(0, 1));
    if (rise < 1) {
      _dashed(
        canvas,
        RRect.fromRectAndRadius(box, const Radius.circular(8)),
        ink,
      );
      final plus = Paint()
        ..color = ink.color
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round;
      final c = box.center;
      canvas
        ..drawLine(c - const Offset(6, 0), c + const Offset(6, 0), plus)
        ..drawLine(c - const Offset(0, 6), c + const Offset(0, 6), plus);
    }
    // The sheet, sliding up from the bottom while the piece rises.
    final sheetUp = math.sin(rise * math.pi);
    if (sheetUp > 0.01) {
      final sheet = Rect.fromLTWH(
        board.left,
        board.bottom - h * 0.3 * sheetUp,
        board.width,
        h * 0.3,
      );
      canvas.save();
      canvas.clipRRect(
        RRect.fromRectAndRadius(board, const Radius.circular(12)),
      );
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          sheet,
          topLeft: const Radius.circular(10),
          topRight: const Radius.circular(10),
        ),
        Paint()..color = const Color(0xFF141824),
      );
      canvas.restore();
    }
    if (rise > 0) {
      final scale = 0.7 + 0.3 * rise + 0.28 * grow;
      final start = Offset(board.center.dx, board.bottom - h * 0.12);
      final centre = Offset.lerp(start, box.center, rise)!;
      _shirt(canvas, centre, box.width * 0.42 * scale, accent);
    }
    // The side bar with its slider, while growing.
    if (grow > 0 || t > 0.58) {
      final bar = Rect.fromLTWH(
        board.right - 14,
        board.top + h * 0.2,
        8,
        h * 0.5,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(bar.inflate(4), const Radius.circular(8)),
        Paint()..color = const Color(0xDB0E1018),
      );
      final y = bar.bottom - bar.height * (0.35 + 0.5 * grow);
      canvas
        ..drawLine(
          Offset(bar.center.dx, bar.bottom),
          Offset(bar.center.dx, bar.top),
          Paint()
            ..color = const Color(0x55F4F4F2)
            ..strokeWidth = 2,
        )
        ..drawCircle(
          Offset(bar.center.dx, y),
          5,
          Paint()..color = const Color(0xFFF4F4F2),
        );
    }
  }

  /// A simple drawn tee.
  void _shirt(Canvas canvas, Offset c, double s, Color color) {
    final p = Path()
      ..moveTo(c.dx - s * 0.35, c.dy - s * 0.5)
      ..lineTo(c.dx - s * 0.75, c.dy - s * 0.25)
      ..lineTo(c.dx - s * 0.55, c.dy + s * 0.02)
      ..lineTo(c.dx - s * 0.42, c.dy - s * 0.08)
      ..lineTo(c.dx - s * 0.42, c.dy + s * 0.6)
      ..lineTo(c.dx + s * 0.42, c.dy + s * 0.6)
      ..lineTo(c.dx + s * 0.42, c.dy - s * 0.08)
      ..lineTo(c.dx + s * 0.55, c.dy + s * 0.02)
      ..lineTo(c.dx + s * 0.75, c.dy - s * 0.25)
      ..lineTo(c.dx + s * 0.35, c.dy - s * 0.5)
      ..quadraticBezierTo(
        c.dx,
        c.dy - s * 0.28,
        c.dx - s * 0.35,
        c.dy - s * 0.5,
      )
      ..close();
    canvas
      ..drawShadow(p, Colors.black, 3, false)
      ..drawPath(p, Paint()..color = color);
  }

  void _dashed(Canvas canvas, RRect r, Paint paint) {
    for (final m in (Path()..addRRect(r)).computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 8) {
        canvas.drawPath(m.extractPath(d, d + 4), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_CanvasDemoPainter old) => old.t != t;
}

/// A rubber "SOON" stamp, pressed in and rocking a little.
class _SoonStampPainter extends CustomPainter {
  _SoonStampPainter({required this.t, required this.color});
  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    canvas
      ..save()
      ..translate(c.dx, c.dy)
      ..rotate(-0.16 + 0.04 * math.sin(t * 2 * math.pi));
    final ring = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;
    final r = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: 132, height: 44),
      const Radius.circular(10),
    );
    canvas
      ..drawRRect(r, ring)
      ..drawRRect(r.deflate(4), ring..strokeWidth = 1);
    final text = TextPainter(
      text: TextSpan(
        text: 'AFTER BETA',
        style: AppText.mono(
          13,
          color: color,
          weight: FontWeight.w700,
          letterSpacing: 2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(canvas, Offset(-text.width / 2, -text.height / 2));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SoonStampPainter old) => old.t != t;
}

/// A check drawn by the pen, with a few dots bursting out.
class _DonePainter extends CustomPainter {
  _DonePainter({required this.t, required this.color});
  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final circle = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: 40),
      -math.pi / 2,
      2 * math.pi * Curves.easeOut.transform((t / 0.6).clamp(0, 1)),
      false,
      circle,
    );
    final check = Path()
      ..moveTo(c.dx - 17, c.dy + 1)
      ..lineTo(c.dx - 4, c.dy + 14)
      ..lineTo(c.dx + 19, c.dy - 12);
    final drawn = ((t - 0.45) / 0.45).clamp(0.0, 1.0);
    for (final m in check.computeMetrics()) {
      canvas.drawPath(
        m.extractPath(0, m.length * drawn),
        circle..strokeWidth = 4,
      );
    }
    if (t > 0.6) {
      final burst = Curves.easeOut.transform((t - 0.6) / 0.4);
      for (var i = 0; i < 10; i++) {
        final a = i * 2 * math.pi / 10;
        canvas.drawCircle(
          c + Offset(math.cos(a), math.sin(a)) * (46 + 16 * burst),
          2.6 * (1 - burst) + 0.6,
          Paint()..color = color.withValues(alpha: 1 - burst * 0.6),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_DonePainter old) => old.t != t;
}

// ──────────────────────────────────────────────────────────── the overlay

/// The dim with a rounded hole for the spotlight.
class _ScrimPainter extends CustomPainter {
  _ScrimPainter({required this.hole, required this.fade});
  final Rect? hole;
  final double fade;

  @override
  void paint(Canvas canvas, Size size) {
    final dim = Paint()
      ..color = const Color(0xD905070C).withValues(alpha: 0.85 * fade);
    final screen = Path()..addRect(Offset.zero & size);
    final h = hole;
    if (h == null) {
      canvas.drawPath(screen, dim);
      return;
    }
    final cut = Path()
      ..addRRect(RRect.fromRectAndRadius(h, const Radius.circular(18)));
    canvas.drawPath(Path.combine(PathOperation.difference, screen, cut), dim);
  }

  @override
  bool shouldRepaint(_ScrimPainter old) => old.hole != hole || old.fade != fade;
}

/// The pen: a loose marker loop around the spotlight (a little wobbly, and
/// overshooting where it closes, like a hand-drawn circle), then an arrow
/// from the card to it.
class _PenPainter extends CustomPainter {
  _PenPainter({
    required this.hole,
    required this.progress,
    required this.arrowFrom,
    required this.color,
    required this.seed,
  });
  final Rect hole;
  final double progress;
  final Offset? arrowFrom;
  final Color color;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final pen = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // The loop: 0 → 0.62 of the stroke. Around the spotlight, or just
    // inside it when the spotlight nearly fills the screen.
    final big =
        hole.width > size.width * 0.8 || hole.height > size.height * 0.6;
    final loop = _loop(big ? hole.deflate(10) : hole.inflate(7));
    final loopT = Curves.easeInOut.transform((progress / 0.62).clamp(0, 1));
    for (final m in loop.computeMetrics()) {
      canvas.drawPath(m.extractPath(0, m.length * loopT), pen);
    }

    // The arrow: 0.55 → 1.
    final from = arrowFrom;
    if (from == null || progress < 0.55) return;
    final arrowT = Curves.easeOut.transform(
      ((progress - 0.55) / 0.45).clamp(0, 1),
    );
    final down = from.dy < hole.top;
    final to = Offset(
      hole.center.dx.clamp(hole.left + 20, hole.right - 20),
      down ? hole.top - 12 : hole.bottom + 12,
    );
    final bend = (to.dx - from.dx).abs() < 40 ? 46.0 : 0.0;
    final control = Offset((from.dx + to.dx) / 2 + bend, (from.dy + to.dy) / 2);
    final shaft = Path()
      ..moveTo(from.dx, from.dy)
      ..quadraticBezierTo(control.dx, control.dy, to.dx, to.dy);
    for (final m in shaft.computeMetrics()) {
      canvas.drawPath(m.extractPath(0, m.length * arrowT), pen);
      if (arrowT > 0.95) {
        final tip = m.getTangentForOffset(m.length)!;
        final angle = math.atan2(tip.vector.dy, tip.vector.dx);
        for (final side in [-1, 1]) {
          final a = angle + math.pi + side * 0.5;
          canvas.drawLine(
            tip.position,
            tip.position + Offset(math.cos(a), math.sin(a)) * 11,
            pen,
          );
        }
      }
    }
  }

  /// A hand-drawn rounded loop: radius wobbles a touch, and it runs a bit
  /// past its start.
  Path _loop(Rect r) {
    final rng = math.Random(seed);
    final wobble = [for (var i = 0; i < 6; i++) rng.nextDouble() * 2 - 1];
    final c = r.center;
    final rx = r.width / 2, ry = r.height / 2;
    final path = Path();
    const turns = 1.12;
    const n = 120;
    for (var i = 0; i <= n; i++) {
      final a = -math.pi * 0.7 + 2 * math.pi * turns * i / n;
      var k = 1.0;
      for (var j = 0; j < wobble.length; j++) {
        k += 0.012 * wobble[j] * math.sin(a * (j + 2) + j);
      }
      // A superellipse hugs a wide rectangle better than an ellipse does.
      final cs = math.cos(a), sn = math.sin(a);
      final x = c.dx + rx * k * cs.sign * math.pow(cs.abs(), 0.6);
      final y = c.dy + ry * k * sn.sign * math.pow(sn.abs(), 0.6);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    return path;
  }

  @override
  bool shouldRepaint(_PenPainter old) =>
      old.hole != hole ||
      old.progress != progress ||
      old.arrowFrom != arrowFrom;
}

/// The finger: a soft dot that taps (with a ripple), double-taps, swipes up
/// or swipes side to side over the spotlight.
class _FingerPainter extends CustomPainter {
  _FingerPainter({
    required this.hole,
    required this.gesture,
    required this.t,
    required this.visible,
  });
  final Rect hole;
  final TourGesture gesture;
  final double t;
  final bool visible;

  @override
  void paint(Canvas canvas, Size size) {
    if (!visible || gesture == TourGesture.none) return;
    final c = hole.center;
    final travel = math.min(hole.height * 0.3, 110.0);
    final across = math.min(hole.width * 0.3, 120.0);
    var at = c;
    var press = 0.0;
    final ripples = <double>[];
    switch (gesture) {
      case TourGesture.tap:
        press = _pulse(t, 0.2, 0.35);
        ripples.add(t);
      case TourGesture.doubleTap:
        press = math.max(_pulse(t, 0.15, 0.27), _pulse(t, 0.32, 0.44));
        ripples
          ..add(t)
          ..add((t - 0.17) % 1);
      case TourGesture.swipeUp:
        final m = Curves.easeInOut.transform(((t - 0.15) / 0.6).clamp(0, 1));
        at = c + Offset(0, travel * (1 - 2 * m));
        press = t > 0.1 && t < 0.8 ? 1 : 0;
      case TourGesture.swipeSide:
        final m = Curves.easeInOut.transform(((t - 0.15) / 0.6).clamp(0, 1));
        at = c + Offset(across * (2 * m - 1), 0);
        press = t > 0.1 && t < 0.8 ? 1 : 0;
      case TourGesture.none:
        return;
    }
    for (final r in ripples) {
      if (r > 0.5) continue;
      final k = r / 0.5;
      canvas.drawCircle(
        at,
        14 + 26 * k,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.5 * (1 - k))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
    final radius = 13 - 3 * press;
    canvas
      ..drawCircle(
        at + const Offset(0, 3),
        radius + 2,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      )
      ..drawCircle(
        at,
        radius,
        Paint()..color = Colors.white.withValues(alpha: 0.88),
      )
      ..drawCircle(
        at,
        radius,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.18)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
  }

  /// 0 → 1 → 0 between [from] and [to].
  static double _pulse(double t, double from, double to) {
    if (t < from || t > to) return 0;
    return math.sin((t - from) / (to - from) * math.pi);
  }

  @override
  bool shouldRepaint(_FingerPainter old) =>
      old.t != t || old.hole != hole || old.visible != visible;
}
