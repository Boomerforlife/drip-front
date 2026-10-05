import 'package:flutter/material.dart';

import '../motion.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../theme/app_theme.dart';
import 'drip_image.dart';
import 'tap.dart';

/// One big item in focus with its neighbours peeking either side, smaller and
/// faded (Pinterest's piece view). Swiping moves the focus; tapping the
/// focused item calls [onTapFocused], tapping a neighbour brings it in.
class PeekCarousel extends StatefulWidget {
  const PeekCarousel({
    super.key,
    required this.count,
    required this.itemBuilder,
    this.initial = 0,
    this.onFocus,
    this.onTapFocused,
    this.semanticLabel,
  });

  final int count;
  final Widget Function(BuildContext context, int index) itemBuilder;
  final int initial;
  final ValueChanged<int>? onFocus;
  final ValueChanged<int>? onTapFocused;
  final String Function(int index)? semanticLabel;

  @override
  State<PeekCarousel> createState() => _PeekCarouselState();
}

class _PeekCarouselState extends State<PeekCarousel> {
  late final _pages = PageController(
    viewportFraction: 0.62,
    initialPage: widget.initial.clamp(0, widget.count - 1),
  );
  late int _current = _pages.initialPage;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: _pages,
      itemCount: widget.count,
      onPageChanged: (i) {
        Haptics.tick();
        _current = i;
        widget.onFocus?.call(i);
      },
      itemBuilder: (context, i) => AnimatedBuilder(
        animation: _pages,
        builder: (context, child) {
          final page = _pages.hasClients && _pages.position.haveDimensions
              ? _pages.page ?? _current.toDouble()
              : _current.toDouble();
          final d = (page - i).abs().clamp(0.0, 1.0);
          return Opacity(
            opacity: 1 - 0.45 * d,
            child: Transform.scale(scale: 1 - 0.16 * d, child: child),
          );
        },
        child: Tap(
          onTap: () => i == _current
              ? widget.onTapFocused?.call(i)
              : _pages.animateToPage(
                  i,
                  duration: Motion.dur(context, Motion.page),
                  curve: Motion.out,
                ),
          scale: 0.97,
          semanticLabel: widget.semanticLabel?.call(i),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: widget.itemBuilder(context, i),
          ),
        ),
      ),
    );
  }
}

/// A garment's cut-out on the light studio card, with an optional corner
/// badge ("ON CANVAS", "IN WARDROBE").
class PieceCard extends StatelessWidget {
  const PieceCard({
    super.key,
    required this.image,
    this.semanticLabel,
    this.badge,
    this.highlighted = false,
  });

  final String image;
  final String? semanticLabel;
  final String? badge;
  final bool highlighted;

  static const background = Color(0xFFF4F4F2);

  @override
  Widget build(BuildContext context) {
    final accent = context.palette.accent;
    return Container(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: highlighted ? accent : Colors.transparent,
          width: 2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Padding(
            padding: const EdgeInsets.all(18),
            child: DripImage(
              image,
              fit: BoxFit.contain,
              backdrop: false,
              logicalWidth: 260,
              semanticLabel: semanticLabel,
            ),
          ),
          if (badge != null)
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badge!,
                  style: AppText.mono(
                    8,
                    color: AppColors.base,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
