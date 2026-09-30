import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/motion.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/tap.dart';
import '../session/session_controller.dart';
import 'onboarding_steps.dart';
import 'onboarding_widgets.dart';

enum _Step {
  welcome,
  statement,
  intro,
  eras,
  colours,
  clothes,
  acc,
  brands,
  fit,
  name,
  build,
  ticket,
  join,
}

/// The whole pre-sign-in journey (`Drip Onboarding.dc.html`) as one screen:
/// welcome → the hard truth → what Drip is → eras and genres → colours →
/// pieces, accessories, labels → fit and budget → name → "building" → the
/// Drip ticket → Google sign-in. Picks are saved on the device as they're made
/// and sent to the account once the user signs in.
class OnboardingFlow extends ConsumerStatefulWidget {
  const OnboardingFlow({super.key});

  @override
  ConsumerState<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends ConsumerState<OnboardingFlow> {
  static const _steps = _Step.values;

  int _step = 0;
  int _dir = 1;
  double _prog = 0;
  Color _glow = AppColors.red;
  String? _toast;
  bool _signingIn = false;

  Timer? _buildTimer;
  Timer? _toastTimer;
  Timer? _resumeTimer;
  late final AppLifecycleListener _lifecycle;
  late final TextEditingController _name;

  _Step get _id => _steps[_step];

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: ref.read(onboardingProvider).name);
    // Back from Google's page without a session (closed, or cancelled): give
    // the deep link a moment to land, then let the user try again.
    _lifecycle = AppLifecycleListener(
      onResume: () {
        if (!_signingIn) return;
        _resumeTimer?.cancel();
        _resumeTimer = Timer(const Duration(seconds: 3), () {
          if (mounted && !ref.read(sessionProvider).signedIn) {
            setState(() => _signingIn = false);
          }
        });
      },
    );
  }

  @override
  void dispose() {
    _buildTimer?.cancel();
    _toastTimer?.cancel();
    _resumeTimer?.cancel();
    _lifecycle.dispose();
    _name.dispose();
    super.dispose();
  }

  // ───────────────────────────────────────────────────────────── navigation

  void _go(int n) {
    _buildTimer?.cancel();
    setState(() {
      _dir = n >= _step ? 1 : -1;
      _step = n.clamp(0, _steps.length - 1);
      _prog = 0;
    });
    if (_id == _Step.build) {
      _buildTimer = Timer.periodic(const Duration(milliseconds: 45), (t) {
        final p = _prog + 1.7;
        if (p >= 100) {
          t.cancel();
          setState(() => _prog = 100);
          Timer(const Duration(milliseconds: 650), () {
            if (mounted && _id == _Step.build) _go(_step + 1);
          });
        } else {
          setState(() => _prog = p);
        }
      });
    }
  }

  void _back() {
    if (_step > 0 && _id != _Step.build) _go(_step - 1);
  }

  void _say(String text) {
    _toastTimer?.cancel();
    setState(() => _toast = text);
    _toastTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  // ────────────────────────────────────────────────────────────── actions

  Future<void> _primary() async {
    final picks = ref.read(onboardingProvider);
    switch (_id) {
      case _Step.eras when picks.moodIds.isEmpty:
        return _say('Pick at least one era');
      case _Step.colours when picks.paletteIds.isEmpty:
        return _say('Wear at least one colour');
      case _Step.name when picks.name.trim().length < 2:
        return _say('Add your name first');
      case _Step.join:
        return _google(picks);
      default:
        _go(_step + 1);
    }
  }

  Future<void> _google(OnboardingState picks) async {
    if (picks.name.trim().length < 2) return _say('Add your name first');
    Haptics.commit();
    setState(() => _signingIn = true);
    final session = ref.read(sessionProvider.notifier);
    try {
      await session.completeOnboarding();
      await session.signInWithGoogle();
      // The session arrives through the deep link; the router then moves on.
    } catch (_) {
      if (!mounted) return;
      setState(() => _signingIn = false);
      _say("Couldn't open Google sign-in. Try again.");
    }
  }

  void _alt() {
    if (_id == _Step.welcome) {
      context.push('/signin');
    } else {
      _say('Phone sign-in · after beta');
    }
  }

  // ────────────────────────────────────────────────────────────────── view

  static const _headers = {
    _Step.intro: (
      'The core mechanics',
      'What is Drip?',
      'Not another feed. A stylist that lives in your pocket.',
    ),
    _Step.eras: (
      'Establish your era',
      'Your vibe',
      'Stop dressing for the algorithm. Pick what you’d actually wear.',
    ),
    _Step.colours: (
      'Visual personalization',
      'Colour theory',
      'Black goes with everything. Confidence goes with more.',
    ),
    _Step.clothes: (
      'What’s in the closet',
      'Your pieces',
      'A closet is just a personality on hangers.',
    ),
    _Step.acc: (
      'The finishing touches',
      'Accessories',
      'The fit is the sentence. Accessories are the punctuation.',
    ),
    _Step.brands: (
      'Where your fits come from',
      'Labels',
      'Some of the labels we build your fits from. Tap the ones you wear.',
    ),
    _Step.fit: (
      'Last calibration',
      'Fit & budget',
      'Fit is the flex. Nobody wears your size but you.',
    ),
  };

  Widget _body(OnboardingState picks) => switch (_id) {
    _Step.welcome => const WelcomeStep(),
    _Step.statement => const StatementStep(),
    _Step.intro => const IntroStep(),
    _Step.eras => ErasStep(onGlow: (c) => setState(() => _glow = c)),
    _Step.colours => ColoursStep(onGlow: (c) => setState(() => _glow = c)),
    _Step.clothes => const ClothesStep(),
    _Step.acc => const AccessoriesStep(),
    _Step.brands => const BrandsStep(),
    _Step.fit => const FitStep(),
    _Step.name => NameStep(
      controller: _name,
      handle: TicketInfo.handleFor(picks.name),
      onChanged: (v) {
        ref.read(onboardingProvider.notifier).setName(v);
      },
    ),
    _Step.build => BuildStep(
      progress: _prog,
      colours: [for (final c in TicketInfo(picks).colours) Color(c.$3)],
    ),
    _Step.ticket => const TicketStep(),
    _Step.join => JoinStep(
      name: picks.name,
      handle: TicketInfo.handleFor(picks.name),
    ),
  };

  String _label(OnboardingState p) => switch (_id) {
    _Step.welcome => 'GET STARTED →',
    _Step.statement => 'HELP ME →',
    _Step.intro => 'UNDERSTOOD. NEXT →',
    _Step.eras =>
      p.moodIds.length + p.genres.length > 0
          ? 'LOCK IN ${p.moodIds.length + p.genres.length} VIBES →'
          : 'CONFIRM VIBE →',
    _Step.colours => 'CALIBRATE SPECTRUM →',
    _Step.clothes =>
      p.clothes.isNotEmpty
          ? 'SAVE ${p.clothes.length} PIECES →'
          : 'SAVE PIECES →',
    _Step.acc =>
      p.accessories.isNotEmpty
          ? 'STACK ${p.accessories.length} →'
          : 'ACCESSORISE →',
    _Step.brands =>
      p.brands.isNotEmpty
          ? 'SAVE ${p.brands.length} LABELS →'
          : 'SAVE LABELS →',
    _Step.fit => 'BUILD MY DRIP →',
    _Step.name => 'PRINT MY TICKET →',
    _Step.build => '',
    _Step.ticket => 'CLAIM YOUR TICKET →',
    _Step.join => 'CONTINUE WITH GOOGLE',
  };

  @override
  Widget build(BuildContext context) {
    final picks = ref.watch(onboardingProvider);
    final id = _id;
    final question = _headers.containsKey(id);
    final tuned =
        (picks.moodIds.length * 9 +
                picks.genres.length * 4 +
                picks.paletteIds.length * 5 +
                picks.clothes.length * 2 +
                picks.accessories.length * 2 +
                picks.brands.length * 3 +
                (_step >= _Step.fit.index ? 6 : 0))
            .clamp(0, 100);
    final disabled =
        (id == _Step.eras && picks.moodIds.isEmpty) ||
        (id == _Step.colours && picks.paletteIds.isEmpty);
    final showDots = id != _Step.welcome;
    final dots = [
      for (final s in _steps)
        if (s != _Step.welcome && s != _Step.build) s,
    ];

    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: AppColors.base,
        resizeToAvoidBottomInset: true,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // The glow follows the last thing picked.
            Positioned(
              top: -140,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Center(
                  child: TweenAnimationBuilder<Color?>(
                    tween: ColorTween(begin: _glow, end: _glow),
                    duration: const Duration(milliseconds: 900),
                    builder: (context, c, _) => Container(
                      width: 460,
                      height: 460,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            (c ?? _glow).withValues(alpha: 0.30),
                            (c ?? _glow).withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (id == _Step.welcome || id == _Step.join)
              const Positioned.fill(child: IgnorePointer(child: _DotGrid())),
            SafeArea(
              child: Column(
                children: [
                  _TopRow(
                    canGoBack: _step > 0 && id != _Step.build,
                    onBack: _back,
                    tuned: question && id != _Step.intro ? tuned : null,
                  ),
                  if (question)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 2, 24, 0),
                      child: _Header(_headers[id]!, key: ValueKey(id)),
                    ),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 420),
                      switchInCurve: Motion.out,
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: Offset(0.07 * _dir, 0),
                            end: Offset.zero,
                          ).animate(anim),
                          child: child,
                        ),
                      ),
                      child: LayoutBuilder(
                        key: ValueKey(id),
                        builder: (context, box) => SingleChildScrollView(
                          physics: const ClampingScrollPhysics(),
                          padding: EdgeInsets.fromLTRB(
                            24,
                            question ? 20 : 8,
                            24,
                            24,
                          ),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: box.maxHeight - (question ? 44 : 32),
                            ),
                            child: _body(picks),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (id != _Step.build)
                    _Footer(
                      dots: showDots ? dots.indexOf(id) : -1,
                      dotCount: dots.length,
                      label: _label(picks),
                      disabled: disabled,
                      loading: _signingIn,
                      onPrimary: _signingIn ? () {} : _primary,
                      altLabel: id == _Step.welcome
                          ? 'I ALREADY HAVE AN ACCOUNT'
                          : id == _Step.join
                          ? 'CONTINUE WITH PHONE'
                          : null,
                      onAlt: _alt,
                      onSkip:
                          const {
                            _Step.clothes,
                            _Step.acc,
                            _Step.brands,
                            _Step.fit,
                          }.contains(id)
                          ? () => _go(_step + 1)
                          : null,
                    ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 104,
              child: IgnorePointer(
                child: AnimatedOpacity(
                  opacity: _toast == null ? 0 : 1,
                  duration: const Duration(milliseconds: 300),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.elevated,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _toast ?? '',
                        style: AppText.mono(11, letterSpacing: 1),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopRow extends StatelessWidget {
  const _TopRow({
    required this.canGoBack,
    required this.onBack,
    required this.tuned,
  });
  final bool canGoBack;
  final VoidCallback onBack;
  final int? tuned;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          children: [
            SizedBox(
              width: 44,
              height: 44,
              child: canGoBack
                  ? Tap(
                      onTap: onBack,
                      semanticLabel: 'Back',
                      child: Center(
                        child: Text(
                          '←',
                          style: AppText.inter(18, color: AppColors.muted),
                        ),
                      ),
                    )
                  : null,
            ),
            const Spacer(),
            if (tuned != null)
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Row(
                  children: [
                    Text(
                      'FEED TUNED',
                      style: AppText.mono(
                        10,
                        color: AppColors.muted,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 64,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.elevated,
                        borderRadius: BorderRadius.circular(2),
                      ),
                      alignment: Alignment.centerLeft,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 600),
                        curve: Motion.out,
                        width: 64 * tuned! / 100,
                        decoration: BoxDecoration(
                          color: AppColors.cyan,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 38,
                      child: Text(
                        '$tuned%',
                        textAlign: TextAlign.right,
                        style: AppText.mono(10, color: AppColors.cyan),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.h, {super.key});
  final (String, String, String) h;

  @override
  Widget build(BuildContext context) {
    return Enter(
      dy: 16,
      duration: const Duration(milliseconds: 500),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Eyebrow(h.$1),
          const SizedBox(height: 8),
          Text(h.$2.toUpperCase(), style: AppText.display(28, lineHeight: 34)),
          const SizedBox(height: 10),
          Text(
            h.$3,
            style: AppText.manrope(15, weight: FontWeight.w800, lineHeight: 20),
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.dots,
    required this.dotCount,
    required this.label,
    required this.disabled,
    required this.loading,
    required this.onPrimary,
    required this.onAlt,
    this.altLabel,
    this.onSkip,
  });

  /// Index of the current dot, or -1 to hide the row (the welcome step).
  final int dots;
  final int dotCount;
  final String label;
  final bool disabled;
  final bool loading;
  final VoidCallback onPrimary;
  final VoidCallback onAlt;
  final String? altLabel;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 30,
            child: dots < 0
                ? null
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < dotCount; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Motion.out,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: i == dots ? 24 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: i == dots
                                ? AppColors.red
                                : AppColors.elevated,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                    ],
                  ),
          ),
          Tap(
            onTap: onPrimary,
            scale: 0.97,
            semanticLabel: label,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: disabled
                    ? AppColors.elevated.withValues(alpha: 0.6)
                    : AppColors.red,
                borderRadius: BorderRadius.circular(24),
              ),
              child: loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.base,
                      ),
                    )
                  : Text(
                      label,
                      style: AppText.mono(
                        12,
                        weight: FontWeight.w500,
                        letterSpacing: 1.5,
                        color: disabled ? AppColors.muted : AppColors.base,
                      ),
                    ),
            ),
          ),
          if (altLabel != null) ...[
            const SizedBox(height: 12),
            Tap(
              onTap: onAlt,
              scale: 0.97,
              semanticLabel: altLabel,
              child: Container(
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppColors.cream.withValues(alpha: 0.22),
                  ),
                ),
                child: Text(
                  altLabel!,
                  style: AppText.mono(
                    12,
                    weight: FontWeight.w500,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
          ],
          if (onSkip != null)
            Tap(
              onTap: onSkip,
              semanticLabel: 'Skip for now',
              child: Container(
                height: 32,
                alignment: Alignment.center,
                child: Text(
                  'SKIP FOR NOW',
                  style: AppText.mono(
                    10,
                    color: AppColors.muted,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A faint dot grid that fades out toward the bottom (welcome and join).
class _DotGrid extends StatelessWidget {
  const _DotGrid();

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) => const RadialGradient(
        center: Alignment(0, -0.45),
        radius: 0.85,
        colors: [Colors.white, Colors.transparent],
      ).createShader(rect),
      child: CustomPaint(painter: _DotPainter()),
    );
  }
}

class _DotPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = AppColors.cream.withValues(alpha: 0.12);
    for (var y = 0.0; y < size.height; y += 22) {
      for (var x = 0.0; x < size.width; x += 22) {
        canvas.drawCircle(Offset(x, y), 0.6, p);
      }
    }
  }

  @override
  bool shouldRepaint(_DotPainter old) => false;
}
