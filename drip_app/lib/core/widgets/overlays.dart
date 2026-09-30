import 'package:flutter/material.dart';

import '../motion.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'app_button.dart';
import 'bottom_nav.dart';
import 'glass.dart';

/// Bottom sheet in DRIP's glass material, with a drag-handle and
/// keyboard-aware padding. Slides in on the iOS drawer curve (fast start, soft
/// landing) and leaves quicker than it arrives.
Future<T?> showDripSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool scrollable = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    barrierColor: const Color(0x8C000000),
    showDragHandle: false,
    sheetAnimationStyle: AnimationStyle(
      duration: Motion.content,
      reverseDuration: Motion.nav,
      curve: Motion.drawer,
      reverseCurve: Curves.easeIn,
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: Glass(
        thickness: GlassThickness.thick,
        shadow: false,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 6),
              Flexible(child: builder(ctx)),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Title + body wrapper for sheet content.
class SheetContent extends StatelessWidget {
  const SheetContent({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
  });
  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: AppText.display(16)),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: AppText.manrope(
                12,
                color: AppColors.muted,
                lineHeight: 18,
              ),
            ),
          ],
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

/// Confirmation dialog. Returns `true` when the user confirms.
Future<bool> showDripConfirm(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'CONFIRM',
  String cancelLabel = 'CANCEL',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierColor: const Color(0xB3000000),
    builder: (ctx) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppText.display(16)),
            const SizedBox(height: 10),
            Text(
              message,
              style: AppText.manrope(
                13,
                color: AppColors.muted,
                lineHeight: 19,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: cancelLabel,
                    style: AppButtonStyle.outline,
                    height: 44,
                    onPressed: () => Navigator.of(ctx).pop(false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppButton(
                    label: confirmLabel,
                    style: destructive
                        ? AppButtonStyle.danger
                        : AppButtonStyle.primary,
                    height: 44,
                    onPressed: () => Navigator.of(ctx).pop(true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  return result ?? false;
}

/// Brief floating message: a glass pill that clears the floating nav.
/// For UI that stays visible in the beta but has no backend yet (the social
/// layer, Discover and search, sharing…): says so instead of pretending.
void showAfterBeta(BuildContext context, [String? feature]) {
  Haptics.tick();
  showDripToast(
    context,
    feature == null
        ? 'This feature is coming after beta ✦'
        : '$feature is coming after beta ✦',
  );
}

void showDripToast(BuildContext context, String message) {
  final m = ScaffoldMessenger.maybeOf(context);
  if (m == null) return;
  m
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 2200),
        padding: EdgeInsets.zero,
        margin: EdgeInsets.fromLTRB(20, 0, 20, NavMetrics.extent(context) + 4),
        content: Glass(
          radius: 18,
          thickness: GlassThickness.regular,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Text(
            message.toUpperCase(),
            textAlign: TextAlign.center,
            style: AppText.mono(11, letterSpacing: 0.6),
          ),
        ),
      ),
    );
}
