import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/motion.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/overlays.dart';
import '../../core/widgets/states.dart';
import '../../core/widgets/tap.dart';
import '../../core/widgets/top_bar.dart';
import '../../data/providers.dart';
import '../onboarding/local_selfie.dart';

/// My selfies: every selfie kept on this phone, newest first. Tapping one
/// opens it full size, to use it (for Gen) or delete it. Nothing here ever
/// leaves the device.
class SelfieGalleryScreen extends ConsumerWidget {
  const SelfieGalleryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gallery = ref.watch(selfieGalleryProvider);
    final inUse = ref.watch(localStoreProvider).selfiePath;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: AppColors.base,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const DripTopBar(title: 'MY SELFIES', leading: BackGlyph()),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
              child: Text(
                'Only on this phone. Never uploaded.',
                style: AppText.manrope(13, color: AppColors.muted),
              ),
            ),
            Expanded(
              child: switch (gallery) {
                AsyncData(:final value) when value.isEmpty => EmptyState(
                  title: 'No selfies yet',
                  message:
                      'Take one with the Selfie Coordinator and it lands here.',
                  actionLabel: 'TAKE A SELFIE',
                  onAction: () => context.push('/selfie'),
                ),
                AsyncData(:final value) => GridView.builder(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, bottom + 96),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 3 / 4,
                  ),
                  itemCount: value.length,
                  itemBuilder: (context, i) => _Thumb(
                    path: value[i],
                    inUse: value[i] == inUse,
                    onTap: () => _open(context, value[i]),
                  ),
                ),
                AsyncError() => ErrorState(
                  message: 'Couldn’t open your selfies. Try again.',
                  onRetry: () => ref.invalidate(selfieGalleryProvider),
                ),
                _ => const LoadingState(),
              },
            ),
            if (gallery.value?.isNotEmpty ?? false)
              Padding(
                padding: EdgeInsets.fromLTRB(24, 8, 24, bottom + 16),
                child: AppButton(
                  label: 'TAKE A NEW ONE',
                  style: AppButtonStyle.outline,
                  onPressed: () => context.push('/selfie'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _open(BuildContext context, String path) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: const Color(0xF20E1018),
        transitionDuration: Motion.dur(context, Motion.content),
        reverseTransitionDuration: Motion.dur(context, Motion.quick),
        pageBuilder: (_, _, _) => _SelfieViewer(path: path),
        transitionsBuilder: (_, a, _, child) =>
            FadeTransition(opacity: a, child: child),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.path, required this.inUse, required this.onTap});
  final String path;
  final bool inUse;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tap(
      onTap: onTap,
      semanticLabel: inUse ? 'Selfie in use' : 'Selfie',
      scale: 0.97,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Hero(tag: path, child: SelfieImage(path, cacheWidth: 360)),
            if (inUse)
              Positioned(
                left: 6,
                bottom: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.cream,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'IN USE',
                    style: AppText.mono(8, color: AppColors.base),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// One selfie, full size: USE IT (makes it the selfie in use) or DELETE.
class _SelfieViewer extends ConsumerWidget {
  const _SelfieViewer({required this.path});
  final String path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inUse = ref.watch(localStoreProvider).selfiePath == path;
    final pad = MediaQuery.paddingOf(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: EdgeInsets.fromLTRB(16, pad.top + 8, 16, pad.bottom + 16),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: BackGlyph(onTap: () => Navigator.of(context).pop()),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Hero(
                  tag: path,
                  child: SelfieImage(path, fit: BoxFit.contain),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'DELETE',
                    style: AppButtonStyle.outline,
                    onPressed: () async {
                      final sure = await showDripConfirm(
                        context,
                        title: 'DELETE THIS SELFIE?',
                        message: 'It’s removed from this phone for good.',
                        confirmLabel: 'DELETE',
                        destructive: true,
                      );
                      if (!sure || !context.mounted) return;
                      await ref
                          .read(selfieGalleryProvider.notifier)
                          .delete(path);
                      if (context.mounted) {
                        Navigator.of(context).pop();
                        showDripToast(context, 'Selfie deleted');
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppButton(
                    label: inUse ? 'IN USE ✓' : 'USE THIS ONE',
                    onPressed: inUse
                        ? null
                        : () async {
                            Haptics.commit();
                            await ref
                                .read(localSelfieProvider.notifier)
                                .use(path);
                            if (context.mounted) {
                              showDripToast(context, 'Using this selfie');
                            }
                          },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A selfie from this phone: a file, or a `data:` URI (web and tests).
class SelfieImage extends StatelessWidget {
  const SelfieImage(
    this.path, {
    super.key,
    this.fit = BoxFit.cover,
    this.cacheWidth,
  });

  final String path;
  final BoxFit fit;

  /// Decode smaller for thumbnails.
  final int? cacheWidth;

  @override
  Widget build(BuildContext context) {
    final broken = ColoredBox(
      color: AppColors.elevated,
      child: Center(
        child: Text('—', style: AppText.mono(12, color: AppColors.muted)),
      ),
    );
    if (path.startsWith('data:')) {
      return Image.memory(
        UriData.parse(path).contentAsBytes(),
        fit: fit,
        cacheWidth: cacheWidth,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => broken,
      );
    }
    if (kIsWeb) return broken;
    return Image.file(
      File(path),
      fit: fit,
      cacheWidth: cacheWidth,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => broken,
    );
  }
}
