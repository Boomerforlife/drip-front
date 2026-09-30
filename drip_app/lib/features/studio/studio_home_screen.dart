import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/drip_image.dart';
import '../../core/widgets/overlays.dart';
import '../../core/widgets/tap.dart';
import '../../core/widgets/top_bar.dart';
import '../../data/mock/mock_content.dart';
import '../../routing/main_shell.dart';
import '../wardrobe/wardrobe_controller.dart';
import 'studio_controller.dart';

class StudioHomeScreen extends ConsumerWidget {
  const StudioHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = context.palette.accent;
    return ShellPage(
      child: Column(
        children: [
          DripTopBar(
            title: 'DRIP STUDIO',
            leading: const BackGlyph(),
            trailing: GlyphButton(
              '⚡',
              label: 'Studio engine',
              onTap: () => showDripToast(context, 'OOTD Engine v1.0 · online'),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _Hero(),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _EntryCard(
                          glyph: '🛠',
                          title: 'BUILD FROM SCRATCH',
                          subtitle: 'Select piece by piece on active model',
                          borderColor: accent,
                          onTap: () {
                            ref
                                .read(studioProvider.notifier)
                                .useSource(wardrobe: false);
                            context.push('/studio/builder');
                          },
                        ),
                        const SizedBox(height: 12),
                        _EntryCard(
                          glyph: '🔄',
                          title: 'REMIX A FIT',
                          subtitle: 'A random fit from the catalogue to riff on',
                          onTap: () {
                            ref.read(studioProvider.notifier)
                              ..useSource(wardrobe: false)
                              ..randomize();
                            showDripToast(
                              context,
                              'Remixed from the catalogue',
                            );
                            context.push('/studio/builder');
                          },
                        ),
                        const SizedBox(height: 12),
                        _EntryCard(
                          glyph: '📦',
                          title: 'USE MY WARDROBE',
                          subtitle: 'Digitized real garments uploaded by you',
                          onTap: () async {
                            await ref.read(wardrobeProvider.future);
                            ref
                                .read(studioProvider.notifier)
                                .useSource(wardrobe: true);
                            if (context.mounted) {
                              context.push('/studio/builder');
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        _TaylorPromo(onTap: () => context.push('/stylist')),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DripImage(MockContent.studioHero),
          const ColoredBox(color: Color(0x660E1018)),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: context.palette.accent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'OOTD ENGINE V1.0',
                    style: AppText.mono(8, color: AppColors.base),
                  ),
                ),
                const SizedBox(height: 12),
                Text('CALIBRATE YOUR LOOK', style: AppText.display(22)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.glyph,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.borderColor,
  });

  final String glyph;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Tap(
      onTap: onTap,
      semanticLabel: title,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: borderColor == null ? null : Border.all(color: borderColor!),
        ),
        child: Row(
          children: [
            SizedBox(width: 24, child: Text(glyph, style: AppText.inter(24))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppText.display(14)),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppText.manrope(11, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            Text('→', style: AppText.inter(16)),
          ],
        ),
      ),
    );
  }
}

class _TaylorPromo extends StatelessWidget {
  const _TaylorPromo({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.elevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cyan),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: ClipOval(
                  child: DripImage(MockContent.taylorAvatarSmall),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '✦ TAYLOR AI ASSISTANT',
                style: AppText.mono(10, color: AppColors.cyan),
              ),
              const Spacer(),
              Text('ONLINE', style: AppText.mono(9, color: AppColors.muted)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '"Got an event? Tell me what\'s the occasion and your desired vibe. I\'ll frame a blueprint fit instantly."',
            style: AppText.manrope(13),
          ),
          const SizedBox(height: 12),
          AppButton(label: 'CONSULT STYLIST ✦', height: 36, onPressed: onTap),
        ],
      ),
    );
  }
}
