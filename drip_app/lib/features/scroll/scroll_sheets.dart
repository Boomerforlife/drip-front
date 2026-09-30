import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/motion.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/drip_image.dart';
import '../../core/widgets/overlays.dart';
import '../../core/widgets/skeleton.dart';
import '../../core/widgets/tap.dart';
import '../../data/models/ootd.dart';
import '../home/feed_controller.dart';
import '../social/social_controller.dart';

// ─────────────────────────────────────────────────────────────── comments

Future<void> showCommentsSheet(BuildContext context, String ootdId) {
  return showDripSheet<void>(
    context,
    builder: (ctx) => _CommentsBody(ootdId: ootdId),
  );
}

class _CommentsBody extends ConsumerStatefulWidget {
  const _CommentsBody({required this.ootdId});
  final String ootdId;

  @override
  ConsumerState<_CommentsBody> createState() => _CommentsBodyState();
}

class _CommentsBodyState extends ConsumerState<_CommentsBody> {
  final _text = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final value = _text.text.trim();
    if (value.isEmpty || _sending) return;
    setState(() => _sending = true);
    Haptics.commit();
    _text.clear();
    await ref.read(postsProvider.notifier).addComment(widget.ootdId, value);
    if (mounted) setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    final post = ref.watch(ootdProvider(widget.ootdId));
    final comments = ref.watch(commentsProvider(widget.ootdId));
    final accent = context.palette.accent;
    final maxList = MediaQuery.sizeOf(context).height * 0.46;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
          child: Row(
            children: [
              Text('COMMENTS', style: AppText.display(15)),
              const SizedBox(width: 8),
              Text(
                formatCount(post?.comments ?? 0),
                style: AppText.mono(12, color: AppColors.muted),
              ),
            ],
          ),
        ),
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxList, minHeight: 120),
          child: comments.when(
            loading: () => const ShimmerScope(child: _CommentsSkeleton()),
            error: (_, _) => Center(
              child: Tap(
                onTap: () => ref.invalidate(commentsProvider(widget.ootdId)),
                child: Text(
                  "COULDN'T LOAD · TAP TO RETRY",
                  style: AppText.mono(10, color: AppColors.red),
                ),
              ),
            ),
            data: (list) => list.isEmpty
                ? Center(
                    child: Text(
                      'BE THE FIRST TO COMMENT',
                      style: AppText.mono(
                        10,
                        color: AppColors.muted,
                        letterSpacing: 1.4,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    shrinkWrap: true,
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 16),
                    itemBuilder: (context, i) => _CommentRow(c: list[i]),
                  ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(23),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  child: TextField(
                    controller: _text,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _send(),
                    textInputAction: TextInputAction.send,
                    cursorColor: accent,
                    style: AppText.manrope(14),
                    decoration: InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                      hintText: 'Add a comment…',
                      hintStyle: AppText.manrope(14, color: AppColors.muted),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              AnimatedOpacity(
                duration: Motion.quick,
                opacity: _text.text.trim().isEmpty ? 0.4 : 1,
                child: Tap(
                  onTap: _text.text.trim().isEmpty ? null : _send,
                  semanticLabel: 'Post comment',
                  scale: 0.9,
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_upward_rounded,
                      size: 22,
                      color: AppColors.base,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CommentRow extends StatelessWidget {
  const _CommentRow({required this.c});
  final OotdComment c;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 34,
          height: 34,
          child: ClipOval(child: DripImage(c.avatar)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '@${c.handle}',
                    style: AppText.manrope(12, weight: FontWeight.w700),
                  ),
                  const SizedBox(width: 8),
                  Text(c.ago, style: AppText.mono(9, color: AppColors.muted)),
                ],
              ),
              const SizedBox(height: 3),
              Text(c.text, style: AppText.manrope(13, lineHeight: 18)),
            ],
          ),
        ),
        if (c.likes > 0) ...[
          const SizedBox(width: 10),
          Column(
            children: [
              const Icon(
                Icons.favorite_border_rounded,
                size: 16,
                color: AppColors.muted,
              ),
              const SizedBox(height: 2),
              Text(
                formatCount(c.likes),
                style: AppText.mono(9, color: AppColors.muted),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _CommentsSkeleton extends StatelessWidget {
  const _CommentsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      children: [
        for (var i = 0; i < 3; i++)
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                Skeleton(width: 34, height: 34, circle: true),
                SizedBox(width: 12),
                Expanded(child: Skeleton(height: 34, radius: 10)),
              ],
            ),
          ),
      ],
    );
  }
}

// ───────────────────────────────────────────────────────────────── share

Future<void> showShareSheet(BuildContext context, Ootd post) {
  return showDripSheet<void>(context, builder: (ctx) => _ShareBody(post: post));
}

class _ShareBody extends ConsumerWidget {
  const _ShareBody({required this.post});
  final Ootd post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final people = ref.watch(suggestedCreatorsProvider);
    final feed = ref.read(postsProvider.notifier);
    return SheetContent(
      title: 'SHARE FIT',
      subtitle: '${post.title} · @${post.creatorHandle}',
      children: [
        Text(
          'SEND TO',
          style: AppText.mono(10, color: AppColors.muted, letterSpacing: 1.4),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 88,
          child: people.when(
            loading: () => const ShimmerScope(
              child: Row(
                children: [
                  Skeleton(width: 56, height: 56, circle: true),
                  SizedBox(width: 14),
                  Skeleton(width: 56, height: 56, circle: true),
                  SizedBox(width: 14),
                  Skeleton(width: 56, height: 56, circle: true),
                ],
              ),
            ),
            error: (_, _) => const SizedBox.shrink(),
            data: (list) => ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(width: 14),
              itemBuilder: (context, i) {
                final u = list[i];
                return Tap(
                  onTap: () {
                    Haptics.commit();
                    feed.share(post.id);
                    Navigator.of(context).pop();
                    showDripToast(context, 'Sent to @${u.handle}');
                  },
                  semanticLabel: 'Send to ${u.handle}',
                  child: SizedBox(
                    width: 64,
                    child: Column(
                      children: [
                        SizedBox(
                          width: 56,
                          height: 56,
                          child: ClipOval(child: DripImage(u.avatar)),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          u.handle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.manrope(10, color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        _ShareAction(
          icon: Icons.link_rounded,
          label: 'Copy link',
          onTap: () {
            // Respond immediately; the clipboard write finishes on its own.
            Clipboard.setData(
              ClipboardData(text: 'https://drip.design/fit/${post.id}'),
            );
            Haptics.commit();
            feed.share(post.id);
            Navigator.of(context).pop();
            showDripToast(context, 'Link copied');
          },
        ),
        _ShareAction(
          icon: Icons.add_circle_outline_rounded,
          label: 'Add to your story',
          onTap: () {
            Navigator.of(context).pop();
            context.push('/create');
          },
        ),
      ],
    );
  }
}

class _ShareAction extends StatelessWidget {
  const _ShareAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tap(
      onTap: onTap,
      semanticLabel: label,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.cream),
            const SizedBox(width: 14),
            Text(label, style: AppText.manrope(14, weight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
