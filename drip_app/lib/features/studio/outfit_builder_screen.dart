import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/motion.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/controls.dart';
import '../../core/widgets/drip_image.dart';
import '../../core/widgets/overlays.dart';
import '../../core/widgets/skeleton.dart';
import '../../core/widgets/tap.dart';
import '../../core/widgets/top_bar.dart';
import '../../data/api/api_client.dart';
import '../../data/models/stylist.dart';
import '../../routing/main_shell.dart';
import '../outfits/outfit_controller.dart';
import 'fit_canvas.dart';
import 'studio_controller.dart';
import 'studio_layouts.dart';

/// The Studio canvas: start blank, pick pieces from the catalogue (or your
/// own wardrobe) one category at a time, and watch each land on the canvas in
/// the place its layout gives it. Save it as your own fit; the server scores
/// it.
class OutfitBuilderScreen extends ConsumerStatefulWidget {
  const OutfitBuilderScreen({super.key});

  @override
  ConsumerState<OutfitBuilderScreen> createState() =>
      _OutfitBuilderScreenState();
}

class _OutfitBuilderScreenState extends ConsumerState<OutfitBuilderScreen> {
  bool _saving = false;

  static const _categories = [
    ('TOPS', 'Tops'),
    ('BOTTOMS', 'Bottoms'),
    ('FOOTWEAR', 'Shoes'),
    ('OUTERWEAR', 'Layers'),
    ('DRESSES', 'Dresses'),
    ('ACCESSORIES', 'Extras'),
  ];

  Future<void> _save() async {
    final studio = ref.read(studioProvider);
    if (studio.worn.isEmpty) {
      showDripToast(context, 'Add a piece to the canvas first');
      return;
    }
    final mine = ref.read(libraryProvider).value?.mine.length ?? 0;
    final name = await _askName(studio.saved?.name ?? 'Fit #${mine + 1}');
    if (name == null || !mounted) return;
    setState(() => _saving = true);
    try {
      final fit = await ref.read(studioProvider.notifier).save(name: name);
      if (!mounted) return;
      showDripToast(
        context,
        fit.dripRate == null
            ? 'Saved to your Studio'
            : 'Saved · drip rate ${fit.dripRate}',
      );
    } on ApiException catch (e) {
      debugPrint('[studio] save failed: $e ${e.details}');
      final why = e.details.isEmpty ? '' : ' (${e.details.first})';
      if (mounted) showDripToast(context, '${e.friendly}$why');
    } catch (e, st) {
      debugPrint('[studio] save failed: $e $st');
      if (mounted) showDripToast(context, "Couldn't save the fit. Try again.");
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// The sheet owns its text controller, so it's disposed only once the
  /// sheet has finished closing (disposing it as the sheet's future completes
  /// broke the field mid-animation: the error seen on save).
  Future<String?> _askName(String initial) => showDripSheet<String>(
    context,
    builder: (_) => _NameSheet(initial: initial),
  );

  void _pick(StudioPiece piece) {
    Haptics.tick();
    final note = ref.read(studioProvider.notifier).select(piece);
    if (note != null) showDripToast(context, note);
  }

  @override
  Widget build(BuildContext context) {
    final studio = ref.watch(studioProvider);
    final c = ref.read(studioProvider.notifier);
    final plan = FitLayouts.plan(studio.worn);
    final accent = context.palette.accent;

    return ShellPage(
      child: Column(
        children: [
          DripTopBar(
            title: 'CANVAS',
            leading: const BackGlyph(),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _HeaderIcon(
                  icon: Icons.undo_rounded,
                  label: 'Undo',
                  onTap: c.canUndo ? c.undo : null,
                ),
                _HeaderIcon(
                  icon: Icons.shuffle_rounded,
                  label: 'Surprise me',
                  onTap: () {
                    Haptics.tick();
                    c.randomize();
                  },
                ),
                _HeaderIcon(
                  icon: Icons.restart_alt_rounded,
                  label: 'Clear the canvas',
                  onTap: studio.worn.isEmpty ? null : c.reset,
                ),
                const SizedBox(width: 4),
                _SavePill(
                  saving: _saving,
                  saved: studio.saved != null && !studio.dirty,
                  onTap: _save,
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Center(
                child: FitCanvas(
                  worn: studio.worn,
                  placed: studio.placed,
                  stack: studio.stack,
                  selected: studio.category,
                  onSlotTap: c.setCategory,
                  onMoveStart: c.beginMove,
                  onMove: c.move,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: Row(
              children: [
                Text(
                  'LAYOUT · ${plan.layout.label.toUpperCase()}',
                  style: AppText.mono(
                    9,
                    color: AppColors.muted,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(width: 10),
                if (studio.placed.isNotEmpty)
                  Tap(
                    onTap: c.snapBack,
                    semanticLabel: 'Snap every piece back into the layout',
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        'SNAP BACK ↺',
                        style: AppText.mono(
                          9,
                          color: accent,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  )
                else if (studio.worn.isNotEmpty)
                  Text(
                    'DRAG · PINCH TO RESIZE',
                    style: AppText.mono(
                      9,
                      color: AppColors.dim,
                      letterSpacing: 1.2,
                    ),
                  ),
                const Spacer(),
                if (studio.total > 0)
                  Text(
                    formatPrice(studio.total),
                    style: AppText.mono(11, weight: FontWeight.w500),
                  ),
                if (studio.dripRate != null) ...[
                  const SizedBox(width: 10),
                  Text(
                    '✦ ${studio.dripRate}',
                    style: AppText.mono(
                      11,
                      color: accent,
                      weight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          _Tray(categories: _categories, onPick: _pick),
        ],
      ),
    );
  }
}

/// Category tabs, the catalogue/wardrobe switch, and the pieces carousel.
class _Tray extends ConsumerWidget {
  const _Tray({required this.categories, required this.onPick});
  final List<(String, String)> categories;
  final ValueChanged<StudioPiece> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studio = ref.watch(studioProvider);
    final c = ref.read(studioProvider.notifier);
    // The tab is the canvas key's category (extra accessories share one).
    final category = baseCategory(studio.category);
    final wornIds = {
      for (final e in studio.worn.entries)
        if (baseCategory(e.key) == category) e.value.id,
    };
    // TAKE OFF removes the piece being edited, or the newest in this tab.
    final removable = studio.worn.containsKey(studio.category)
        ? studio.category
        : studio.stack.lastWhere(
            (k) => baseCategory(k) == category,
            orElse: () => '',
          );
    final worn = studio.worn[removable];
    final key = (category, studio.fromWardrobe);
    final pieces = ref.watch(studioPiecesProvider(key));
    final label = categories
        .firstWhere((x) => x.$1 == category, orElse: () => categories.first)
        .$2
        .toUpperCase();

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.only(top: 12, bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: AppColors.elevated)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: categories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final (id, name) = categories[i];
                return _CategoryTab(
                  label: name,
                  selected: id == category,
                  filled: studio.worn.keys.any((k) => baseCategory(k) == id),
                  onTap: () => c.setCategory(id),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: Row(
              children: [
                _SourceSwitch(
                  wardrobe: studio.fromWardrobe,
                  onChanged: (w) => c.setSource(wardrobe: w),
                ),
                const Spacer(),
                if (worn != null)
                  Tap(
                    onTap: () => c.remove(removable),
                    semanticLabel: 'Take off ${worn.name}',
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        'TAKE OFF ✕',
                        style: AppText.mono(
                          10,
                          color: AppColors.red,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            height: 124,
            child: pieces.when(
              loading: () => const _CarouselSkeleton(),
              error: (e, _) => Center(
                child: Tap(
                  onTap: () => ref.invalidate(studioPiecesProvider(key)),
                  child: Text(
                    "COULDN'T LOAD PIECES · TAP TO RETRY",
                    style: AppText.mono(9, color: AppColors.red),
                  ),
                ),
              ),
              data: (list) => list.isEmpty
                  ? _EmptyCarousel(
                      fromWardrobe: studio.fromWardrobe,
                      category: label,
                    )
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 10),
                      itemBuilder: (context, i) => _PieceTile(
                        piece: list[i],
                        selected: wornIds.contains(list[i].id),
                        onTap: () => onPick(list[i]),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryTab extends StatelessWidget {
  const _CategoryTab({
    required this.label,
    required this.selected,
    required this.filled,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = context.palette.accent;
    return Tap(
      onTap: onTap,
      scale: 0.95,
      semanticLabel: '$label${filled ? ', on the canvas' : ''}',
      child: AnimatedContainer(
        duration: Motion.quick,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.cream : AppColors.base,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color: selected ? AppColors.cream : AppColors.elevated,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label.toUpperCase(),
              style: AppText.mono(
                10,
                weight: FontWeight.w500,
                letterSpacing: 1,
                color: selected ? AppColors.base : AppColors.cream,
              ),
            ),
            if (filled) ...[
              const SizedBox(width: 6),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SourceSwitch extends StatelessWidget {
  const _SourceSwitch({required this.wardrobe, required this.onChanged});
  final bool wardrobe;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget option(String label, bool value) {
      final on = wardrobe == value;
      return Tap(
        onTap: () => onChanged(value),
        semanticLabel: label,
        child: AnimatedContainer(
          duration: Motion.quick,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: on ? AppColors.elevated : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: AppText.mono(
              9,
              letterSpacing: 1,
              color: on ? AppColors.cream : AppColors.muted,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AppColors.base,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.elevated),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          option('DRIP CATALOGUE', false),
          option('MY WARDROBE', true),
        ],
      ),
    );
  }
}

class _PieceTile extends StatelessWidget {
  const _PieceTile({
    required this.piece,
    required this.selected,
    required this.onTap,
  });
  final StudioPiece piece;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = context.palette.accent;
    return Tap(
      onTap: onTap,
      scale: 0.94,
      semanticLabel: selected ? 'Take off ${piece.name}' : 'Wear ${piece.name}',
      child: SizedBox(
        width: 84,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: Motion.quick,
              width: 84,
              height: 88,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: FitLayout.background,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected ? accent : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DripImage(
                    piece.image,
                    fit: BoxFit.contain,
                    logicalWidth: 84,
                    backdrop: false,
                  ),
                  if (selected)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        width: 18,
                        height: 18,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: accent,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          size: 12,
                          color: AppColors.base,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 5),
            Text(
              piece.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.manrope(10, weight: FontWeight.w600),
            ),
            if (piece.price > 0)
              Text(
                formatPrice(piece.price),
                style: AppText.mono(9, color: AppColors.muted),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCarousel extends StatelessWidget {
  const _EmptyCarousel({required this.fromWardrobe, required this.category});
  final bool fromWardrobe;
  final String category;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              fromWardrobe
                  ? 'NO $category IN YOUR WARDROBE YET'
                  : 'NO $category IN THE CATALOGUE YET',
              textAlign: TextAlign.center,
              style: AppText.mono(9, color: AppColors.muted, letterSpacing: 1),
            ),
            if (fromWardrobe) ...[
              const SizedBox(height: 8),
              Tap(
                onTap: () => context.push('/wardrobe/capture'),
                semanticLabel: 'Add a garment',
                child: Text(
                  'ADD ONE  →',
                  style: AppText.mono(
                    10,
                    color: context.palette.accent,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CarouselSkeleton extends StatelessWidget {
  const _CarouselSkeleton();

  @override
  Widget build(BuildContext context) {
    return ShimmerScope(
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 5,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, _) => const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Skeleton(width: 84, height: 88, radius: 16),
            SizedBox(height: 6),
            Skeleton(width: 60, height: 9, radius: 4),
          ],
        ),
      ),
    );
  }
}

class _SavePill extends StatelessWidget {
  const _SavePill({
    required this.saving,
    required this.saved,
    required this.onTap,
  });
  final bool saving;
  final bool saved;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = context.palette.accent;
    return Tap(
      onTap: saving ? null : onTap,
      scale: 0.95,
      semanticLabel: saved ? 'Saved' : 'Save fit',
      child: AnimatedContainer(
        duration: Motion.quick,
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: saved ? Colors.transparent : accent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent),
        ),
        child: saving
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.base,
                ),
              )
            : Text(
                saved ? 'SAVED ✓' : 'SAVE',
                style: AppText.mono(
                  10,
                  weight: FontWeight.w500,
                  letterSpacing: 1.2,
                  color: saved ? accent : AppColors.base,
                ),
              ),
      ),
    );
  }
}

/// A 44px header action that dims (and stops responding) when unavailable.
class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tap(
      onTap: onTap,
      semanticLabel: label,
      scale: 0.9,
      child: SizedBox(
        width: 36,
        height: 44,
        child: AnimatedOpacity(
          duration: Motion.quick,
          opacity: onTap == null ? 0.35 : 1,
          child: Icon(icon, size: 20, color: AppColors.cream),
        ),
      ),
    );
  }
}

class _NameSheet extends StatefulWidget {
  const _NameSheet({required this.initial});
  final String initial;

  @override
  State<_NameSheet> createState() => _NameSheetState();
}

class _NameSheetState extends State<_NameSheet> {
  late final _c = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _done([String? v]) {
    final name = (v ?? _c.text).trim();
    Navigator.of(context).pop(name.isEmpty ? widget.initial : name);
  }

  @override
  Widget build(BuildContext context) {
    return SheetContent(
      title: 'NAME THIS FIT',
      subtitle: 'It lands in your Studio. Only you can see it.',
      children: [
        DripField(
          controller: _c,
          hint: 'e.g. Sunday cargo fit',
          radius: 14,
          autofocus: true,
          onSubmitted: _done,
        ),
        const SizedBox(height: 14),
        AppButton(label: 'SAVE FIT ✦', height: 44, onPressed: _done),
      ],
    );
  }
}
