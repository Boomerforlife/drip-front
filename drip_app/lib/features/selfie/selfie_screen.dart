import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/overlays.dart';
import '../../core/widgets/tap.dart';
import '../../core/widgets/top_bar.dart';
import '../wardrobe/wardrobe_controller.dart';
import 'camera_stage.dart';
import 'intent_step.dart';
import 'review_step.dart';
import 'selfie_controller.dart';

/// The Selfie Coordinator: intent → live guided camera → review → the existing
/// selfie pipeline. Pops with `true` once a selfie has been saved, so a caller
/// (such as Photoshoot) can carry on.
class SelfieScreen extends ConsumerStatefulWidget {
  const SelfieScreen({super.key});

  @override
  ConsumerState<SelfieScreen> createState() => _SelfieScreenState();
}

class _SelfieScreenState extends ConsumerState<SelfieScreen> {
  final _picker = ImagePicker();

  void _exit([bool saved = false]) {
    if (context.canPop()) {
      context.pop(saved);
    } else {
      context.go('/home');
    }
  }

  /// The photo-upload fallback: the OS camera or the library. The photo goes
  /// through the same review as a live shot.
  Future<void> _pick(ImageSource source) async {
    final c = ref.read(selfieProvider.notifier);
    try {
      final file = await _picker.pickImage(
        source: source,
        preferredCameraDevice: CameraDevice.front,
        maxWidth: 1600,
        imageQuality: 88,
      );
      if (file == null || !mounted) return;
      await c.addShot(
        await file.readAsBytes(),
        contentType: imageContentType(file.name) ?? 'image/jpeg',
      );
      if (mounted) c.showReview();
    } catch (_) {
      if (mounted) showDripToast(context, 'Camera unavailable');
    }
  }

  Future<void> _use() async {
    try {
      await ref.read(selfieProvider.notifier).useSelected();
    } catch (e) {
      if (mounted) showDripToast(context, selfieUploadError(e));
      return;
    }
    if (!mounted) return;
    showDripToast(context, 'Selfie saved on this phone');
    _exit(true);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(selfieProvider);
    final c = ref.read(selfieProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.base,
      body: switch (s.step) {
        SelfieStep.camera => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: CameraStage(
              intent: s.intent,
              angleTip: s.angleTip,
              shotCount: s.shots.length,
              lastShot: s.shots.isEmpty ? null : s.shots.last.bytes,
              onCaptured: (bytes) async {
                await c.addShot(bytes);
                // Keep shooting up to the cap, then go to the results.
                if (mounted && ref.read(selfieProvider).full) c.showReview();
              },
              onReview: c.showReview,
              onClose: _exit,
              onChangeIntent: c.changeIntent,
              onTakePhoto: () => _pick(ImageSource.camera),
              onLibrary: () => _pick(ImageSource.gallery),
            ),
          ),
        ),
        _ => SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                children: [
                  DripTopBar(
                    title: s.step == SelfieStep.intent
                        ? 'SELFIE'
                        : 'YOUR SHOTS',
                    leading: BackGlyph(
                      onTap: s.step == SelfieStep.review
                          ? c.backToCamera
                          : _exit,
                    ),
                    // Every selfie kept on this phone.
                    trailing: s.step == SelfieStep.intent
                        ? Tap(
                            onTap: () => context.push('/selfies'),
                            semanticLabel: 'My selfies',
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text(
                                'MY SELFIES',
                                style: AppText.mono(10, color: AppColors.cyan),
                              ),
                            ),
                          )
                        : null,
                  ),
                  Expanded(
                    child: s.step == SelfieStep.intent
                        ? IntentStep(
                            selected: s.intent,
                            onPick: c.chooseIntent,
                            onLibrary: () => _pick(ImageSource.gallery),
                          )
                        : ReviewStep(
                            state: s,
                            onSelect: c.select,
                            onUse: _use,
                            onRetake: c.retake,
                            onAnotherAngle: c.anotherAngle,
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      },
    );
  }
}
