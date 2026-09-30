import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/drip_image.dart';
import '../../core/widgets/pills.dart';
import '../../core/widgets/states.dart';
import '../../core/widgets/tap.dart';
import '../../core/widgets/top_bar.dart';
import '../../data/models/studio.dart';
import '../../routing/main_shell.dart';
import '../outfits/outfit_card.dart';
import '../outfits/outfit_controller.dart';
import '../studio/studio_controller.dart';
import 'wardrobe_controller.dart';

/// Saved looks: complete outfits the user bookmarked or generated.
class SavedOutfitsScreen extends ConsumerWidget {
  const SavedOutfitsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(savedOutfitsProvider);
    final mine = ref.watch(libraryProvider).value?.mine ?? const <UserFit>[];
    final closet = ref.watch(wardrobeProvider).value?.length;

    return ShellPage(
      child: Column(
        children: [
          DripTopBar(
            title: 'SAVED LOOKS',
            leading: const BackGlyph(),
            trailing: GlyphButton(
              '📁',
              label: 'Closet',
              onTap: () => context.go('/wardrobe'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: FilterPill(
                    label: 'MY CLOSET${closet == null ? '' : ' ($closet)'}',
                    selected: false,
                    onTap: () => context.go('/wardrobe'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilterPill(
                    label:
                        'SAVED STYLES${saved.value == null ? '' : ' (${saved.value!.length})'}',
                    selected: true,
                    onTap: () {},
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: saved.whenDrip(
              onRetry: () => ref.invalidate(libraryProvider),
              data: (looks) => ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Text(
                      'Complete aesthetics you have bookmarked, generated, or want to purchase. Distinct from individual garments.',
                      style: AppText.manrope(
                        12,
                        color: AppColors.muted,
                        lineHeight: 16,
                      ),
                    ),
                  ),
                  if (looks.isEmpty)
                    const EmptyState(
                      title: 'NO SAVED LOOKS',
                      message: 'Tap SAVE on a fit in the Scroll to bookmark it here.',
                    )
                  else
                    OutfitMasonry(
                      outfits: looks,
                      style: OutfitCardStyle.saved,
                      gap: 12,
                      tall: 220,
                      short: 180,
                    ),
                  if (mine.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 24, 16, 12),
                      child: SectionLabel('YOUR STUDIO FITS'),
                    ),
                    for (final fit in mine)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                        child: _StudioFitRow(fit: fit),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A fit the user built in the Studio: its pieces, score and price. Tapping
/// reopens it on the canvas (saving again updates it).
class _StudioFitRow extends ConsumerWidget {
  const _StudioFitRow({required this.fit});
  final UserFit fit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Tap(
      onTap: () {
        ref.read(studioProvider.notifier).load(fit);
        context.push('/studio/builder');
      },
      semanticLabel: 'Open ${fit.name} in the Studio',
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.elevated),
        ),
        child: Row(
          children: [
            for (final p in fit.pieces.values.take(4))
              Container(
                width: 44,
                height: 44,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  color: AppColors.base,
                  borderRadius: BorderRadius.circular(10),
                ),
                clipBehavior: Clip.antiAlias,
                child: DripImage(p.image, fit: BoxFit.contain),
              ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fit.name.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.display(12),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    [
                      '${fit.pieces.length} PIECES',
                      if (fit.dripRate != null) '✦ ${fit.dripRate}',
                      if ((fit.price ?? 0) > 0) formatPrice(fit.price!),
                    ].join('  ·  '),
                    style: AppText.mono(9, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.muted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
