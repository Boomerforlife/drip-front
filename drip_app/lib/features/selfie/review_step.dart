import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/tap.dart';
import 'selfie_controller.dart';

/// Step 6: the shots, a short photography note on the selected one, and the
/// three ways forward.
class ReviewStep extends StatelessWidget {
  const ReviewStep({
    super.key,
    required this.state,
    required this.onSelect,
    required this.onUse,
    required this.onRetake,
    required this.onAnotherAngle,
  });

  final SelfieState state;
  final ValueChanged<int> onSelect;
  final VoidCallback onUse;
  final VoidCallback onRetake;
  final VoidCallback onAnotherAngle;

  @override
  Widget build(BuildContext context) {
    final accent = context.palette.accent;
    final shot = state.current;
    if (shot == null) return const SizedBox.shrink();
    final multi = state.shots.length > 1;
    final isBest = multi && state.selected == state.best;
    final notes = [
      if (isBest) 'This one has the cleanest composition.',
      ...shot.review.notes,
    ];

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.memory(
                    shot.bytes,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                  ),
                  if (isBest)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: accent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'BEST COMPOSITION',
                          style: AppText.mono(
                            10,
                            color: context.palette.onAccent,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final n in notes.take(3))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(
                      n,
                      style: AppText.manrope(
                        13,
                        color: AppColors.cream,
                        lineHeight: 18,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (multi) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 54,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: state.shots.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) => Tap(
                onTap: () => onSelect(i),
                semanticLabel: 'Shot ${i + 1}',
                child: Container(
                  width: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: i == state.selected
                          ? accent
                          : AppColors.elevated,
                      width: i == state.selected ? 2 : 1,
                    ),
                    image: DecorationImage(
                      image: MemoryImage(state.shots[i].bytes),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
        Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            12,
            16,
            12 + MediaQuery.paddingOf(context).bottom,
          ),
          child: Column(
            children: [
              AppButton(
                label: 'USE THIS PHOTO',
                loading: state.uploading,
                onPressed: onUse,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: 'RETAKE',
                      style: AppButtonStyle.outline,
                      height: 44,
                      onPressed: state.uploading ? null : onRetake,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppButton(
                      label: 'ANOTHER ANGLE',
                      style: AppButtonStyle.outline,
                      height: 44,
                      onPressed: state.uploading || state.full
                          ? null
                          : onAnotherAngle,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
