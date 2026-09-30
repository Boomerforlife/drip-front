import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/drip_image.dart';
import '../../core/widgets/overlays.dart';
import '../../core/widgets/states.dart';
import '../../core/widgets/tap.dart';
import '../../core/widgets/top_bar.dart';
import '../../data/models/outfit.dart';
import '../../routing/main_shell.dart';
import '../bag/bag_controller.dart';
import '../bag/bag_sheet.dart';
import 'fit_actions.dart';
import 'outfit_controller.dart';

/// "Fit Analysis": annotated hero, garment breakdown and shop actions.
class OutfitDetailScreen extends ConsumerWidget {
  const OutfitDetailScreen({super.key, required this.outfitId});
  final String outfitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outfit = ref.watch(outfitProvider(outfitId));
    final saved = ref.watch(fitMarksProvider).isSaved(outfitId);

    return ShellPage(
      child: Column(
        children: [
          DripTopBar(
            title: 'FIT ANALYSIS',
            card: true,
            height: 42,
            titleSize: 14,
            leading: const BackGlyph(),
            trailing: GlyphButton(
              '↗',
              mono: true,
              size: 18,
              label: 'Share',
              onTap: () => showAfterBeta(context, 'Sharing fits'),
            ),
          ),
          Expanded(
            child: outfit.whenDrip(
              onRetry: () => ref.invalidate(outfitProvider(outfitId)),
              data: (outfit) {
                if (outfit == null) {
                  return const EmptyState(
                    title: 'FIT NOT FOUND',
                    message: 'This look is no longer available.',
                  );
                }
                return _Content(outfit: outfit, saved: saved);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Content extends ConsumerWidget {
  const _Content({required this.outfit, required this.saved});
  final Outfit outfit;
  final bool saved;

  List<Hotspot> get _hotspots {
    if (outfit.isCollage) return const [];
    if (outfit.hotspots.isNotEmpty) return outfit.hotspots;
    final p = outfit.pieces;
    return [
      if (p.isNotEmpty)
        Hotspot(label: p[0].name.toUpperCase(), x: 0.34, y: 0.25, filled: true),
      if (p.length > 1)
        Hotspot(
          label: p[1].name.toUpperCase(),
          x: 0.14,
          y: 0.62,
          highlighted: true,
        ),
    ];
  }

  void _addToBag(
    BuildContext context,
    WidgetRef ref,
    Iterable<OutfitPiece> pieces,
  ) {
    final added = ref.read(bagProvider.notifier).addAll([
      for (final p in pieces)
        BagLine(
          name: p.name,
          subtitle: p.brand.isEmpty
              ? p.slot
              : '${p.slot} · BY ${p.brand.toUpperCase()}',
          price: p.price,
        ),
    ]);
    if (added == 0) showDripToast(context, 'Already in your bag');
    showBagSheet(context);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = context.palette.accent;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                _Hero(outfit: outfit, hotspots: _hotspots),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    border: Border(top: BorderSide(color: AppColors.elevated)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(outfit.title, style: AppText.display(18)),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 4,
                                  children: [
                                    for (final t in outfit.tags)
                                      Text(
                                        '#${t.toUpperCase()}',
                                        style: AppText.mono(
                                          9,
                                          color: AppColors.cyan,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Column(
                            children: [
                              Text(
                                '✦ ${outfit.rate}',
                                style: AppText.display(22, color: accent),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'DRIP RATE',
                                style: AppText.mono(8, color: AppColors.muted),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const SectionLabel(
                        'GARMENT CALIBRATION SPEC',
                        size: 9,
                        letterSpacing: 0,
                      ),
                      const SizedBox(height: 8),
                      for (final p in outfit.pieces) ...[
                        _PieceRow(
                          piece: p,
                          onShop: () => _addToBag(context, ref, [p]),
                        ),
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
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Tap(
                onTap: () => toggleSaveWithToast(context, ref, outfit.id),
                semanticLabel: saved ? 'Unsave look' : 'Save look',
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: saved
                        ? accent.withValues(alpha: 0.15)
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: saved ? accent : AppColors.elevated,
                    ),
                  ),
                  child: Text(
                    '✦',
                    style: AppText.inter(
                      14,
                      color: saved ? accent : AppColors.cream,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppButton(
                  label: 'SHOP ENTIRE FIT →',
                  height: 44,
                  onPressed: () => _addToBag(context, ref, outfit.pieces),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.outfit, required this.hotspots});
  final Outfit outfit;
  final List<Hotspot> hotspots;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 320,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
        child: LayoutBuilder(
          builder: (context, c) => Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(
                color: AppColors.surface,
                child: DripImage(
                  outfit.image,
                  fit: outfit.isCollage ? BoxFit.contain : BoxFit.cover,
                  alignment: Alignment.topCenter,
                ),
              ),
              for (final h in hotspots)
                Positioned(
                  left: h.x * c.maxWidth,
                  top: h.y * c.maxHeight,
                  child: _HotspotPill(hotspot: h, outfit: outfit),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HotspotPill extends StatelessWidget {
  const _HotspotPill({required this.hotspot, required this.outfit});
  final Hotspot hotspot;
  final Outfit outfit;

  @override
  Widget build(BuildContext context) {
    final fill = hotspot.filled ? context.palette.accent : AppColors.cyan;
    final textColor = hotspot.filled
        ? AppColors.cream
        : const Color(0xFF090D17);
    return Tap(
      onTap: () {
        final piece =
            outfit.pieces
                .where((p) => p.name.toUpperCase() == hotspot.label)
                .firstOrNull ??
            (hotspot.filled
                ? outfit.pieces.firstOrNull
                : outfit.pieces.skip(1).firstOrNull);
        if (piece != null) {
          showDripToast(
            context,
            '${piece.slot} · ${piece.name} ${formatPriceShort(piece.price)}',
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: fill.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.cream,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 190),
              child: Text(
                hotspot.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.mono(8, color: textColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PieceRow extends StatelessWidget {
  const _PieceRow({required this.piece, required this.onShop});
  final OutfitPiece piece;
  final VoidCallback onShop;

  @override
  Widget build(BuildContext context) {
    final accent = context.palette.accent;
    return Tap(
      onTap: onShop,
      semanticLabel: 'Shop ${piece.name}',
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.base,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.elevated),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              padding: const EdgeInsets.symmetric(vertical: 4),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(piece.slot, style: AppText.mono(8, color: accent)),
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
                  const SizedBox(height: 2),
                  Text(
                    piece.brand.isNotEmpty
                        ? 'BY ${piece.brand.toUpperCase()}'
                        : piece.buyUrl != null
                        ? 'AVAILABLE ONLINE'
                        : 'DRIP PICK',
                    style: AppText.mono(9, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  piece.price > 0 ? formatPrice(piece.price) : '—',
                  style: AppText.mono(11, color: AppColors.cyan),
                ),
                const SizedBox(height: 2),
                Text('SHOP ↗', style: AppText.mono(8, color: AppColors.muted)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
