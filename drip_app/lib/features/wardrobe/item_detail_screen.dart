import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
import '../../data/api/api_client.dart';
import '../../data/models/meta.dart';
import '../../data/models/stylist.dart';
import '../../data/models/wardrobe.dart';
import '../../data/providers.dart';
import '../../routing/main_shell.dart';
import '../studio/studio_controller.dart';
import 'wardrobe_controller.dart';

class ItemDetailScreen extends ConsumerWidget {
  const ItemDetailScreen({super.key, required this.itemId});
  final String itemId;

  /// Corrects the tags: only the category and colour are editable, and only
  /// with values from `GET /meta`.
  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    WardrobeItem item,
  ) async {
    if (item.isProcessing) {
      showDripToast(context, 'Still processing, edit it once it\'s ready');
      return;
    }
    final AppMeta meta;
    try {
      meta = await ref.read(metaProvider.future);
    } catch (_) {
      if (context.mounted) showDripToast(context, "Couldn't load the options");
      return;
    }
    if (!context.mounted) return;
    var slot = item.slot;
    var colour = item.colorway.isEmpty ? null : item.colorway.toLowerCase();

    Widget chip(String label, bool selected, VoidCallback onTap) => Tap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? context.palette.accent : AppColors.elevated,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: AppText.manrope(
            12,
            weight: FontWeight.w600,
            color: selected ? AppColors.base : AppColors.cream,
          ),
        ),
      ),
    );

    final result = await showDripSheet<bool>(
      context,
      scrollable: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SheetContent(
          title: 'FIX THE TAGS',
          subtitle: 'Drip tagged this automatically. Correct it if it\'s off.',
          children: [
            const SectionLabel('CATEGORY', size: 9, letterSpacing: 0),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final c in meta.slots)
                  chip(
                    WardrobeItem.categoryLabel(c),
                    slot == c,
                    () => setSheet(() => slot = c),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const SectionLabel('COLOUR', size: 9, letterSpacing: 0),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final c in meta.colourFamilies)
                  chip(
                    '${c[0].toUpperCase()}${c.substring(1)}',
                    colour == c,
                    () => setSheet(() => colour = c),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            AppButton(
              label: 'SAVE CHANGES',
              height: 44,
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
          ],
        ),
      ),
    );
    if (result != true) return;
    final changedSlot = slot != item.slot ? slot : null;
    final changedColour = colour != item.colorway.toLowerCase() ? colour : null;
    if (changedSlot == null && changedColour == null) return;
    try {
      await ref
          .read(wardrobeProvider.notifier)
          .retag(item.id, slot: changedSlot, colour: changedColour);
      if (context.mounted) showDripToast(context, 'Item updated');
    } on ApiException catch (e) {
      if (context.mounted) showDripToast(context, e.friendly);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wardrobe = ref.watch(wardrobeProvider);
    final item = ref.watch(wardrobeItemProvider(itemId));
    final rotation = ref.watch(rotationProvider).value ?? const <String>[];
    final inRotation = rotation.contains(itemId);
    final accent = context.palette.accent;

    return ShellPage(
      child: Column(
        children: [
          DripTopBar(
            title: 'WARDROBE ITEM',
            leading: const BackGlyph(),
            trailing: GlyphButton(
              '⚡',
              mono: true,
              color: inRotation ? accent : AppColors.cream,
              label: inRotation ? 'Remove from rotation' : 'Add to rotation',
              onTap: item == null
                  ? null
                  : () async {
                      await ref
                          .read(wardrobeRepositoryProvider)
                          .setRotation(itemId, inRotation: !inRotation);
                      ref.invalidate(rotationProvider);
                      if (context.mounted) {
                        showDripToast(
                          context,
                          inRotation ? 'Out of rotation' : 'Added to rotation',
                        );
                      }
                    },
            ),
          ),
          Expanded(
            child: wardrobe.whenDrip(
              onRetry: () => ref.invalidate(wardrobeProvider),
              data: (_) {
                if (item == null) {
                  return EmptyState(
                    title: 'ITEM NOT FOUND',
                    message: 'This garment is no longer in your closet.',
                    actionLabel: 'BACK TO WARDROBE',
                    onAction: () => context.go('/wardrobe'),
                  );
                }
                return _Body(
                  item: item,
                  onEdit: () => _edit(context, ref, item),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.item, required this.onEdit});
  final WardrobeItem item;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = context.palette.accent;

    return SingleChildScrollView(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: SizedBox(
                height: 260,
                width: double.infinity,
                child: ColoredBox(
                  color: AppColors.surface,
                  child: DripImage(item.image, fit: BoxFit.contain),
                ),
              ),
            ),
          ),
          if (!item.isReady)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                item.isProcessing
                    ? 'Drip is cutting this out and tagging it. It updates '
                          'by itself in a moment.'
                    : "Drip couldn't find a garment in this photo. Remove it "
                          'and try a clearer, well-lit shot.',
                style: AppText.manrope(
                  12,
                  color: item.isFailed ? AppColors.red : AppColors.muted,
                  lineHeight: 17,
                ),
              ),
            ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(top: BorderSide(color: AppColors.elevated)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        item.name.toUpperCase(),
                        style: AppText.display(18),
                      ),
                    ),
                    if (item.price > 0)
                      Text(
                        formatPrice(item.price),
                        style: AppText.mono(14, color: accent),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _Prop(
                        'SOURCE',
                        item.origin == 'saved' ? 'From Drip' : 'Your photo',
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _Prop(
                        'COLORWAY',
                        item.colorway.isEmpty ? '—' : item.colorway,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(child: _Prop('CATEGORY', item.category)),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (var i = 0; i < item.tags.length; i++)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: i == 0 ? AppColors.cream : AppColors.cyan,
                          ),
                        ),
                        child: Text(
                          item.tags[i],
                          style: AppText.mono(
                            9,
                            color: i == 0 ? AppColors.cream : AppColors.cyan,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                AppButton(
                  label: 'CREATE FIT WITH THIS ✦',
                  height: 44,
                  onPressed: item.isReady && item.slot != null
                      ? () {
                          final category = StudioSlots.label(item.slot!);
                          ref.read(studioProvider.notifier)
                            ..useSource(wardrobe: true)
                            ..setCategory(category)
                            ..select(
                              StudioPiece(
                                id: item.id,
                                name: item.name,
                                category: category,
                                image: item.image,
                                source: 'wardrobe',
                              ),
                            );
                          context.push('/studio/builder');
                        }
                      : null,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _Outlined(
                        label: 'FIX TAGS',
                        color: AppColors.cream,
                        border: AppColors.muted,
                        onTap: onEdit,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _Outlined(
                        label: 'REMOVE CLOSET',
                        color: AppColors.red,
                        border: AppColors.red,
                        onTap: () async {
                          final ok = await showDripConfirm(
                            context,
                            title: 'REMOVE ITEM?',
                            message:
                                '${item.name} will be removed from your closet.',
                            confirmLabel: 'REMOVE',
                            destructive: true,
                          );
                          if (!ok) return;
                          await ref
                              .read(wardrobeProvider.notifier)
                              .remove(item.id);
                          if (context.mounted) {
                            showDripToast(context, 'Removed ${item.name}');
                            context.go('/wardrobe');
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _Prop extends StatelessWidget {
  const _Prop(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.mono(9, color: AppColors.muted)),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.manrope(13, weight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _Outlined extends StatelessWidget {
  const _Outlined({
    required this.label,
    required this.color,
    required this.border,
    required this.onTap,
  });
  final String label;
  final Color color;
  final Color border;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tap(
      onTap: onTap,
      child: Container(
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
        ),
        child: Text(label, style: AppText.mono(11, color: color)),
      ),
    );
  }
}
