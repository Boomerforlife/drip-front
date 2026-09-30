import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/drip_image.dart';
import '../../core/widgets/overlays.dart';
import '../../core/widgets/states.dart';
import '../../core/widgets/tap.dart';
import '../../core/widgets/top_bar.dart';
import '../../data/api/api_client.dart';
import 'wardrobe_controller.dart';

/// Garment capture: pick a photo and send it. The upload goes straight to
/// storage; Drip then cuts the garment out and tags it in the background, so
/// the user never waits on a model. The item shows up in the wardrobe as
/// "processing" and fills itself in.
class AddToWardrobeScreen extends ConsumerStatefulWidget {
  const AddToWardrobeScreen({super.key});

  @override
  ConsumerState<AddToWardrobeScreen> createState() =>
      _AddToWardrobeScreenState();
}

class _AddToWardrobeScreenState extends ConsumerState<AddToWardrobeScreen> {
  final _picker = ImagePicker();
  bool _camera = true;
  XFile? _file;

  Future<void> _pick(ImageSource source) async {
    setState(() => _camera = source == ImageSource.camera);
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 88,
      );
      if (file == null) return;
      _file = file;
      ref.read(captureProvider.notifier).pick(file.path);
    } catch (_) {
      if (mounted) {
        showDripToast(
          context,
          source == ImageSource.camera
              ? 'Camera unavailable — try the library'
              : 'Couldn\'t open your library',
        );
      }
    }
  }

  Future<void> _send() async {
    final file = _file;
    if (file == null) return;
    final type =
        imageContentType(file.name) ??
        imageContentType(file.path) ??
        file.mimeType;
    if (type == null ||
        !const {'image/jpeg', 'image/png', 'image/webp'}.contains(type)) {
      showDripToast(context, 'Use a JPG, PNG or WebP photo');
      return;
    }
    final bytes = await file.readAsBytes();
    final item = await ref.read(captureProvider.notifier).send(bytes, type);
    if (!mounted) return;
    if (item == null) {
      final err = ref.read(captureProvider).upload.error;
      showDripToast(
        context,
        err is ApiException ? err.friendly : 'Upload failed. Try again.',
      );
      return;
    }
    showDripToast(context, 'Uploaded. Drip is cutting it out now');
    context.go('/wardrobe');
  }

  @override
  Widget build(BuildContext context) {
    final capture = ref.watch(captureProvider);
    final bottom = math.max(MediaQuery.paddingOf(context).bottom, 8.0);
    final path = capture.imagePath;
    final sending = capture.upload.isLoading;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      // Swipe left to leave the camera, back to Home (like Instagram).
      onHorizontalDragEnd: (d) {
        if ((d.primaryVelocity ?? 0) < -500 && !sending && context.canPop()) {
          context.pop();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.base,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const DripTopBar(title: 'GARMENT CAPTURE', leading: BackGlyph()),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: _ModeButton(
                        label: 'TAKE PHOTO 📸',
                        active: _camera,
                        onTap: sending ? null : () => _pick(ImageSource.camera),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ModeButton(
                        label: 'CHOOSE FROM LIBRARY',
                        active: !_camera,
                        onTap: sending
                            ? null
                            : () => _pick(ImageSource.gallery),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sending
                            ? 'UPLOADING...'
                            : path == null
                            ? 'WAITING FOR A GARMENT PHOTO'
                            : 'READY TO DIGITIZE',
                        style: AppText.mono(9, color: AppColors.muted),
                      ),
                      const SizedBox(height: 8),
                      _Canvas(path: path, sending: sending),
                      const SizedBox(height: 16),
                      Text(
                        path == null
                            ? 'Lay the piece flat in good light (or wear it), '
                                  'then take a photo or pick one from your '
                                  'library.'
                            : 'Drip cuts the garment out of the photo and tags '
                                  'its category, colour and season. It takes a '
                                  'moment, and you can keep using the app while '
                                  'it works.',
                        style: AppText.manrope(
                          12,
                          color: AppColors.muted,
                          lineHeight: 18,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, bottom + 16),
                child: AppButton(
                  label: 'ADD TO WARDROBE ✦',
                  height: 44,
                  loading: sending,
                  onPressed: path != null ? _send : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.active,
    required this.onTap,
  });
  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tap(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? AppColors.cream : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: active ? null : Border.all(color: AppColors.elevated),
        ),
        child: Text(
          label,
          style: AppText.mono(
            10,
            color: active ? AppColors.base : AppColors.cream,
          ),
        ),
      ),
    );
  }
}

class _Canvas extends StatelessWidget {
  const _Canvas({required this.path, required this.sending});
  final String? path;
  final bool sending;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 320,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.elevated),
      ),
      clipBehavior: Clip.antiAlias,
      child: path == null
          ? Center(child: Text('📸', style: AppText.inter(40)))
          : Stack(
              fit: StackFit.expand,
              children: [
                DripImage(path!, fit: BoxFit.contain),
                if (sending)
                  const ColoredBox(
                    color: Color(0x990E1018),
                    child: LoadingState(label: 'UPLOADING...'),
                  ),
              ],
            ),
    );
  }
}
