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
          builder: (_, hint, _) => CustomPaint(
            painter: _GuidePainter(
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
                    text: _count != null
                        ? 'Hold still.'
                        : hint.guidance?.text,
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
          border: Border.all(
            color: ready ? accent : AppColors.cream,
            width: 3,
          ),
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

/// A faint oval and eye line showing where the head should sit. Sized from
/// the chosen photo type, so Fashion asks for a wider frame than Dating.
class _GuidePainter extends CustomPainter {
  _GuidePainter({
    required this.intent,
    required this.color,
    required this.ready,
  });
  final SelfieIntent intent;
  final Color color;
  final bool ready;

  @override
  void paint(Canvas canvas, Size size) {
    final faceH = (intent.faceMin + intent.faceMax) / 2;
    final ovalH = size.height * faceH * 1.3;
    final ovalW = ovalH * 0.78;
    final headroom = (intent.headroomMin + intent.headroomMax) / 2;
    final cy = size.height * headroom + ovalH / 2;
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, cy),
      width: ovalW,
      height: ovalH,
    );
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = ready ? 2 : 1.4
      ..color = color.withValues(alpha: ready ? 0.9 : 0.32);
    canvas.drawOval(rect, stroke);

    // Eye line: short ticks either side of the oval, a third of the way down.
    final y = rect.top + ovalH * 0.38;
    final tick = Paint()
      ..strokeWidth = 1.2
      ..color = color.withValues(alpha: 0.28);
    canvas.drawLine(Offset(rect.left - 26, y), Offset(rect.left - 6, y), tick);
    canvas.drawLine(
      Offset(rect.right + 6, y),
      Offset(rect.right + 26, y),
      tick,
    );
  }

  @override
  bool shouldRepaint(_GuidePainter old) =>
      old.intent != intent || old.color != color || old.ready != ready;
}
