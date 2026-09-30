import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/motion.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/controls.dart';
import '../../core/widgets/drip_image.dart';
import '../../core/widgets/overlays.dart';
import '../../core/widgets/tap.dart';
import '../../core/widgets/top_bar.dart';
import '../../data/api/api_client.dart';
import '../../data/mock/mock_content.dart';
import '../../data/repositories/stylist_repository.dart';
import 'stylist_controller.dart';

class TaylorScreen extends ConsumerWidget {
  const TaylorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stylistProvider);
    final controller = ref.read(stylistProvider.notifier);
    final options = ref.watch(stylistOptionsProvider).value;
    final occasions = options?.$1 ?? const <String>[];
    final vibes = options?.$2 ?? const <String>[];
    final loading = s.blueprint.isLoading;
    final bottom = math.max(MediaQuery.paddingOf(context).bottom, 8.0);

    Future<void> generate() async {
      final result = await controller.generate();
      if (!context.mounted) return;
      if (result != null) {
        context.push('/stylist/result');
        return;
      }
      final error = ref.read(stylistProvider).blueprint.error;
      if (error == null) return;
      showDripToast(
        context,
        error is NoFitsYet
            ? "Taylor's rail is still being stocked. Try again soon."
            : error is ApiException
            ? error.friendly
            : 'Taylor is offline — try again',
      );
    }

    return Scaffold(
      backgroundColor: AppColors.base,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            DripTopBar(
              title: 'TAYLOR STYLIST',
              leading: const BackGlyph(),
              trailing: GlyphButton(
                '✦',
                label: 'About Taylor',
                onTap: () =>
                    showDripToast(context, 'Taylor AI · active consultation'),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 32,
                          height: 32,
                          child: ClipOval(
                            child: DripImage(MockContent.taylorAvatar),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Taylor AI',
                              style: AppText.manrope(
                                13,
                                weight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'ACTIVE CONSULTATION',
                              style: AppText.mono(9, color: AppColors.cyan),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(4),
                          topRight: Radius.circular(16),
                          bottomLeft: Radius.circular(16),
                          bottomRight: Radius.circular(16),
                        ),
                      ),
                      child: Text(
                        '"${MockContent.stylistGreeting}"',
                        style: AppText.manrope(13, lineHeight: 20),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'TARGET OCCASION',
                      style: AppText.mono(9, color: AppColors.muted),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final o in occasions)
                          _Chip(
                            label: o,
                            selected: s.occasion == o,
                            onTap: () => controller.setOccasion(o),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'DESIRED ATTIRE VIBE',
                      style: AppText.mono(9, color: AppColors.muted),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final v in vibes)
                          _Chip(
                            label: v,
                            selected: s.vibe == v,
                            onTap: () => controller.setVibe(v),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Text('📦', style: AppText.inter(18)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Restrict to my digitized garments',
                              style: AppText.manrope(13),
                            ),
                          ),
                          DripSwitch(
                            value: s.restrictToWardrobe,
                            onChanged: controller.setRestrict,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, bottom + 16),
              child: AppButton(
                label: 'GENERATE BLUEPRINT LOOK ✦',
                height: 44,
                loading: loading,
                onPressed: generate,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tap(
      onTap: () {
        if (!selected) Haptics.tick();
        onTap();
      },
      semanticLabel: label,
      child: AnimatedContainer(
        duration: Motion.quick,
        curve: Motion.out,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.cream : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? AppColors.cream
                : AppColors.cream.withValues(alpha: 0.10),
          ),
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
  }
}
