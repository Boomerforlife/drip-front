import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/overlays.dart';
import '../../core/widgets/tap.dart';
import '../../data/models/outfit.dart';
import '../bag/bag_controller.dart';

/// Opens a piece's product page on the brand's own store, inside the app (Chrome Custom Tabs on
/// Android, Safari View on iOS, a new tab on web), so the feed stays one swipe away.
Future<void> openProductPage(BuildContext context, OutfitPiece piece) async {
  final url = piece.buyUrl;
  final uri = url == null ? null : Uri.tryParse(url);
  if (uri == null || !uri.hasScheme) {
    showDripToast(context, 'No store link for this piece yet');
    return;
  }
  var opened = false;
  try {
    opened = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    if (!opened) {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  } catch (_) {
    opened = false;
  }
  if (!opened && context.mounted) {
    showDripToast(
      context,
      "Couldn't open ${piece.brand.isEmpty ? 'the store' : piece.brand}",
    );
  }
}

/// "Shop the look", right over the feed: every piece with its store and price. Tapping a piece
/// opens it on the store; [onFullBreakdown] goes to the Fit Analysis screen.
Future<void> showShopSheet(
  BuildContext context,
  Outfit outfit, {
  VoidCallback? onFullBreakdown,
}) {
  return showDripSheet<void>(
    context,
    scrollable: true,
    builder: (_) =>
        _ShopSheet(outfit: outfit, onFullBreakdown: onFullBreakdown),
  );
}

class _ShopSheet extends ConsumerWidget {
  const _ShopSheet({required this.outfit, this.onFullBreakdown});
  final Outfit outfit;
  final VoidCallback? onFullBreakdown;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pieces = outfit.pieces;
    final total = pieces.fold<int>(0, (s, p) => s + p.price);
    final n = pieces.length;
    return SheetContent(
      title: 'SHOP THE LOOK',
      subtitle: total > 0
          ? '$n ${n == 1 ? 'PIECE' : 'PIECES'} · ${formatPrice(total)} TOTAL'
          : '$n ${n == 1 ? 'PIECE' : 'PIECES'}',
      children: [
        for (final p in pieces) _ShopRow(piece: p),
        const SizedBox(height: 16),
        AppButton(
          label: 'ADD ALL TO BAG',
          style: AppButtonStyle.outline,
          height: 44,
          onPressed: () {
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
            showDripToast(
              context,
              added == 0 ? 'Already in your bag' : 'Added $added to your bag',
            );
          },
        ),
        if (onFullBreakdown != null) ...[
          const SizedBox(height: 10),
          AppButton(
            label: 'FULL FIT BREAKDOWN →',
            style: AppButtonStyle.outline,
            height: 44,
            onPressed: () {
              Navigator.of(context).pop();
              onFullBreakdown!();
            },
          ),
        ],
      ],
    );
  }
}

class _ShopRow extends StatelessWidget {
  const _ShopRow({required this.piece});
  final OutfitPiece piece;

  @override
  Widget build(BuildContext context) {
    final hasLink = piece.buyUrl != null;
    final store = piece.brand.isEmpty ? 'STORE' : piece.brand.toUpperCase();
    return Tap(
      onTap: () => openProductPage(context, piece),
      semanticLabel: hasLink ? 'View ${piece.name} on $store' : piece.name,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.elevated)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 48,
                height: 48,
                color: AppColors.surface,
                padding: const EdgeInsets.all(4),
                child: piece.image == null
                    ? Center(
                        child: Text(
                          piece.slot,
                          style: AppText.mono(7, color: AppColors.muted),
                        ),
                      )
                    : Image.network(
                        piece.image!,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
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
                    style: AppText.manrope(13, weight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    hasLink
                        ? 'VIEW ON $store ↗'
                        : '${piece.slot} · NO LINK YET',
                    style: AppText.mono(
                      9,
                      color: hasLink ? AppColors.cyan : AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              piece.price > 0 ? formatPrice(piece.price) : '—',
              style: AppText.mono(12, color: AppColors.cream),
            ),
          ],
        ),
      ),
    );
  }
}
