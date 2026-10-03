import 'dart:io' show File;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// Resolves an image reference to an [ImageProvider]:
/// bundled asset (`assets/...`), remote / blob URL, or a local file path
/// (photos picked from the camera or gallery).
ImageProvider dripImageProvider(String source) {
  if (source.startsWith('assets/')) return AssetImage(source);
  if (kIsWeb ||
      source.startsWith('http') ||
      source.startsWith('blob:') ||
      source.startsWith('data:')) {
    return NetworkImage(source);
  }
  return FileImage(File(source));
}

/// Cover-fit image with a dark placeholder while decoding / on failure.
class DripImage extends StatelessWidget {
  const DripImage(
    this.source, {
    super.key,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.semanticLabel,
    this.logicalWidth,
    this.backdrop = true,
  });

  final String source;
  final BoxFit fit;
  final AlignmentGeometry alignment;
  final String? semanticLabel;

  /// Display width, in logical pixels, when the image is shown small (avatars,
  /// thumbnails). The photo is then decoded at that size instead of full
  /// resolution: far less memory and decode time, so lists scroll smoother.
  final double? logicalWidth;

  /// Paints the tinted placeholder behind the image. Turn off for cut-outs
  /// (transparent PNGs) shown on their own background.
  final bool backdrop;

  @override
  Widget build(BuildContext context) {
    ImageProvider provider = dripImageProvider(source);
    if (logicalWidth != null) {
      final dpr = MediaQuery.devicePixelRatioOf(context);
      provider = ResizeImage.resizeIfNeeded(
        (logicalWidth! * dpr).ceil(),
        null,
        provider,
      );
    }
    return Image(
      image: provider,
      fit: fit,
      alignment: alignment,
      semanticLabel: semanticLabel,
      gaplessPlayback: true,
      // Decoding: a quiet tinted block, then the photo fades over it (no
      // blank flash, no spinner). Cached / synchronous frames skip the fade.
      frameBuilder: (context, child, frame, sync) {
        if (sync) return child;
        if (!backdrop) {
          return AnimatedOpacity(
            opacity: frame == null ? 0 : 1,
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOut,
            child: child,
          );
        }
        return Stack(
          fit: StackFit.passthrough,
          children: [
            Positioned.fill(child: ColoredBox(color: AppColors.elevated)),
            AnimatedOpacity(
              opacity: frame == null ? 0 : 1,
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOut,
              child: child,
            ),
          ],
        );
      },
      errorBuilder: (context, error, stack) => const _ImageFailed(),
    );
  }
}

/// Circular avatar with an optional ring, matching the story / profile avatars.
class DripAvatar extends StatelessWidget {
  const DripAvatar(
    this.source, {
    super.key,
    required this.size,
    this.ringColor,
    this.ringWidth = 2,
    this.radius,
    this.shadowColor,
  });

  final String source;
  final double size;
  final Color? ringColor;
  final double ringWidth;

  /// Corner radius; defaults to a full circle.
  final double? radius;
  final Color? shadowColor;

  @override
  Widget build(BuildContext context) {
    final r = radius ?? size / 2;
    final ring = ringColor != null;
    return Container(
      width: size,
      height: size,
      padding: ring ? EdgeInsets.all(ringWidth) : null,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ring ? r : r),
        border: ring ? Border.all(color: ringColor!, width: ringWidth) : null,
        boxShadow: shadowColor == null
            ? null
            : [
                BoxShadow(
                  color: shadowColor!,
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(
          ring ? (r - ringWidth).clamp(0, r) : r,
        ),
        child: DripImage(source, logicalWidth: size),
      ),
    );
  }
}

/// Shown when an image can't be decoded / fetched: intentional, not broken.
class _ImageFailed extends StatelessWidget {
  const _ImageFailed();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.elevated,
      child: LayoutBuilder(
        builder: (context, box) {
          final roomy = box.maxWidth > 90 && box.maxHeight > 60;
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.image_not_supported_outlined,
                  color: AppColors.muted,
                  size: 20,
                ),
                if (roomy) ...[
                  const SizedBox(height: 6),
                  Text(
                    'IMAGE UNAVAILABLE',
                    style: AppText.mono(
                      8,
                      color: AppColors.muted,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
