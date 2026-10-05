import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/drip_image.dart';
import '../../core/widgets/overlays.dart';
import '../../core/widgets/skeleton.dart';
import '../../core/widgets/tap.dart';
import '../../data/api/api_client.dart';
import '../../data/models/product.dart';
import '../../data/models/stylist.dart';
import '../../data/providers.dart';
import '../onboarding/onboarding_data.dart';
import '../outfits/shop_sheet.dart';
import '../session/session_controller.dart';
import '../studio/studio_controller.dart';
import '../studio/studio_layouts.dart';

/// Puts a discovered piece on the Studio canvas, beside whatever's already
/// there, and opens the builder: the existing fit-collage engine, not a new
/// one. Only ready (published) pieces: a fit can only be saved with those.
String? styleProduct(BuildContext context, WidgetRef ref, DripProduct p) {
  if (!p.ready || p.category == null) return null;
  final c = ref.read(studioProvider.notifier)
    ..setCategory(categoryForLayoutSlot(p.category!));
  final note = c.select(
    StudioPiece(
      id: p.id,
      name: p.title,
      category: StudioSlots.label(p.category!),
      image: p.image ?? '',
      price: p.price ?? 0,
      brand: p.brand,
    ),
  );
  context.push('/studio/builder');
  return note;
}

/// A product card for the search grid: the cut-out on a soft plate (or, while
/// Drip is still cutting it out, the store's photo, dimmed, with a shimmer),
/// then brand, name and price.
class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.product, required this.onTap});
  final DripProduct product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = product;
    return Tap(
      onTap: onTap,
      semanticLabel: '${p.brand ?? ''} ${p.title}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 0.82,
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: p.cutout ? const Color(0xFFE9E4DA) : AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: AppColors.cream.withValues(alpha: 0.08),
                ),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (p.image != null)
                    p.cutout
                        ? Padding(
                            padding: const EdgeInsets.all(14),
                            child: DripImage(
                              p.image!,
                              fit: BoxFit.contain,
                              backdrop: false,
                              logicalWidth: 200,
                            ),
                          )
                        : Opacity(
                            opacity: 0.55,
                            child: DripImage(p.image!, logicalWidth: 200),
                          ),
                  if (!p.ready) ...[
                    const Positioned.fill(child: Skeleton(radius: 0)),
                    Positioned(
                      left: 10,
                      bottom: 10,
                      child: _Badge('CUTTING OUT…', color: AppColors.cyan),
                    ),
                  ] else if (p.onSale)
                    Positioned(
                      left: 10,
                      top: 10,
                      child: _Badge('SALE', color: AppColors.red),
                    ),
                  if (p.soldOut)
                    Positioned(
                      right: 10,
                      top: 10,
                      child: _Badge('SOLD OUT', color: AppColors.muted),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            (p.brand ?? p.retailer ?? '').toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.mono(9, color: AppColors.muted, letterSpacing: 1),
          ),
          const SizedBox(height: 2),
          Text(
            p.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.manrope(12, weight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              if (p.price != null)
                Text(formatPrice(p.price!), style: AppText.mono(11)),
              if (p.onSale) ...[
                const SizedBox(width: 6),
                Text(
                  formatPrice(p.originalPrice!),
                  style: AppText.mono(
                    10,
                    color: AppColors.muted,
                  ).copyWith(decoration: TextDecoration.lineThrough),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.text, {required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: AppColors.base.withValues(alpha: 0.85),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(text, style: AppText.mono(8, color: color, letterSpacing: 1)),
  );
}

/// The piece up close: cut-out, what it is, price against the user's budget,
/// and the two things to do with it: style it into a fit, or buy it.
Future<void> showProductSheet(
  BuildContext context,
  WidgetRef ref,
  DripProduct product,
) {
  return showDripSheet<void>(
    context,
    scrollable: true,
    builder: (_) => _ProductSheet(product: product),
  );
}

class _ProductSheet extends ConsumerWidget {
  const _ProductSheet({required this.product});
  final DripProduct product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = product;
    final budget = ref.watch(onboardingProvider.select((s) => s.budget));
    final store = p.retailer ?? p.brand ?? 'the store';
    return SheetContent(
      title: p.title.toUpperCase(),
      subtitle: [
        p.brand,
        if (p.retailer != null && p.retailer != p.brand) 'at ${p.retailer}',
      ].whereType<String>().join(' '),
      children: [
        Container(
          height: 260,
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: p.cutout ? const Color(0xFFE9E4DA) : AppColors.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: p.image == null
              ? const SizedBox.shrink()
              : DripImage(
                  p.image!,
                  fit: p.cutout ? BoxFit.contain : BoxFit.cover,
                  backdrop: !p.cutout,
                ),
        ),
        if (!p.ready) ...[
          const SizedBox(height: 10),
          Text(
            'Drip is still cutting this one out. It lands in a minute or two.',
            style: AppText.manrope(12, color: AppColors.muted),
          ),
        ],
        const SizedBox(height: 14),
        Row(
          children: [
            if (p.price != null)
              Text(formatPrice(p.price!), style: AppText.display(18)),
            if (p.onSale) ...[
              const SizedBox(width: 8),
              Text(
                formatPrice(p.originalPrice!),
                style: AppText.mono(
                  12,
                  color: AppColors.muted,
                ).copyWith(decoration: TextDecoration.lineThrough),
              ),
            ],
            const Spacer(),
            if (p.price != null)
              Builder(
                builder: (_) {
                  // The slider's top ("15,000+") means no cap.
                  final fits =
                      budget >= OnboardingData.budgetMax || p.price! <= budget;
                  return Text(
                    fits
                        ? 'IN YOUR BUDGET'
                        : 'OVER YOUR ${formatPrice(budget)}',
                    style: AppText.mono(
                      9,
                      color: fits ? AppColors.cyan : AppColors.muted,
                    ),
                  );
                },
              ),
          ],
        ),
        if (p.facts.isNotEmpty || p.styleTags.isNotEmpty) ...[
          const SizedBox(height: 14),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final f in p.facts) _Chip(f),
              for (final s in p.styleTags) _Chip('#$s', accent: true),
            ],
          ),
        ],
        if (p.sizes.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'SIZES  ${p.sizes.join(' · ')}',
            style: AppText.mono(9, color: AppColors.muted),
          ),
        ],
        const SizedBox(height: 18),
        AppButton(
          label: p.ready ? 'STYLE IT INTO A FIT ✦' : 'STYLE IT ONCE IT’S READY',
          height: 46,
          onPressed: p.ready && p.category != null
              ? () {
                  Navigator.of(context).pop();
                  final note = styleProduct(context, ref, p);
                  if (note != null) showDripToast(context, note);
                }
              : null,
        ),
        const SizedBox(height: 10),
        AppButton(
          label: 'SHOP AT ${store.toUpperCase()} ↗',
          style: AppButtonStyle.outline,
          height: 46,
          onPressed: p.buyUrl == null
              ? null
              : () => openStoreLink(context, p.buyUrl, store: store),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.text, {this.accent = false});
  final String text;
  final bool accent;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: accent
            ? AppColors.cyan.withValues(alpha: 0.5)
            : AppColors.elevated,
      ),
    ),
    child: Text(
      text,
      style: AppText.mono(10, color: accent ? AppColors.cyan : AppColors.cream),
    ),
  );
}

/// "Paste a link": any product page from any store. Drip reads it, then cuts
/// it out in the background.
Future<void> showImportLinkSheet(BuildContext context, WidgetRef ref) async {
  final text = TextEditingController();
  final url = await showDripSheet<String>(
    context,
    builder: (ctx) => SheetContent(
      title: 'ADD A PIECE BY LINK',
      subtitle: 'Paste a product link from any store. Drip cuts it out and adds it to your pieces.',
      children: [
        TextField(
          controller: text,
          autofocus: true,
          keyboardType: TextInputType.url,
          style: AppText.manrope(13),
          decoration: InputDecoration(
            hintText: 'https://…',
            hintStyle: AppText.manrope(13, color: AppColors.muted),
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        const SizedBox(height: 14),
        AppButton(
          label: 'ADD PIECE',
          height: 44,
          onPressed: () => Navigator.of(ctx).pop(text.text),
        ),
      ],
    ),
  );
  text.dispose();
  final link = url?.trim() ?? '';
  if (link.isEmpty || !context.mounted) return;
  if (!RegExp(r'^https?://', caseSensitive: false).hasMatch(link)) {
    showDripToast(context, 'That doesn’t look like a link');
    return;
  }
  try {
    final p = await ref.read(discoveryRepositoryProvider).importLink(link);
    if (context.mounted) {
      showDripToast(
        context,
        p.ready ? 'Added ${p.title}' : 'Got it. Cutting it out now…',
      );
    }
  } catch (e) {
    if (context.mounted) {
      // A 422 carries the store's reason ("refused automated access…"): say it as is.
      showDripToast(
        context,
        e is ApiException
            ? (e.status == 422 ? e.message : e.friendly)
            : 'Couldn’t read a product from that link',
      );
    }
  }
}
