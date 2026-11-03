import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/drip_image.dart';
import '../../core/widgets/overlays.dart';
import '../../core/widgets/pills.dart';
import '../../core/widgets/states.dart';
import '../../core/widgets/tap.dart';
import '../../core/widgets/top_bar.dart';
import '../../data/models/wardrobe.dart';
import '../../routing/main_shell.dart';
import 'wardrobe_controller.dart';
import '../tour/tour.dart';

/// Groups garments the way the wardrobe grid labels them. Uploads still
/// being processed (or that failed) sit together at the top.
String sectionFor(WardrobeItem i) {
  if (i.isProcessing) return 'PROCESSING';
  if (i.isFailed) return 'NEEDS A BETTER PHOTO';
  return switch (i.category) {
    'Boots' || 'Shoes' => 'SHOES',
    'Accessories' => 'ACCESSORIES',
    'Bottoms' => 'BOTTOMS',
    'Dresses' => 'DRESSES',
    'Unsorted' => 'UNSORTED',
    _ => 'TOPS & OUTERWEAR',
  };
}

class WardrobeScreen extends ConsumerStatefulWidget {
  const WardrobeScreen({super.key});

  @override
  ConsumerState<WardrobeScreen> createState() => _WardrobeScreenState();
}

class _WardrobeScreenState extends ConsumerState<WardrobeScreen> {
  bool _rotationTab = false;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) ref.read(wardrobeProvider.notifier).refreshIfStale();
    });
  }

  Future<void> _remove(WardrobeItem item) async {
    final ok = await showDripConfirm(
      context,
      title: 'REMOVE ITEM?',
      message: '${item.name} will be removed from your closet.',
      confirmLabel: 'REMOVE',
      destructive: true,
    );
    if (ok) {
      await ref.read(wardrobeProvider.notifier).remove(item.id);
      if (mounted) showDripToast(context, 'Removed ${item.name}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final wardrobe = ref.watch(wardrobeProvider);
    final rotation = ref.watch(rotationProvider).value ?? const <String>[];
    final count = wardrobe.value?.length;

    return ShellPage(
      child: Column(
        children: [
          DripTopBar(
            title: 'WARDROBE',
            card: true,
            height: 44,
            leading: const BackGlyph(),
            trailing: GlyphButton(
              '➕',
              mono: true,
              label: 'Add garment',
              onTap: () => context.push('/wardrobe/capture'),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
              border: Border(bottom: BorderSide(color: AppColors.elevated)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  FilterPill(
                    label: 'MY WARDROBE${count == null ? '' : ' ($count)'}',
                    selected: !_rotationTab,
                    onTap: () => setState(() => _rotationTab = false),
                  ),
                  const SizedBox(width: 8),
                  FilterPill(
                    label: 'SAVED',
                    selected: false,
                    onTap: () => context.push('/saved'),
                  ),
                  const SizedBox(width: 8),
                  FilterPill(
                    label: 'ROTATION',
                    selected: _rotationTab,
                    onTap: () => setState(() => _rotationTab = true),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: wardrobe.whenDrip(
              onRetry: () => ref.invalidate(wardrobeProvider),
              data: (items) {
                final visible = _rotationTab
                    ? items.where((i) => rotation.contains(i.id)).toList()
                    : items;
                if (visible.isEmpty) {
                  return EmptyState(
                    title: _rotationTab
                        ? 'NO ROTATION YET'
                        : 'YOUR CLOSET IS EMPTY',
                    message: _rotationTab
                        ? 'Mark garments with ⚡ on their page to keep your most-worn pieces here.'
                        : 'Photograph a piece you own and Drip will cut it out and tag it.',
                    actionLabel: _rotationTab ? null : 'UPLOAD GARMENT',
                    onAction: () => context.push('/wardrobe/capture'),
                  );
                }
                final sections = <String, List<WardrobeItem>>{};
                for (final i in visible) {
                  sections.putIfAbsent(sectionFor(i), () => []).add(i);
                }
                return ListView(
                  // Clear the floating nav (the tab root draws under it).
                  padding: EdgeInsets.fromLTRB(
                    16,
                    16,
                    16,
                    16 + MediaQuery.paddingOf(context).bottom,
                  ),
                  children: [
                    for (final entry in sections.entries) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          SectionLabel(entry.key),
                          if (entry.key == sections.keys.first)
                            Tap(
                              onTap: () => setState(() => _editing = !_editing),
                              child: Text(
                                _editing ? 'DONE ✓' : 'EDIT GRID ✎',
                                style: AppText.mono(10, color: AppColors.cyan),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _Grid(
                        items: entry.value,
                        editing: _editing,
                        onRemove: _remove,
                        addTile:
                            entry.key == sections.keys.last && !_rotationTab,
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({
    required this.items,
    required this.editing,
    required this.onRemove,
    required this.addTile,
  });
  final List<WardrobeItem> items;
  final bool editing;
  final ValueChanged<WardrobeItem> onRemove;
  final bool addTile;

  @override
  Widget build(BuildContext context) {
    final cells = <Widget>[
      for (final i in items)
        GarmentCard(item: i, editing: editing, onRemove: () => onRemove(i)),
      if (addTile) const _UploadTile(),
    ];
    final rows = <Widget>[];
    for (var i = 0; i < cells.length; i += 2) {
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: cells[i]),
            const SizedBox(width: 12),
            Expanded(
              child: i + 1 < cells.length
                  ? cells[i + 1]
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      );
      if (i + 2 < cells.length) rows.add(const SizedBox(height: 12));
    }
    return Column(children: rows);
  }
}

class GarmentCard extends StatelessWidget {
  const GarmentCard({
    super.key,
    required this.item,
    this.editing = false,
    this.onRemove,
  });
  final WardrobeItem item;
  final bool editing;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Tap(
      onTap: () => editing
          ? onRemove?.call()
          : context.push('/wardrobe/item/${item.id}'),
      semanticLabel: item.name,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: editing ? AppColors.red : AppColors.elevated,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    height: 100,
                    width: double.infinity,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        DripImage(item.image),
                        if (item.isProcessing)
                          const ColoredBox(
                            color: Color(0x990E1018),
                            child: LoadingState(compact: true),
                          ),
                      ],
                    ),
                  ),
                ),
                if (editing)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: AppColors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '✕',
                        style: AppText.inter(12, color: AppColors.base),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.manrope(12, weight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              item.status,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.mono(
                8,
                color: item.isFailed ? AppColors.red : AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UploadTile extends StatelessWidget {
  const _UploadTile();

  @override
  Widget build(BuildContext context) {
    return TourAnchor(
      id: 'wardrobe.add',
      child: Tap(
        onTap: () => context.push('/wardrobe/capture'),
        semanticLabel: 'Upload garment',
        child: Container(
          height: 158,
          decoration: BoxDecoration(
            color: AppColors.elevated,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.cyan),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('➕', style: AppText.inter(24, color: AppColors.cyan)),
              const SizedBox(height: 10),
              Text(
                'UPLOAD GARMENT',
                style: AppText.mono(9, color: AppColors.cyan),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
