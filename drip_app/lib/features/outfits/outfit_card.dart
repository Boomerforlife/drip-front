import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/drip_image.dart';
import '../../core/widgets/tap.dart';
import '../../data/models/outfit.dart';
import 'fit_actions.dart';
import 'outfit_controller.dart';

enum OutfitCardStyle {
  /// Discover: gradient fade with title + `$310 · 92 RATE`.
  gradient,

  /// Search results: caption plate with title + `$320 · @creator`.
  plate,

  /// Saved looks: Bungee title + `$390 · @creator`.
  saved,
}

/// A tappable look tile with a like heart. Opens Fit Analysis.
class OutfitCard extends ConsumerWidget {
  const OutfitCard({
    super.key,
    required this.outfit,
    required this.height,
    this.style = OutfitCardStyle.gradient,
    this.radius = 20,
    this.onTap,
  });

  final Outfit outfit;
  final double height;
  final OutfitCardStyle style;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pad = style == OutfitCardStyle.gradient ? 10.0 : 8.0;
    final heartSize = style == OutfitCardStyle.saved
        ? 14.0
        : (style == OutfitCardStyle.plate ? 10.0 : 12.0);

    final liked = ref.watch(fitMarksProvider).isLiked(outfit.id);
    final heart = Tap(
      onTap: () => toggleLikeWithToast(context, ref, outfit.id),
      semanticLabel: liked
          ? 'Unlike ${outfit.title}'
          : 'Like ${outfit.title}',
      child: Container(
        padding: style == OutfitCardStyle.plate
            ? const EdgeInsets.all(4)
            : const EdgeInsets.all(2),
        decoration: style == OutfitCardStyle.plate
            ? BoxDecoration(
                color: AppColors.elevated,
                borderRadius: BorderRadius.circular(8),
              )
            : null,
        child: Text(
          liked ? '♥' : '♡',
          style: AppText.inter(
            heartSize,
            color: liked ? AppColors.red : AppColors.muted,
          ),
        ),
      ),
    );

    return Tap(
      onTap: onTap ?? () => context.push('/outfit/${outfit.id}'),
      semanticLabel: outfit.title,
      scale: 0.98,
      child: SizedBox(
        height: height,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Stack(
            fit: StackFit.expand,
            children: [
              DripImage(outfit.image),
              if (style != OutfitCardStyle.plate)
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Color(0xEB0E1018), Color(0x000E1018)],
                      stops: [0, 0.6],
                    ),
                  ),
                ),
              Padding(
                padding: EdgeInsets.all(pad),
                child: Column(
                  children: [
                    Align(alignment: Alignment.topRight, child: heart),
                    const Spacer(),
                    Align(alignment: Alignment.bottomLeft, child: _caption()),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _caption() {
    switch (style) {
      case OutfitCardStyle.gradient:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              outfit.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.mono(9),
            ),
            const SizedBox(height: 2),
            Text(
              '${formatPrice(outfit.price)} · ${outfit.rate} RATE',
              style: AppText.mono(8, color: AppColors.cyan),
            ),
          ],
        );
      case OutfitCardStyle.plate:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.base.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                outfit.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.mono(9),
              ),
              const SizedBox(height: 2),
              Text(
                '${formatPrice(outfit.price)} · @${outfit.creatorHandle}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.mono(8, color: AppColors.cyan),
              ),
            ],
          ),
        );
      case OutfitCardStyle.saved:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              outfit.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.display(10),
            ),
            const SizedBox(height: 2),
            Text(
              '${formatPrice(outfit.price)} · @${outfit.creatorHandle}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.mono(8, color: AppColors.cyan),
            ),
          ],
        );
    }
  }
}

/// Two-column layout where card heights alternate 220 / 180 like the design.
class OutfitMasonry extends StatelessWidget {
  const OutfitMasonry({
    super.key,
    required this.outfits,
    this.style = OutfitCardStyle.gradient,
    this.gap = 16,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.tall = 220,
    this.short = 180,
  });

  final List<Outfit> outfits;
  final OutfitCardStyle style;
  final double gap;
  final EdgeInsets padding;
  final double tall;
  final double short;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < outfits.length; i += 2) {
      final row = i ~/ 2;
      final leftTall = row.isEven;
      final left = outfits[i];
      final right = i + 1 < outfits.length ? outfits[i + 1] : null;
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: OutfitCard(
                outfit: left,
                style: style,
                height: leftTall ? tall : short,
              ),
            ),
            SizedBox(width: gap),
            Expanded(
              child: right == null
                  ? const SizedBox.shrink()
                  : OutfitCard(
                      outfit: right,
                      style: style,
                      height: leftTall ? short : tall,
                    ),
            ),
          ],
        ),
      );
      if (i + 2 < outfits.length) rows.add(SizedBox(height: gap));
    }
    return Padding(
      padding: padding,
      child: Column(children: rows),
    );
  }
}
