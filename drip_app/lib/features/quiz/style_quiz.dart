import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/motion.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/overlays.dart';
import '../../core/widgets/tap.dart';
import '../../data/api/api_client.dart';
import '../../data/providers.dart';
import '../onboarding/onboarding_widgets.dart';

/// One answer on a quiz question.
class QuizOption {
  const QuizOption(this.id, this.emoji, this.label);
  final String id;
  final String emoji;
  final String label;
}

/// One multiple-choice question. [why] says in a line what the answer
/// changes, so it never feels like a survey for its own sake.
class QuizQuestion {
  const QuizQuestion(this.id, this.question, this.why, this.options);
  final String id;
  final String question;
  final String why;
  final List<QuizOption> options;
}

/// The style quiz: ten taps that tell the feed what the onboarding can't:
/// what a whole outfit is worth to the user, what makes them buy, what
/// they're dressing for next, how bold to go. Saved on the account as
/// `onboardingPrefs.quiz` (`{v, at, <question id>: <option id>}`), next to
/// the onboarding picks the feed already ranks on.
const styleQuiz = [
  QuizQuestion(
    'spend',
    'What would you spend on a whole outfit?',
    'Keeps the fits you see in your price range.',
    [
      QuizOption('u2k', '🪙', 'Under ₹2,000'),
      QuizOption('2to5k', '💸', '₹2,000 – 5,000'),
      QuizOption('5to10k', '💳', '₹5,000 – 10,000'),
      QuizOption('10kplus', '💎', '₹10,000 and up'),
    ],
  ),
  QuizQuestion(
    'buy',
    'What gets you to hit buy?',
    'So the feed leads with what convinces you.',
    [
      QuizOption('deal', '🏷️', 'A good deal'),
      QuizOption('exact', '🎯', 'The exact piece I pictured'),
      QuizOption('styled', '🧍', 'Seeing it styled head to toe'),
      QuizOption('brand', '⭐', 'A label I trust'),
    ],
  ),
  QuizQuestion(
    'next',
    'What are you dressing for next?',
    'Your next few fits lean towards it.',
    [
      QuizOption('work', '💼', 'College or work'),
      QuizOption('night', '🌙', 'A night out'),
      QuizOption('trip', '✈️', 'A trip'),
      QuizOption('function', '🎉', 'A wedding or function'),
      QuizOption('everyday', '☕', 'Just everyday'),
    ],
  ),
  QuizQuestion(
    'volume',
    'How loud do you dress?',
    'Sets how bold your feed gets.',
    [
      QuizOption('quiet', '🤍', 'Quiet and clean'),
      QuizOption('statement', '✨', 'One statement piece'),
      QuizOption('loud', '📣', 'Head-turning'),
      QuizOption('mood', '🎲', 'Depends on the day'),
    ],
  ),
  QuizQuestion(
    'colour',
    "What's your colour comfort zone?",
    'On top of the palette you picked.',
    [
      QuizOption('neutral', '🤎', 'Neutrals only'),
      QuizOption('pop', '🟡', 'Neutrals with one pop'),
      QuizOption('full', '🌈', 'Full colour'),
      QuizOption('black', '🖤', 'All black'),
    ],
  ),
  QuizQuestion(
    'matters',
    'What matters most in a piece?',
    'Breaks the tie between two similar pieces.',
    [
      QuizOption('comfort', '🛋️', 'Comfort'),
      QuizOption('cut', '📐', 'Fit and cut'),
      QuizOption('fabric', '🧵', 'Fabric and quality'),
      QuizOption('trend', '📈', 'Being on trend'),
    ],
  ),
  QuizQuestion(
    'where',
    'Where do you shop the most?',
    'Points us at stores you already buy from.',
    [
      QuizOption('highstreet', '🛍️', 'High-street stores'),
      QuizOption('marketplace', '📦', 'Online marketplaces'),
      QuizOption('local', '🪡', 'Indian labels'),
      QuizOption('thrift', '♻️', 'Thrift and vintage'),
    ],
  ),
  QuizQuestion(
    'when',
    'When do you usually shop?',
    'Tells us when to show new drops, and when deals.',
    [
      QuizOption('sales', '🔥', 'Sales and drops'),
      QuizOption('need', '🧾', 'When I need something'),
      QuizOption('monthly', '📅', 'Every month or so'),
      QuizOption('impulse', '⚡', 'Whenever something hits'),
    ],
  ),
  QuizQuestion(
    'weather',
    "What's the weather like where you live?",
    "So we don't suggest wool in a heatwave.",
    [
      QuizOption('humid', '💧', 'Hot and humid'),
      QuizOption('dry', '☀️', 'Hot and dry'),
      QuizOption('mild', '🌤️', 'Mild most of the year'),
      QuizOption('cold', '❄️', 'Properly cold winters'),
    ],
  ),
  QuizQuestion(
    'explore',
    'How adventurous should your feed be?',
    'How often we slip in something new.',
    [
      QuizOption('safe', '✅', "Safe bets I'd wear tomorrow"),
      QuizOption('mix', '⚖️', 'A mix of both'),
      QuizOption('push', '🚀', 'Push me out of my comfort zone'),
    ],
  ),
];

/// The answers saved on the account (question id → option id), empty when
/// the quiz hasn't been taken.
final quizAnswersProvider = Provider<Map<String, String>>((ref) {
  final quiz = ref.watch(accountProvider).value?.onboardingPrefs['quiz'];
  if (quiz is! Map) return const {};
  return {
    for (final q in styleQuiz)
      if (quiz[q.id] is String) q.id: quiz[q.id] as String,
  };
});

/// The style quiz, a question a screen: tap an answer and the next question
/// slides in by itself. Every question can be skipped, and leaving halfway
/// keeps what was answered.
class StyleQuizScreen extends ConsumerStatefulWidget {
  const StyleQuizScreen({super.key});

  @override
  ConsumerState<StyleQuizScreen> createState() => _StyleQuizScreenState();
}

class _StyleQuizScreenState extends ConsumerState<StyleQuizScreen> {
  /// A pick shows for this long before the next question comes in.
  static const _beat = Duration(milliseconds: 280);

  late final Map<String, String> _answers;

  /// What the account held when the quiz opened, to tell if anything changed.
  late final Map<String, String> _before;
  late int _at;

  /// +1 moving forward, -1 back: which side the next question slides from.
  int _dir = 1;
  bool _done = false;
  bool _saving = false;
  bool _failed = false;
  bool _saved = false;
  Timer? _next;

  @override
  void initState() {
    super.initState();
    _before = ref.read(quizAnswersProvider);
    _answers = {..._before};
    // Picks up where an unfinished quiz stopped (from the top on a retake).
    final open = styleQuiz.indexWhere((q) => !_answers.containsKey(q.id));
    _at = open < 0 ? 0 : open;
  }

  @override
  void dispose() {
    _next?.cancel();
    super.dispose();
  }

  void _pick(QuizQuestion q, QuizOption o) {
    if (_next?.isActive ?? false) return;
    setState(() => _answers[q.id] = o.id);
    _next = Timer(Motion.dur(context, _beat), _forward);
  }

  void _forward() {
    if (!mounted) return;
    if (_at == styleQuiz.length - 1) {
      setState(() {
        _dir = 1;
        _done = true;
      });
      unawaited(_save());
      return;
    }
    setState(() {
      _dir = 1;
      _at++;
    });
  }

  void _back() {
    _next?.cancel();
    if (_at == 0) return;
    Haptics.tick();
    setState(() {
      _dir = -1;
      _at--;
    });
  }

  void _skip() {
    _next?.cancel();
    Haptics.tick();
    _forward();
  }

  /// `PATCH /me`: the answers go into `onboardingPrefs.quiz`, keeping every
  /// other pick on the account (PATCH replaces the whole object). Runs on the
  /// app's container, not this screen's `ref`, so a save started on the way
  /// out still finishes after the screen has gone.
  Future<void> _save() async {
    if (_saved) return;
    final scope = ProviderScope.containerOf(context, listen: false);
    final answers = {..._answers};
    setState(() {
      _saving = true;
      _failed = false;
    });
    try {
      final account = await scope.read(accountProvider.future);
      final now = DateTime.now().toUtc().toIso8601String().substring(0, 10);
      await scope
          .read(accountRepositoryProvider)
          .updateProfile(
            onboardingPrefs: {
              ...account.onboardingPrefs,
              'quiz': {'v': 1, 'at': now, ...answers},
            },
          );
      _saved = true;
      scope.invalidate(accountProvider);
    } catch (e) {
      if (mounted) {
        _failed = true;
        showDripToast(
          context,
          e is ApiException ? e.friendly : "Couldn't save your answers.",
        );
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  /// Leaving early: whatever changed is saved quietly on the way out.
  void _close() {
    _next?.cancel();
    final changed =
        _answers.length != _before.length ||
        _answers.entries.any((e) => _before[e.key] != e.value);
    if (!_done && changed) unawaited(_save().catchError((_) {}));
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = context.palette.accent;
    final q = styleQuiz[_at];
    final reduced = Motion.reduced(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        backgroundColor: AppColors.base,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 20, 0),
                child: Row(
                  children: [
                    Tap(
                      semanticLabel: 'Close the quiz',
                      scale: 0.9,
                      onTap: _close,
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
                    const SizedBox(width: 6),
                    Expanded(
                      child: _Progress(
                        done: _done ? styleQuiz.length : _at,
                        total: styleQuiz.length,
                        color: accent,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      _done ? 'DONE' : '${_at + 1}/${styleQuiz.length}',
                      style: AppText.mono(11, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: Motion.dur(context, Motion.content),
                  switchInCurve: Motion.out,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, animation) {
                    final incoming =
                        child.key == ValueKey(_done ? 'done' : q.id);
                    final from = (incoming ? _dir : -_dir) * 0.18;
                    return FadeTransition(
                      opacity: animation,
                      child: reduced
                          ? child
                          : SlideTransition(
                              position: Tween(
                                begin: Offset(from, 0),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                    );
                  },
                  child: _done
                      ? _Finished(
                          key: const ValueKey('done'),
                          answered: _answers.length,
                          saving: _saving,
                          failed: _failed,
                          onRetry: _save,
                        )
                      : _QuestionView(
                          key: ValueKey(q.id),
                          number: _at + 1,
                          question: q,
                          picked: _answers[q.id],
                          onPick: (o) => _pick(q, o),
                        ),
                ),
              ),
              if (!_done)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                  child: Row(
                    children: [
                      AnimatedOpacity(
                        opacity: _at > 0 ? 1 : 0,
                        duration: Motion.dur(context, Motion.quick),
                        child: _TextAction(
                          'BACK',
                          onTap: _at > 0 ? _back : null,
                        ),
                      ),
                      const Spacer(),
                      _TextAction(
                        _answers.containsKey(q.id) ? 'NEXT' : 'SKIP',
                        onTap: _skip,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The question, why it's asked, and its answers as big tap targets.
class _QuestionView extends StatelessWidget {
  const _QuestionView({
    super.key,
    required this.number,
    required this.question,
    required this.picked,
    required this.onPick,
  });

  final int number;
  final QuizQuestion question;
  final String? picked;
  final ValueChanged<QuizOption> onPick;

  @override
  Widget build(BuildContext context) {
    final accent = context.palette.accent;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
      children: [
        Text(
          'QUESTION ${number.toString().padLeft(2, '0')}',
          style: AppText.mono(10, color: accent, letterSpacing: 2),
        ),
        const SizedBox(height: 12),
        Text(
          question.question.toUpperCase(),
          style: AppText.display(24, lineHeight: 30),
        ),
        const SizedBox(height: 10),
        Text(
          question.why,
          style: AppText.manrope(13, color: AppColors.muted, lineHeight: 19),
        ),
        const SizedBox(height: 26),
        for (final (i, o) in question.options.indexed) ...[
          if (i > 0) const SizedBox(height: 10),
          Enter(
            delay: Duration(milliseconds: 40 + i * 50),
            dy: 12,
            duration: const Duration(milliseconds: 420),
            child: _OptionCard(
              option: o,
              on: picked == o.id,
              onTap: () => onPick(o),
            ),
          ),
        ],
      ],
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.option,
    required this.on,
    required this.onTap,
  });

  final QuizOption option;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = context.palette.accent;
    final quick = Motion.dur(context, Motion.quick);
    return LabelledTap(
      onTap: onTap,
      scale: 0.98,
      selects: true,
      semanticLabel: '${option.label}${on ? ', picked' : ''}',
      child: AnimatedContainer(
        duration: quick,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: on ? accent.withValues(alpha: 0.12) : AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: on ? accent : AppColors.elevated,
            width: on ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(option.emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                option.label,
                style: AppText.manrope(15, weight: FontWeight.w600),
              ),
            ),
            AnimatedScale(
              scale: on ? 1 : 0,
              duration: quick,
              curve: Curves.easeOutBack,
              child: Icon(Icons.check_circle_rounded, size: 22, color: accent),
            ),
          ],
        ),
      ),
    );
  }
}

/// A thin bar per question, filled up to the current one.
class _Progress extends StatelessWidget {
  const _Progress({
    required this.done,
    required this.total,
    required this.color,
  });

  final int done;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < total; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(
            child: AnimatedContainer(
              duration: Motion.dur(context, Motion.content),
              curve: Motion.out,
              height: 4,
              decoration: BoxDecoration(
                color: i < done ? color : AppColors.elevated,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _TextAction extends StatelessWidget {
  const _TextAction(this.label, {required this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tap(
      onTap: onTap,
      semanticLabel: label,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Text(
          label,
          style: AppText.mono(11, color: AppColors.muted, letterSpacing: 1.6),
        ),
      ),
    );
  }
}

/// The end: what the answers do, and the way back into the app.
class _Finished extends StatelessWidget {
  const _Finished({
    super.key,
    required this.answered,
    required this.saving,
    required this.failed,
    required this.onRetry,
  });

  final int answered;
  final bool saving;
  final bool failed;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final accent = context.palette.accent;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(),
          Enter(
            dy: 10,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                shape: BoxShape.circle,
                border: Border.all(color: accent, width: 2),
              ),
              child: Icon(Icons.check_rounded, size: 34, color: accent),
            ),
          ),
          const SizedBox(height: 24),
          Enter(
            delay: const Duration(milliseconds: 80),
            child: Text(
              'YOUR FEED IS TUNED',
              style: AppText.display(26, lineHeight: 32),
            ),
          ),
          const SizedBox(height: 12),
          Enter(
            delay: const Duration(milliseconds: 140),
            child: Text(
              'Drip will use these to pick fits you\'re more likely to wear '
              'and buy. Retake it any time from Home.',
              style: AppText.manrope(
                14,
                color: AppColors.muted,
                lineHeight: 21,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            saving
                ? 'SAVING…'
                : failed
                ? 'NOT SAVED YET'
                : '$answered OF ${styleQuiz.length} ANSWERED',
            style: AppText.mono(10, color: accent, letterSpacing: 1.6),
          ),
          const Spacer(),
          if (failed)
            AppButton(label: 'TRY AGAIN', onPressed: onRetry)
          else
            AppButton(
              label: 'SEE MY FITS',
              loading: saving,
              onPressed: () => context.go('/scroll'),
            ),
          const SizedBox(height: 10),
          AppButton(
            label: 'BACK TO HOME',
            style: AppButtonStyle.outline,
            onPressed: () => context.go('/home'),
          ),
        ],
      ),
    );
  }
}
