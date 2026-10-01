import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/motion.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/drip_image.dart';
import '../../core/widgets/fit_hero.dart';
import '../../core/widgets/glass.dart';
import '../../core/widgets/like_burst.dart';
import '../../core/widgets/nav_glyphs.dart';
import '../../core/widgets/overlays.dart';
import '../../core/widgets/skeleton.dart';
import '../../core/widgets/states.dart';
import '../../core/widgets/tap.dart';
import '../../data/models/outfit.dart';
import '../home/feed_controller.dart';
import '../outfits/fit_actions.dart';
import '../outfits/outfit_controller.dart';
import '../outfits/shop_sheet.dart';

/// The Fashion Scroll: full-screen, one fit at a time, snapping vertically.
///
/// Fits come a page at a time from `GET /scroll` (ranked, not seen before);
/// the next page loads as you near the end, and the last page is a
/// "caught up" card. Each card reports how long it was on screen (`open` or
/// `skip`), which trains the ranking.
///
/// Only the visible page is built (`PageView.builder`), the next images are
/// pre-cached, and everything laid over the photo is either a gradient or a
/// small glass element, so the photograph stays the hero.
class FashionScrollScreen extends ConsumerStatefulWidget {
  const FashionScrollScreen({super.key, this.startId});

  /// Fit to open on (from Home). Null starts at the top of the feed.
  final String? startId;

  @override
  ConsumerState<FashionScrollScreen> createState() =>
      _FashionScrollScreenState();
}

class _FashionScrollScreenState extends ConsumerState<FashionScrollScreen> {
  /// A card viewed at least this long counts as `open`, else `skip`.
  static const _openAfter = Duration(milliseconds: 2000);

  /// Start loading the next page this many cards before the end.
  static const _prefetch = 3;

  PageController? _pc;
  int _page = 0;
  String? _viewingId;
  final _viewing = Stopwatch();

  /// Held so the last card can still be reported from [dispose], when `ref`
  /// can no longer be used.
  FeedController? _feed;

  @override
  void dispose() {
    _reportView();
    _pc?.dispose();
    super.dispose();
  }

  PageController _controllerFor(List<Outfit> items) {
    if (_pc != null) return _pc!;
    final start = widget.startId == null
        ? 0
        : items
              .indexWhere((o) => o.id == widget.startId)
              .clamp(0, items.length);
    _page = start;
    return _pc = PageController(initialPage: _page);
  }

  void _precache(List<Outfit> items, int i) {
    for (final j in [i + 1, i + 2]) {
      if (j < items.length && items[j].image.isNotEmpty) {
        precacheImage(dripImageProvider(items[j].image), context);
      }
    }
  }

  /// Starts timing the card now on screen (reporting the previous one).
  void _startViewing(List<Outfit> items, int i) {
    final id = i < items.length ? items[i].id : null;
    if (id == _viewingId) return;
    _reportView();
    _feed = ref.read(feedProvider.notifier);
    _viewingId = id;
    _viewing
      ..reset()
      ..start();
  }

  void _reportView() {
    final id = _viewingId;
    if (id == null) return;
    final dwell = _viewing.elapsed;
    _viewingId = null;
    _feed?.signal(
      id,
      dwell >= _openAfter ? 'open' : 'skip',
      dwellMs: dwell.inMilliseconds,
    );
  }

  void _onPage(FeedState feed, int i) {
    setState(() => _page = i);
    _precache(feed.items, i);
    _startViewing(feed.items, i);
    if (i >= feed.items.length - _prefetch) {
      ref.read(feedProvider.notifier).loadMore();
    }
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  void _toTop() {
    Haptics.tick();
    _pc?.animateToPage(0, duration: Motion.page, curve: Motion.out);
  }

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(feedProvider);
    return PopScope(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, _) {
        // Reached via the tab (no Home underneath): back goes Home, not out.
        if (!didPop) context.go('/home');
      },
      child: feed.when(
        loading: () => const _ReelSkeleton(),
        error: (e, _) =>
            ErrorState.from(e, onRetry: () => ref.invalidate(feedProvider)),
        data: (state) {
          final items = state.items;
          if (items.isEmpty) {
            return EmptyState(
              title: 'FRESH FITS INCOMING',
              message:
                  "Drip's catalogue is still being stocked. New fits land "
                  "here as soon as they're ready.",
              actionLabel: 'CHECK AGAIN',
              onAction: () => ref.invalidate(feedProvider),
            );
          }
          final pc = _controllerFor(items);
          if (_viewingId == null && _page < items.length) {
            _startViewing(items, _page);
            _precache(items, _page);
          }
          return Stack(
            fit: StackFit.expand,
            children: [
              PageView.builder(
                controller: pc,
                scrollDirection: Axis.vertical,
                // A touch of resistance at the ends, native-feeling physics.
                physics: const PageScrollPhysics(
                  parent: ClampingScrollPhysics(),
                ),
                itemCount: items.length + 1,
                onPageChanged: (i) => _onPage(state, i),
                itemBuilder: (context, i) => i < items.length
                    ? _ReelPage(outfit: items[i], active: i == _page)
                    : _FeedTail(
                        state: state,
                        onRetry: () =>
                            ref.read(feedProvider.notifier).loadMore(),
                        onTop: _toTop,
                      ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _TopChrome(
                  index: _page.clamp(0, items.length - 1),
                  count: items.length,
                  more: state.hasMore,
                  onBack: context.canPop() ? _back : null,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The page after the last fit: loading the next page, a retry, or the end.
class _FeedTail extends StatelessWidget {
  const _FeedTail({
    required this.state,
    required this.onRetry,
    required this.onTop,
  });
  final FeedState state;
  final VoidCallback onRetry;
  final VoidCallback onTop;

  @override
  Widget build(BuildContext context) {
    if (state.hasMore && !state.loadMoreFailed) {
      return const _ReelSkeleton();
    }
    if (state.loadMoreFailed) {
      return ErrorState(message: "Couldn't load more fits.", onRetry: onRetry);
    }
    return EmptyState(
      title: "YOU'RE ALL CAUGHT UP",
      message: "That's every fresh fit for now. More drop soon.",
      actionLabel: 'BACK TO THE TOP',
      onAction: onTop,
    );
  }
}

// ────────────────────────────────────────────────────────────────── chrome

class _TopChrome extends StatelessWidget {
  const _TopChrome({
    required this.index,
    required this.count,
    required this.more,
    required this.onBack,
  });

  final int index;
  final int count;

  /// More pages to come: the count is a floor, not the total.
  final bool more;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 16, 0),
        child: Row(
          children: [
            if (onBack != null)
              GlassIconButton(
                semanticLabel: 'Back',
                onTap: onBack,
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 17,
                  color: AppColors.cream,
                ),
              )
            else
              const SizedBox(width: 8),
            Glass(
              radius: 20,
              thickness: GlassThickness.thin,
              shadow: false,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const ReelGlyph(color: AppColors.cream, size: 18, glow: 1),
                  const SizedBox(width: 8),
                  Text(
                    'FASHION SCROLL',
                    style: AppText.mono(
                      10,
                      weight: FontWeight.w500,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Glass(
              radius: 16,
              thickness: GlassThickness.thin,
              shadow: false,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: Text(
                '${index + 1} / $count${more ? '+' : ''}',
                style: AppText.mono(10, color: AppColors.cream),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────── page

class _ReelPage extends ConsumerStatefulWidget {
  const _ReelPage({required this.outfit, required this.active});
  final Outfit outfit;
  final bool active;

  @override
  ConsumerState<_ReelPage> createState() => _ReelPageState();
}

class _ReelPageState extends ConsumerState<_ReelPage> {
  int _burst = 0;

  void _doubleTapLike() {
    final id = widget.outfit.id;
    if (!ref.read(fitMarksProvider).isLiked(id)) {
      toggleLikeWithToast(context, ref, id);
    }
    Haptics.thump();
    setState(() => _burst++);
  }

  @override
  Widget build(BuildContext context) {
    final outfit = widget.outfit;
    // Includes the floating nav's height (the shell adds it).
    final bottom = MediaQuery.paddingOf(context).bottom;

    return GestureDetector(
      onDoubleTap: _doubleTapLike,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        fit: StackFit.expand,
        children: [
          FitHero(
            ootdId: outfit.id,
            radius: 28,
            child: SizedBox.expand(
              child: ColoredBox(
                color: AppColors.base,
                child: DripImage(outfit.image, alignment: Alignment.topCenter),
              ),
            ),
          ),
          // Top scrim keeps the chrome legible on bright photos.
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 150,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x99000000), Color(0x00000000)],
                  ),
                ),
              ),
            ),
          ),
          // Bottom scrim carries the description.
          const Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 420,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Color(0xF00E1018), Color(0x000E1018)],
                    stops: [0.1, 1],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 84,
            bottom: bottom + 6,
            child: _Description(outfit: outfit),
          ),
          Positioned(
            right: 8,
            bottom: bottom + 10,
            child: _ActionRail(outfit: outfit),
          ),
          Center(child: LikeBurst(trigger: _burst, size: 110)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────── description

/// Who it's from, what it is, and what it costs, written like part of the
/// post rather than an analytics panel.
class _Description extends StatelessWidget {
  const _Description({required this.outfit});
  final Outfit outfit;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Curated by Drip (creator posts come after the beta).
        Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.base,
                border: Border.all(color: p.accent, width: 1.5),
              ),
              child: Text('d.', style: AppText.fredoka(17)),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '@drip',
                    style: AppText.manrope(14, weight: FontWeight.w800),
                  ),
                  Text(
                    outfit.isCollage ? 'CURATED FLAT-LAY' : 'CURATED FIT',
                    style: AppText.mono(9, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _FollowChip(
              following: false,
              onTap: () => showAfterBeta(context, 'Following creators'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          outfit.title.toUpperCase(),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppText.display(18, lineHeight: 22),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _MetaChip(outfit.isCollage ? 'COLLAGE' : 'ON BODY', filled: true),
            for (final t in outfit.tags.take(3)) _MetaChip(t.toUpperCase()),
          ],
        ),
        if (outfit.pieces.isNotEmpty) ...[
          const SizedBox(height: 10),
          _ShopStrip(outfit: outfit),
        ],
        const SizedBox(height: 10),
        Text(
          '✦ DRIP ${outfit.rate}',
          style: AppText.mono(10, color: p.accent, weight: FontWeight.w500),
        ),
      ],
    );
  }
}

class _FollowChip extends StatelessWidget {
  const _FollowChip({required this.following, required this.onTap});
  final bool following;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = context.palette.accent;
    return Tap(
      onTap: onTap,
      scale: 0.94,
      semanticLabel: following ? 'Following, tap to unfollow' : 'Follow',
      child: AnimatedContainer(
        duration: Motion.quick,
        curve: Motion.out,
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: following ? Colors.white.withValues(alpha: 0.10) : accent,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: following ? Colors.white.withValues(alpha: 0.28) : accent,
          ),
        ),
        child: Text(
          following ? 'FOLLOWING' : 'FOLLOW',
          style: AppText.mono(
            10,
            color: following ? AppColors.cream : AppColors.base,
            weight: FontWeight.w500,
            letterSpacing: 0.6,
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip(this.label, {this.filled = false});
  final String label;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: filled
            ? Colors.white.withValues(alpha: 0.16)
            : Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Text(
        label,
        style: AppText.mono(
          9,
          weight: filled ? FontWeight.w500 : FontWeight.w400,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// Piece count and total price of the fit. Tapping opens "Shop the look" over the feed: each
/// piece links to its product page.
class _ShopStrip extends ConsumerWidget {
  const _ShopStrip({required this.outfit});
  final Outfit outfit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final total = outfit.price;
    final n = outfit.pieces.length;
    final noun = n == 1 ? 'PIECE' : 'PIECES';
    return Tap(
      onTap: () {
        ref.read(feedProvider.notifier).signal(outfit.id, 'open');
        showShopSheet(
          context,
          outfit,
          onFullBreakdown: () => context.push('/outfit/${outfit.id}'),
        );
      },
      semanticLabel: 'Shop the look: ${outfit.title}',
      scale: 0.98,
      child: Glass(
        radius: 16,
        thickness: GlassThickness.thin,
        shadow: false,
        padding: const EdgeInsets.fromLTRB(12, 9, 10, 9),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SHOP THE LOOK · $n $noun',
                    style: AppText.mono(
                      9,
                      color: AppColors.muted,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    total > 0
                        ? '${formatPrice(total)} total'
                        : 'See the pieces',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.manrope(12, weight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_rounded,
              size: 18,
              color: AppColors.cream,
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────── rail

class _ActionRail extends ConsumerWidget {
  const _ActionRail({required this.outfit});
  final Outfit outfit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final marks = ref.watch(fitMarksProvider);
    final liked = marks.isLiked(outfit.id);
    final saved = marks.isSaved(outfit.id);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _RailButton(
          icon: liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          color: liked ? AppColors.red : AppColors.cream,
          label: 'LIKE',
          active: liked,
          semantic: liked ? 'Unlike' : 'Like',
          onTap: () {
            Haptics.commit();
            toggleLikeWithToast(context, ref, outfit.id);
          },
        ),
        _RailButton(
          icon: Icons.mode_comment_outlined,
          label: 'CHAT',
          semantic: 'Comments',
          onTap: () => showAfterBeta(context, 'Comments'),
        ),
        _RailButton(
          icon: saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
          color: saved ? context.palette.accent : AppColors.cream,
          label: 'SAVE',
          active: saved,
          semantic: saved ? 'Remove from saved' : 'Save',
          onTap: () {
            Haptics.commit();
            toggleSaveWithToast(context, ref, outfit.id);
          },
        ),
        _RailButton(
          icon: Icons.ios_share_rounded,
          label: 'SHARE',
          semantic: 'Share',
          onTap: () => showAfterBeta(context, 'Sharing'),
        ),
      ],
    );
  }
}

class _RailButton extends StatelessWidget {
  const _RailButton({
    required this.icon,
    required this.label,
    required this.semantic,
    required this.onTap,
    this.color = AppColors.cream,
    this.active = false,
  });

  final IconData icon;
  final Color color;
  final String label;
  final bool active;
  final String semantic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Tap(
        onTap: onTap,
        scale: 0.88,
        semanticLabel: semantic,
        child: SizedBox(
          width: 56,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 46,
                height: 46,
                child: Glass(
                  radius: 23,
                  thickness: GlassThickness.thin,
                  shadow: false,
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: Motion.quick,
                      switchInCurve: Curves.easeOutBack,
                      transitionBuilder: (c, a) =>
                          ScaleTransition(scale: a, child: c),
                      child: Icon(
                        icon,
                        key: ValueKey(icon),
                        size: 23,
                        color: color,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: AppText.mono(
                  9,
                  weight: FontWeight.w500,
                  color: active ? color : AppColors.cream,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────── loading

/// Loading placeholder: the same silhouette as a reel page.
class _ReelSkeleton extends StatelessWidget {
  const _ReelSkeleton();

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return ShimmerScope(
      child: Stack(
        fit: StackFit.expand,
        children: [
          const Skeleton(radius: 0),
          Positioned(
            left: 16,
            bottom: bottom + 10,
            right: 84,
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Skeleton(width: 38, height: 38, circle: true),
                    SizedBox(width: 10),
                    Skeleton(width: 110, height: 14, radius: 7),
                  ],
                ),
                SizedBox(height: 16),
                Skeleton(width: 220, height: 20, radius: 8),
                SizedBox(height: 8),
                Skeleton(height: 12, radius: 6),
                SizedBox(height: 6),
                Skeleton(width: 180, height: 12, radius: 6),
                SizedBox(height: 16),
                Skeleton(height: 48, radius: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
