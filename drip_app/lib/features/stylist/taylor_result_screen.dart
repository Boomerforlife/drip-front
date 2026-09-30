import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/drip_image.dart';
import '../../core/widgets/overlays.dart';
import '../../core/widgets/states.dart';
import '../../core/widgets/tap.dart';
import '../../core/widgets/top_bar.dart';
import '../../data/models/stylist.dart';
import '../bag/bag_controller.dart';
import '../bag/bag_sheet.dart';
import 'stylist_controller.dart';

class TaylorResultScreen extends ConsumerWidget {
  const TaylorResultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blueprint = ref.watch(stylistProvider).blueprint.value;
    final bottom = math.max(MediaQuery.paddingOf(context).bottom, 8.0);

    return Scaffold(
      backgroundColor: AppColors.base,
      body: blueprint == null
          ? SafeArea(
              child: Column(
                children: [
                  const DripTopBar(
                    title: 'TAYLOR STYLIST',
                    leading: BackGlyph(),
                  ),
                  Expanded(
                    child: EmptyState(
                      title: 'NO BLUEPRINT YET',
                      message:
                          'Tell Taylor the occasion and vibe to get a look.',
                      actionLabel: 'START CONSULTATION',
                      onAction: () => context.go('/stylist'),
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Banner(blueprint: blueprint),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: _Explanation(blueprint: blueprint),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Blueprints contained',
                                style: AppText.mono(9, color: AppColors.muted),
                              ),
                              const SizedBox(height: 8),
                              for (final p in blueprint.pieces) ...[
                                _PieceRow(piece: p),
                                const SizedBox(height: 8),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  color: AppColors.base,
                  padding: EdgeInsets.fromLTRB(16, 16, 16, bottom + 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          label: blueprint.fitId == null
                              ? 'CUSTOMIZE'
                              : 'VIEW FIT',
                          style: AppButtonStyle.subtle,
                          height: 36,
                          onPressed: () => blueprint.fitId == null
                              ? context.push('/studio/builder')
                              : context.push('/outfit/${blueprint.fitId}'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: AppButton(
                          label: 'BUY ENTIRE FIT →',
                          height: 36,
                          onPressed: () {
                            ref
                                .read(bagProvider.notifier)
                                .addAll(
                                  blueprint.pieces.map(
                                    (p) => BagLine(
                                      name: p.name,
                                      subtitle: p.category,
                                      price: p.price,
                                    ),
                                  ),
                                );
                            showBagSheet(context);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.blueprint});
  final Blueprint blueprint;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 260 + MediaQuery.paddingOf(context).top,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
        child: Stack(
          fit: StackFit.expand,
          children: [
            DripImage(blueprint.banner, alignment: Alignment.topCenter),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x990E1018), Color(0x000E1018)],
                  stops: [0, 0.7],
                ),
              ),
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.cyan,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            "TAYLOR'S CHOICE",
                            style: AppText.mono(8, color: AppColors.base),
                          ),
                        ),
                        const Spacer(),
                        Tap(
                          onTap: () => context.canPop()
                              ? context.pop()
                              : context.go('/home'),
                          semanticLabel: 'Back',
                          child: Text('✕', style: AppText.inter(18)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      blueprint.headline,
                      style: AppText.display(28, lineHeight: 34),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Explanation extends StatelessWidget {
  const _Explanation({required this.blueprint});
  final Blueprint blueprint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cream.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('🧠', style: AppText.inter(16)),
              const SizedBox(width: 8),
              Text(
                'WHY THIS LOCKUP MATCHES',
                style: AppText.mono(10, color: AppColors.muted),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '"${blueprint.reasoning}"',
            style: AppText.manrope(13, lineHeight: 20),
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: AppColors.elevated),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'DRIP ESTIMATE: ✦ ${blueprint.drip}',
                style: AppText.mono(9, color: AppColors.muted),
              ),
              Text(
                'CALIBRATED BY AI',
                style: AppText.mono(9, color: AppColors.cyan),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PieceRow extends ConsumerWidget {
  const _PieceRow({required this.piece});
  final BlueprintPiece piece;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inBag = ref.watch(bagProvider).any((l) => l.name == piece.name);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: DripImage(piece.image),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  piece.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.manrope(12, weight: FontWeight.w700),
                ),
                const SizedBox(height: 0),
                Text(
                  '${piece.category} · ${formatPriceShort(piece.price)}',
                  style: AppText.mono(8, color: AppColors.muted),
                ),
              ],
            ),
          ),
          Tap(
            onTap: () {
              if (inBag) {
                ref.read(bagProvider.notifier).remove(piece.name);
                showDripToast(context, 'Removed from bag');
              } else {
                ref.read(bagProvider.notifier).addAll([
                  BagLine(
                    name: piece.name,
                    subtitle: piece.category,
                    price: piece.price,
                  ),
                ]);
                showDripToast(context, 'Added to bag');
              }
            },
            semanticLabel: inBag ? 'Remove from bag' : 'Add to bag',
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Text(
                inBag ? '✓' : '➕',
                style: AppText.inter(14, color: AppColors.cyan),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
