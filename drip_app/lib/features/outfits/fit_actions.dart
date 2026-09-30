import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/overlays.dart';
import '../../data/api/api_client.dart';
import 'outfit_controller.dart';

/// Likes a fit (or unlikes it), telling the user if the server refused.
Future<void> toggleLikeWithToast(
  BuildContext context,
  WidgetRef ref,
  String id,
) async {
  try {
    await ref.read(fitMarksProvider.notifier).toggleLike(id);
  } on ApiException catch (e) {
    if (context.mounted) showDripToast(context, e.friendly);
  }
}

/// Saves a fit (or unsaves it) with a toast either way.
Future<void> toggleSaveWithToast(
  BuildContext context,
  WidgetRef ref,
  String id,
) async {
  try {
    final saved = await ref.read(fitMarksProvider.notifier).toggleSave(id);
    if (context.mounted) {
      showDripToast(
        context,
        saved ? 'Saved to your vault' : 'Removed from saved',
      );
    }
  } on ApiException catch (e) {
    if (context.mounted) showDripToast(context, e.friendly);
  }
}
