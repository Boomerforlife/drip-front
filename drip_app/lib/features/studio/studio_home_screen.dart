import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/drip_image.dart';
import '../../core/widgets/glass.dart';
import '../../core/widgets/overlays.dart';
import '../../core/widgets/tap.dart';
import '../../core/widgets/top_bar.dart';
import '../../data/mock/mock_content.dart';
import '../../data/models/studio.dart';
import '../../data/providers.dart';
import '../../routing/main_shell.dart';
import '../outfits/outfit_controller.dart';
import '../wardrobe/wardrobe_controller.dart';
import 'fit_canvas.dart';
import 'studio_controller.dart';
import '../tour/tour.dart';

/// Drip Studio: where you make your own fits (a blank canvas, pieces from
/// the catalogue or your wardrobe), keep them, and later see your Gen photos.
class StudioHomeScreen extends ConsumerWidget {
  const StudioHomeScreen({super.key});

  void _open(BuildContext context, WidgetRef ref, {required bool wardrobe}) {
    ref.read(studioProvider.notifier).useSource(wardrobe: wardrobe);
    context.push('/studio/builder');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lib = ref.watch(libraryProvider);
    final mine = lib.value?.mine ?? const <UserFit>[];
    final gen = lib.value?.gen ?? const <GenJob>[];

    return ShellPage(
      child: Column(
        children: [
          const DripTopBar(title: 'DRIP STUDIO'),
          Expanded(
            child: RefreshIndicator(
              color: context.palette.accent,
              backgroundColor: AppColors.surface,
              onRefresh: () async {
                ref.invalidate(libraryProvider);
                await ref.read(libraryProvider.future);
              },
              child: ListView(
                // A tab root draws under the floating bar: clear it.
                padding: EdgeInsets.fromLTRB(
                  16,
                  4,
                  16,
                  24 + MediaQuery.paddingOf(context).bottom,
                ),
                children: [
                  TourAnchor(
                    id: 'studio.new',
                    child: _NewFitCard(
                      onTap: () => _open(context, ref, wardrobe: false),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _SmallCard(
                          icon: Icons.checkroom_rounded,
                          title: 'From my wardrobe',
                          subtitle: 'Your own pieces',
                          onTap: () async {
                            await ref.read(wardrobeProvider.future);
                            if (context.mounted) {
                              _open(context, ref, wardrobe: true);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SmallCard(
                          icon: Icons.shuffle_rounded,
                          title: 'Surprise me',
                          subtitle: 'A random fit to riff on',
                          onTap: () {
                            ref.read(studioProvider.notifier)
                              ..useSource(wardrobe: false)
                              ..randomize();
                            context.push('/studio/builder');
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  _SectionHeader(
                    'YOUR FITS',
                    count: mine.isEmpty ? null : mine.length,
                  ),
                  const SizedBox(height: 12),
                  if (mine.isEmpty)
                    _EmptyNote(
                      lib.isLoading
                          ? 'Loading your fits…'
                          : 'Fits you build and save land here.',
                    )
                  else
                    SizedBox(
                      // Canvas (118 wide at 9:16 = 210) + name + meta.
                      height: 262,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: mine.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 12),
                        itemBuilder: (context, i) => _FitCard(
                          fit: mine[i],
                          onTap: () {
                            ref.read(studioProvider.notifier).load(mine[i]);
                            context.push('/studio/builder');
                          },
                        ),
                      ),
                    ),
                  const SizedBox(height: 28),
                  const _SectionHeader('GEN PHOTOS'),
                  const SizedBox(height: 12),
                  if (gen.isEmpty)
                    _GenPlaceholder(
                      onTap: () =>
                          showAfterBeta(context, 'AI photoshoots of your fits'),
                    )
                  else
                    SizedBox(
                      height: 170,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: gen.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 10),
                        itemBuilder: (context, i) => ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: SizedBox(
                            width: 120,
                            child: DripImage(gen[i].outputUrl ?? ''),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 28),
                  _TaylorPromo(onTap: () => context.push('/stylist')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The main way in: a blank canvas, previewed with its "add" outlines.
class _NewFitCard extends StatelessWidget {
  const _NewFitCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = context.palette.accent;
    return Tap(
      onTap: onTap,
      scale: 0.98,
      semanticLabel: 'Start a new fit on a blank canvas',
      child: Glass(
        radius: 24,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const SizedBox(
              width: 104,
              child: IgnorePointer(child: FitCanvas(worn: {}, radius: 14)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'BLANK CANVAS',
                    style: AppText.mono(10, color: accent, letterSpacing: 1.6),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'BUILD YOUR\nOWN FIT',
                    style: AppText.display(20, lineHeight: 24),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Pick pieces from the Drip catalogue. Each one lands '
                    'in its place on the canvas.',
                    style: AppText.manrope(
                      12,
                      color: AppColors.muted,
                      lineHeight: 17,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'START A NEW FIT  →',
                    style: AppText.mono(
                      11,
                      color: accent,
                      weight: FontWeight.w500,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SmallCard extends StatelessWidget {
  const _SmallCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tap(
      onTap: onTap,
      scale: 0.97,
      semanticLabel: title,
      child: Glass(
        radius: 18,
        thickness: GlassThickness.thin,
        shadow: false,
        padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: context.palette.accent),
            const SizedBox(height: 12),
            Text(title, style: AppText.manrope(13, weight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(subtitle, style: AppText.manrope(11, color: AppColors.muted)),
          ],
        ),
      ),
    );
  }
}

/// A saved fit, drawn as a small canvas.
class _FitCard extends StatelessWidget {
  const _FitCard({required this.fit, required this.onTap});
  final UserFit fit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final meta = [
      if (fit.dripRate != null) '✦ ${fit.dripRate}',
      if ((fit.price ?? 0) > 0) formatPrice(fit.price!),
    ].join('  ·  ');
    return Tap(
      onTap: onTap,
      scale: 0.97,
      semanticLabel: 'Open ${fit.name}',
      child: SizedBox(
        width: 118,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Consumer(
              builder: (context, ref, _) => FitCanvas(
                worn: wornForFit(fit, ref.read(localStoreProvider)),
                placed: placementForFit(fit, ref.read(localStoreProvider)),
                stack: fit.stack,
                compact: true,
                radius: 14,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              fit.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.manrope(12, weight: FontWeight.w700),
            ),
            if (meta.isNotEmpty)
              Text(meta, style: AppText.mono(9, color: AppColors.muted)),
          ],
        ),
      ),
    );
  }
}

class _GenPlaceholder extends StatelessWidget {
  const _GenPlaceholder({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tap(
      onTap: onTap,
      scale: 0.98,
      semanticLabel: 'Gen photos, coming after beta',
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.elevated),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.auto_awesome_rounded,
              size: 22,
              color: AppColors.muted,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'See yourself in your fits. AI photoshoots of the looks you '
                'build will live here.',
                style: AppText.manrope(
                  12,
                  color: AppColors.muted,
                  lineHeight: 17,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'AFTER BETA',
              style: AppText.mono(9, color: AppColors.dim, letterSpacing: 1),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text, {this.count});
  final String text;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(text, style: AppText.display(14)),
        if (count != null) ...[
          const SizedBox(width: 8),
          Text(
            '$count'.padLeft(2, '0'),
            style: AppText.mono(10, color: AppColors.dim),
          ),
        ],
      ],
    );
  }
}

class _EmptyNote extends StatelessWidget {
  const _EmptyNote(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: AppText.manrope(12, color: AppColors.muted));
  }
}

class _TaylorPromo extends StatelessWidget {
  const _TaylorPromo({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tap(
      onTap: onTap,
      scale: 0.98,
      semanticLabel: 'Ask Taylor, the AI stylist',
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.elevated),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: ClipOval(child: DripImage(MockContent.taylorAvatarSmall)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Stuck? Ask Taylor',
                    style: AppText.manrope(13, weight: FontWeight.w700),
                  ),
                  Text(
                    'Pick an occasion and a vibe, get a fit.',
                    style: AppText.manrope(11, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            Text('→', style: AppText.inter(16, color: context.palette.accent)),
          ],
        ),
      ),
    );
  }
}
