import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/tap.dart';
import 'selfie_camera.dart';

/// Shown whenever the live guide can't run (permission refused, no camera,
/// web/desktop, or the camera failed to start). It hands off to the same photo
/// upload the rest of Drip uses, and the photo still gets reviewed.
class CameraFallback extends StatelessWidget {
  const CameraFallback({
    super.key,
    required this.outcome,
    required this.onTakePhoto,
    required this.onLibrary,
    this.onRetry,
  });

  final CameraOutcome outcome;
  final VoidCallback onTakePhoto;
  final VoidCallback onLibrary;

  /// Offered when access was refused, in case the user just changed it.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final denied = outcome == CameraOutcome.denied;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.elevated),
                ),
                child: const Icon(
                  Icons.no_photography_outlined,
                  size: 28,
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                denied ? 'CAMERA ACCESS IS OFF' : 'LIVE GUIDE UNAVAILABLE',
                textAlign: TextAlign.center,
                style: AppText.display(16),
              ),
              const SizedBox(height: 8),
              Text(
                denied
                    ? 'Turn camera access on in your device settings to get '
                          'live guidance. Or add a photo now and I’ll still '
                          'review it.'
                    : 'The live guide needs a phone camera. Add a photo and '
                          'I’ll still review the framing and light.',
                textAlign: TextAlign.center,
                style: AppText.manrope(
                  13,
                  color: AppColors.muted,
                  lineHeight: 19,
                ),
              ),
              const SizedBox(height: 22),
              AppButton(label: 'TAKE A PHOTO', height: 44, onPressed: onTakePhoto),
              const SizedBox(height: 10),
              AppButton(
                label: 'CHOOSE FROM LIBRARY',
                style: AppButtonStyle.outline,
                height: 44,
                onPressed: onLibrary,
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 6),
                Tap(
                  onTap: onRetry,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text(
                      'TRY THE LIVE CAMERA AGAIN',
                      style: AppText.mono(10, color: AppColors.cyan),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Text(
                'Tip: face a window, with the camera at eye level.',
                textAlign: TextAlign.center,
                style: AppText.mono(10, color: AppColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
