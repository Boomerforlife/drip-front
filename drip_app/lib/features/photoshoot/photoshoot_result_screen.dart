import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/drip_image.dart';
import '../../core/widgets/overlays.dart';
import '../../core/widgets/states.dart';
import '../../core/widgets/top_bar.dart';
import '../../routing/main_shell.dart';
import 'photoshoot_controller.dart';

class PhotoshootResultScreen extends ConsumerWidget {
  const PhotoshootResultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final render = ref.watch(photoshootProvider).render.value;
    final accent = context.palette.accent;

    return ShellPage(
      child: Column(
        children: [
          DripTopBar(
            title: 'GENERATED FIT',
            leading: const BackGlyph(),
            trailing: GlyphButton(
              '✨',
              label: 'Regenerate',
              onTap: () => context.pop(),
            ),
          ),
          Expanded(
            child: render == null
                ? EmptyState(
                    title: 'NOTHING RENDERED',
                    message: 'Pick a fit and a scene, then generate your look.',
                    actionLabel: 'BACK TO STUDIO SHOT',
                    onAction: () => context.go('/photoshoot'),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: SizedBox(
                          height: 360,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              DripImage(render.image),
                              Positioned(
                                left: 12,
                                bottom: 12,
                                child: Row(
                                  children: [
                                    _Chip(
                                      text: 'SCENE: ${render.scene}',
                                      color: AppColors.cyan,
                                    ),
                                    const SizedBox(width: 8),
                                    _Chip(
                                      text: render.fellBack
                                          ? 'FIT COLLAGE'
                                          : 'FIT SCORE: ${render.score}%',
                                      color: accent,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(render.title, style: AppText.display(18)),
                      const SizedBox(height: 4),
                      Text(
                        render.fellBack
                            ? 'GEN FELL BACK TO THE FIT · CREDIT REFUNDED'
                            : 'GENERATED STUDIO AI RENDER · EST. 2077',
                        style: AppText.mono(11, color: AppColors.cyan),
                      ),
                      const SizedBox(height: 20),
                      AppButton(
                        label: 'POST TO DRIP FEED 🚀',
                        height: 44,
                        onPressed: () =>
                            showAfterBeta(context, 'Posting to the feed'),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: AppButton(
                              label: 'SAVE TO LOOKS',
                              style: AppButtonStyle.outline,
                              height: 36,
                              onPressed: () {
                                ref
                                    .read(myPhotosProvider.notifier)
                                    .add(render.image);
                                showDripToast(context, 'Saved to your photos');
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedAction(
                              label: 'MAKE OOTD ✦',
                              color: AppColors.cyan,
                              onTap: () => showAfterBeta(context, 'OOTD posts'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: AppButton(
                              label: 'TRY ANOTHER SCENE',
                              style: AppButtonStyle.subtle,
                              height: 36,
                              onPressed: () {
                                ref
                                    .read(photoshootProvider.notifier)
                                    .clearRender();
                                context.pop();
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: AppButton(
                              label: 'SHARE FIT',
                              style: AppButtonStyle.subtle,
                              height: 36,
                              onPressed: () => showAfterBeta(context, 'Sharing'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.base.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color),
      ),
      child: Text(text, style: AppText.mono(8, color: color)),
    );
  }
}

/// Outlined action with a coloured label (e.g. cyan "MAKE OOTD").
class OutlinedAction extends StatelessWidget {
  const OutlinedAction({
    super.key,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color),
        ),
        child: Text(label, style: AppText.mono(10, color: color)),
      ),
    );
  }
}
