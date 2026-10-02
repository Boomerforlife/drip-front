import 'package:flutter/material.dart';

import '../../core/motion.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/tap.dart';
import 'selfie_intent.dart';

/// Step 1: one tap on what the photo is for. No form, no confirm button: the
/// choice itself moves on to the camera.
class IntentStep extends StatelessWidget {
  const IntentStep({
    super.key,
    required this.selected,
    required this.onPick,
    required this.onLibrary,
  });

  final SelfieIntent selected;
  final ValueChanged<SelfieIntent> onPick;

  /// Skip the guide and choose a photo from the library.
  final VoidCallback onLibrary;

  @override
  Widget build(BuildContext context) {
    final accent = context.palette.accent;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Text('WHAT’S THIS PHOTO FOR?', style: AppText.display(18)),
        const SizedBox(height: 6),
        Text(
          'I’ll guide the framing and light. One tap and we’re in.',
          style: AppText.manrope(
            13,
            color: AppColors.muted,
            lineHeight: 19,
          ),
        ),
        const SizedBox(height: 18),
        for (final intent in SelfieIntent.values) ...[
          Tap(
            onTap: () {
              Haptics.tick();
              onPick(intent);
            },
            semanticLabel: '${intent.label}, ${intent.blurb}',
            child: AnimatedContainer(
              duration: Motion.quick,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: intent == selected ? accent : AppColors.elevated,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(intent.icon, size: 20, color: accent),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          intent.label.toUpperCase(),
                          style: AppText.display(13, lineHeight: 16),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          intent.blurb,
                          style: AppText.manrope(
                            12,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: AppColors.muted,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 8),
        Center(
          child: Tap(
            onTap: onLibrary,
            semanticLabel: 'Choose a photo from your library instead',
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              child: Text(
                'OR USE A PHOTO FROM YOUR LIBRARY →',
                style: AppText.mono(10, color: AppColors.cyan),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
