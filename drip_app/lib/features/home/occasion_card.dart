import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/motion.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/drip_image.dart';
import '../../core/widgets/tap.dart';
import 'occasions.dart';

/// An occasion as a card: the photo is the foundation, a dark fade keeps the
/// words legible, then number, title, line and a marker.
///
/// One card, two jobs. On Home it opens the Scroll for the occasion (an
/// arrow, and a "FOR YOU" tag on the ones the user picked). In onboarding
/// and Your style it's a pick ([selected] not null): picked cards light up
/// with the cyan ring and ✓ every other Drip pick uses, lift slightly, and
/// the photo comes up from behind its veil.
class OccasionCard extends StatelessWidget {
  const OccasionCard({
    super.key,
    required this.occasion,
    required this.index,
    required this.onTap,
    this.selected,
    this.forYou = false,
  });

  final Occasion occasion;
  final int index;
  final VoidCallback onTap;

  /// Null on Home (the card navigates); true/false where it's a choice.
  final bool? selected;

  /// Home only: the user picked this occasion in onboarding.
  final bool forYou;

  @override
  Widget build(BuildContext context) {
    final o = occasion;
    final radius = (20 * context.palette.roundness).clamp(12.0, 24.0);
    final picking = selected != null;
    final on = selected ?? false;
    final reduced = Motion.reduced(context);
    final d = Motion.dur(context, Motion.quick);

    return Tap(
      onTap: () {
        if (picking) Haptics.tick();
        onTap();
      },
      scale: 0.97,
      semanticLabel: picking
          ? '${o.label}${on ? ', picked' : ''}'
          : 'Fits for ${o.label}',
      child: ExcludeSemantics(
        child: AnimatedScale(
          scale: on && !reduced ? 1.03 : 1,
          duration: Motion.content,
          curve: Motion.out,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(color: Color.lerp(o.tint, AppColors.base, 0.35)!),
                if (o.image != null)
                  AnimatedScale(
                    scale: on && !reduced ? 1.08 : 1,
                    duration: const Duration(milliseconds: 700),
                    curve: Motion.out,
                    child: DripImage(o.image!),
                  ),
                // Unpicked choices sit back a little; picked ones come up.
                if (picking)
                  AnimatedOpacity(
                    opacity: on ? 0 : 0.32,
                    duration: d,
                    child: const ColoredBox(color: AppColors.base),
                  ),
                // The fade that keeps the title readable over any photo.
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment(0, -0.35),
                      colors: [Color(0xE60E1018), Color(0x000E1018)],
                    ),
                  ),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment(0, -0.55),
                      colors: [Color(0x800E1018), Color(0x000E1018)],
                    ),
                  ),
                ),
                AnimatedContainer(
                  duration: d,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(radius),
                    border: Border.all(
                      color: on
                          ? AppColors.cyan
                          : AppColors.cream.withValues(alpha: 0.10),
                      width: on ? 2.5 : 1,
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 14,
                  child: Text(
                    '${index + 1}'.padLeft(2, '0'),
                    style: AppText.mono(
                      10,
                      color: AppColors.cream.withValues(alpha: 0.8),
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: picking ? _Pick(on: on) : const _Arrow(),
                ),
                if (forYou)
                  Positioned(
                    top: 9,
                    left: 36,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.cyan,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'FOR YOU',
                        style: AppText.mono(
                          9,
                          color: AppColors.base,
                          weight: FontWeight.w500,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 14,
                  child: LayoutBuilder(
                    // The poster face is wide: the title steps down until
                    // its longest word fits the card ("LATE-NIGHT" never
                    // breaks or clips), whatever the text size setting.
                    builder: (context, box) {
                      final title = o.label.toUpperCase();
                      final longest = title
                          .split(' ')
                          .map((w) => w.length)
                          .reduce(math.max);
                      final scale =
                          MediaQuery.textScalerOf(context).scale(10) / 10;
                      final size = (box.maxWidth / (longest * 0.84) / scale)
                          .clamp(10.0, 17.0);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.display(
                              size,
                              lineHeight: size * 1.24,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            o.line,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.manrope(
                              11,
                              color: AppColors.cream.withValues(alpha: 0.78),
                              lineHeight: 15,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Arrow extends StatelessWidget {
  const _Arrow();

  @override
  Widget build(BuildContext context) => Container(
    width: 28,
    height: 28,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: AppColors.base.withValues(alpha: 0.35),
      shape: BoxShape.circle,
      border: Border.all(color: AppColors.cream.withValues(alpha: 0.18)),
    ),
    child: Text('→', style: AppText.inter(13)),
  );
}

/// The pick marker: an empty ring, or "✓ ACTIVE" (the same badge the era
/// tiles use) popping in.
class _Pick extends StatelessWidget {
  const _Pick({required this.on});
  final bool on;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 22,
      child: Stack(
        alignment: Alignment.topRight,
        children: [
          AnimatedOpacity(
            opacity: on ? 0 : 1,
            duration: Motion.dur(context, Motion.quick),
            child: Container(
              width: 18,
              height: 18,
              margin: const EdgeInsets.only(top: 2, right: 2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.cream.withValues(alpha: 0.6),
                  width: 1.5,
                ),
              ),
            ),
          ),
          AnimatedScale(
            scale: on ? 1 : 0,
            alignment: Alignment.topRight,
            duration: Motion.dur(context, Motion.content),
            curve: Curves.easeOutBack,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.cyan,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '✓ ACTIVE',
                style: AppText.mono(
                  10,
                  color: AppColors.base,
                  weight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
