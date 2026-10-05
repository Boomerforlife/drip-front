import 'dart:math' as math;
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/motion.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/tap.dart';
import 'camera_fallback.dart';
import 'guidance_engine.dart';
import 'guidance_models.dart';
import 'luma_analyzer.dart';
import 'selfie_camera.dart';
import 'selfie_intent.dart';

/// Steps 2–5: the live camera with calm guidance, a 3-2-1 countdown and
/// capture. Shots go up through [onCaptured]; the screen keeps them.
class CameraStage extends ConsumerStatefulWidget {
  const CameraStage({
    super.key,
    required this.intent,
    required this.angleTip,
    required this.shotCount,
    required this.lastShot,
    required this.onCaptured,
    required this.onReview,
    required this.onClose,
    required this.onChangeIntent,
    required this.onTakePhoto,
    required this.onLibrary,
  });

  final SelfieIntent intent;
  final String? angleTip;
  final int shotCount;
  final Uint8List? lastShot;
  final ValueChanged<Uint8List> onCaptured;
  final VoidCallback onReview;
  final VoidCallback onClose;
  final VoidCallback onChangeIntent;
  final VoidCallback onTakePhoto;
  final VoidCallback onLibrary;

  @override
  ConsumerState<CameraStage> createState() => _CameraStageState();
}

class _Hint {
  const _Hint(this.guidance, this.ready);
  final Guidance? guidance;
  final bool ready;
}

class _CameraStageState extends ConsumerState<CameraStage>
    with WidgetsBindingObserver {
  late final SelfieCameraService _camera;
  late SelfieGuidanceEngine _engine;
  final _analyzer = LumaAnalyzer();
  final _hint = ValueNotifier<_Hint>(const _Hint(null, false));

  StreamSubscription<SelfieFrame>? _sub;
  Timer? _countdownTimer;
  CameraOutcome? _outcome;
  int? _count;
  bool _capturing = false;
  bool _flash = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _camera = ref.read(selfieCameraFactoryProvider)();
    _engine = _newEngine();
    _start();
  }

  SelfieGuidanceEngine _newEngine() => ref.read(selfieEngineFactoryProvider)(
    widget.intent,
    setupTip: widget.angleTip,
  );

  Future<void> _start() async {
    final outcome = await _camera.start();
    if (!mounted) return;
    setState(() => _outcome = outcome);
    if (outcome != CameraOutcome.ready) return;
    _engine = _newEngine();
    _analyzer.reset();
    _sub = _camera.frames.listen(_onFrame);
    // Show the opening tip straight away, before the first frame lands.
    _hint.value = _Hint(
      _engine.update(
        const FrameObservation(
          FrameStats(
            meanLuma: 0.5,
            lightBias: 0,
            highlightClip: 0,
            shadowClip: 0,
            sharpness: 1,
            backgroundBusy: 0,
          ),
        ),
        DateTime.now(),
      ),
      false,
    );
  }

  void _onFrame(SelfieFrame f) {
    if (_capturing) return;
    final stats = _analyzer.analyze(
      f.luma,
      f.width,
      f.height,
      f.rowStride,
      live: true,
      rotated: _camera.framesRotated,
    );
    final g = _engine.update(FrameObservation(stats), DateTime.now());
    final old = _hint.value;
    if (old.guidance?.id != g?.id || old.ready != _engine.ready) {
      _hint.value = _Hint(g, _engine.ready);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_outcome != CameraOutcome.ready) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _cancelCountdown();
      _sub?.cancel();
      _camera.suspend();
    } else if (state == AppLifecycleState.resumed) {
      setState(() => _outcome = null);
      _start();
    }
  }

  void _cancelCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    if (_count != null && mounted) setState(() => _count = null);
  }

  void _onShutter() {
    if (_capturing || _outcome != CameraOutcome.ready) return;
    if (_count != null) {
      _cancelCountdown();
      return;
    }
    Haptics.tick();
    setState(() => _count = 3);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      final next = (_count ?? 1) - 1;
      if (next <= 0) {
        t.cancel();
        _countdownTimer = null;
        _capture();
      } else if (mounted) {
        Haptics.tick();
        setState(() => _count = next);
      }
    });
  }

  Future<void> _capture() async {
    if (!mounted) return;
    setState(() {
      _count = null;
      _capturing = true;
      _flash = true;
    });
    try {
      final bytes = await _camera.capture();
      Haptics.commit();
      if (mounted) widget.onCaptured(bytes);
    } catch (_) {
      if (mounted) setState(() => _outcome = CameraOutcome.unavailable);
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
    Future<void>.delayed(const Duration(milliseconds: 140), () {
      if (mounted) setState(() => _flash = false);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _countdownTimer?.cancel();
    _sub?.cancel();
    _camera.dispose();
    _hint.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final outcome = _outcome;
    if (outcome == null) {
      return const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (outcome != CameraOutcome.ready) {
      return CameraFallback(
        outcome: outcome,
        onTakePhoto: widget.onTakePhoto,
        onLibrary: widget.onLibrary,
        onRetry: outcome == CameraOutcome.denied
            ? () {
                setState(() => _outcome = null);
                _start();
              }
            : null,
      );
    }

    final accent = context.palette.accent;
    return Stack(
      fit: StackFit.expand,
      children: [
        // Immersive preview, cropped to fill.
        ClipRect(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _camera.previewAspect * 1000,
              height: 1000,
              child: _camera.buildPreview(),
            ),
          ),
        ),
        ValueListenableBuilder<_Hint>(
          valueListenable: _hint,
          builder: (_, hint, _) => IgnorePointer(
            child: _FaceHusk(
              intent: widget.intent,
              color: hint.ready ? accent : AppColors.cream,
              ready: hint.ready,
            ),
          ),
        ),
        // Capture flash.
        IgnorePointer(
          child: AnimatedOpacity(
            opacity: _flash ? 0.7 : 0,
            duration: const Duration(milliseconds: 120),
            child: const ColoredBox(color: Colors.white),
          ),
        ),
        // Top: close, the kind of shot, and the shot number.
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
            child: Column(
              children: [
                Row(
                  children: [
                    Tap(
                      onTap: widget.onClose,
                      semanticLabel: 'Close',
                      scale: 0.9,
                      child: const SizedBox(
                        width: 44,
                        height: 44,
                        child: Icon(
                          Icons.close_rounded,
                          size: 22,
                          color: AppColors.cream,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Tap(
                      onTap: widget.onChangeIntent,
                      semanticLabel: 'Change photo type',
                      child: _Pill(widget.intent.label.toUpperCase()),
                    ),
                    const Spacer(),
                    _Pill('SHOT ${widget.shotCount + 1}'),
                  ],
                ),
                const SizedBox(height: 14),
                ValueListenableBuilder<_Hint>(
                  valueListenable: _hint,
                  builder: (_, hint, _) => _Caption(
                    text: _count != null ? 'Hold still.' : hint.guidance?.text,
                    good: hint.guidance?.tone == GuidanceTone.good,
                    accent: accent,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Bottom: thumb zone, clear of the face.
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: EdgeInsets.fromLTRB(
              24,
              28,
              24,
              16 + MediaQuery.paddingOf(context).bottom,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.55),
                  Colors.transparent,
                ],
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SizedBox(
                  width: 64,
                  child: widget.lastShot == null
                      ? null
                      : Tap(
                          onTap: widget.onReview,
                          semanticLabel: 'Review your shots',
                          child: Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.cream),
                              image: DecorationImage(
                                image: MemoryImage(widget.lastShot!),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                ),
                ValueListenableBuilder<_Hint>(
                  valueListenable: _hint,
                  builder: (_, hint, _) => _Shutter(
                    count: _count,
                    busy: _capturing,
                    ready: hint.ready,
                    accent: accent,
                    onTap: _onShutter,
                  ),
                ),
                SizedBox(
                  width: 64,
                  child: widget.shotCount == 0
                      ? null
                      : Align(
                          alignment: Alignment.centerRight,
                          child: Tap(
                            onTap: widget.onReview,
                            semanticLabel: 'Done, review shots',
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text(
                                'DONE',
                                style: AppText.mono(
                                  11,
                                  color: accent,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Text(label, style: AppText.mono(10, letterSpacing: 1)),
  );
}

/// One calm line. It fades between instructions and is empty when there is
/// nothing to say.
class _Caption extends StatelessWidget {
  const _Caption({
    required this.text,
    required this.good,
    required this.accent,
  });
  final String? text;
  final bool good;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: AnimatedSwitcher(
        duration: Motion.dur(context, Motion.quick),
        child: text == null
            ? const SizedBox.shrink(key: ValueKey('none'))
            : Container(
                key: ValueKey(text),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    text!,
                    textAlign: TextAlign.center,
                    style: AppText.manrope(
                      15,
                      weight: FontWeight.w600,
                      color: good ? accent : AppColors.cream,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _Shutter extends StatelessWidget {
  const _Shutter({
    required this.count,
    required this.busy,
    required this.ready,
    required this.accent,
    required this.onTap,
  });
  final int? count;
  final bool busy;
  final bool ready;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tap(
      onTap: busy ? null : onTap,
      semanticLabel: count == null ? 'Take photo' : 'Cancel countdown',
      scale: 0.94,
      child: AnimatedContainer(
        duration: Motion.quick,
        width: 78,
        height: 78,
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: ready ? accent : AppColors.cream, width: 3),
        ),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: count == null ? AppColors.cream : Colors.black54,
          ),
          child: count == null
              ? null
              : Text('$count', style: AppText.display(32, lineHeight: 34)),
        ),
      ),
    );
  }
}

/// Where the head should sit: a featureless face shape, a husk of head, ears,
/// neck and shoulders, sized from the chosen photo type (Fashion asks for a
/// wider frame than Dating). It breathes slowly and a soft light traces its
/// outline, so it reads as a guide to step into; once the framing is right it
/// firms up in the accent colour. Still when motion is reduced.
class _FaceHusk extends StatefulWidget {
  const _FaceHusk({
    required this.intent,
    required this.color,
    required this.ready,
  });
  final SelfieIntent intent;
  final Color color;
  final bool ready;

  @override
  State<_FaceHusk> createState() => _FaceHuskState();
}

class _FaceHuskState extends State<_FaceHusk>
    with SingleTickerProviderStateMixin {
  late final AnimationController _t = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _t.stop();
    } else if (!_t.isAnimating) {
      _t.repeat();
    }
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      builder: (_, _) => CustomPaint(
        painter: _HuskPainter(
          intent: widget.intent,
          color: widget.color,
          ready: widget.ready,
          t: _t.value,
          moving: _t.isAnimating,
        ),
      ),
    );
  }
}

class _HuskPainter extends CustomPainter {
  _HuskPainter({
    required this.intent,
    required this.color,
    required this.ready,
    required this.t,
    required this.moving,
  });
  final SelfieIntent intent;
  final Color color;
  final bool ready;

  /// 0–1 round the loop: the breath and the light along the outline.
  final double t;
  final bool moving;

  @override
  void paint(Canvas canvas, Size size) {
    final faceH = (intent.faceMin + intent.faceMax) / 2;
    final h = size.height * faceH * 1.3; // head, crown to chin
    final w = h * 0.74;
    final headroom = (intent.headroomMin + intent.headroomMax) / 2;
    final cx = size.width / 2;
    final top = size.height * headroom;

    // A slow breath: the whole husk swells by a hair and settles.
    final breath = moving ? 1 + 0.012 * math.sin(t * 2 * math.pi) : 1.0;
    canvas.save();
    canvas.translate(cx, top + h / 2);
    canvas.scale(breath);
    canvas.translate(-cx, -(top + h / 2));

    final head = _head(cx, top, w, h);
    final body = _body(cx, top, w, h);

    canvas.drawPath(
      head,
      Paint()..color = color.withValues(alpha: ready ? 0.10 : 0.05),
    );
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = ready ? 2 : 1.4
      ..color = color.withValues(alpha: ready ? 0.9 : 0.34);
    canvas.drawPath(head, line);
    canvas.drawPath(
      body,
      line..color = line.color.withValues(alpha: line.color.a * 0.75),
    );

    // The light: a short brighter stretch gliding round the head.
    if (moving && !ready) {
      for (final m in head.computeMetrics()) {
        final len = m.length * 0.16;
        final start = (t * m.length) % m.length;
        final glow = Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 2
          ..color = color.withValues(alpha: 0.75);
        canvas.drawPath(m.extractPath(start, start + len), glow);
        if (start + len > m.length) {
          canvas.drawPath(m.extractPath(0, start + len - m.length), glow);
        }
      }
    }
    canvas.restore();
  }

  /// Crown to chin, with ears: wide at the temples, narrowing to the jaw.
  static Path _head(double cx, double top, double w, double h) {
    final r = w / 2;
    final p = Path()..moveTo(cx, top);
    // Right side: crown, temple, ear, jaw, chin.
    p.cubicTo(
      cx + r * 0.58,
      top,
      cx + r,
      top + h * 0.17,
      cx + r,
      top + h * 0.4,
    );
    p.cubicTo(
      cx + r * 1.13,
      top + h * 0.42,
      cx + r * 1.13,
      top + h * 0.56,
      cx + r * 0.99,
      top + h * 0.58,
    );
    p.cubicTo(
      cx + r * 0.95,
      top + h * 0.72,
      cx + r * 0.72,
      top + h * 0.88,
      cx + r * 0.42,
      top + h * 0.96,
    );
    p.quadraticBezierTo(cx, top + h * 1.02, cx - r * 0.42, top + h * 0.96);
    // Left side, mirrored back up to the crown.
    p.cubicTo(
      cx - r * 0.72,
      top + h * 0.88,
      cx - r * 0.95,
      top + h * 0.72,
      cx - r * 0.99,
      top + h * 0.58,
    );
    p.cubicTo(
      cx - r * 1.13,
      top + h * 0.56,
      cx - r * 1.13,
      top + h * 0.42,
      cx - r,
      top + h * 0.4,
    );
    p.cubicTo(cx - r, top + h * 0.17, cx - r * 0.58, top, cx, top);
    return p..close();
  }

  /// Neck and the line of the shoulders, open at the bottom.
  static Path _body(double cx, double top, double w, double h) {
    final r = w / 2;
    final p = Path();
    for (final side in const [1.0, -1.0]) {
      p
        ..moveTo(cx + side * r * 0.4, top + h * 0.95)
        ..lineTo(cx + side * r * 0.44, top + h * 1.12)
        ..quadraticBezierTo(
          cx + side * r * 0.62,
          top + h * 1.2,
          cx + side * r * 1.75,
          top + h * 1.3,
        )
        ..quadraticBezierTo(
          cx + side * r * 2.3,
          top + h * 1.38,
          cx + side * r * 2.45,
          top + h * 1.75,
        );
    }
    return p;
  }

  @override
  bool shouldRepaint(_HuskPainter old) =>
      old.t != t ||
      old.intent != intent ||
      old.color != color ||
      old.ready != ready ||
      old.moving != moving;
}
