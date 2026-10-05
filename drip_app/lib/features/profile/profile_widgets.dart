import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/drip_image.dart';
import '../../core/widgets/tap.dart';
import '../../data/models/user.dart';

/// Avatar, name, handle and bio block at the top of a profile.
class ProfileIntro extends StatelessWidget {
  const ProfileIntro({
    super.key,
    required this.user,
    required this.ringColor,
    this.nameSize = 20,
    this.trailing,
    this.onEdit,
    this.onAvatarTap,
  });

  final DripUser user;
  final Color ringColor;
  final double nameSize;
  final Widget? trailing;
  final VoidCallback? onEdit;

  /// Your own profile: tapping the picture changes it.
  final VoidCallback? onAvatarTap;

  @override
  Widget build(BuildContext context) {
    final avatar = Container(
      width: 80,
      height: 80,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: ringColor, width: 2),
        boxShadow: ringColor == context.palette.secondary
            ? null
            : [
                BoxShadow(
                  color: ringColor.withValues(alpha: 0.2),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: user.avatar.isEmpty
            ? ColoredBox(color: AppColors.elevated)
            : DripImage(user.avatar, logicalWidth: 80),
      ),
    );
    return Row(
      children: [
        if (onAvatarTap == null)
          avatar
        else
          Tap(
            onTap: onAvatarTap,
            semanticLabel: 'Change your profile photo',
            child: avatar,
          ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      user.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.display(nameSize),
                    ),
                  ),
                  ?trailing,
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    user.at,
                    style: AppText.mono(11, color: context.palette.secondary),
                  ),
                  if (onEdit != null) ...[
                    const SizedBox(width: 8),
                    Tap(
                      onTap: onEdit,
                      semanticLabel: 'Edit profile',
                      child: Text(
                        'EDIT ✎',
                        style: AppText.mono(9, color: AppColors.muted),
                      ),
                    ),
                  ],
                ],
              ),
              if (user.bio.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  user.bio,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.manrope(
                    12,
                    color: AppColors.muted,
                    lineHeight: 16,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class ProfileStats extends StatelessWidget {
  const ProfileStats({
    super.key,
    required this.user,
    this.radius = 16,
    this.onFollowers,
    this.onFollowing,
  });
  final DripUser user;
  final double radius;
  final VoidCallback? onFollowers;
  final VoidCallback? onFollowing;

  @override
  Widget build(BuildContext context) {
    Widget stat(
      String value,
      String label, {
      Color labelColor = AppColors.muted,
      VoidCallback? onTap,
    }) => Expanded(
      child: Tap(
        onTap: onTap,
        child: Column(
          children: [
            Text(value, style: AppText.display(14)),
            const SizedBox(height: 0),
            Text(label, style: AppText.mono(8, color: labelColor)),
          ],
        ),
      ),
    );
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.elevated),
      ),
      child: Row(
        children: [
          stat(formatCount(user.followers), 'FOLLOWERS', onTap: onFollowers),
          stat(formatCount(user.following), 'FOLLOWING', onTap: onFollowing),
          stat(
            '${user.styleScore}',
            'STYLE SCORE',
            labelColor: context.palette.accent,
          ),
        ],
      ),
    );
  }
}

/// Style DNA chips: accent-filled, cyan-filled, then outlined.
class DnaChips extends StatelessWidget {
  const DnaChips({super.key, required this.tags, this.radius = 8});
  final List<String> tags;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final accent = context.palette.accent;
    final secondary = context.palette.secondary;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (var i = 0; i < tags.length; i++)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: switch (i) {
                0 => accent,
                1 => secondary,
                _ => AppColors.surface,
              },
              borderRadius: BorderRadius.circular(radius),
              border: i >= 2 ? Border.all(color: secondary) : null,
            ),
            child: Text(
              tags[i],
              style: AppText.mono(
                9,
                color: i >= 2 ? secondary : AppColors.base,
              ),
            ),
          ),
      ],
    );
  }
}

/// Underlined text tabs (FITS / OOTD / PHOTOS).
class ProfileTabs extends StatelessWidget {
  const ProfileTabs({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
    this.size = 12,
  });
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    final accent = context.palette.accent;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.elevated)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            if (i > 0) const SizedBox(width: 16),
            Tap(
              onTap: () => onChanged(i),
              child: Container(
                padding: const EdgeInsets.only(bottom: 8, top: 6),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: i == index ? accent : AppColors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  labels[i],
                  style: AppText.display(
                    size,
                    color: i == index ? AppColors.cream : AppColors.muted,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Two-column grid of square-ish photo tiles.
class PhotoGrid extends StatelessWidget {
  const PhotoGrid({
    super.key,
    required this.tiles,
    this.height = 140,
    this.radius = 16,
  });
  final List<PhotoTile> tiles;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < tiles.length; i += 2) {
      rows.add(
        Row(
          children: [
            Expanded(child: _tile(context, tiles[i])),
            const SizedBox(width: 16),
            Expanded(
              child: i + 1 < tiles.length
                  ? _tile(context, tiles[i + 1])
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      );
      if (i + 2 < tiles.length) rows.add(const SizedBox(height: 16));
    }
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(children: rows),
    );
  }

  Widget _tile(BuildContext context, PhotoTile t) {
    return Tap(
      onTap: t.route == null ? null : () => context.push(t.route!),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: SizedBox(height: height, child: DripImage(t.image)),
      ),
    );
  }
}

class PhotoTile {
  const PhotoTile(this.image, [this.route]);
  final String image;
  final String? route;
}
