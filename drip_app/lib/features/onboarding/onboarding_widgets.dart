import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/motion.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/tap.dart';

/// Fades and slides its child in after [delay] (the flow's "rise" entrance).
/// Under reduced motion it just appears.
class Enter extends StatefulWidget {
  const Enter({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.dy = 16,
    this.dx = 0,
    this.duration = const Duration(milliseconds: 600),
  });

  final Widget child;
  final Duration delay;
  final double dy;
  final double dx;
  final Duration duration;

  @override
  State<Enter> createState() => _EnterState();
}

class _EnterState extends State<Enter> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  Timer? _timer;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (Motion.reduced(context)) {
      _c.value = 1;
    } else if (widget.delay == Duration.zero) {
      _c.forward();
    } else {
      _timer = Timer(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(parent: _c, curve: Motion.out);
    return AnimatedBuilder(
      animation: curve,
      child: widget.child,
      builder: (context, child) => Opacity(
        opacity: curve.value.clamp(0, 1),
        child: Transform.translate(
          offset: Offset(
            widget.dx * (1 - curve.value),
            widget.dy * (1 - curve.value),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Small red mono eyebrow above a headline.
class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key, this.color = AppColors.red});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: AppText.mono(11, color: color, letterSpacing: 2),
  );
}

/// Mono caption used above groups of choices.
class GroupLabel extends StatelessWidget {
  const GroupLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: AppText.mono(10, color: AppColors.muted, letterSpacing: 2),
  );
}

/// A selectable pill with a tick that slides in when picked.
class PickPill extends StatelessWidget {
  const PickPill({
    super.key,
    required this.label,
    required this.on,
    required this.onTap,
    this.big = false,
    this.tick = '✓',
  });

  final String label;
  final bool on;
  final VoidCallback onTap;
  final bool big;
  final String tick;

  @override
  Widget build(BuildContext context) {
    return Tap(
      onTap: onTap,
      scale: 0.93,
      semanticLabel: label,
      child: AnimatedScale(
        scale: on ? 1.05 : 1,
        duration: Motion.quick,
        curve: Curves.easeOutBack,
        child: AnimatedContainer(
          duration: Motion.quick,
          padding: EdgeInsets.symmetric(
            horizontal: big ? 18 : 15,
            vertical: big ? 12 : 10,
          ),
          decoration: BoxDecoration(
            color: on
                ? AppColors.cyan.withValues(alpha: 0.14)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: on ? AppColors.cyan : AppColors.elevated),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSize(
                duration: Motion.quick,
                curve: Motion.out,
                child: SizedBox(
                  width: on ? 18 : 0,
                  child: on
                      ? Text(
                          tick,
                          style: AppText.manrope(12, color: AppColors.cyan),
                        )
                      : null,
                ),
              ),
              Text(
                label,
                style: AppText.manrope(
                  big ? 14 : 13,
                  weight: FontWeight.w600,
                  color: on ? AppColors.cyan : AppColors.cream,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The small cyan "✓" badge that pops in on a selected tile.
class TickBadge extends StatelessWidget {
  const TickBadge({super.key, required this.on, this.label = '✓'});
  final bool on;
  final String label;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: on ? 1 : 0,
      alignment: Alignment.topRight,
      duration: Motion.content,
      curve: Curves.easeOutBack,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.cyan,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: AppText.mono(
            10,
            color: AppColors.base,
            weight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// A rounded rectangle outlined with dashes.
class DashedBorder extends StatelessWidget {
  const DashedBorder({
    super.key,
    required this.child,
    this.radius = 20,
    this.color = const Color(0x40E8DFC8),
    this.width = 2,
  });

  final Widget child;
  final double radius;
  final Color color;
  final double width;

  @override
  Widget build(BuildContext context) => CustomPaint(
    foregroundPainter: _DashPainter(radius, color, width),
    child: child,
  );
}

class _DashPainter extends CustomPainter {
  _DashPainter(this.radius, this.color, this.width);
  final double radius;
  final Color color;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(radius),
        ).deflate(width / 2),
      );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;
    for (final m in path.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 12) {
        canvas.drawPath(m.extractPath(d, d + 6), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) =>
      old.radius != radius || old.color != color || old.width != width;
}
