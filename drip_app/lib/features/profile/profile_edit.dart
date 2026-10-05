import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/controls.dart';
import '../../core/widgets/overlays.dart';
import '../../data/api/api_client.dart';
import '../../data/models/account.dart';
import '../../data/providers.dart';
import '../../data/repositories/account_repository.dart';
import '../wardrobe/wardrobe_controller.dart' show imageContentType;

/// Editing the public profile: the picture, the username and the name. These
/// live on the account (`/me`), unlike selfies, which stay on the phone.

/// "EDIT ✎" on your profile: photo, name, username.
Future<void> showEditProfileSheet(BuildContext context, WidgetRef ref) async {
  final pick = await showDripSheet<String>(
    context,
    builder: (ctx) => SheetContent(
      title: 'EDIT PROFILE',
      children: [
        for (final (id, label) in const [
          ('photo', 'PROFILE PHOTO'),
          ('name', 'NAME'),
          ('username', 'USERNAME'),
        ]) ...[
          AppButton(
            label: label,
            style: AppButtonStyle.outline,
            height: 44,
            onPressed: () => Navigator.of(ctx).pop(id),
          ),
          const SizedBox(height: 10),
        ],
      ],
    ),
  );
  if (pick == null || !context.mounted) return;
  switch (pick) {
    case 'photo':
      await showProfilePhotoSheet(context, ref);
    case 'name':
      await showDisplayNameSheet(context, ref);
    case 'username':
      await showUsernameSheet(context, ref);
  }
}

/// Picks a gallery photo or takes one, and makes it the profile picture.
/// Tests replace it.
typedef ProfilePhotoPicker = Future<XFile?> Function(ImageSource source);

final profilePhotoPickerProvider = Provider<ProfilePhotoPicker>(
  (ref) =>
      (source) => ImagePicker().pickImage(
        source: source,
        // A profile picture is shown small: 800 px is plenty, and quick to send.
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      ),
);

/// "Change profile photo": gallery, camera or remove. Uploads straight away.
Future<void> showProfilePhotoSheet(BuildContext context, WidgetRef ref) async {
  final hasPhoto = ref.read(accountProvider).value?.photoUrl != null;
  final choice = await showDripSheet<String>(
    context,
    builder: (ctx) => SheetContent(
      title: 'PROFILE PHOTO',
      subtitle: 'Anyone who sees your profile will see this picture.',
      children: [
        AppButton(
          label: 'CHOOSE FROM GALLERY',
          height: 44,
          onPressed: () => Navigator.of(ctx).pop('gallery'),
        ),
        const SizedBox(height: 10),
        AppButton(
          label: 'TAKE A PHOTO',
          style: AppButtonStyle.outline,
          height: 44,
          onPressed: () => Navigator.of(ctx).pop('camera'),
        ),
        if (hasPhoto) ...[
          const SizedBox(height: 10),
          AppButton(
            label: 'REMOVE PHOTO',
            style: AppButtonStyle.outline,
            height: 44,
            onPressed: () => Navigator.of(ctx).pop('remove'),
          ),
        ],
      ],
    ),
  );
  if (choice == null || !context.mounted) return;
  final repo = ref.read(accountRepositoryProvider);
  try {
    if (choice == 'remove') {
      await repo.removePhoto();
      ref.invalidate(accountProvider);
      if (context.mounted) showDripToast(context, 'Profile photo removed');
      return;
    }
    final XFile? file;
    try {
      file = await ref.read(profilePhotoPickerProvider)(
        choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
      );
    } catch (_) {
      if (context.mounted) {
        showDripToast(
          context,
          choice == 'camera'
              ? 'Can’t open the camera. Try your gallery'
              : 'Can’t open your photos. Allow access in Settings',
        );
      }
      return;
    }
    if (file == null || !context.mounted) return;
    showDripToast(context, 'Updating your photo…');
    await repo.uploadPhoto(
      await file.readAsBytes(),
      contentType:
          imageContentType(file.name) ??
          imageContentType(file.path) ??
          'image/jpeg',
    );
    ref.invalidate(accountProvider);
    if (context.mounted) showDripToast(context, 'Profile photo updated');
  } on ApiException catch (e) {
    if (context.mounted) showDripToast(context, e.friendly);
  }
}

/// Change the username, checking availability as the user types.
Future<void> showUsernameSheet(BuildContext context, WidgetRef ref) async {
  final current = ref.read(accountProvider).value?.username;
  final saved = await showDripSheet<String>(
    context,
    builder: (_) => _UsernameSheet(initial: current ?? ''),
  );
  if (saved != null && context.mounted) {
    showDripToast(context, 'You’re @$saved now');
  }
}

class _UsernameSheet extends ConsumerStatefulWidget {
  const _UsernameSheet({required this.initial});
  final String initial;

  @override
  ConsumerState<_UsernameSheet> createState() => _UsernameSheetState();
}

class _UsernameSheetState extends ConsumerState<_UsernameSheet> {
  late final _text = TextEditingController(text: widget.initial);
  Timer? _debounce;
  UsernameCheck? _check;
  bool _checking = false;
  bool _saving = false;
  String? _error;

  String get _value => _text.text.trim().toLowerCase();

  @override
  void dispose() {
    _debounce?.cancel();
    _text.dispose();
    super.dispose();
  }

  void _changed(String _) {
    _debounce?.cancel();
    final u = _value;
    final local = usernameProblem(u);
    setState(() {
      _error = u.isEmpty ? null : local;
      _check = null;
      _checking = local == null && u != widget.initial;
    });
    if (local != null || u == widget.initial) return;
    // Ask the server once typing pauses.
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final check = await ref
            .read(accountRepositoryProvider)
            .usernameAvailable(u);
        if (!mounted || check.username != _value) return;
        setState(() {
          _check = check;
          _checking = false;
          _error = check.available ? null : check.reason;
        });
      } on ApiException {
        if (mounted) setState(() => _checking = false);
      }
    });
  }

  Future<void> _save() async {
    final u = _value;
    final problem = usernameProblem(u);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(accountRepositoryProvider).setUsername(u);
      ref.invalidate(accountProvider);
      if (mounted) Navigator.of(context).pop(u);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e.status == 409 ? 'That username is taken' : e.friendly;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = _value;
    final unchanged = u == widget.initial;
    final ok =
        !unchanged &&
        usernameProblem(u) == null &&
        _error == null &&
        (_check?.available ?? false);
    final status = _error != null
        ? (_error!, AppColors.red)
        : _checking
        ? ('Checking…', AppColors.muted)
        : ok
        ? ('@$u is free', AppColors.cyan)
        : ('Letters, numbers, dots and underscores', AppColors.muted);
    return SheetContent(
      title: 'USERNAME',
      subtitle: 'How people find you on Drip.',
      children: [
        DripField(
          controller: _text,
          hint: 'yourname',
          autofocus: true,
          radius: 14,
          leading: Text('@', style: AppText.mono(14, color: AppColors.muted)),
          textInputAction: TextInputAction.done,
          onChanged: _changed,
          onSubmitted: (_) => ok ? _save() : null,
        ),
        const SizedBox(height: 8),
        Text(status.$1, style: AppText.mono(10, color: status.$2)),
        const SizedBox(height: 16),
        AppButton(
          label: 'SAVE USERNAME',
          height: 44,
          loading: _saving,
          onPressed: ok && !_saving ? _save : null,
        ),
      ],
    );
  }
}

/// Change the name shown on the profile (empty → back to the Google name).
Future<void> showDisplayNameSheet(BuildContext context, WidgetRef ref) async {
  final Account? account = ref.read(accountProvider).value;
  final text = TextEditingController(text: account?.displayName ?? '');
  final name = await showDripSheet<String>(
    context,
    builder: (ctx) => SheetContent(
      title: 'NAME',
      subtitle:
          'Shown on your profile. Leave it empty to use your Google name.',
      children: [
        DripField(
          controller: text,
          hint: 'Your name',
          autofocus: true,
          radius: 14,
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        const SizedBox(height: 16),
        AppButton(
          label: 'SAVE NAME',
          height: 44,
          onPressed: () => Navigator.of(ctx).pop(text.text),
        ),
      ],
    ),
  );
  text.dispose();
  if (name == null || !context.mounted) return;
  final trimmed = name.trim();
  if (trimmed.length > 40) {
    showDripToast(context, 'Keep it to 40 characters');
    return;
  }
  try {
    await ref
        .read(accountRepositoryProvider)
        .setDisplayName(trimmed.isEmpty ? null : trimmed);
    ref.invalidate(accountProvider);
    if (context.mounted) showDripToast(context, 'Name updated');
  } on ApiException catch (e) {
    if (context.mounted) showDripToast(context, e.friendly);
  }
}
