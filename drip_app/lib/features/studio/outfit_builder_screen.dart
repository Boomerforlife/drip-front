import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/motion.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/drip_image.dart';
import '../../core/widgets/overlays.dart';
import '../../core/widgets/tap.dart';
import '../../core/widgets/top_bar.dart';
import '../../core/widgets/states.dart';
import '../../data/api/api_client.dart';
import '../../data/mock/mock_content.dart';
import '../../data/models/stylist.dart';
import '../../routing/main_shell.dart';
import 'studio_controller.dart';

class OutfitBuilderScreen extends ConsumerStatefulWidget {
  const OutfitBuilderScreen({super.key});

  @override
  ConsumerState<OutfitBuilderScreen> createState() =>
      _OutfitBuilderScreenState();
}

class _OutfitBuilderScreenState extends ConsumerState<OutfitBuilderScreen> {
  bool _saving = false;

  Future<void> _pickCategory() async {
    final current = ref.read(studioProvider).category;
    final chosen = await showDripSheet<String>(
      context,
      builder: (ctx) => SheetContent(
        title: 'SWAP CATEGORY',
        children: [
          for (final c in StudioSlots.categories)
            Tap(
              onTap: () => Navigator.of(ctx).pop(c),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.elevated)),
                ),
                child: Row(
                  children: [
                    Expanded(child: Text(c, style: AppText.mono(13))),
                    if (c == current)
                      Text(
                        '✓',
                        style: AppText.mono(14, color: context.palette.accent),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
    if (chosen != null) ref.read(studioProvider.notifier).setCategory(chosen);
  }

  /// Saves the canvas as a private fit in the user's studio. The server
  /// scores it (the drip rate needs at least two pieces).
  Future<void> _save() async {
    final studio = ref.read(studioProvider);
    if (studio.worn.isEmpty) {
      showDripToast(context, 'Add at least one piece first');
      return;
    }
    setState(() => _saving = true);
    try {
      final fit = await ref.read(studioProvider.notifier).save();
      if (!mounted) return;
      showDripToast(
        context,
        fit.dripRate == null
            ? 'Saved to your studio'
            : 'Saved · drip rate ${fit.dripRate}',
      );
    } on ApiException catch (e) {
      if (mounted) showDripToast(context, e.friendly);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final studio = ref.watch(studioProvider);
    final controller = ref.read(studioProvider.notifier);
    final rate = studio.dripRate;
    final accent = context.palette.accent;
    final pieces = ref.watch(
      studioPiecesProvider((studio.category, studio.fromWardrobe)),
    );

    return ShellPage(
      child: Column(
        children: [
          DripTopBar(
            title: 'STUDIO CANVAS',
            leading: const BackGlyph(),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _HeaderIcon(
                  icon: Icons.undo_rounded,
                  label: 'Undo',
                  onTap: controller.canUndo ? controller.undo : null,
                ),
                _HeaderIcon(
                  icon: Icons.restart_alt_rounded,
                  label: 'Reset',
                  onTap: controller.reset,
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(
                    height: 360,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          DripImage(
                            MockContent.builderModel,
                            alignment: Alignment.topCenter,
                          ),
                          Positioned(
                            left: 12,
                            top: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.base.withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: accent),
                              ),
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                child: Text(
                                  rate == null
                                      ? 'DRIP RATE: SAVE TO SCORE'
                                      : 'DRIP RATE: $rate%',
                                  key: ValueKey(rate),
                                  style: AppText.mono(8, color: accent),
                                ),
                              ),
                            ),
                          ),
                          // Currently worn pieces (layers on the model).
                          Positioned(
                            right: 12,
                            top: 12,
                            child: Column(
                              children: [
                                for (final p in studio.worn.values)
                                  Container(
                                    width: 36,
                                    height: 36,
                                    margin: const EdgeInsets.only(bottom: 6),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: AppColors.cream.withValues(
                                          alpha: 0.6,
                                        ),
                                      ),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(9),
                                      child: DripImage(p.image),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 12,
                            child: Center(
                              child: Tap(
                                onTap: controller.randomize,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: accent,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    '✦ RANDOMIZE FIT ✦',
                                    style: AppText.display(
                                      10,
                                      color: AppColors.base,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'SWAP PIECES',
                              style: AppText.mono(10, color: AppColors.muted),
                            ),
                            Tap(
                              onTap: _pickCategory,
                              child: Text(
                                '${studio.category} ▼',
                                style: AppText.mono(10, color: AppColors.cyan),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 80,
                          child: pieces.when(
                            loading: () => const LoadingState(compact: true),
                            error: (e, _) => Center(
                              child: Tap(
                                onTap: () => ref.invalidate(
                                  studioPiecesProvider((
                                    studio.category,
                                    studio.fromWardrobe,
                                  )),
                                ),
                                child: Text(
                                  "COULDN'T LOAD PIECES · TAP TO RETRY",
                                  style: AppText.mono(9, color: AppColors.red),
                                ),
                              ),
                            ),
                            data: (list) => list.isEmpty
                                ? Center(
                                    child: Text(
                                      studio.fromWardrobe
                                          ? 'NO ${studio.category} IN YOUR WARDROBE YET'
                                          : 'NO ${studio.category} IN THE CATALOGUE YET',
                                      textAlign: TextAlign.center,
                                      style: AppText.mono(
                                        9,
                                        color: AppColors.muted,
                                      ),
                                    ),
                                  )
                                : ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: list.length,
                                    separatorBuilder: (_, _) =>
                                        const SizedBox(width: 8),
                                    itemBuilder: (context, i) => _PieceTile(
                                      piece: list[i],
                                      selected:
                                          studio.worn[studio.category]?.id ==
                                          list[i].id,
                                      onTap: () => controller.select(list[i]),
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'PHOTOSHOOT 📸',
                    style: AppButtonStyle.subtle,
                    height: 36,
                    onPressed: () => context.push('/photoshoot'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AppButton(
                    label: 'SAVE FIT ✦',
                    height: 36,
                    loading: _saving,
                    onPressed: _save,
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
    return Tap(
      onTap: onTap,
      semanticLabel: piece.name,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 80,
        height: 80,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? context.palette.accent : AppColors.elevated,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: DripImage(piece.image),
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
        width: 40,
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
