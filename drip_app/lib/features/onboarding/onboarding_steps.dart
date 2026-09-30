import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/assets.dart';
import '../../core/motion.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/brand.dart';
import '../../core/widgets/drip_image.dart';
import '../../core/widgets/tap.dart';
import '../session/session_controller.dart';
import 'onboarding_data.dart';
import 'onboarding_widgets.dart';

Duration _ms(num v) => Duration(milliseconds: v.round());

/// Width of one cell in a [cols]-column grid with [gap] between cells.
double _cell(double maxWidth, int cols, double gap) =>
    (maxWidth - gap * (cols - 1)) / cols;

// ───────────────────────────────────────────────────────────────── welcome

class WelcomeStep extends StatelessWidget {
  const WelcomeStep({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 70),
        Enter(
          delay: _ms(100),
          dy: 22,
          child: const Align(
            alignment: Alignment.centerLeft,
            child: DripWordmark(height: 72),
          ),
        ),
        const SizedBox(height: 26),
        Enter(
          delay: _ms(350),
          dy: 30,
          child: Text(
            'THE FIT\nFINDS YOU.',
            style: AppText.display(44, lineHeight: 48),
          ),
        ),
        const SizedBox(height: 20),
        Enter(
          delay: _ms(1000),
          dy: 22,
          child: Text(
            'Discover complete outfits curated for your era. Scroll, vibe, '
            'and save fits that hit different. No crew required.',
            style: AppText.manrope(16, color: AppColors.muted, lineHeight: 24),
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────── statement

class StatementStep extends StatelessWidget {
  const StatementStep({super.key});

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
        const Enter(dy: 8, child: Eyebrow('HARD TRUTH №1')),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          children: [
            for (var i = 0; i < _words.length; i++)
              Enter(
                delay: _ms(300 + i * 90),
                dy: 28,
                child: _Word(_words[i], struck: i == 0),
              ),
          ],
        ),
        const SizedBox(height: 22),
        Enter(
          delay: const Duration(seconds: 2),
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
      _t = Timer(const Duration(milliseconds: 1300), () {
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
                duration: const Duration(milliseconds: 500),
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

// ──────────────────────────────────────────────────────────────────── intro

class IntroStep extends StatelessWidget {
  const IntroStep({super.key});

  static const _cards = [
    ('01', 'SCROLL', 'Browse handpicked editorial looks customized daily.'),
    (
      '02',
      'SAVE',
      'Double-tap to save looks to your permanent personal vault.',
    ),
    ('03', 'BUILD', 'Mix and match accessories, outerwear, and footwear.'),
    ('04', 'WEAR', 'Experience your virtual try-on and step into the vibe.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < _cards.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          Enter(
            delay: _ms(i * 120),
            dy: 22,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.elevated),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.elevated,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _cards[i].$1,
                          style: AppText.mono(
                            14,
                            color: AppColors.cyan,
                            weight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_cards[i].$2, style: AppText.display(15)),
                            const SizedBox(height: 6),
                            Text(
                              _cards[i].$3,
                              style: AppText.manrope(
                                14,
                                color: AppColors.muted,
                                lineHeight: 19,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: -16,
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.red, AppColors.cyan],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
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
                    child: Tap(
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
            const SizedBox(height: 28),
            const Enter(
              delay: Duration(milliseconds: 600),
              dy: 8,
              child: GroupLabel('GO DEEPER · OPTIONAL'),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (var i = 0; i < OnboardingData.genres.length; i++)
                  Enter(
                    delay: _ms(500 + i * 50),
                    dy: 30,
                    child: SizedBox(
                      width: era,
                      height: 132,
                      child: _GenreTile(
                        index: i,
                        on: picks.genres.contains(OnboardingData.genres[i]),
                        onTap: () => c.toggleGenre(OnboardingData.genres[i]),
                      ),
                    ),
                  ),
              ],
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
    return Tap(
      onTap: onTap,
      scale: 0.95,
      semanticLabel: '${era.label}${on ? ', picked' : ''}',
      child: AnimatedScale(
        scale: on ? 1.02 : 1,
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
                scale: on ? 1.1 : 1,
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
    return Tap(
      onTap: onTap,
      scale: 0.96,
      semanticLabel: '$label${on ? ', picked' : ''}',
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
              scale: on ? 1.1 : 1,
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
                    Row(
                      children: [
                        for (final o in all)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 500),
                            curve: Motion.out,
                            width: picks.paletteIds.contains(o.id)
                                ? (box.maxWidth - 2) / chosen.length
                                : 0,
                            color: Color(o.hex),
                          ),
                      ],
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
                  child: Tap(
                    onTap: () => setState(() => _custom = !_custom),
                    scale: 0.9,
                    semanticLabel: 'Add your own colour',
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

  Widget _customPanel(OnboardingController c) {
    final hex =
        '#${(_picked.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
    return Container(
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
                        cursorColor: AppColors.red,
                        style: AppText.manrope(14),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          counterText: '',
                          hintText: 'Name it, e.g. Mustard',
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
            value: _hue / 360,
            colors: [
              for (var h = 0; h <= 360; h += 60)
                HSLColor.fromAHSL(1, h.toDouble(), 0.85, 0.55).toColor(),
            ],
            onChanged: (v) => setState(() => _hue = v * 360),
          ),
          const SizedBox(height: 10),
          _GradientSlider(
            value: _light,
            colors: [
              HSLColor.fromAHSL(1, _hue, 0.85, 0.12).toColor(),
              HSLColor.fromAHSL(1, _hue, 0.85, 0.5).toColor(),
              HSLColor.fromAHSL(1, _hue, 0.85, 0.92).toColor(),
            ],
            onChanged: (v) => setState(() => _light = v.clamp(0.1, 0.92)),
          ),
          const SizedBox(height: 16),
          Tap(
            onTap: () {
              final ok = c.addCustomColour(_name.text, _picked.toARGB32());
              if (ok) {
                widget.onGlow(_picked);
                _name.clear();
                setState(() => _custom = false);
              } else {
                ScaffoldMessenger.maybeOf(context)
                  ?..hideCurrentSnackBar()
                  ..showSnackBar(
                    const SnackBar(content: Text('Six custom colours max')),
                  );
              }
            },
            scale: 0.97,
            semanticLabel: 'Add to my palette',
            child: Container(
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.elevated,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'ADD TO MY PALETTE',
                style: AppText.mono(
                  11,
                  weight: FontWeight.w500,
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

class _GradientSlider extends StatelessWidget {
  const _GradientSlider({
    required this.value,
    required this.colors,
    required this.onChanged,
  });
  final double value;
  final List<Color> colors;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        void at(double dx) => onChanged((dx / box.maxWidth).clamp(0, 1));
        return GestureDetector(
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
        Tap(
          onTap: onTap,
          scale: 0.9,
          semanticLabel: '$name${on ? ', picked' : ''}',
          child: Column(
            children: [
              AnimatedScale(
                scale: on ? 1.08 : 1,
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
                maxLines: 1,
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
          Positioned(
            top: -6,
            right: 2,
            child: Tap(
              onTap: onDelete,
              semanticLabel: 'Remove $name',
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
    return Tap(
      onTap: onTap,
      scale: 0.96,
      semanticLabel: '$label${on ? ', picked' : ''}',
      child: AnimatedScale(
        scale: on ? 1.02 : 1,
        duration: Motion.content,
        curve: Curves.easeOutBack,
        child: AnimatedContainer(
          duration: Motion.quick,
          decoration: BoxDecoration(
            color: on
                ? AppColors.cyan.withValues(alpha: 0.14)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: on ? AppColors.cyan : AppColors.elevated,
              width: 2,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned.fill(child: CustomPaint(painter: _StripesPainter())),
              Positioned(
                left: 10,
                right: 10,
                top: 10,
                bottom: 26,
                child: Center(
                  child: AnimatedScale(
                    scale: on ? 1.08 : 1,
                    duration: const Duration(milliseconds: 500),
                    curve: Motion.out,
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.manrope(
                        20,
                        weight: FontWeight.w800,
                        lineHeight: 22,
                        color: AppColors.cream.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(top: 8, right: 10, child: TickBadge(on: on)),
              Positioned(
                left: 12,
                right: 12,
                bottom: 8,
                child: Text(
                  sub,
                  style: AppText.mono(
                    10,
                    color: AppColors.dim,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StripesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AppColors.cream.withValues(alpha: 0.045)
      ..strokeWidth = 8;
    for (var x = -size.height; x < size.width; x += 16 * math.sqrt2) {
      canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), p);
    }
  }

  @override
  bool shouldRepaint(_StripesPainter old) => false;
}

// ───────────────────────────────────────────────────────────────────── fit

class FitStep extends ConsumerWidget {
  const FitStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final picks = ref.watch(onboardingProvider);
    final c = ref.read(onboardingProvider.notifier);
    final budget = picks.budget;
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

class _FitRow extends StatelessWidget {
  const _FitRow({required this.fit, required this.on, required this.onTap});
  final FitOption fit;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tap(
      onTap: onTap,
      scale: 0.98,
      semanticLabel: '${fit.label}, ${fit.desc}${on ? ', picked' : ''}',
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

class NameStep extends StatelessWidget {
  const NameStep({
    super.key,
    required this.controller,
    required this.handle,
    required this.onChanged,
  });
  final TextEditingController controller;
  final String handle;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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

class JoinStep extends StatelessWidget {
  const JoinStep({super.key, required this.name, required this.handle});
  final String name;
  final String handle;

  @override
  Widget build(BuildContext context) {
    final who = (name.trim().isEmpty ? 'FRIEND' : name.trim()).toUpperCase();
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Enter(
          dy: 10,
          child: Transform.rotate(
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
                  Text(
                    '#77-DRIP-9082',
                    style: AppText.mono(11, color: AppColors.red),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 22),
        const Enter(
          delay: Duration(milliseconds: 100),
          child: Eyebrow('TICKET PRINTED · LAST STEP'),
        ),
        const SizedBox(height: 12),
        Enter(
          delay: _ms(180),
          child: Text(
            'ONE TAP AND YOU’RE IN, $who.',
            style: AppText.display(34, lineHeight: 40),
          ),
        ),
        const SizedBox(height: 12),
        Enter(
          delay: _ms(260),
          child: Text(
            'Drip uses your Google account. No passwords to remember. '
            'Signing in creates your account and keeps your ticket.',
            style: AppText.manrope(15, color: AppColors.muted, lineHeight: 22),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'YOUR HANDLE',
              style: AppText.mono(11, color: AppColors.muted),
            ),
            Text('@$handle', style: AppText.mono(11, color: AppColors.cyan)),
          ],
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────── build

class BuildStep extends StatelessWidget {
  const BuildStep({super.key, required this.progress, required this.colours});

  /// 0–100.
  final double progress;
  final List<Color> colours;

  static const _lines = [
    (0, 'Reading your eras'),
    (20, 'Mixing your palette'),
    (42, 'Pulling matching fits'),
    (64, 'Briefing Taylor'),
    (84, 'Printing your ticket'),
  ];

  @override
  Widget build(BuildContext context) {
    final orbit = colours.isEmpty
        ? const [AppColors.cream, AppColors.red, AppColors.cyan]
        : colours;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 250,
          height: 250,
          child: Stack(
            children: [
              for (var i = 0; i < orbit.length; i++)
                Positioned(
                  left:
                      125 + math.cos(i / orbit.length * math.pi * 2) * 106 - 7,
                  top: 125 + math.sin(i / orbit.length * math.pi * 2) * 106 - 7,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: orbit[i],
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.cream),
                    ),
                  ),
                ),
              Positioned.fill(
                child: CustomPaint(painter: _RingPainter(progress / 100)),
              ),
              Center(
                child: Text.rich(
                  TextSpan(
                    text: '${progress.floor()}',
                    style: AppText.display(40),
                    children: [
                      TextSpan(
                        text: '%',
                        style: AppText.display(22, color: AppColors.cyan),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        for (var i = 0; i < _lines.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _BuildLine(
              text: _lines[i].$2,
              started: progress >= _lines[i].$1,
              done:
                  progress >= (i + 1 < _lines.length ? _lines[i + 1].$1 : 101),
            ),
          ),
      ],
    );
  }
}

class _BuildLine extends StatelessWidget {
  const _BuildLine({
    required this.text,
    required this.started,
    required this.done,
  });
  final String text;
  final bool started;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final active = started && !done;
    return AnimatedOpacity(
      opacity: started ? 1 : 0.35,
      duration: const Duration(milliseconds: 400),
      child: AnimatedSlide(
        offset: Offset(started ? 0 : 0.04, 0),
        duration: const Duration(milliseconds: 400),
        curve: Motion.out,
        child: Row(
          children: [
            SizedBox(
              width: 16,
              child: Text(
                done
                    ? '✓'
                    : active
                    ? '●'
                    : '○',
                textAlign: TextAlign.center,
                style: AppText.mono(
                  12,
                  color: done
                      ? AppColors.cyan
                      : active
                      ? AppColors.red
                      : AppColors.dim,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              text,
              style: AppText.mono(
                12,
                letterSpacing: 0.5,
                color: active
                    ? AppColors.cream
                    : done
                    ? AppColors.muted
                    : AppColors.dim,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final rect = Rect.fromCircle(center: c, radius: 80);
    canvas.drawArc(
      rect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = AppColors.elevated,
    );
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * t.clamp(0, 1),
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..color = AppColors.red,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.t != t;
}

// ─────────────────────────────────────────────────────────────────── ticket

/// What the ticket and the "prepared for you" list are built from.
class TicketInfo {
  TicketInfo(this.p) {
    for (final c in OnboardingData.colours) {
      if (p.paletteIds.contains(c.id)) colours.add((c.id, c.name, c.hex));
    }
    for (final c in p.customColours) {
      if (p.paletteIds.contains(c.id)) colours.add((c.id, c.name, c.hex));
    }
  }

  final OnboardingState p;
  final colours = <(String, String, int)>[];

  List<String> get eraLabels => [
    for (final e in OnboardingData.eras)
      if (p.moodIds.contains(e.id)) e.label,
  ];

  FitOption get fit => OnboardingData.fits.firstWhere(
    (f) => f.id == p.fit,
    orElse: () => OnboardingData.fits[1],
  );

  String get handle => handleFor(p.name);

  static String handleFor(String name) {
    final slug = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return '${slug.isEmpty ? 'yourname' : slug}_77';
  }

  String get budget =>
      '${formatPrice(p.budget)}${p.budget >= OnboardingData.budgetMax ? '+' : ''}';

  String get season {
    if (colours.isEmpty) return 'Soft Summer';
    final warm = colours.where((c) => OnboardingData.isWarm(c.$1, c.$3)).length;
    final cool = colours.length - warm;
    return warm > cool
        ? 'Warm Autumn'
        : cool > warm
        ? 'Cool Winter'
        : 'Clear Spring';
  }

  int get fits =>
      140 +
      p.moodIds.length * 96 +
      p.genres.length * 31 +
      p.paletteIds.length * 12;
}

class TicketStep extends ConsumerStatefulWidget {
  const TicketStep({super.key});

  @override
  ConsumerState<TicketStep> createState() => _TicketStepState();
}

class _TicketStepState extends ConsumerState<TicketStep> {
  double _tx = 0, _ty = 0;

  static const _bars = [
    1,
    0,
    0,
    1,
    0,
    0,
    1,
    1,
    0,
    1,
    0,
    0,
    1,
    0,
    1,
    1,
    0,
    0,
    1,
    0,
    0,
    1,
    0,
    0,
  ];

  @override
  Widget build(BuildContext context) {
    final info = TicketInfo(ref.watch(onboardingProvider));
    final p = info.p;
    const ink = AppColors.base;
    const faint = Color(0xFF5B5346);
    const stamp = Color(0xFFC41818);

    Widget label(String t) =>
        Text(t, style: AppText.mono(9, color: faint, letterSpacing: 2));
    Widget value(String t, {Color color = ink}) => Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        t,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: AppText.mono(12, color: color, weight: FontWeight.w500),
      ),
    );

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
        '${info.fit.label} fits, around ${info.budget} a piece${p.brands.isNotEmpty ? ', leaning ${p.brands.first}.' : '.'}',
      ),
      (
        '${math.max(6, p.clothes.length + p.accessories.length + 2)} starter pieces for your wardrobe',
        p.clothes.isNotEmpty
            ? '${p.clothes.take(3).join(', ')} and more, ready to tag.'
            : 'Add your first piece from the camera.',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Column(
          children: [
            const Eyebrow('CALIBRATION SECURED', color: AppColors.cyan),
            const SizedBox(height: 8),
            Text(
              'YOUR DRIP TICKET.',
              textAlign: TextAlign.center,
              style: AppText.display(26, lineHeight: 32),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Enter(
          delay: const Duration(milliseconds: 200),
          dy: 40,
          child: GestureDetector(
            onPanUpdate: (d) {
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
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x8C000000),
                    blurRadius: 40,
                    offset: Offset(0, 24),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  // A gradient replaces `color`, so the paper tones are opaque.
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color.alphaBlend(
                          const Color(0x99FFFFFF),
                          AppColors.cream,
                        ),
                        AppColors.cream,
                        Color.alphaBlend(
                          const Color(0x33786950),
                          AppColors.cream,
                        ),
                      ],
                      stops: const [0, 0.45, 1],
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        right: -46,
                        top: 34,
                        child: Opacity(
                          opacity: 0.075,
                          child: Transform.rotate(
                            angle: -8 * math.pi / 180,
                            child: const DripWordmark(
                              height: 250,
                              variant: WordmarkVariant.light,
                            ),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                color: ink.withValues(alpha: 0.28),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(28, 28, 28, 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'THE DRIP LIST',
                                      style: AppText.mono(
                                        10,
                                        color: ink,
                                        letterSpacing: 2.5,
                                        weight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      'Nº 0001 · ESTD 2077',
                                      style: AppText.mono(
                                        10,
                                        color: stamp,
                                        letterSpacing: 1.5,
                                        weight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Drip List Pass',
                                  style: AppText.fredoka(22, color: ink),
                                ),
                                const SizedBox(height: 22),
                                label('STYLE DNA'),
                                const SizedBox(height: 6),
                                Text(
                                  info.eraLabels.isEmpty
                                      ? 'YOUR ERA'
                                      : info.eraLabels
                                            .take(2)
                                            .join(' + ')
                                            .toUpperCase(),
                                  style: AppText.display(
                                    27,
                                    lineHeight: 31,
                                    color: ink,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                SizedBox(
                                  width: 220,
                                  height: 14,
                                  child: DrawOn(
                                    delay: const Duration(milliseconds: 600),
                                    color: stamp,
                                    width: 2.5,
                                    builder: (s) => Path()
                                      ..moveTo(
                                        2 * s.width / 230,
                                        8 * s.height / 14,
                                      )
                                      ..cubicTo(
                                        40 * s.width / 230,
                                        2 * s.height / 14,
                                        70 * s.width / 230,
                                        12 * s.height / 14,
                                        110 * s.width / 230,
                                        6 * s.height / 14,
                                      )
                                      ..cubicTo(
                                        150 * s.width / 230,
                                        0,
                                        180 * s.width / 230,
                                        3 * s.height / 14,
                                        226 * s.width / 230,
                                        9 * s.height / 14,
                                      ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  p.genres.isEmpty
                                      ? 'Every era, no rules.'
                                      : '${p.genres.take(3).join(' · ')} energy.',
                                  style: AppText.manrope(
                                    13,
                                    weight: FontWeight.w700,
                                    lineHeight: 18,
                                    color: const Color(0xFF3A342A),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          label('HOLDER'),
                                          value(
                                            p.name.trim().isEmpty
                                                ? 'You'
                                                : p.name.trim(),
                                          ),
                                          const SizedBox(height: 16),
                                          label('PALETTE'),
                                          const SizedBox(height: 6),
                                          Wrap(
                                            spacing: 5,
                                            runSpacing: 5,
                                            children: [
                                              for (final c in info.colours.take(
                                                6,
                                              ))
                                                Container(
                                                  width: 20,
                                                  height: 20,
                                                  decoration: BoxDecoration(
                                                    color: Color(c.$3),
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                      color: ink.withValues(
                                                        alpha: 0.55,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          label('FIT · SPEND'),
                                          value(
                                            '${info.fit.label} · ≤${info.budget}',
                                          ),
                                          const SizedBox(height: 16),
                                          label('SEASON'),
                                          value(info.season),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // The perforation, with its two notches.
                          SizedBox(
                            height: 1,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Positioned.fill(
                                  child: CustomPaint(
                                    painter: _PerforationPainter(
                                      ink.withValues(alpha: 0.4),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  left: -10,
                                  top: -10,
                                  child: _Notch(),
                                ),
                                Positioned(
                                  right: -10,
                                  top: -10,
                                  child: _Notch(),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(28, 20, 28, 24),
                            child: Column(
                              children: [
                                SizedBox(
                                  height: 30,
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      for (
                                        var i = 0;
                                        i < _bars.length;
                                        i++
                                      ) ...[
                                        if (i > 0) const SizedBox(width: 4),
                                        Expanded(
                                          child: DecoratedBox(
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(1),
                                              color: ink.withValues(
                                                alpha: _bars[i] == 1
                                                    ? 0.88
                                                    : 0.14,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        label('ACCESS NO'),
                                        const SizedBox(height: 2),
                                        Text(
                                          '#77-DRIP-9082',
                                          style: AppText.mono(
                                            13,
                                            color: stamp,
                                            weight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Transform.rotate(
                                      angle: -12 * math.pi / 180,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          border: Border.all(
                                            color: stamp,
                                            width: 2,
                                          ),
                                        ),
                                        child: Text(
                                          'VERIFIED ✦',
                                          style: AppText.mono(
                                            9,
                                            color: stamp,
                                            letterSpacing: 2,
                                            weight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 28),
        const GroupLabel('PREPARED FOR YOU'),
        const SizedBox(height: 12),
        for (var i = 0; i < prepared.length; i++)
          Enter(
            delay: _ms(1500 + i * 180),
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
                        style: AppText.manrope(14, color: AppColors.cyan),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            prepared[i].$1,
                            style: AppText.manrope(14, weight: FontWeight.w700),
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
    );
  }
}

class _Notch extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: 20,
    height: 20,
    decoration: const BoxDecoration(
      shape: BoxShape.circle,
      color: AppColors.base,
    ),
  );
}

class _PerforationPainter extends CustomPainter {
  _PerforationPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (var x = 12.0; x < size.width - 12; x += 8) {
      canvas.drawLine(Offset(x, 0), Offset(x + 4, 0), paint);
    }
  }

  @override
  bool shouldRepaint(_PerforationPainter old) => old.color != color;
}

/// Draws a stroke on along [builder]'s path after [delay] (a pen signing).
class DrawOn extends StatefulWidget {
  const DrawOn({
    super.key,
    required this.builder,
    required this.color,
    this.width = 2,
    this.delay = Duration.zero,
  });

  final Path Function(Size) builder;
  final Color color;
  final double width;
  final Duration delay;

  @override
  State<DrawOn> createState() => _DrawOnState();
}

class _DrawOnState extends State<DrawOn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  Timer? _t;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (Motion.reduced(context)) {
      _c.value = 1;
    } else {
      _t = Timer(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _t?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (context, _) => CustomPaint(
      painter: _DrawPainter(
        widget.builder,
        widget.color,
        widget.width,
        _c.value,
      ),
    ),
  );
}

class _DrawPainter extends CustomPainter {
  _DrawPainter(this.builder, this.color, this.width, this.t);
  final Path Function(Size) builder;
  final Color color;
  final double width;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;
    for (final m in builder(size).computeMetrics()) {
      canvas.drawPath(m.extractPath(0, m.length * t), paint);
    }
  }

  @override
  bool shouldRepaint(_DrawPainter old) => old.t != t;
}
