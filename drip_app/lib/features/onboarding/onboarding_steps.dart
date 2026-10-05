import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/constants/assets.dart';
import '../../core/motion.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/brand.dart';
import '../../core/widgets/drip_image.dart';
import '../home/occasion_card.dart';
import '../home/occasions.dart';
import '../session/session_controller.dart';
import 'onboarding_data.dart';
import 'onboarding_ticket.dart';
import 'onboarding_widgets.dart';

export 'onboarding_ticket.dart' show TicketInfo;

Duration _ms(num v) => Duration(milliseconds: v.round());

/// Width of one cell in a [cols]-column grid with [gap] between cells.
double _cell(double maxWidth, int cols, double gap) =>
    (maxWidth - gap * (cols - 1)) / cols;

// ───────────────────────────────────────────────────────────────── welcome

/// The first screen is the brand's opening line: the wordmark, then the
/// hard truth struck through as it lands, then the offer. One screen where
/// there used to be three (welcome, statement, "what is Drip").
class WelcomeStep extends StatelessWidget {
  const WelcomeStep({super.key});

  static const _words = [
    'OVERDRESSED',
    'IS',
    'A',
    'CONCEPT',
    'INVENTED',
    'BY',
    'PEOPLE',
    'WHO',
    'CAN’T',
    'DRESS.',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Enter(
          delay: _ms(50),
          dy: 16,
          child: const Align(
            alignment: Alignment.centerLeft,
            child: DripWordmark(height: 56),
          ),
        ),
        const SizedBox(height: 30),
        Enter(
          delay: _ms(150),
          dy: 8,
          child: const Eyebrow('The fit finds you'),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 12,
          children: [
            for (var i = 0; i < _words.length; i++)
              Enter(
                delay: _ms(250 + i * 55),
                dy: 22,
                child: _Word(_words[i], struck: i == 0),
              ),
          ],
        ),
        const SizedBox(height: 26),
        Enter(
          delay: _ms(1300),
          dy: 12,
          child: Text.rich(
            TextSpan(
              style: AppText.manrope(
                22,
                weight: FontWeight.w800,
                lineHeight: 28,
              ),
              children: [
                const TextSpan(text: 'Let us '),
                TextSpan(
                  text: 'help you',
                  style: TextStyle(color: AppColors.cyan),
                ),
                const TextSpan(text: ' with that.'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Word extends StatefulWidget {
  const _Word(this.text, {required this.struck});
  final String text;
  final bool struck;

  @override
  State<_Word> createState() => _WordState();
}

class _WordState extends State<_Word> {
  bool _line = false;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    if (widget.struck) {
      _t = Timer(const Duration(milliseconds: 1050), () {
        if (mounted) setState(() => _line = true);
      });
    }
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.centerLeft,
      children: [
        Text(
          widget.text,
          style: AppText.display(
            32,
            lineHeight: 40,
            color: widget.struck ? AppColors.muted : AppColors.cream,
          ),
        ),
        if (widget.struck)
          Positioned.fill(
            child: Align(
              alignment: Alignment.centerLeft,
              child: AnimatedFractionallySizedBox(
                duration: Motion.dur(
                  context,
                  const Duration(milliseconds: 500),
                ),
                curve: Curves.easeOut,
                widthFactor: _line ? 1 : 0,
                child: Container(height: 4, color: AppColors.red),
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────── dress for

/// "Dress me for": three ticket stubs, one tap. The pick is the user's own
/// statement of whose clothes lead their feed, never inferred from anything.
class DressForStep extends ConsumerWidget {
  const DressForStep({super.key, required this.onPick});

  /// Called with 'male', 'female' or 'unspecified'.
  final ValueChanged<String> onPick;

  static const options = [
    ('male', 'Male', 'Menswear first'),
    ('female', 'Female', 'Womenswear first'),
    ('unspecified', 'Prefer not to say', 'Everything, no lean'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final picked = ref.watch(onboardingProvider.select((p) => p.gender));
    return Column(
      children: [
        for (var i = 0; i < options.length; i++)
          Enter(
            delay: _ms(i * 90),
            dy: 18,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _DressCard(
                number: i + 1,
                title: options[i].$2,
                line: options[i].$3,
                on: picked == options[i].$1,
                onTap: () => onPick(options[i].$1),
              ),
            ),
          ),
      ],
    );
  }
}

/// A ticket stub: the choice on the left, a perforation, and the numbered
/// stub on the right that takes the tick.
class _DressCard extends StatelessWidget {
  const _DressCard({
    required this.number,
    required this.title,
    required this.line,
    required this.on,
    required this.onTap,
  });
  final int number;
  final String title;
  final String line;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final d = Motion.dur(context, Motion.quick);
    return LabelledTap(
      onTap: onTap,
      selects: true,
      scale: 0.97,
      semanticLabel: '$title, $line${on ? ', picked' : ''}',
      child: AnimatedScale(
        scale: on && !Motion.reduced(context) ? 1.02 : 1,
        duration: Motion.content,
        curve: Motion.out,
        child: AnimatedContainer(
          duration: d,
          height: 96,
          decoration: BoxDecoration(
            color: on
                ? AppColors.cyan.withValues(alpha: 0.12)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: on ? AppColors.cyan : AppColors.elevated,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          title.toUpperCase(),
                          maxLines: 1,
                          style: AppText.display(20, lineHeight: 24),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        line,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.manrope(
                          13,
                          color: on ? AppColors.cream : AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // The perforation and the stub.
              CustomPaint(
                size: const Size(1, 64),
                painter: _VerticalDashes(
                  on
                      ? AppColors.cyan.withValues(alpha: 0.6)
                      : AppColors.cream.withValues(alpha: 0.18),
                ),
              ),
              SizedBox(
                width: 72,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$number'.padLeft(2, '0'),
                      style: AppText.mono(
                        10,
                        color: on ? AppColors.cyan : AppColors.dim,
                      ),
                    ),
                    const SizedBox(height: 8),
                    AnimatedContainer(
                      duration: d,
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: on ? AppColors.cyan : AppColors.transparent,
                        border: Border.all(
                          color: on
                              ? AppColors.cyan
                              : AppColors.cream.withValues(alpha: 0.35),
                          width: 1.5,
                        ),
                      ),
                      child: AnimatedOpacity(
                        opacity: on ? 1 : 0,
                        duration: d,
                        child: Text(
                          '✓',
                          style: AppText.manrope(13, color: AppColors.base),
                        ),
                      ),
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

class _VerticalDashes extends CustomPainter {
  _VerticalDashes(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (var y = 0.0; y < size.height; y += 8) {
      canvas.drawLine(Offset(0, y), Offset(0, y + 4), p);
    }
  }

  @override
  bool shouldRepaint(_VerticalDashes old) => old.color != color;
}

// ───────────────────────────────────────────────────────────── eras + genres

class ErasStep extends ConsumerWidget {
  const ErasStep({super.key, required this.onGlow});

  /// Fades the backdrop glow to the era just picked.
  final ValueChanged<Color> onGlow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final picks = ref.watch(onboardingProvider);
    final c = ref.read(onboardingProvider.notifier);
    return LayoutBuilder(
      builder: (context, box) {
        final era = _cell(box.maxWidth, 2, 12);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (var i = 0; i < OnboardingData.eras.length; i++)
                  Enter(
                    delay: _ms(i * 70),
                    dy: 34,
                    child: SizedBox(
                      width: era,
                      height: era,
                      child: _EraTile(
                        era: OnboardingData.eras[i],
                        on: picks.moodIds.contains(OnboardingData.eras[i].id),
                        onTap: () {
                          final e = OnboardingData.eras[i];
                          if (!picks.moodIds.contains(e.id)) onGlow(e.glow);
                          c.toggleMood(e.id);
                        },
                      ),
                    ),
                  ),
                Enter(
                  delay: _ms(500),
                  dy: 34,
                  child: SizedBox(
                    width: era,
                    height: era,
                    child: LabelledTap(
                      onTap: () {
                        final all = OnboardingData.eras.toList()..shuffle();
                        final three = all.take(3).toList();
                        c.setMoods({for (final e in three) e.id});
                        onGlow(three.first.glow);
                      },
                      scale: 0.95,
                      semanticLabel: 'Surprise me: pick three eras for me',
                      child: DashedBorder(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '✦',
                              style: AppText.inter(22, color: AppColors.cyan),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'SURPRISE ME',
                              style: AppText.mono(11, letterSpacing: 1.5),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Pick three for me',
                              style: AppText.manrope(
                                12,
                                color: AppColors.muted,
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
            AnimatedSize(
              duration: Motion.dur(context, Motion.content),
              curve: Motion.out,
              alignment: Alignment.topCenter,
              child: picks.moodIds.isEmpty
                  ? const SizedBox(width: double.infinity)
                  : _GoDeeper(tile: era),
            ),
          ],
        );
      },
    );
  }
}

class _EraTile extends StatelessWidget {
  const _EraTile({required this.era, required this.on, required this.onTap});
  final EraOption era;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return LabelledTap(
      onTap: onTap,
      scale: 0.95,
      semanticLabel: '${era.label}${on ? ', picked' : ''}',
      selects: true,
      child: AnimatedScale(
        scale: on && !Motion.reduced(context) ? 1.02 : 1,
        duration: Motion.content,
        curve: Curves.easeOutBack,
        child: AnimatedContainer(
          duration: Motion.quick,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: on ? AppColors.cyan : AppColors.elevated,
              width: 2,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              AnimatedScale(
                scale: on && !Motion.reduced(context) ? 1.1 : 1,
                duration: const Duration(milliseconds: 700),
                curve: Motion.out,
                child: DripImage(Assets.image('mood_${era.id}')),
              ),
              AnimatedOpacity(
                opacity: on ? 0.4 : 0.6,
                duration: Motion.quick,
                child: const ColoredBox(color: AppColors.base),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: Stack(
                  alignment: Alignment.topRight,
                  children: [
                    if (!on)
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.cream.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                    TickBadge(on: on, label: '✓ ACTIVE'),
                  ],
                ),
              ),
              Positioned(
                left: 12,
                bottom: 10,
                child: Text(era.label, style: AppText.display(14)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GenreTile extends StatelessWidget {
  const _GenreTile({
    required this.index,
    required this.on,
    required this.onTap,
  });
  final int index;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = OnboardingData.genres[index];
    return LabelledTap(
      onTap: onTap,
      scale: 0.96,
      semanticLabel: '$label${on ? ', picked' : ''}',
      selects: true,
      child: AnimatedContainer(
        duration: Motion.quick,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: on ? AppColors.cyan : AppColors.elevated,
            width: 2,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedScale(
              scale: on && !Motion.reduced(context) ? 1.1 : 1,
              duration: const Duration(milliseconds: 700),
              curve: Motion.out,
              child: DripImage(Assets.image(OnboardingData.genreImages[index])),
            ),
            AnimatedOpacity(
              opacity: on ? 0.75 : 1,
              duration: Motion.quick,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x4D0E1018), Color(0xEB0E1018)],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 10,
              left: 12,
              child: Text(
                '${index + 1}'.padLeft(2, '0'),
                style: AppText.mono(10),
              ),
            ),
            Positioned(top: 8, right: 10, child: TickBadge(on: on)),
            Positioned(
              left: 12,
              right: 12,
              bottom: 10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: AppText.display(13, lineHeight: 16)),
                  const SizedBox(height: 4),
                  Text(
                    OnboardingData.genreDescriptions[index],
                    style: AppText.manrope(12, lineHeight: 15),
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

// ──────────────────────────────────────────────────────────────── colours

class ColoursStep extends ConsumerStatefulWidget {
  const ColoursStep({super.key, required this.onGlow});
  final ValueChanged<Color> onGlow;

  @override
  ConsumerState<ColoursStep> createState() => _ColoursStepState();
}

class _ColoursStepState extends ConsumerState<ColoursStep> {
  bool _custom = false;
  double _hue = 255;
  double _light = 0.6;
  final _name = TextEditingController();

  Color get _picked => HSLColor.fromAHSL(1, _hue, 0.85, _light).toColor();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final picks = ref.watch(onboardingProvider);
    final c = ref.read(onboardingProvider.notifier);
    final all = <({String id, String name, int hex, bool custom})>[
      for (final o in OnboardingData.colours)
        (id: o.id, name: o.name, hex: o.hex, custom: false),
      for (final o in picks.customColours)
        (id: o.id, name: o.name, hex: o.hex, custom: true),
    ];
    final chosen = [
      for (final o in all)
        if (picks.paletteIds.contains(o.id)) o,
    ];

    return LayoutBuilder(
      builder: (context, box) {
        final cell = _cell(box.maxWidth, 4, 8);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Enter(
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.elevated),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    // Segments resize together; mid-animation they can add
                    // up to more than the bar, so the row is unbounded and
                    // the bar clips it.
                    OverflowBox(
                      alignment: Alignment.centerLeft,
                      maxWidth: double.infinity,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final o in all)
                            AnimatedContainer(
                              duration: Motion.dur(
                                context,
                                const Duration(milliseconds: 500),
                              ),
                              curve: Motion.out,
                              width: picks.paletteIds.contains(o.id)
                                  ? (box.maxWidth - 2) / chosen.length
                                  : 0,
                              color: Color(o.hex),
                            ),
                        ],
                      ),
                    ),
                    if (chosen.isEmpty)
                      Center(
                        child: Text(
                          'YOUR PALETTE',
                          style: AppText.mono(
                            10,
                            color: AppColors.muted,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            Wrap(
              spacing: 8,
              runSpacing: 18,
              children: [
                for (var i = 0; i < all.length; i++)
                  Enter(
                    delay: _ms(i * 45),
                    dy: 20,
                    child: SizedBox(
                      width: cell,
                      child: _Swatch(
                        name: all[i].name,
                        color: Color(all[i].hex),
                        on: picks.paletteIds.contains(all[i].id),
                        onDelete: all[i].custom
                            ? () => c.removeCustomColour(all[i].id)
                            : null,
                        onTap: () {
                          if (!picks.paletteIds.contains(all[i].id)) {
                            widget.onGlow(Color(all[i].hex));
                          }
                          c.togglePalette(all[i].id);
                        },
                      ),
                    ),
                  ),
                SizedBox(
                  width: cell,
                  child: LabelledTap(
                    onTap: _toggleCustom,
                    scale: 0.9,
                    semanticLabel: _custom
                        ? 'Close, without adding a colour'
                        : 'Add your own colour',
                    child: Column(
                      children: [
                        AnimatedRotation(
                          turns: _custom ? 0.125 : 0,
                          duration: Motion.content,
                          curve: Curves.easeOutBack,
                          child: DashedBorder(
                            radius: 29,
                            color: _custom
                                ? AppColors.cyan
                                : AppColors.cream.withValues(alpha: 0.4),
                            child: SizedBox(
                              width: 58,
                              height: 58,
                              child: Center(
                                child: Text(
                                  '+',
                                  style: AppText.inter(
                                    26,
                                    color: _custom
                                        ? AppColors.cyan
                                        : AppColors.cream.withValues(
                                            alpha: 0.6,
                                          ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'ADD OWN',
                          style: AppText.mono(10, color: AppColors.cyan),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            AnimatedSize(
              duration: Motion.content,
              curve: Motion.out,
              alignment: Alignment.topCenter,
              child: _custom
                  ? _customPanel(c)
                  : const SizedBox(width: double.infinity),
            ),
          ],
        );
      },
    );
  }

  void _addCustom(OnboardingController c) {
    if (!c.addCustomColour(_name.text, _picked.toARGB32())) return;
    widget.onGlow(_picked);
    _name.clear();
    setState(() => _custom = false);
  }

  /// Where the mixer lives, so opening it can bring it into view.
  final _panel = GlobalKey();

  /// "Add own" opens the mixer and brings it (down to its "add to my
  /// palette" button) into view; nobody should have to go looking for what
  /// they just asked for.
  void _toggleCustom() {
    setState(() => _custom = !_custom);
    if (!_custom) return;
    // Wait for the panel to finish growing, then scroll it fully on screen.
    final grow = Motion.dur(context, Motion.content);
    Future<void>.delayed(grow + const Duration(milliseconds: 20), () {
      final target = _panel.currentContext;
      if (!mounted || target == null || !target.mounted || !_custom) return;
      Scrollable.ensureVisible(
        target,
        duration: grow,
        curve: Motion.out,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
    });
  }

  Widget _customPanel(OnboardingController c) {
    // Six of your own at most: say so on the button instead of failing late.
    final full = ref.watch(onboardingProvider).customColours.length >= 6;
    final hex =
        '#${(_picked.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
    return Container(
      key: _panel,
      margin: const EdgeInsets.only(top: 22),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.elevated),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const GroupLabel('ADD YOUR OWN'),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: _picked,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.cream, width: 2),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.base,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.elevated),
                      ),
                      child: TextField(
                        controller: _name,
                        maxLength: 16,
                        textInputAction: TextInputAction.done,
                        textCapitalization: TextCapitalization.words,
                        onSubmitted: full ? null : (_) => _addCustom(c),
                        cursorColor: AppColors.red,
                        style: AppText.manrope(14),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          counterText: '',
                          hintText: 'e.g. Mustard',
                          hintStyle: AppText.manrope(
                            14,
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$hex · DRAG TO MIX',
                      style: AppText.mono(11, color: AppColors.cyan),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _GradientSlider(
            label: 'Hue',
            value: _hue / 360,
            colors: [
              for (var h = 0; h <= 360; h += 60)
                HSLColor.fromAHSL(1, h.toDouble(), 0.85, 0.55).toColor(),
            ],
            onChanged: (v) => setState(() => _hue = v * 360),
          ),
          const SizedBox(height: 10),
          _GradientSlider(
            label: 'Lightness',
            value: _light,
            colors: [
              HSLColor.fromAHSL(1, _hue, 0.85, 0.12).toColor(),
              HSLColor.fromAHSL(1, _hue, 0.85, 0.5).toColor(),
              HSLColor.fromAHSL(1, _hue, 0.85, 0.92).toColor(),
            ],
            onChanged: (v) => setState(() => _light = v.clamp(0.1, 0.92)),
          ),
          const SizedBox(height: 16),
          LabelledTap(
            onTap: full ? null : () => _addCustom(c),
            scale: 0.97,
            semanticLabel: full
                ? 'Palette full. Remove a colour of your own to add another'
                : 'Add to my palette',
            child: Container(
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: full
                    ? AppColors.elevated.withValues(alpha: 0.6)
                    : AppColors.elevated,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                full ? 'PALETTE FULL · REMOVE ONE' : 'ADD TO MY PALETTE',
                style: AppText.mono(
                  11,
                  weight: FontWeight.w500,
                  letterSpacing: 1.5,
                  color: full ? AppColors.muted : AppColors.cream,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GradientSlider extends StatelessWidget {
  const _GradientSlider({
    required this.label,
    required this.value,
    required this.colors,
    required this.onChanged,
  });
  final String label;
  final double value;
  final List<Color> colors;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(0.0, 1.0);
    return LayoutBuilder(
      builder: (context, box) {
        void at(double dx) => onChanged((dx / box.maxWidth).clamp(0, 1));
        return Semantics(
          slider: true,
          label: label,
          value: '${(v * 100).round()}%',
          increasedValue: '${((v + 0.05).clamp(0, 1) * 100).round()}%',
          decreasedValue: '${((v - 0.05).clamp(0, 1) * 100).round()}%',
          onIncrease: () => onChanged((v + 0.05).clamp(0, 1)),
          onDecrease: () => onChanged((v - 0.05).clamp(0, 1)),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanDown: (d) => at(d.localPosition.dx),
            onPanUpdate: (d) => at(d.localPosition.dx),
            child: SizedBox(
              height: 28,
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Container(
                    height: 12,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      gradient: LinearGradient(colors: colors),
                    ),
                  ),
                  Positioned(
                    left: (box.maxWidth - 24) * value.clamp(0, 1),
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.cream,
                        border: Border.all(color: AppColors.base, width: 3),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.name,
    required this.color,
    required this.on,
    required this.onTap,
    this.onDelete,
  });
  final String name;
  final Color color;
  final bool on;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final ink = OnboardingData.luminance(color.toARGB32()) > 0.55
        ? AppColors.base
        : AppColors.cream;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        LabelledTap(
          onTap: onTap,
          scale: 0.9,
          semanticLabel: '$name${on ? ', picked' : ''}',
          selects: true,
          child: Column(
            children: [
              AnimatedScale(
                scale: on && !Motion.reduced(context) ? 1.08 : 1,
                duration: Motion.content,
                curve: Curves.easeOutBack,
                child: AnimatedContainer(
                  duration: Motion.content,
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.cream,
                      width: on ? 2 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.cream.withValues(alpha: on ? 0.14 : 0),
                        spreadRadius: on ? 6 : 0,
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: AnimatedOpacity(
                    opacity: on ? 1 : 0,
                    duration: Motion.quick,
                    child: Text('✓', style: AppText.manrope(20, color: ink)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppText.mono(
                  10,
                  color: on ? AppColors.cream : AppColors.muted,
                ),
              ),
            ],
          ),
        ),
        if (onDelete != null)
          // A 22px badge with a 38px hit area, so it's easy to hit and
          // hard to miss into the swatch beneath.
          Positioned(
            top: -14,
            right: -6,
            child: LabelledTap(
              onTap: onDelete,
              semanticLabel: 'Remove $name',
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.elevated,
                    border: Border.all(
                      color: AppColors.cream.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text('×', style: AppText.manrope(12)),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ────────────────────────────────────────────── clothes / accessories / brands

class ClothesStep extends ConsumerWidget {
  const ClothesStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final picks = ref.watch(onboardingProvider);
    final c = ref.read(onboardingProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var g = 0; g < OnboardingData.clothes.length; g++) ...[
          if (g > 0) const SizedBox(height: 22),
          Enter(
            delay: _ms(g * 150),
            dy: 14,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GroupLabel(OnboardingData.clothes[g].$1),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final item in OnboardingData.clothes[g].$2)
                      PickPill(
                        label: item,
                        on: picks.clothes.contains(item),
                        onTap: () => c.toggleCloth(item),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class AccessoriesStep extends ConsumerWidget {
  const AccessoriesStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final picks = ref.watch(onboardingProvider);
    final c = ref.read(onboardingProvider.notifier);
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (var i = 0; i < OnboardingData.accessories.length; i++)
          Enter(
            delay: _ms(i * 35),
            dy: 14,
            child: PickPill(
              label: OnboardingData.accessories[i],
              big: true,
              tick: '✦',
              on: picks.accessories.contains(OnboardingData.accessories[i]),
              onTap: () => c.toggleAccessory(OnboardingData.accessories[i]),
            ),
          ),
      ],
    );
  }
}

class BrandsStep extends ConsumerWidget {
  const BrandsStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final picks = ref.watch(onboardingProvider);
    final c = ref.read(onboardingProvider.notifier);
    return LayoutBuilder(
      builder: (context, box) {
        final w = _cell(box.maxWidth, 2, 12);
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (var i = 0; i < OnboardingData.brands.length; i++)
              Enter(
                delay: _ms(i * 40),
                dy: 24,
                child: SizedBox(
                  width: w,
                  height: 96,
                  child: _BrandTile(
                    label: OnboardingData.brands[i],
                    sub: OnboardingData.brandSubs[i].toUpperCase(),
                    on: picks.brands.contains(OnboardingData.brands[i]),
                    onTap: () => c.toggleBrand(OnboardingData.brands[i]),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _BrandTile extends StatelessWidget {
  const _BrandTile({
    required this.label,
    required this.sub,
    required this.on,
    required this.onTap,
  });
  final String label;
  final String sub;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final reduced = Motion.reduced(context);
    final look =
        OnboardingData.brandLooks[label] ??
        const BrandLook(0xFF1B1D26, 0xFFE8DFC8, face: MarkFace.heavy);
    final ink = Color(look.ink);
    final d = Motion.dur(context, Motion.quick);
    return LabelledTap(
      onTap: onTap,
      scale: 0.96,
      semanticLabel: '$label${on ? ', picked' : ''}',
      selects: true,
      child: AnimatedScale(
        scale: on && !reduced ? 1.02 : 1,
        duration: Motion.content,
        curve: Motion.out,
        // The label's colour fills the whole tile. Unpicked, a dark veil
        // holds the wall of colour back; picked, it lifts to full strength
        // and takes the same cyan ring and tick as every other pick.
        child: AnimatedContainer(
          duration: d,
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: on ? AppColors.cyan : AppColors.transparent,
              width: 2.5,
            ),
          ),
          decoration: BoxDecoration(
            color: Color(look.fill),
            borderRadius: BorderRadius.circular(18),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned(
                left: 14,
                right: 14,
                top: 14,
                bottom: 28,
                child: Center(
                  child: AnimatedScale(
                    scale: on && !reduced ? 1.06 : 1,
                    duration: Motion.content,
                    curve: Motion.out,
                    child: look.logo != null
                        ? _Logo(
                            asset: look.logo!,
                            ratio: look.ratio,
                            color: ink,
                          )
                        : _Wordmark(
                            look.mark ?? label,
                            face: look.face,
                            color: ink,
                          ),
                  ),
                ),
              ),
              Positioned(
                left: 14,
                right: 14,
                bottom: 9,
                child: Text(
                  sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.mono(
                    10,
                    color: ink.withValues(alpha: 0.72),
                    letterSpacing: 1,
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: on ? 0 : 0.34,
                    duration: d,
                    child: const ColoredBox(color: AppColors.base),
                  ),
                ),
              ),
              Positioned(top: 8, right: 10, child: TickBadge(on: on)),
            ],
          ),
        ),
      ),
    );
  }
}

/// A brand mark at an equal *optical* size: every logo gets the same area
/// (so a wide wordmark isn't dwarfed by a square badge), within the tile.
class _Logo extends StatelessWidget {
  const _Logo({required this.asset, required this.ratio, required this.color});
  final String asset;
  final double ratio;
  final Color color;

  static const _area = 1100.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        var w = math.sqrt(_area * ratio), h = math.sqrt(_area / ratio);
        final fit = math.min(
          1.0,
          math.min(box.maxWidth / w, box.maxHeight / h),
        );
        w *= fit;
        h *= fit;
        return TweenAnimationBuilder<Color?>(
          tween: ColorTween(end: color),
          duration: Motion.dur(context, Motion.quick),
          builder: (context, c, _) => SvgPicture.asset(
            asset,
            width: w,
            height: h,
            colorFilter: ColorFilter.mode(c ?? color, BlendMode.srcIn),
          ),
        );
      },
    );
  }
}

/// A label without a logo: its name, set in one of Drip's faces at a weight
/// that sits level with the logos around it.
class _Wordmark extends StatelessWidget {
  const _Wordmark(this.text, {required this.face, required this.color});
  final String text;
  final MarkFace face;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final style = switch (face) {
      MarkFace.poster => AppText.display(17, lineHeight: 19, color: color),
      MarkFace.round => AppText.fredoka(24, lineHeight: 26, color: color),
      MarkFace.light => AppText.manrope(
        23,
        weight: FontWeight.w300,
        lineHeight: 26,
        letterSpacing: 0.5,
        color: color,
      ),
      MarkFace.heavy => AppText.manrope(
        19,
        weight: FontWeight.w800,
        lineHeight: 19,
        color: color,
      ),
      MarkFace.spaced => AppText.manrope(
        16,
        weight: FontWeight.w800,
        letterSpacing: 5,
        color: color,
      ),
      MarkFace.tag => AppText.mono(
        14,
        weight: FontWeight.w500,
        letterSpacing: 3.5,
        color: color,
      ),
    };
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(text, textAlign: TextAlign.center, style: style),
    );
  }
}

/// "More like you": genres that go with the eras just picked, revealed once
/// there's an era to go on. Four to six suggestions, not a wall of fourteen;
/// the rest are one tap away.
class _GoDeeper extends ConsumerStatefulWidget {
  const _GoDeeper({required this.tile});

  /// Tile width (two columns, like the eras).
  final double tile;

  @override
  ConsumerState<_GoDeeper> createState() => _GoDeeperState();
}

class _GoDeeperState extends ConsumerState<_GoDeeper> {
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final picks = ref.watch(onboardingProvider);
    final c = ref.read(onboardingProvider.notifier);
    final suggested = OnboardingData.suggestedGenres(picks.moodIds);
    final shown = _all
        ? OnboardingData.genres
        : [
            for (final g in OnboardingData.genres)
              if (suggested.contains(g) || picks.genres.contains(g)) g,
          ];
    final more = OnboardingData.genres.length - shown.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 28),
        const GroupLabel('MORE LIKE YOU · OPTIONAL'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final g in shown)
              Enter(
                key: ValueKey(g),
                dy: 16,
                duration: Motion.content,
                child: SizedBox(
                  width: widget.tile,
                  height: 132,
                  child: _GenreTile(
                    index: OnboardingData.genres.indexOf(g),
                    on: picks.genres.contains(g),
                    onTap: () => c.toggleGenre(g),
                  ),
                ),
              ),
          ],
        ),
        if (more > 0)
          LabelledTap(
            onTap: () => setState(() => _all = true),
            semanticLabel: 'Show all ${OnboardingData.genres.length} genres',
            child: Container(
              height: 48,
              alignment: Alignment.centerLeft,
              child: Text(
                'SHOW $more MORE ↓',
                style: AppText.mono(
                  11,
                  color: AppColors.cyan,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────── occasions

/// Where the fit needs to show up: the same occasion cards as Home's "Shop
/// by occasion" (photo, fade, title), here as picks. The ones chosen lead
/// that wall on Home.
class OccasionsStep extends ConsumerWidget {
  const OccasionsStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final picked = ref.watch(onboardingProvider.select((p) => p.occasions));
    final c = ref.read(onboardingProvider.notifier);
    return LayoutBuilder(
      builder: (context, box) {
        final w = _cell(box.maxWidth, 2, 12);
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (var i = 0; i < Occasions.all.length; i++)
              Enter(
                delay: _ms(i * 45),
                dy: 24,
                child: SizedBox(
                  width: w,
                  height: w * 1.22,
                  child: OccasionCard(
                    occasion: Occasions.all[i],
                    index: i,
                    selected: picked.contains(Occasions.all[i].id),
                    onTap: () => c.toggleOccasion(Occasions.all[i].id),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ────────────────────────────────────────────────────────────────── labels

/// Labels and spend, together: both are "how you shop".
class LabelsStep extends StatelessWidget {
  const LabelsStep({super.key});

  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [BrandsStep(), SizedBox(height: 30), BudgetPicker()],
  );
}

/// "Usual spend per piece": the number, big, and a slider under it.
class BudgetPicker extends ConsumerWidget {
  const BudgetPicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budget = ref.watch(onboardingProvider.select((p) => p.budget));
    final c = ref.read(onboardingProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const GroupLabel('USUAL SPEND PER PIECE'),
        const SizedBox(height: 8),
        Text(
          '${formatPrice(budget)}${budget >= OnboardingData.budgetMax ? '+' : ''}',
          style: AppText.display(34),
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: AppColors.red,
            inactiveTrackColor: AppColors.elevated,
            thumbColor: AppColors.red,
            overlayColor: AppColors.red.withValues(alpha: 0.15),
          ),
          child: Slider(
            min: OnboardingData.budgetMin.toDouble(),
            max: OnboardingData.budgetMax.toDouble(),
            divisions:
                (OnboardingData.budgetMax - OnboardingData.budgetMin) ~/ 500,
            value: budget
                .clamp(OnboardingData.budgetMin, OnboardingData.budgetMax)
                .toDouble(),
            semanticFormatterCallback: (v) =>
                'Usual spend ${formatPrice(v.round())} a piece',
            onChanged: (v) => c.setBudget(v.round()),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('₹500', style: AppText.mono(10, color: AppColors.dim)),
            Text('₹15,000+', style: AppText.mono(10, color: AppColors.dim)),
          ],
        ),
      ],
    );
  }
}

// ───────────────────────────────────────────────────────────────────── fit

class FitStep extends ConsumerWidget {
  const FitStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final picks = ref.watch(onboardingProvider);
    final c = ref.read(onboardingProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const GroupLabel('HOW DO YOU LIKE IT TO SIT'),
        const SizedBox(height: 10),
        for (var i = 0; i < OnboardingData.fits.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          Enter(
            delay: _ms(i * 90),
            dy: 16,
            child: _FitRow(
              fit: OnboardingData.fits[i],
              on: picks.fit == OnboardingData.fits[i].id,
              onTap: () => c.setFit(OnboardingData.fits[i].id),
            ),
          ),
        ],
        const SizedBox(height: 26),
        const BudgetPicker(),
      ],
    );
  }
}

class _FitRow extends StatelessWidget {
  const _FitRow({required this.fit, required this.on, required this.onTap});
  final FitOption fit;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return LabelledTap(
      onTap: onTap,
      scale: 0.98,
      semanticLabel: '${fit.label}, ${fit.desc}${on ? ', picked' : ''}',
      selects: true,
      child: AnimatedContainer(
        duration: Motion.quick,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: on ? AppColors.cyan : AppColors.elevated,
            width: on ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  fit.label,
                  style: AppText.manrope(14, weight: FontWeight.w600),
                ),
                Text(fit.desc, style: AppText.mono(11, color: AppColors.muted)),
              ],
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, box) => Stack(
                children: [
                  Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: AppColors.elevated,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOutBack,
                    height: 6,
                    width: box.maxWidth * fit.bar / 100,
                    decoration: BoxDecoration(
                      color: on ? AppColors.cyan : AppColors.dim,
                      borderRadius: BorderRadius.circular(3),
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

// ──────────────────────────────────────────────────────────── name / join

/// The little tilted Drip List Pass. On the name step it takes the name as
/// it's typed, so the name visibly lands on the pass; on the join step it
/// carries the access number.
class _PassChip extends StatelessWidget {
  const _PassChip(this.detail, {this.placeholder = false});
  final String detail;

  /// Nothing typed yet: the slot shows what goes there, quietly.
  final bool placeholder;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -3 * math.pi / 180,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.red),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('DRIP LIST PASS', style: AppText.fredoka(14)),
            const SizedBox(width: 10),
            Flexible(
              child: AnimatedDefaultTextStyle(
                duration: Motion.dur(context, Motion.quick),
                style: AppText.mono(
                  11,
                  color: placeholder
                      ? AppColors.red.withValues(alpha: 0.45)
                      : AppColors.red,
                ),
                child: Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NameStep extends ConsumerWidget {
  const NameStep({
    super.key,
    required this.controller,
    required this.handle,
    required this.onChanged,
    required this.onSubmitted,
  });
  final TextEditingController controller;
  final String handle;
  final ValueChanged<String> onChanged;

  /// The keyboard's "done": same as the button below.
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Enter(
          dy: 10,
          child: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, v, _) {
              final name = v.text.trim();
              return _PassChip(
                name.isEmpty ? 'YOUR NAME' : name.toUpperCase(),
                placeholder: name.isEmpty,
              );
            },
          ),
        ),
        const SizedBox(height: 22),
        const Enter(child: Eyebrow('ONE MORE THING')),
        const SizedBox(height: 12),
        Enter(
          delay: _ms(80),
          child: Text(
            'WHAT DO WE\nCALL YOU?',
            style: AppText.display(34, lineHeight: 40),
          ),
        ),
        const SizedBox(height: 12),
        Enter(
          delay: _ms(160),
          child: Text(
            'Your name goes on your Drip ticket. Make it look good.',
            style: AppText.manrope(15, weight: FontWeight.w700, lineHeight: 22),
          ),
        ),
        const SizedBox(height: 24),
        Enter(
          delay: _ms(240),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: controller.text.isEmpty
                        ? AppColors.elevated
                        : AppColors.cyan,
                  ),
                ),
                child: TextField(
                  controller: controller,
                  onChanged: onChanged,
                  onSubmitted: (_) => onSubmitted(),
                  // Keep focus (and the keyboard) on "done": if the name isn't
                  // valid yet the user is still typing; if it is, the step
                  // changes and the field goes away anyway.
                  onEditingComplete: () {},
                  // The only thing to do here, so the keyboard comes up ready.
                  autofocus: controller.text.isEmpty,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.givenName],
                  // With the keyboard up, keep the handle preview below the
                  // field in view too: it's the feedback for what's typed.
                  scrollPadding: const EdgeInsets.fromLTRB(20, 20, 20, 64),
                  autocorrect: false,
                  maxLength: 18,
                  textCapitalization: TextCapitalization.words,
                  cursorColor: AppColors.red,
                  style: AppText.manrope(16),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    counterText: '',
                    hintText: 'Your first name',
                    hintStyle: AppText.manrope(16, color: AppColors.muted),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'YOUR HANDLE',
                    style: AppText.mono(11, color: AppColors.muted),
                  ),
                  Text(
                    '@$handle',
                    style: AppText.mono(11, color: AppColors.cyan),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────── build

/// The heading shared by the build beat and the finished ticket, so the
/// ticket below it sits in exactly the same place on both.
class _TicketHeader extends StatelessWidget {
  const _TicketHeader({required this.eyebrow, required this.color});
  final String eyebrow;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Eyebrow(eyebrow, color: color),
        const SizedBox(height: 8),
        Semantics(
          header: true,
          child: Text(
            'YOUR DRIP TICKET.',
            textAlign: TextAlign.center,
            style: AppText.display(26, lineHeight: 32),
          ),
        ),
      ],
    );
  }
}

/// "Your Drip is being assembled": the ticket prints in front of the user,
/// each field filling in as its line is read, then the stamp lands. Same
/// length as before; nothing waits longer than it did.
class BuildStep extends ConsumerWidget {
  const BuildStep({super.key, required this.progress});

  /// 0–100.
  final double progress;

  static const _lines = [
    (0, 'Reading your eras'),
    (20, 'Mixing your palette'),
    (42, 'Pulling matching fits'),
    (64, 'Briefing Taylor'),
    (84, 'Printing your ticket'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = TicketInfo(ref.watch(onboardingProvider));
    final line = _lines.lastWhere((l) => progress >= l.$1).$2;
    final done = progress >= 100;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Announced as it changes: what's being read, and how far along.
        Semantics(
          liveRegion: true,
          label: done ? 'Ticket printed' : line,
          child: ExcludeSemantics(
            child: _TicketHeader(
              eyebrow: done
                  ? 'Calibration secured'
                  : '$line · ${progress.floor()}%',
              color: done ? AppColors.cyan : AppColors.red,
            ),
          ),
        ),
        const SizedBox(height: 20),
        DripTicket(info: info, progress: progress / 100),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────── ticket

class TicketStep extends ConsumerStatefulWidget {
  const TicketStep({super.key, this.printed = false});

  /// Arrived straight from the build beat: the ticket is already on screen
  /// and finished, so it stays put instead of entering again.
  final bool printed;

  @override
  ConsumerState<TicketStep> createState() => _TicketStepState();
}

class _TicketStepState extends ConsumerState<TicketStep> {
  double _tx = 0, _ty = 0;

  @override
  Widget build(BuildContext context) {
    final info = TicketInfo(ref.watch(onboardingProvider));
    final p = info.p;

    final prepared = [
      (
        '${p.name.trim().isNotEmpty ? '${p.name.trim()}, ' : ''}${info.fits} fits are queued in your Scroll',
        info.eraLabels.isNotEmpty
            ? 'Tuned to ${info.eraLabels.take(3).join(', ')}${p.genres.isNotEmpty ? ' with a ${p.genres.first.toLowerCase()} streak.' : '.'}'
            : 'A mixed feed to learn from.',
      ),
      (
        '${info.season} colour season',
        '${info.colours.isEmpty ? 3 : info.colours.length} shades locked into your Colour Theory profile.',
      ),
      (
        'Taylor is briefed',
        '${info.fit.label} fits, around ${info.budget} a piece${p.brands.isNotEmpty ? ', leaning ${info.brandLabels.first}.' : '.'}',
      ),
      (
        '${math.max(6, p.clothes.length + p.accessories.length + 2)} starter pieces for your wardrobe',
        p.clothes.isNotEmpty
            ? '${p.clothes.take(3).join(', ')} and more, ready to tag.'
            : 'Add your first piece from the camera.',
      ),
    ];

    final ticket = GestureDetector(
      // A light tilt under the finger: something to hold, not a screenshot.
      onPanUpdate: Motion.reduced(context)
          ? null
          : (d) {
              final box = context.size;
              if (box == null) return;
              setState(() {
                _tx = ((d.localPosition.dy / 480) - .5) * -10;
                _ty = ((d.localPosition.dx / box.width) - .5) * 12;
              });
            },
      onPanEnd: (_) => setState(() => _tx = _ty = 0),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        transformAlignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.0011)
          ..rotateX(_tx * math.pi / 180)
          ..rotateY(_ty * math.pi / 180),
        child: DripTicket(info: info, entrance: !widget.printed),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _TicketHeader(
          eyebrow: 'Calibration secured',
          color: AppColors.cyan,
        ),
        const SizedBox(height: 20),
        if (widget.printed)
          ticket
        else
          Enter(delay: _ms(200), dy: 40, child: ticket),
        const SizedBox(height: 22),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Text(
              'One tap with Google saves your Drip and creates your account. '
              'No passwords.',
              textAlign: TextAlign.center,
              style: AppText.manrope(
                14,
                color: AppColors.muted,
                lineHeight: 20,
              ),
            ),
          ),
        ),
        const SizedBox(height: 26),
        // Same width as the ticket: one composition on big screens.
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const GroupLabel('PREPARED FOR YOU'),
                const SizedBox(height: 12),
                for (var i = 0; i < prepared.length; i++)
                  Enter(
                    delay: _ms((widget.printed ? 250 : 1500) + i * 120),
                    dy: 14,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.elevated),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppColors.cyan.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '✓',
                                style: AppText.manrope(
                                  14,
                                  color: AppColors.cyan,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    prepared[i].$1,
                                    style: AppText.manrope(
                                      14,
                                      weight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    prepared[i].$2,
                                    style: AppText.manrope(
                                      13,
                                      color: AppColors.muted,
                                      lineHeight: 18,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
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
