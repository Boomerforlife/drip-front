import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/controls.dart';
import '../../core/widgets/drip_image.dart';
import '../../core/widgets/overlays.dart';
import '../../core/widgets/states.dart';
import '../../core/widgets/tap.dart';
import '../../core/widgets/top_bar.dart';
import '../../data/api/api_client.dart';
import '../../data/mock/mock_content.dart';
import '../../data/models/account.dart';
import '../../data/models/outfit.dart';
import '../../data/models/stylist.dart';
import '../../data/providers.dart';
import '../../routing/main_shell.dart';
import '../outfits/outfit_controller.dart';
import '../wardrobe/wardrobe_controller.dart';
import 'photoshoot_controller.dart';

class PhotoshootScreen extends ConsumerStatefulWidget {
  const PhotoshootScreen({super.key});

  @override
  ConsumerState<PhotoshootScreen> createState() => _PhotoshootScreenState();
}

class _PhotoshootScreenState extends ConsumerState<PhotoshootScreen> {
  final _picker = ImagePicker();
  bool _uploadingSelfie = false;

  @override
  void initState() {
    super.initState();
    // Pick up fits liked or saved since the library was last loaded.
    Future.microtask(() {
      if (mounted) ref.invalidate(libraryProvider);
    });
  }

  /// Gen renders the user wearing the fit, so it needs a selfie on file.
  Future<bool> _addSelfie() async {
    final source = await showDripSheet<ImageSource>(
      context,
      builder: (ctx) => SheetContent(
        title: 'ADD A SELFIE',
        subtitle:
            'AI GEN puts you in the fit. Use a clear, front-facing photo in '
            'good light. It stays private to your account.',
        children: [
          AppButton(
            label: 'TAKE A SELFIE',
            height: 44,
            onPressed: () => Navigator.of(ctx).pop(ImageSource.camera),
          ),
          const SizedBox(height: 10),
          AppButton(
            label: 'CHOOSE FROM LIBRARY',
            style: AppButtonStyle.outline,
            height: 44,
            onPressed: () => Navigator.of(ctx).pop(ImageSource.gallery),
          ),
        ],
      ),
    );
    if (source == null || !mounted) return false;
    final XFile? file;
    try {
      file = await _picker.pickImage(
        source: source,
        preferredCameraDevice: CameraDevice.front,
        maxWidth: 1600,
        imageQuality: 88,
      );
    } catch (_) {
      if (mounted) showDripToast(context, 'Camera unavailable');
      return false;
    }
    if (file == null || !mounted) return false;
    final type = imageContentType(file.name) ?? 'image/jpeg';
    setState(() => _uploadingSelfie = true);
    try {
      await ref
          .read(accountRepositoryProvider)
          .uploadAvatar(await file.readAsBytes(), contentType: type);
      ref.invalidate(accountProvider);
      if (mounted) showDripToast(context, 'Selfie saved');
      return true;
    } on ApiException catch (e) {
      if (mounted) showDripToast(context, e.friendly);
      return false;
    } finally {
      if (mounted) setState(() => _uploadingSelfie = false);
    }
  }

  Future<void> _customScene(PhotoshootController c) async {
    final t = TextEditingController();
    final label = await showDripSheet<String>(
      context,
      builder: (ctx) => SheetContent(
        title: 'CUSTOM SCENE',
        subtitle: 'Describe the environment for this shoot.',
        children: [
          DripField(
            controller: t,
            hint: 'e.g. Rooftop at dawn',
            radius: 14,
            autofocus: true,
            onSubmitted: (v) => Navigator.of(ctx).pop(v),
          ),
          const SizedBox(height: 14),
          AppButton(
            label: 'USE SCENE',
            height: 44,
            onPressed: () => Navigator.of(ctx).pop(t.text),
          ),
        ],
      ),
    );
    t.dispose();
    if (label != null && label.trim().isNotEmpty) {
      c.setScene('custom', customLabel: label.trim());
    }
  }

  Future<void> _generate() async {
    final s = ref.read(photoshootProvider);
    final controller = ref.read(photoshootProvider.notifier);
    final fits = ref.read(shootableFitsProvider).value ?? const <Outfit>[];
    final fit = fits.where((o) => o.id == s.fitId).firstOrNull ??
        fits.firstOrNull;
    if (fit == null) {
      showDripToast(context, 'Save or like a fit in the Scroll first');
      return;
    }

    String? real;
    if (s.mode == ShootMode.real) {
      try {
        final file = await _picker.pickImage(
          source: ImageSource.camera,
          maxWidth: 1600,
          imageQuality: 88,
        );
        if (file == null) return;
        real = file.path;
      } catch (_) {
        if (mounted) {
          showDripToast(context, 'Camera unavailable — switch to AI GEN');
        }
        return;
      }
    } else {
      final Account account;
      try {
        account = await ref.read(accountProvider.future);
      } on ApiException catch (e) {
        if (mounted) showDripToast(context, e.friendly);
        return;
      }
      if (!mounted) return;
      if (account.genCreditsRemaining <= 0) {
        showDripToast(context, "You've used all your AI GEN credits");
        return;
      }
      if (!account.hasAvatar && !await _addSelfie()) return;
    }
    await controller.generate(fit: fit, realImage: real);
    if (!mounted) return;
    final render = ref.read(photoshootProvider).render;
    if (render.hasError) {
      final e = render.error;
      showDripToast(
        context,
        e is GenCreditsUsedUp
            ? "You've used all your AI GEN credits"
            : e is ApiException
            ? e.friendly
            : 'The render failed — try again',
      );
      return;
    }
    if (render.value?.fellBack ?? false) {
      showDripToast(
        context,
        "Gen couldn't render this one, so here's the fit. Credit refunded.",
      );
    }
    context.push('/photoshoot/result');
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(photoshootProvider);
    final c = ref.read(photoshootProvider.notifier);
    final fits = ref.watch(shootableFitsProvider);
    final account = ref.watch(accountProvider).value;
    final accent = context.palette.accent;

    return ShellPage(
      child: Column(
        children: [
          DripTopBar(
            title: 'STUDIO SHOT',
            leading: const BackGlyph(),
            trailing: GlyphButton(
              '⚡',
              label: 'Render engine',
              onTap: () => showDripToast(context, 'Render engine ready'),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                const SectionLabel('SELECT SHOOT MODE'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _ModeTab(
                        label: 'REAL LOOK',
                        selected: s.mode == ShootMode.real,
                        onTap: () => c.setMode(ShootMode.real),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ModeTab(
                        label: 'AI GEN ✦',
                        selected: s.mode == ShootMode.ai,
                        onTap: () => c.setMode(ShootMode.ai),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ModeTab(
                        label: 'EDITS',
                        selected: false,
                        dimmed: true,
                        onTap: () => showAfterBeta(context, 'Edits'),
                      ),
                    ),
                  ],
                ),
                if (s.mode == ShootMode.ai) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          account == null
                              ? 'AI GEN PUTS YOU IN THE FIT'
                              : '${account.genCreditsRemaining} AI GEN '
                                    '${account.genCreditsRemaining == 1 ? 'CREDIT' : 'CREDITS'} LEFT',
                          style: AppText.mono(9, color: AppColors.muted),
                        ),
                      ),
                      Tap(
                        onTap: _uploadingSelfie ? null : _addSelfie,
                        semanticLabel: 'Add or replace your selfie',
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Text(
                            _uploadingSelfie
                                ? 'UPLOADING…'
                                : account?.hasAvatar ?? false
                                ? 'SELFIE ON FILE ✓'
                                : 'ADD A SELFIE →',
                            style: AppText.mono(9, color: AppColors.cyan),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
                const SectionLabel('SELECT THE FIT TO SHOOT'),
                const SizedBox(height: 12),
                SizedBox(
                  height: 154,
                  child: fits.when(
                    data: (items) => items.isEmpty
                        ? const EmptyState(
                            title: 'NO FITS TO SHOOT',
                            message:
                                'Save or like a fit in the Scroll to shoot it.',
                          )
                        : ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: items.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 12),
                            itemBuilder: (context, i) {
                              final item = items[i];
                              final activeId = items.any((i) => i.id == s.fitId)
                                  ? s.fitId
                                  : items.first.id;
                              final selected = item.id == activeId;
                              return Tap(
                                onTap: () => c.setFit(item.id),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 160),
                                  width: 160,
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: selected
                                          ? AppColors.cyan
                                          : AppColors.elevated,
                                      width: selected ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: SizedBox(
                                          height: 100,
                                          width: double.infinity,
                                          child: DripImage(item.image),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        item.title.toUpperCase(),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppText.display(
                                          10,
                                          lineHeight: 12,
                                          color: selected
                                              ? AppColors.cream
                                              : AppColors.muted,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        selected
                                            ? 'ACTIVE SELECTION'
                                            : '✦ DRIP ${item.rate}',
                                        style: AppText.mono(
                                          8,
                                          lineHeight: 10,
                                          color: selected
                                              ? AppColors.cyan
                                              : AppColors.muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                    loading: () => const LoadingState(compact: true),
                    error: (e, _) => ErrorState.from(
                      e,
                      onRetry: () => ref.invalidate(libraryProvider),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const SectionLabel('SELECT SCENE ENVIRONMENT'),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 112 / 90,
                  children: [
                    for (final scene in MockContent.scenes)
                      _SceneCard(
                        scene: scene,
                        label: scene.id == 'custom' && s.customLabel != null
                            ? s.customLabel!.toUpperCase()
                            : scene.label,
                        selected: s.sceneId == scene.id,
                        accent: accent,
                        onTap: () => scene.id == 'custom'
                            ? _customScene(c)
                            : c.setScene(scene.id),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: AppButton(
              label: 'GENERATE SCENE LOOK ✦',
              height: 44,
              loading: s.render.isLoading,
              onPressed: _generate,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeTab extends StatelessWidget {
  const _ModeTab({
    required this.label,
    required this.selected,
    required this.onTap,
    this.dimmed = false,
  });
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  /// Shown but not available yet (still tappable, to say so).
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null || dimmed ? 0.4 : 1,
      child: Tap(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 29,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.cream : AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: selected || onTap == null || dimmed
                ? null
                : Border.all(color: AppColors.elevated),
          ),
          child: Text(
            label,
            style: AppText.mono(
              10,
              color: selected ? AppColors.base : AppColors.muted,
            ),
          ),
        ),
      ),
    );
  }
}

class _SceneCard extends StatelessWidget {
  const _SceneCard({
    required this.scene,
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });
  final ShootScene scene;
  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tap(
      onTap: onTap,
      semanticLabel: label,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? accent : AppColors.elevated),
        ),
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: double.infinity,
                  child: scene.image == null
                      ? ColoredBox(color: AppColors.elevated)
                      : DripImage(scene.image!),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppText.mono(
                9,
                lineHeight: 12,
                color: selected ? accent : AppColors.cream,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
