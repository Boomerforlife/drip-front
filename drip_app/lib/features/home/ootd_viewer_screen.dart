import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/drip_image.dart';
import '../../core/widgets/glass.dart';
import '../../core/widgets/overlays.dart';
import '../../core/widgets/states.dart';
import '../../core/widgets/tap.dart';
import '../../data/models/ootd.dart';
import '../../data/providers.dart';
import 'feed_controller.dart';

/// Full-screen story-style viewer. Tap left/right to move through the feed,
/// swipe down (or ✕) to close.
class OotdViewerScreen extends ConsumerStatefulWidget {
  const OotdViewerScreen({super.key, required this.ootdId});
  final String ootdId;

  @override
  ConsumerState<OotdViewerScreen> createState() => _OotdViewerScreenState();
}

class _OotdViewerScreenState extends ConsumerState<OotdViewerScreen> {
  int? _index;
  final _message = TextEditingController();
  final _reactions = <String, String>{};

  static const _reactionOptions = [
    ('🔥', 'HEAT'),
    ('💀', 'DEAD'),
    ('❄️', 'CHILL'),
    ('⚡', 'SHOCK'),
  ];

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  Future<void> _react(Ootd post, String label) async {
    final same = _reactions[post.id] == label;
    setState(
      () => same ? _reactions.remove(post.id) : _reactions[post.id] = label,
    );
    if (!same) {
      await ref.read(postsRepositoryProvider).sendReaction(post.id, label);
      if (mounted) {
        showDripToast(context, 'Sent $label to @${post.creatorHandle}');
      }
    }
  }

  Future<void> _send(Ootd post) async {
    final text = _message.text.trim();
    if (text.isEmpty) return;
    FocusScope.of(context).unfocus();
    _message.clear();
    await ref.read(postsRepositoryProvider).sendMessage(post.id, text);
    if (mounted) {
      showDripToast(context, 'Message sent to @${post.creatorHandle}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(postsProvider);

    return Scaffold(
      backgroundColor: AppColors.base,
      body: feed.whenDrip(
        onRetry: () => ref.invalidate(postsProvider),
        data: (posts) {
          final start = posts.indexWhere((p) => p.id == widget.ootdId);
          if (start < 0) {
            return EmptyState(
              title: 'FIT NOT FOUND',
              message: 'This OOTD is no longer available.',
              actionLabel: 'BACK',
              onAction: _close,
            );
          }
          final i = (_index ?? start).clamp(0, posts.length - 1);
          final post = posts[i];

          void go(int delta) {
            final next = i + delta;
            if (next < 0) return;
            if (next >= posts.length) {
              _close();
              return;
            }
            setState(() => _index = next);
          }

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragEnd: (d) {
              if ((d.primaryVelocity ?? 0) > 500) _close();
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 240),
                  child: SizedBox.expand(
                    key: ValueKey(post.id),
                    child: DripImage(post.image),
                  ),
                ),
                const ColoredBox(color: Color(0x4D0E1018)),
                // Tap zones: left third = previous, rest = next.
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: () => go(-1),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: () => go(1),
                      ),
                    ),
                  ],
                ),
                SafeArea(
                  bottom: false,
                  child: Column(
                    children: [
                      _Progress(count: posts.length, current: i),
                      const SizedBox(height: 8),
                      _StoryHeader(post: post, onClose: _close),
                      const SizedBox(height: 28),
                      const IgnorePointer(child: _GestureGuides()),
                    ],
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: _Footer(
                    post: post,
                    reaction: _reactions[post.id],
                    options: _reactionOptions,
                    onReact: (l) => _react(post, l),
                    message: _message,
                    onSend: () => _send(post),
                    onViewFit: () => context.push(
                      '/outfit/${post.outfitId ?? 'o_cyber_flare'}',
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.count, required this.current});
  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    final accent = context.palette.accent;
    return Container(
      height: 4,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < count; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: i < current
                      ? accent
                      : i == current
                      ? AppColors.cream
                      : AppColors.elevated.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StoryHeader extends StatelessWidget {
  const _StoryHeader({required this.post, required this.onClose});
  final Ootd post;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Glass(
      radius: 20,
      thickness: GlassThickness.thin,
      shadow: false,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Tap(
            onTap: () => context.push('/u/${post.creatorHandle}'),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.cream),
                  ),
                  child: ClipOval(child: DripImage(post.creatorAvatar)),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '@${post.creatorHandle}',
                      style: AppText.manrope(13, weight: FontWeight.w700),
                    ),
                    Text(
                      'ESTD 2077 · ${post.postedAgo}',
                      style: AppText.mono(9, color: AppColors.muted),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: context.palette.accent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'LIVE FIT',
              style: AppText.mono(
                8,
                color: AppColors.base,
                weight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Tap(
            onTap: onClose,
            semanticLabel: 'Close',
            child: SizedBox(
              width: 40,
              height: 40,
              child: Center(child: Text('✕', style: AppText.inter(20))),
            ),
          ),
        ],
      ),
    );
  }
}

class _GestureGuides extends StatelessWidget {
  const _GestureGuides();

  @override
  Widget build(BuildContext context) {
    final style = AppText.mono(
      9,
      color: AppColors.muted.withValues(alpha: 0.4),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('◀ TAP LEFT', style: style),
          Text('TAP RIGHT ▶', style: style),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.post,
    required this.reaction,
    required this.options,
    required this.onReact,
    required this.message,
    required this.onSend,
    required this.onViewFit,
  });

  final Ootd post;
  final String? reaction;
  final List<(String, String)> options;
  final ValueChanged<String> onReact;
  final TextEditingController message;
  final VoidCallback onSend;
  final VoidCallback onViewFit;

  @override
  Widget build(BuildContext context) {
    final accent = context.palette.accent;
    final desc = post.caption.isEmpty ? post.tags.join('  ') : post.caption;
    return Glass(
      thickness: GlassThickness.thick,
      shadow: false,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        12 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.title.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.display(16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      desc,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.manrope(
                        12,
                        color: AppColors.muted,
                        lineHeight: 16,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                children: [
                  Text(
                    '✦ ${post.score}',
                    style: AppText.display(20, color: accent),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'DRIP RATE',
                    style: AppText.mono(8, color: AppColors.muted),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final (emoji, label) in options)
                Tap(
                  onTap: () => onReact(label),
                  semanticLabel: label,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: reaction == label
                          ? accent.withValues(alpha: 0.18)
                          : AppColors.base,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: reaction == label ? accent : AppColors.elevated,
                      ),
                    ),
                    child: Text('$emoji $label', style: AppText.mono(10)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.base,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.elevated),
                  ),
                  child: TextField(
                    controller: message,
                    onSubmitted: (_) => onSend(),
                    textInputAction: TextInputAction.send,
                    cursorColor: accent,
                    style: AppText.manrope(13),
                    decoration: InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                      hintText: 'Send message @${post.creatorHandle}...',
                      hintStyle: AppText.manrope(13, color: AppColors.muted),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              AppButton(
                label: 'VIEW FIT →',
                onPressed: onViewFit,
                expand: false,
                height: 44,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '↓ SWIPE DOWN TO ESCAPE',
            style: AppText.mono(9, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}
