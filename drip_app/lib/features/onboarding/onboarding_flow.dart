import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/motion.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/tap.dart';
import '../../core/widgets/top_bar.dart';
import '../../data/providers.dart';
import '../session/session_controller.dart';
import 'local_selfie.dart';
import 'onboarding_data.dart';
import 'onboarding_steps.dart';
import 'onboarding_widgets.dart';

/// The onboarding, in the order a stylist would ask: who we're dressing,
/// what they wear, the colours they reach for, where they're going, the
/// labels they trust, then (if they like) their face on the ticket. The
/// name prints the ticket; one tap with Google saves it.
enum _Step {
  welcome,
  dressFor,
  eras,
  colours,
  labels,
  selfie,
  name,
  build,
  ticket,
}

/// Steps saved by earlier versions of the flow, mapped onto this one so a
/// relaunch mid-onboarding still resumes close to where the user was.
const _legacySteps = {
  'statement': _Step.dressFor,
  'intro': _Step.dressFor,
  'clothes': _Step.labels,
  'acc': _Step.labels,
  // Occasions left onboarding (they're picked in Your style now).
  'occasions': _Step.labels,
  'brands': _Step.labels,
  'fit': _Step.selfie,
  'join': _Step.ticket,
};

/// The whole pre-sign-in journey as one screen. Picks are saved on the device
/// as they're made (temporary onboarding state) and reach the account only
/// when the user saves their Drip; the selfie never does (local media). The
/// step reached is saved too, so a relaunch picks up where the user left off.
class OnboardingFlow extends ConsumerStatefulWidget {
  const OnboardingFlow({super.key});

  @override
  ConsumerState<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends ConsumerState<OnboardingFlow> {
  static const _steps = _Step.values;

  int _step = 0;
  int _dir = 1;

  /// The step before this one: arriving at the ticket straight from the
  /// build beat, the printed ticket stays where it is.
  _Step? _from;
  double _prog = 0;
  Color _glow = AppColors.red;
  String? _toast;
  bool _signingIn = false;

  /// The camera or gallery is open.
  bool _picking = false;

  /// True for a beat after the step changes: taps landing mid-transition are
  /// dropped so a quick double-tap can't skip a screen.
  bool _moving = false;

  Timer? _buildTimer;
  Timer? _toastTimer;
  Timer? _resumeTimer;
  Timer? _movingTimer;
  Timer? _advanceTimer;
  late final AppLifecycleListener _lifecycle;
  late final TextEditingController _name;

  _Step get _id => _steps[_step];

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: ref.read(onboardingProvider).name);
    // Resume where the user left off. The "building" beat isn't a place to
    // land on, so a relaunch there reopens the name step instead.
    final saved = ref.read(localStoreProvider).onboardingStep;
    final at =
        _Step.values.where((s) => s.name == saved).firstOrNull ??
        _legacySteps[saved];
    if (at != null) _step = (at == _Step.build ? _Step.name : at).index;
    // Never resume past a required answer that's missing (picks cleared or
    // unreadable): land on that question instead.
    final picks = ref.read(onboardingProvider);
    for (final (step, ok) in [
      (_Step.dressFor, picks.gender != null),
      (_Step.eras, picks.moodIds.isNotEmpty),
      (_Step.colours, picks.paletteIds.isNotEmpty),
    ]) {
      if (!ok && _step > step.index) {
        _step = step.index;
        break;
      }
    }
    for (final e in OnboardingData.eras) {
      if (picks.moodIds.contains(e.id)) {
        _glow = e.glow;
        break;
      }
    }
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
    _movingTimer?.cancel();
    _advanceTimer?.cancel();
    _lifecycle.dispose();
    _name.dispose();
    super.dispose();
  }

  // ───────────────────────────────────────────────────────────── navigation

  /// Holds off further navigation until the current move has settled.
  void _lock() {
    _moving = true;
    _movingTimer?.cancel();
    _movingTimer = Timer(_settle, () => _moving = false);
  }

  void _go(int n) {
    _buildTimer?.cancel();
    _toastTimer?.cancel();
    _advanceTimer?.cancel();
    _lock();
    setState(() {
      _dir = n >= _step ? 1 : -1;
      _from = _id;
      _step = n.clamp(0, _steps.length - 1);
      _prog = 0;
      _toast = null;
      // Leaving the last step while Google is open: the wait belongs to that
      // step's button, not the next one's.
      _signingIn = false;
    });
    if (_id != _Step.build) {
      unawaited(ref.read(localStoreProvider).setOnboardingStep(_id.name));
    }
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

  /// Back one step. The "building" beat is skipped on the way back: it only
  /// plays going forward, so back from the ticket lands on the name.
  void _back() {
    if (_moving || _step == 0 || _id == _Step.build) return;
    final to = _step - 1;
    _go(_steps[to] == _Step.build ? to - 1 : to);
  }

  /// A short note in the footer, right above the button it's about.
  void _say(String text) {
    _toastTimer?.cancel();
    Haptics.tick();
    setState(() => _toast = text);
    _toastTimer = Timer(const Duration(milliseconds: 2400), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  /// A name is two letters or more (in any script), not just punctuation.
  static bool _named(OnboardingState p) =>
      _letter.allMatches(p.name).length >= 2;
  static final _letter = RegExp(r'\p{L}', unicode: true);

  // ────────────────────────────────────────────────────────────── actions

  /// "Dress me for" is one tap: the pick shows, then the flow moves on by
  /// itself. Changing the pick before it does restarts the beat.
  void _dressFor(String gender) {
    ref.read(onboardingProvider.notifier).setGender(gender);
    _advanceTimer?.cancel();
    _advanceTimer = Timer(const Duration(milliseconds: 420), () {
      if (mounted && _id == _Step.dressFor && !_moving) _go(_step + 1);
    });
  }

  Future<void> _primary() async {
    // A tap landing while the step is still changing was meant for the old
    // step's button: drop it, so one action never runs twice.
    if (_moving || _picking) return;
    final picks = ref.read(onboardingProvider);
    switch (_id) {
      case _Step.dressFor when picks.gender == null:
        return _say('Tap the one that fits');
      case _Step.eras when picks.moodIds.isEmpty:
        return _say('Tap an era, or hit Surprise me');
      case _Step.colours when picks.paletteIds.isEmpty:
        return _say('Tap a colour above to add it');
      case _Step.selfie when ref.read(localSelfieProvider).value == null:
        return _pickSelfie(ImageSource.camera);
      case _Step.name when !_named(picks):
        return _say(
          picks.name.trim().isEmpty
              ? 'Type your first name above'
              : 'Your name needs two letters or more',
        );
      case _Step.ticket:
        return _google(picks);
      default:
        _go(_step + 1);
    }
  }

  static const _settle = Duration(milliseconds: 350);

  /// Camera or gallery. The photo stays on this phone; cancelling changes
  /// nothing; a source that won't open says what to try instead.
  Future<void> _pickSelfie(ImageSource source) async {
    if (_picking || _moving) return;
    setState(() => _picking = true);
    try {
      final picked = await ref.read(localSelfieProvider.notifier).pick(source);
      if (picked) Haptics.commit();
    } on SelfieUnavailable catch (e) {
      if (mounted) _say(e.message);
    } catch (_) {
      if (mounted) _say('Couldn’t use that photo. Try another one');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _google(OnboardingState picks) async {
    // The ticket needs a name; take the user to the field rather than
    // leaving them stuck here (possible after a relaunch).
    if (!_named(picks)) {
      _go(_Step.name.index);
      return _say('Add your name to finish your ticket');
    }
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

  /// The secondary button: "I already have an account" on the welcome,
  /// the gallery (or a retake) on the selfie step.
  void _alt() {
    if (_moving) return;
    switch (_id) {
      case _Step.welcome:
        _lock();
        context.push('/signin');
      case _Step.selfie:
        _pickSelfie(
          ref.read(localSelfieProvider).value == null
              ? ImageSource.gallery
              : ImageSource.camera,
        );
      default:
    }
  }

  // ────────────────────────────────────────────────────────────────── view

  /// The steps that ask something (the progress dots count these).
  static const _asks = [
    _Step.dressFor,
    _Step.eras,
    _Step.colours,
    _Step.labels,
    _Step.selfie,
    _Step.name,
    _Step.ticket,
  ];

  /// Eyebrow (why this is asked), title, and the one line that says what to
  /// do. No "step 4 of 9": the dots and the tuning meter carry progress.
  static const _headers = {
    _Step.dressFor: (
      'So your feed fits',
      'Dress me for',
      'Whose fits lead your Scroll? You can change it any time.',
    ),
    _Step.eras: (
      'Your Scroll starts here',
      'Your vibe',
      'Stop dressing for the algorithm. Pick every era you’d actually wear.',
    ),
    _Step.colours: (
      'Taylor styles around these',
      'Colour theory',
      'Tap every colour you wear. Confidence goes with more.',
    ),
    _Step.labels: (
      'Optional · fits from labels you trust',
      'Labels',
      'Tap the ones you wear, then what you usually spend.',
    ),
    _Step.selfie: (
      'Optional · stays on this phone',
      'See yourself in the fit',
      'Add a selfie and your Drip ticket wears it. It never leaves this '
          'phone.',
    ),
  };

  static String _n(int n, String one, String many) =>
      '$n ${n == 1 ? one : many}';

  Widget _body(OnboardingState picks) => switch (_id) {
    _Step.welcome => const WelcomeStep(),
    _Step.dressFor => DressForStep(onPick: _dressFor),
    _Step.eras => ErasStep(onGlow: (c) => setState(() => _glow = c)),
    _Step.colours => ColoursStep(onGlow: (c) => setState(() => _glow = c)),
    _Step.labels => const LabelsStep(),
    _Step.selfie => SelfieStep(busy: _picking),
    _Step.name => NameStep(
      controller: _name,
      handle: TicketInfo.handleFor(picks.name),
      onChanged: (v) {
        ref.read(onboardingProvider.notifier).setName(v);
      },
      onSubmitted: _primary,
    ),
    _Step.build => BuildStep(progress: _prog),
    _Step.ticket => TicketStep(printed: _from == _Step.build),
  };

  /// The button names what it will do; while a requirement is unmet it says
  /// what's needed instead, and on an optional step with nothing picked it's
  /// an honest "skip".
  String _label(OnboardingState p, bool hasSelfie) => switch (_id) {
    _Step.welcome => 'GET STARTED →',
    _Step.dressFor when p.gender == null => 'PICK ONE TO CONTINUE',
    _Step.dressFor => 'CONTINUE →',
    _Step.eras when p.moodIds.isEmpty => 'PICK AN ERA TO CONTINUE',
    _Step.eras =>
      'LOCK IN ${_n(p.moodIds.length + p.genres.length, 'VIBE', 'VIBES')} →',
    _Step.colours when p.paletteIds.isEmpty => 'PICK A COLOUR TO CONTINUE',
    _Step.colours => 'SAVE ${_n(p.paletteIds.length, 'COLOUR', 'COLOURS')} →',
    _Step.labels when p.brands.isEmpty => 'CONTINUE →',
    _Step.labels => 'SAVE ${_n(p.brands.length, 'LABEL', 'LABELS')} →',
    _Step.selfie when !hasSelfie => 'TAKE A SELFIE',
    _Step.selfie => 'LOOKS GOOD →',
    _Step.name when !_named(p) => 'ADD YOUR NAME TO CONTINUE',
    _Step.name => 'PRINT MY TICKET →',
    _Step.build => '',
    _Step.ticket => 'SAVE MY DRIP WITH GOOGLE',
  };

  @override
  Widget build(BuildContext context) {
    final picks = ref.watch(onboardingProvider);
    final hasSelfie = ref.watch(localSelfieProvider).value != null;
    final id = _id;
    final header = _headers[id];
    final question = header != null;
    final tuned =
        ((picks.gender != null ? 8 : 0) +
                picks.moodIds.length * 9 +
                picks.genres.length * 4 +
                picks.paletteIds.length * 5 +
                picks.occasions.length * 3 +
                picks.brands.length * 3 +
                (hasSelfie ? 6 : 0) +
                (_step > _Step.labels.index ? 6 : 0))
            .clamp(0, 100);
    final disabled =
        (id == _Step.dressFor && picks.gender == null) ||
        (id == _Step.eras && picks.moodIds.isEmpty) ||
        (id == _Step.colours && picks.paletteIds.isEmpty) ||
        (id == _Step.name && !_named(picks));
    final reduced = Motion.reduced(context);
    // Built here, not inside the LayoutBuilder below: that builder runs again
    // during the transition, and would otherwise paint the *new* step on the
    // outgoing page too.
    final body = _body(picks);

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
            if (id == _Step.welcome || id == _Step.ticket)
              const Positioned.fill(child: IgnorePointer(child: _DotGrid())),
            SafeArea(
              child: Column(
                children: [
                  _TopRow(
                    canGoBack: _step > 0 && id != _Step.build,
                    onBack: _back,
                    tuned: id == _Step.build
                        ? (tuned + (100 - tuned) * _prog / 100).round()
                        : question
                        ? tuned
                        : null,
                  ),
                  // The pinned header cross-fades with the step (the outgoing
                  // one clears first, so the two never read on top of each
                  // other).
                  AnimatedSwitcher(
                    duration: Motion.content,
                    switchInCurve: Motion.out,
                    switchOutCurve: const Interval(0.5, 1),
                    layoutBuilder: (current, previous) => Stack(
                      alignment: Alignment.topLeft,
                      children: [...previous, ?current],
                    ),
                    child: question
                        ? Padding(
                            key: ValueKey(id),
                            padding: const EdgeInsets.fromLTRB(24, 2, 24, 0),
                            child: _Header(
                              eyebrow: header.$1,
                              title: header.$2,
                              subtitle: header.$3,
                            ),
                          )
                        : const SizedBox(
                            key: ValueKey('no-header'),
                            width: double.infinity,
                          ),
                  ),
                  Expanded(
                    // Steps travel like pages: forward pushes the old one out
                    // to the left as the new one arrives from the right (and
                    // back the other way). Under reduced motion, a fade.
                    child: AnimatedSwitcher(
                      duration: Motion.content,
                      switchInCurve: Motion.out,
                      switchOutCurve: const Interval(0.4, 1),
                      // Each page fills the area. A scroll view sizes itself
                      // to its content, so loose constraints let a narrow
                      // step drift off the 24px gutter.
                      layoutBuilder: (current, previous) => Stack(
                        fit: StackFit.expand,
                        children: [...previous, ?current],
                      ),
                      transitionBuilder: (child, anim) {
                        if (reduced) {
                          return FadeTransition(opacity: anim, child: child);
                        }
                        if (id == _Step.ticket && _from == _Step.build) {
                          return FadeTransition(opacity: anim, child: child);
                        }
                        final incoming = child.key == ValueKey(id);
                        return FadeTransition(
                          opacity: anim,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: Offset(
                                (incoming ? 0.07 : -0.07) * _dir,
                                0,
                              ),
                              end: Offset.zero,
                            ).animate(anim),
                            child: child,
                          ),
                        );
                      },
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
                            child: body,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (id != _Step.build)
                    _Footer(
                      dots: _asks.indexOf(id),
                      dotCount: _asks.length,
                      label: _label(picks, hasSelfie),
                      disabled: disabled,
                      loading: _signingIn || (_picking && id == _Step.selfie),
                      onPrimary: _signingIn ? () {} : _primary,
                      // While Google is open, say what to do; otherwise any
                      // note about the button replaces the dots above it.
                      message:
                          _toast ??
                          (_signingIn
                              ? 'Finish signing in with Google, then come '
                                    'back here'
                              : null),
                      altLabel: switch (id) {
                        _Step.welcome => 'I ALREADY HAVE AN ACCOUNT',
                        _Step.selfie when !hasSelfie => 'CHOOSE FROM GALLERY',
                        _Step.selfie => 'RETAKE',
                        _ => null,
                      },
                      onAlt: _alt,
                      // Skipping the selfie is always there, but quiet.
                      skipLabel: id == _Step.selfie && !hasSelfie
                          ? 'Skip for now'
                          : null,
                      onSkip: () {
                        if (!_moving && !_picking) _go(_step + 1);
                      },
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
              child: AnimatedOpacity(
                opacity: canGoBack ? 1 : 0,
                duration: Motion.quick,
                child: canGoBack ? BackGlyph(onTap: onBack) : null,
              ),
            ),
            const Spacer(),
            if (tuned != null)
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Semantics(
                  label: 'Feed tuned $tuned percent',
                  child: ExcludeSemantics(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(end: tuned!.toDouble()),
                      duration: Motion.dur(context, Motion.content),
                      curve: Motion.out,
                      builder: (context, v, _) => Row(
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
                            child: Container(
                              width: 64 * v / 100,
                              decoration: BoxDecoration(
                                color: AppColors.cyan,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 38,
                            child: Text(
                              '${v.round()}%',
                              textAlign: TextAlign.right,
                              style: AppText.mono(10, color: AppColors.cyan),
                            ),
                          ),
                        ],
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

class _Header extends StatelessWidget {
  const _Header({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
  });
  final String eyebrow;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Enter(
      dy: 12,
      duration: Motion.content,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Eyebrow(eyebrow),
          const SizedBox(height: 8),
          Semantics(
            header: true,
            child: Text(
              title.toUpperCase(),
              style: AppText.display(28, lineHeight: 34),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
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
    this.message,
    this.altLabel,
    this.skipLabel,
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

  /// A note about the button (a requirement, a failure, what to do next).
  /// It takes the dots' place, right where the eye already is.
  final String? message;
  final String? altLabel;

  /// A quiet way past an optional step whose main button does something
  /// (the selfie): full-size to tap, light to look at.
  final String? skipLabel;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    final spoken = label.replaceAll('→', '').trim();
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSize(
            duration: Motion.quick,
            curve: Motion.out,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 30),
              child: AnimatedSwitcher(
                duration: Motion.quick,
                child: message != null
                    ? Padding(
                        key: ValueKey(message),
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            message!.toUpperCase(),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            style: AppText.mono(
                              11,
                              letterSpacing: 1,
                              lineHeight: 16,
                            ),
                          ),
                        ),
                      )
                    : dots < 0
                    ? const SizedBox(key: ValueKey('none'), height: 30)
                    : Semantics(
                        key: const ValueKey('dots'),
                        label: 'Screen ${dots + 1} of $dotCount',
                        child: ExcludeSemantics(
                          child: SizedBox(
                            height: 30,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                for (var i = 0; i < dotCount; i++)
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Motion.out,
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 3,
                                    ),
                                    width: i == dots ? 24 : 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: i == dots
                                          ? AppColors.red
                                          : i < dots
                                          ? AppColors.red.withValues(
                                              alpha: 0.35,
                                            )
                                          : AppColors.elevated,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          ),
          Tap(
            onTap: onPrimary,
            scale: 0.97,
            semanticLabel: loading ? 'Opening Google sign-in' : spoken,
            child: ExcludeSemantics(
              child: AnimatedContainer(
                duration: Motion.quick,
                height: 52,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: disabled
                      ? AppColors.elevated.withValues(alpha: 0.6)
                      : AppColors.red,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: AnimatedSwitcher(
                  duration: Motion.quick,
                  child: loading
                      ? const SizedBox(
                          key: ValueKey('loading'),
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.base,
                          ),
                        )
                      : Text(
                          label,
                          key: ValueKey(label),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.mono(
                            12,
                            weight: FontWeight.w500,
                            letterSpacing: 1.5,
                            color: disabled ? AppColors.muted : AppColors.base,
                          ),
                        ),
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
              child: ExcludeSemantics(
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
            ),
          ],
          if (skipLabel != null)
            Tap(
              onTap: onSkip,
              semanticLabel: skipLabel,
              child: Container(
                height: 44,
                alignment: Alignment.center,
                child: Text(
                  skipLabel!.toUpperCase(),
                  style: AppText.mono(
                    11,
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
