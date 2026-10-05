import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../core/motion.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/brand.dart';
import '../home/occasions.dart';
import '../session/session_controller.dart';
import 'handle.dart';
import 'onboarding_data.dart';

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

  /// The occasions picked, in the order they're offered.
  List<String> get occasionLabels => [
    for (final o in Occasions.all)
      if (p.occasions.contains(o.id)) o.label,
  ];

  /// The labels picked, in the order they were offered.
  List<String> get brandLabels => [
    for (final b in OnboardingData.brands)
      if (p.brands.contains(b)) b,
  ];

  FitOption get fit => OnboardingData.fits.firstWhere(
    (f) => f.id == p.fit,
    orElse: () => OnboardingData.fits[1],
  );

  String get holder => p.name.trim().isEmpty ? 'You' : p.name.trim();

  String get handle => handleFor(p.name);

  /// See [Handles.forName]: every valid name gets a deliberate handle.
  static String handleFor(String name) => Handles.forName(name);

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

  String get styleDna => eraLabels.isEmpty
      ? 'YOUR ERA'
      : eraLabels.take(2).join(' + ').toUpperCase();

  int get fits =>
      140 +
      p.moodIds.length * 96 +
      p.genres.length * 31 +
      p.paletteIds.length * 12;

  /// The whole ticket in one sentence, for screen readers.
  String get summary => [
    'Your Drip ticket',
    'holder $holder',
    if (eraLabels.isNotEmpty) 'style ${eraLabels.take(2).join(' and ')}',
    '$season colour season',
    'spends up to $budget a piece',
    if (occasionLabels.isNotEmpty) 'dressing for ${occasionLabels.join(', ')}',
    if (brandLabels.isNotEmpty) 'labels ${brandLabels.join(', ')}',
  ].join(', ');
}

/// The Drip List Pass: one object, from the moment it starts printing (the
/// build beat, [progress] < 1, fields filling in as each part is "read") to
/// the finished ticket with its stamp.
///
/// The two halves are cut apart by real notches, so whatever is behind the
/// ticket (the glow) shows through them, like a punched stub.
class DripTicket extends StatefulWidget {
  const DripTicket({
    super.key,
    required this.info,
    this.progress = 1,
    this.entrance = false,
  });

  final TicketInfo info;

  /// 0–1: how far printing has got. 1 is the finished ticket.
  final double progress;

  /// A finished ticket shown fresh (not printed in front of the user): the
  /// signature draws and the stamp lands, once.
  final bool entrance;

  @override
  State<DripTicket> createState() => _DripTicketState();
}

class _DripTicketState extends State<DripTicket> {
  static const _ink = AppColors.base;
  static const _faint = Color(0xFF5B5346);
  static const _stamp = Color(0xFFC41818);
  static const _radius = 22.0;
  static const _notch = 11.0;

  static const _bars = [
    1, 0, 0, 1, 0, 0, 1, 1, 0, 1, 0, 0, //
    1, 0, 1, 1, 0, 0, 1, 0, 0, 1, 0, 0,
  ];

  double _stub = 0;
  bool _stampDown = false;
  Timer? _stampTimer;

  @override
  void initState() {
    super.initState();
    if (widget.entrance) {
      _stampTimer = Timer(const Duration(milliseconds: 1100), () {
        if (mounted) setState(() => _stampDown = true);
      });
    } else {
      _stampDown = widget.progress >= 1;
    }
  }

  @override
  void didUpdateWidget(DripTicket old) {
    super.didUpdateWidget(old);
    if (!widget.entrance && widget.progress >= 1) _stampDown = true;
  }

  @override
  void dispose() {
    _stampTimer?.cancel();
    super.dispose();
  }

  // What has been "read" so far, following the build lines.
  bool get _dna => widget.progress >= 0.2;
  bool get _palette => widget.progress >= 0.42;
  bool get _fit => widget.progress >= 0.64;
  bool get _labels => widget.progress >= 0.84;
  double get _printed => ((widget.progress - 0.84) / 0.16).clamp(0, 1);

  static String _short(List<String> items) => items.length <= 3
      ? items.join(' · ')
      : '${items.take(3).join(' · ')} +${items.length - 3}';

  Widget _label(String t) =>
      Text(t, style: AppText.mono(9, color: _faint, letterSpacing: 2));

  Widget _value(String t, {double size = 12}) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Text(
      t,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: AppText.mono(size, color: _ink, weight: FontWeight.w500),
    ),
  );

  Widget _field(String label, String value, {required bool on}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _label(label),
      _Reveal(on: on, child: _value(value)),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final info = widget.info;
    final p = info.p;
    final brands = info.brandLabels;
    final shape = _TicketBorder(
      radius: _radius,
      notch: _notch,
      fromBottom: _stub,
    );

    final body = Padding(
      padding: const EdgeInsets.fromLTRB(26, 26, 26, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: Wrap(
              // The stamp number drops under the title on the narrowest
              // phones instead of overflowing.
              alignment: WrapAlignment.spaceBetween,
              runSpacing: 4,
              children: [
                Text(
                  'THE DRIP LIST',
                  style: AppText.mono(
                    10,
                    color: _ink,
                    letterSpacing: 2.5,
                    weight: FontWeight.w500,
                  ),
                ),
                Text(
                  'Nº 0001 · ESTD 2077',
                  style: AppText.mono(
                    10,
                    color: _stamp,
                    letterSpacing: 1.5,
                    weight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text('Drip List Pass', style: AppText.fredoka(22, color: _ink)),
          const SizedBox(height: 22),
          _label('STYLE DNA'),
          const SizedBox(height: 6),
          _Reveal(
            on: _dna,
            child: Text(
              info.styleDna,
              style: AppText.display(27, lineHeight: 31, color: _ink),
            ),
          ),
          const SizedBox(height: 2),
          SizedBox(
            width: 220,
            height: 14,
            child: DrawOn(
              play: _dna,
              animate: widget.entrance || widget.progress < 1,
              delay: Duration(milliseconds: widget.entrance ? 600 : 0),
              color: _stamp,
              width: 2.5,
              builder: (s) => Path()
                ..moveTo(2 * s.width / 230, 8 * s.height / 14)
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
          const SizedBox(height: 8),
          _Reveal(
            on: _dna,
            child: Text(
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
          ),
          const SizedBox(height: 20),
          // The holder leads: the name is what makes the pass yours.
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('HOLDER'),
                    _value(info.holder, size: 15),
                    if (info.p.name.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '@${info.handle}',
                          style: AppText.mono(
                            10,
                            color: _faint,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _field('SEASON', info.season, on: _palette)),
              const SizedBox(width: 14),
              Expanded(
                child: _field('SPEND', '≤${info.budget} a piece', on: _fit),
              ),
            ],
          ),
          if (brands.isNotEmpty) ...[
            const SizedBox(height: 16),
            _field(
              'LABELS',
              brands.length <= 3
                  ? brands.join(' · ')
                  : '${brands.take(3).join(' · ')} +${brands.length - 3}',
              on: _labels,
            ),
          ],
          if (info.occasionLabels.isNotEmpty) ...[
            const SizedBox(height: 16),
            _field('DRESSING FOR', _short(info.occasionLabels), on: _labels),
          ],
        ],
      ),
    );

    final stub = _MeasureHeight(
      onHeight: (h) {
        if (h != _stub) setState(() => _stub = h);
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(26, 18, 26, 22),
        child: Column(
          children: [
            SizedBox(
              height: 30,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < _bars.length; i++) ...[
                    if (i > 0) const SizedBox(width: 4),
                    Expanded(
                      // Bars print left to right in the last stretch.
                      child: AnimatedOpacity(
                        opacity: i / _bars.length < _printed ? 1 : 0.18,
                        duration: Motion.dur(context, Motion.quick),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(1),
                            color: _ink.withValues(
                              alpha: _bars[i] == 1 ? 0.88 : 0.14,
                            ),
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('ACCESS NO'),
                    const SizedBox(height: 2),
                    Text(
                      '#77-DRIP-9082',
                      style: AppText.mono(
                        13,
                        color: _stamp,
                        weight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                _Stamp(down: _stampDown),
              ],
            ),
          ],
        ),
      ),
    );

    return Semantics(
      label: widget.progress < 1 ? 'Your Drip ticket, printing' : info.summary,
      child: ExcludeSemantics(
        child: Center(
          child: ConstrainedBox(
            // A pass, not a banner: it keeps its proportions on big screens.
            constraints: const BoxConstraints(maxWidth: 420),
            child: DecoratedBox(
              decoration: ShapeDecoration(
                shape: shape,
                // A gradient replaces `color`, so the paper tones are opaque.
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.alphaBlend(const Color(0x99FFFFFF), AppColors.cream),
                    AppColors.cream,
                    Color.alphaBlend(const Color(0x33786950), AppColors.cream),
                  ],
                  stops: const [0, 0.45, 1],
                ),
                shadows: const [
                  BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 44,
                    spreadRadius: -12,
                    offset: Offset(0, 22),
                  ),
                ],
              ),
              child: ClipPath(
                clipper: ShapeBorderClipper(shape: shape),
                child: CustomPaint(
                  foregroundPainter: _FramePainter(
                    stub: _stub,
                    color: _ink.withValues(alpha: 0.26),
                    perforation: _ink.withValues(alpha: 0.4),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        right: -46,
                        top: 34,
                        child: Opacity(
                          opacity: 0.06,
                          child: Transform.rotate(
                            angle: -8 * math.pi / 180,
                            child: const DripWordmark(
                              height: 250,
                              variant: WordmarkVariant.mono,
                              color: _ink,
                            ),
                          ),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _PaletteBand(
                            colours: [
                              for (final c in info.colours.take(8)) Color(c.$3),
                            ],
                            on: _palette,
                          ),
                          body,
                          stub,
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The user's palette as the ticket's colour band, filling in left to right
/// once the palette is "mixed".
class _PaletteBand extends StatelessWidget {
  const _PaletteBand({required this.colours, required this.on});
  final List<Color> colours;
  final bool on;

  @override
  Widget build(BuildContext context) {
    final band = colours.isEmpty
        ? const [AppColors.red, AppColors.cyan]
        : colours;
    return SizedBox(
      height: 7,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < band.length; i++)
            Expanded(
              child: AnimatedOpacity(
                opacity: on ? 1 : 0,
                duration: Motion.dur(context, Motion.content),
                curve: Interval(
                  i / band.length * 0.6,
                  math.min(1, i / band.length * 0.6 + 0.5),
                  curve: Motion.out,
                ),
                child: ColoredBox(color: band[i]),
              ),
            ),
        ],
      ),
    );
  }
}

/// A field that is printed but not yet filled: a faint placeholder the exact
/// size of the value, which fades in over it. The layout never jumps.
class _Reveal extends StatelessWidget {
  const _Reveal({required this.on, required this.child});
  final bool on;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final d = Motion.dur(context, Motion.content);
    return Stack(
      children: [
        Positioned.fill(
          child: AnimatedOpacity(
            opacity: on ? 0 : 1,
            duration: d,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.base.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ),
        AnimatedOpacity(
          opacity: on ? 1 : 0,
          duration: d,
          curve: Motion.out,
          child: child,
        ),
      ],
    );
  }
}

/// "VERIFIED ✦", pressed onto the stub: it lands with a short drop in scale,
/// the way a rubber stamp does. Under reduced motion it simply appears.
class _Stamp extends StatelessWidget {
  const _Stamp({required this.down});
  final bool down;

  static const _red = Color(0xFFC41818);

  @override
  Widget build(BuildContext context) {
    final d = Motion.dur(context, const Duration(milliseconds: 260));
    return AnimatedOpacity(
      opacity: down ? 1 : 0,
      duration: d,
      child: AnimatedScale(
        scale: down ? 1 : 1.5,
        duration: d,
        curve: Motion.out,
        child: Transform.rotate(
          angle: -12 * math.pi / 180,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _red, width: 2),
            ),
            child: Text(
              'VERIFIED ✦',
              style: AppText.mono(
                9,
                color: _red,
                letterSpacing: 2,
                weight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The ticket's outline: a rounded rectangle with a semicircle punched out of
/// each side where the stub tears off ([fromBottom] above the bottom edge).
class _TicketBorder extends ShapeBorder {
  const _TicketBorder({
    required this.radius,
    required this.notch,
    required this.fromBottom,
  });

  final double radius;
  final double notch;
  final double fromBottom;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect, textDirection: textDirection);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final card = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    if (fromBottom <= 0) return card;
    final y = rect.bottom - fromBottom;
    final holes = Path()
      ..addOval(Rect.fromCircle(center: Offset(rect.left, y), radius: notch))
      ..addOval(Rect.fromCircle(center: Offset(rect.right, y), radius: notch));
    return Path.combine(PathOperation.difference, card, holes);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}

  @override
  ShapeBorder scale(double t) => _TicketBorder(
    radius: radius * t,
    notch: notch * t,
    fromBottom: fromBottom * t,
  );

  @override
  bool operator ==(Object other) =>
      other is _TicketBorder &&
      other.radius == radius &&
      other.notch == notch &&
      other.fromBottom == fromBottom;

  @override
  int get hashCode => Object.hash(radius, notch, fromBottom);
}

/// The hairline frames (one around the body, one around the stub, so they
/// stop short of the notches) and the perforation between them.
class _FramePainter extends CustomPainter {
  _FramePainter({
    required this.stub,
    required this.color,
    required this.perforation,
  });
  final double stub;
  final Color color;
  final Color perforation;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    if (stub <= 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(8, 15, size.width - 8, size.height - 8),
          const Radius.circular(15),
        ),
        line,
      );
      return;
    }
    final cut = size.height - stub;
    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(8, 15, size.width - 8, cut - 8),
          const Radius.circular(15),
        ),
        line,
      )
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(8, cut + 8, size.width - 8, size.height - 8),
          const Radius.circular(15),
        ),
        line,
      );
    final dash = Paint()
      ..color = perforation
      ..strokeWidth = 1;
    for (var x = 18.0; x < size.width - 18; x += 8) {
      canvas.drawLine(Offset(x, cut), Offset(x + 4, cut), dash);
    }
  }

  @override
  bool shouldRepaint(_FramePainter old) =>
      old.stub != stub || old.color != color || old.perforation != perforation;
}

/// Reports its child's laid-out height (the stub, so the notches and the
/// perforation sit exactly on the tear line at any text size).
class _MeasureHeight extends SingleChildRenderObjectWidget {
  const _MeasureHeight({required this.onHeight, super.child});
  final ValueChanged<double> onHeight;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMeasureHeight(onHeight);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderMeasureHeight renderObject,
  ) => renderObject.onHeight = onHeight;
}

class _RenderMeasureHeight extends RenderProxyBox {
  _RenderMeasureHeight(this.onHeight);
  ValueChanged<double> onHeight;
  double? _last;

  @override
  void performLayout() {
    super.performLayout();
    final h = size.height;
    if (h == _last) return;
    _last = h;
    WidgetsBinding.instance.addPostFrameCallback((_) => onHeight(h));
  }
}

/// Draws a stroke along [builder]'s path (a pen signing) once [play] is true,
/// after [delay]. With [animate] false it's simply there.
class DrawOn extends StatefulWidget {
  const DrawOn({
    super.key,
    required this.builder,
    required this.color,
    this.width = 2,
    this.delay = Duration.zero,
    this.play = true,
    this.animate = true,
  });

  final Path Function(Size) builder;
  final Color color;
  final double width;
  final Duration delay;
  final bool play;
  final bool animate;

  @override
  State<DrawOn> createState() => _DrawOnState();
}

class _DrawOnState extends State<DrawOn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  Timer? _t;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybeStart();
  }

  @override
  void didUpdateWidget(DrawOn old) {
    super.didUpdateWidget(old);
    _maybeStart();
  }

  void _maybeStart() {
    if (_started || !widget.play) return;
    _started = true;
    if (!widget.animate || Motion.reduced(context)) {
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
        Motion.out.transform(_c.value),
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
    if (t <= 0) return;
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
