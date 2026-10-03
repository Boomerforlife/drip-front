import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/motion.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/utils/image_color.dart';
import '../../core/widgets/drip_image.dart';
import '../../core/widgets/fit_hero.dart';
import '../../core/widgets/glass.dart';
import '../../core/widgets/like_burst.dart';
import '../../core/widgets/overlays.dart';
import '../../core/widgets/skeleton.dart';
import '../../core/widgets/states.dart';
import '../../core/widgets/tap.dart';
import '../../data/models/outfit.dart';
import '../home/feed_controller.dart';
import '../home/occasions.dart';
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
/// small glass element, so the photograph stays the hero. A post's details
/// stay folded away until its caption is tapped.
class FashionScrollScreen extends ConsumerStatefulWidget {
  const FashionScrollScreen({super.key, this.startId, this.occasion});

  /// Fit to open on (from Home). Null starts at the top of the feed.
  final String? startId;

  /// Only fits that suit this occasion (an `Occasions` id), from Home's
  /// occasion cards. Null is the full feed.
  final String? occasion;

  @override
  ConsumerState<FashionScrollScreen> createState() =>
      _FashionScrollScreenState();
}

class _FashionScrollScreenState extends ConsumerState<FashionScrollScreen> {
  /// A card viewed at least this long counts as `open`, else `skip`.
  static const _openAfter = Duration(milliseconds: 2000);

  /// Start loading the next page this many cards before the end.
  static const _prefetch = 3;

  /// The feed this Scroll reads: the full one, or an occasion's.
  late final _feedProvider = scrollFeedProvider(widget.occasion);

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
    _feed = ref.read(_feedProvider.notifier);
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
      ref.read(_feedProvider.notifier).loadMore();
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
    final feed = ref.watch(_feedProvider);
    return PopScope(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, _) {
        // Reached via the tab (no Home underneath): back goes Home, not out.
        if (!didPop) context.go('/home');
      },
      child: feed.when(
        loading: () => const _ReelSkeleton(),
        error: (e, _) =>
            ErrorState.from(e, onRetry: () => ref.invalidate(_feedProvider)),
        data: (state) {
          final items = state.items;
          final occasion = Occasions.byId(widget.occasion);
          if (items.isEmpty && occasion != null) {
            return Stack(
              fit: StackFit.expand,
              children: [
                EmptyState(
                  title: 'NOTHING FOR ${occasion.label.toUpperCase()} YET',
                  message:
                      'No fits in the catalogue suit this one yet. More '
                      'land every day.',
                  actionLabel: 'BROWSE EVERYTHING',
                  onAction: () => context.go('/scroll'),
                ),
                if (context.canPop())
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: _TopChrome(onBack: _back, label: occasion.label),
                  ),
              ],
            );
          }
          if (items.isEmpty) {
            return EmptyState(
              title: 'FRESH FITS INCOMING',
              message:
                  "Drip's catalogue is still being stocked. New fits land "
                  "here as soon as they're ready.",
              actionLabel: 'CHECK AGAIN',
              onAction: () => ref.invalidate(_feedProvider),
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
                    ? _ReelPage(
                        key: ValueKey(items[i].id),
                        outfit: items[i],
                        active: i == _page,
                      )
                    : _FeedTail(
                        state: state,
                        onRetry: () =>
                            ref.read(_feedProvider.notifier).loadMore(),
                        onTop: _toTop,
                      ),
              ),
              if (context.canPop() || occasion != null)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _TopChrome(
                    onBack: context.canPop() ? _back : null,
                    label: occasion?.label,
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
  const _TopChrome({required this.onBack, this.label});

  final VoidCallback? onBack;

  /// The occasion being browsed, shown as a chip.
  final String? label;

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
              ),
            if (label != null) ...[
              const SizedBox(width: 10),
              Glass(
                radius: 18,
                thickness: GlassThickness.thin,
                shadow: false,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                child: Text(
                  'FITS FOR ${label!.toUpperCase()}',
                  style: AppText.mono(10, letterSpacing: 1.2),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────── page

/// One fit, full screen. The picture is the hero: at rest only who posted it,
/// a one-line caption and a slim rail of actions sit on top. Tapping the
/// caption opens the details (tags, shop the look, price, score) in place, the
/// way Instagram opens a long caption; tapping the picture or swiping to the
/// next fit closes them again.
///
/// A collage is a flat-lay, so it is shown whole inside the space the chrome
/// leaves (never cropped, never under the rail or the info), and the space
/// around it takes the collage's own background colour. An on-body photo stays
/// full-bleed with the chrome over a soft scrim.
class _ReelPage extends ConsumerStatefulWidget {
  const _ReelPage({super.key, required this.outfit, required this.active});
  final Outfit outfit;
  final bool active;

  @override
  ConsumerState<_ReelPage> createState() => _ReelPageState();
}

class _ReelPageState extends ConsumerState<_ReelPage> {
  int _burst = 0;
  bool _expanded = false;

  /// The collage's background colour, once its picture has decoded.
  Color? _bg;

  @override
  void didUpdateWidget(_ReelPage old) {
    super.didUpdateWidget(old);
    // Leaving a card closes its details.
    if (old.active && !widget.active) _expanded = false;
  }

  void _doubleTapLike() {
    final id = widget.outfit.id;
    if (!ref.read(fitMarksProvider).isLiked(id)) {
      toggleLikeWithToast(context, ref, id);
    }
    Haptics.thump();
    setState(() => _burst++);
  }

  void _toggle() {
    Haptics.tick();
    setState(() => _expanded = !_expanded);
  }

  @override
  Widget build(BuildContext context) {
    final outfit = widget.outfit;
    final collage = outfit.isCollage;
    final pad = MediaQuery.paddingOf(context);
    // Clear of the status bar / cutout, and of the back button when there is
    // one. `pad.bottom` already includes the floating nav's height (the shell
    // adds it).
    final top = pad.top + (context.canPop() ? 58.0 : 8.0);
    final fade = Motion.dur(context, Motion.content);
    // A collage's empty space is painted in the collage's own background, so
    // the flat-lay reads as filling the screen. Text over a pale one flips to
    // dark ink.
    final bg = _bg ?? AppColors.base;
    final light = collage && bg.computeLuminance() > 0.45;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: light
          ? const SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.dark,
              statusBarBrightness: Brightness.light,
              systemNavigationBarColor: Colors.transparent,
              systemNavigationBarIconBrightness: Brightness.dark,
            )
          : const SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.light,
              statusBarBrightness: Brightness.dark,
              systemNavigationBarColor: Color(0xFF0E1018),
              systemNavigationBarIconBrightness: Brightness.light,
            ),
      child: GestureDetector(
        onDoubleTap: _doubleTapLike,
        // Tapping the picture closes open details (and costs nothing otherwise).
        onTap: _expanded ? _toggle : null,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (collage)
              AnimatedContainer(
                duration: Motion.dur(context, Motion.content),
                color: bg,
              )
            else ...[
              FitHero(
                ootdId: outfit.id,
                radius: 28,
                child: SizedBox.expand(
                  child: ColoredBox(
                    color: AppColors.base,
                    child: DripImage(
                      outfit.image,
                      alignment: Alignment.topCenter,
                    ),
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
              // Bottom scrim: just enough for the identity line at rest ...
              const Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 230,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Color(0xE60E1018), Color(0x000E1018)],
                        stops: [0.1, 1],
                      ),
                    ),
                  ),
                ),
              ),
              // ... and a deeper one while the details are open.
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: MediaQuery.sizeOf(context).height * 0.6,
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: _expanded ? 1 : 0,
                    duration: fade,
                    curve: Motion.out,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Color(0xF50E1018), Color(0x000E1018)],
                          stops: [0.35, 1],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
            Column(
              children: [
                SizedBox(height: top),
                Expanded(
                  child: _Stage(
                    outfit: outfit,
                    expanded: _expanded,
                    onBackground: (c) {
                      if (mounted && c != _bg) setState(() => _bg = c);
                    },
                  ),
                ),
                _InfoPanel(
                  outfit: outfit,
                  expanded: _expanded,
                  onToggle: _toggle,
                  bottom: pad.bottom,
                  ink: light ? AppColors.base : AppColors.cream,
                ),
              ],
            ),
            Center(child: LikeBurst(trigger: _burst, size: 110)),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────── stage

/// Width kept clear on the right of a collage for the action rail.
const _railGutter = 60.0;

/// Everything between the top chrome and the info panel: the whole collage
/// (collages only) and the action rail. It is whatever room the panel leaves,
/// so opening the details shrinks the collage instead of covering it.
class _Stage extends StatelessWidget {
  const _Stage({
    required this.outfit,
    required this.expanded,
    required this.onBackground,
  });
  final Outfit outfit;
  final bool expanded;
  final ValueChanged<Color> onBackground;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (outfit.isCollage)
          Positioned.fill(
            child: AnimatedPadding(
              duration: Motion.dur(context, Motion.content),
              curve: Motion.out,
              // The rail slides away with the details, so the collage may use
              // the width it held.
              padding: EdgeInsets.fromLTRB(
                12,
                4,
                expanded ? 12 : _railGutter,
                8,
              ),
              child: _FittedCollage(outfit: outfit, onBackground: onBackground),
            ),
          ),
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 0, 8, 8),
            child: Align(
              alignment: Alignment.bottomRight,
              // Scales down rather than overflowing on a short screen.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.bottomRight,
                child: IgnorePointer(
                  ignoring: expanded,
                  child: AnimatedOpacity(
                    opacity: expanded ? 0 : 1,
                    duration: Motion.dur(context, Motion.quick),
                    child: _ActionRail(outfit: outfit),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A collage shown whole: as large as fits the room it is given, in its own
/// aspect ratio, never cropped. The aspect ratio and the background colour both
/// come from the decoded image; the colour goes up to the page so the space
/// around the collage matches it.
class _FittedCollage extends StatefulWidget {
  const _FittedCollage({required this.outfit, required this.onBackground});
  final Outfit outfit;
  final ValueChanged<Color> onBackground;

  @override
  State<_FittedCollage> createState() => _FittedCollageState();
}

class _FittedCollageState extends State<_FittedCollage> {
  double? _aspect;
  ImageStream? _stream;
  ui.Image? _sampled;
  late final ImageStreamListener _listener = ImageStreamListener(
    (info, _) {
      final a = info.image.width / info.image.height;
      if (mounted && a != _aspect) setState(() => _aspect = a);
      _sampleBackground(info.image);
    },
    // A broken image shows DripImage's own failure state, full size.
    onError: (_, _) {},
  );

  Future<void> _sampleBackground(ui.Image image) async {
    if (identical(image, _sampled)) return;
    _sampled = image;
    final c = await edgeColor(image);
    if (c != null && mounted) widget.onBackground(c);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(_FittedCollage old) {
    super.didUpdateWidget(old);
    if (old.outfit.image != widget.outfit.image) _resolve();
  }

  void _resolve() {
    final next = dripImageProvider(widget.outfit.image)
        .resolve(createLocalImageConfiguration(context));
    if (next.key == _stream?.key) return;
    _stream?.removeListener(_listener);
    _stream = next..addListener(_listener);
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final a = _aspect;
        final size = a == null
            ? c.biggest
            : applyBoxFit(
                BoxFit.contain,
                Size(a * 1000, 1000),
                c.biggest,
              ).destination;
        return Center(
          child: SizedBox.fromSize(
            size: size,
            child: FitHero(
              ootdId: widget.outfit.id,
              radius: 28,
              child: DripImage(widget.outfit.image, fit: BoxFit.cover),
            ),
          ),
        );
      },
    );
  }
}

// ──────────────────────────────────────────────────────────── info panel

/// Who it's from, in one line, plus a caption to tap. Opens, in place, into the
/// tags, the shop strip, the price and the score.
class _InfoPanel extends StatelessWidget {
  const _InfoPanel({
    required this.outfit,
    required this.expanded,
    required this.onToggle,
    required this.bottom,
    required this.ink,
  });
  final Outfit outfit;
  final bool expanded;
  final VoidCallback onToggle;
  final double bottom;

  /// Text colour over the page: cream, or dark ink over a pale collage.
  final Color ink;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottom + 8),
      child: AnimatedSize(
        duration: Motion.dur(context, Motion.content),
        curve: Motion.out,
        alignment: Alignment.bottomCenter,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Curated by Drip (creator posts come after the beta).
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.base,
                    border: Border.all(color: p.accent, width: 1.5),
                  ),
                  child: Text('d.', style: AppText.fredoka(15)),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '@drip',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.manrope(
                          14,
                          weight: FontWeight.w800,
                          color: ink,
                        ),
                      ),
                      if (expanded)
                        Text(
                          outfit.isCollage ? 'CURATED FLAT-LAY' : 'CURATED FIT',
                          style: AppText.mono(
                            9,
                            color: ink.withValues(alpha: 0.65),
                          ),
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
            const SizedBox(height: 8),
            Semantics(
              button: true,
              label: expanded
                  ? 'Hide details'
                  : 'Show details: ${outfit.title}',
              excludeSemantics: true,
              onTap: onToggle,
              child: GestureDetector(
                onTap: onToggle,
                behavior: HitTestBehavior.opaque,
                child: expanded
                    ? Glass(
                        radius: 22,
                        shadow: false,
                        padding: const EdgeInsets.all(14),
                        child: _Details(outfit: outfit),
                      )
                    : _Caption(title: outfit.title, ink: ink),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The resting caption: the fit's name on one line and a quiet "more".
class _Caption extends StatelessWidget {
  const _Caption({required this.title, required this.ink});
  final String title;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Flexible(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.manrope(13, weight: FontWeight.w600, color: ink),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'MORE',
            style: AppText.mono(
              9,
              color: ink.withValues(alpha: 0.65),
              weight: FontWeight.w500,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Everything about the post, shown on request.
class _Details extends StatelessWidget {
  const _Details({required this.outfit});
  final Outfit outfit;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                outfit.title.toUpperCase(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppText.display(18, lineHeight: 22),
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'LESS',
                style: AppText.mono(
                  9,
                  color: AppColors.muted,
                  weight: FontWeight.w500,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _MetaChip(outfit.isCollage ? 'COLLAGE' : 'ON BODY', filled: true),
            for (final t in outfit.tags.take(3)) _MetaChip(t.toUpperCase()),
            _MetaChip('✦ DRIP ${outfit.rate}', color: p.accent),
          ],
        ),
        if (outfit.pieces.isNotEmpty) ...[
          const SizedBox(height: 10),
          _ShopStrip(outfit: outfit),
        ],
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
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: following ? Colors.white.withValues(alpha: 0.10) : accent,
          borderRadius: BorderRadius.circular(14),
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
  const _MetaChip(this.label, {this.filled = false, this.color});
  final String label;
  final bool filled;

  /// Text colour; cream when null.
  final Color? color;

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
          color: color ?? AppColors.cream,
          weight: filled || color != null ? FontWeight.w500 : FontWeight.w400,
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

/// Like, comment, save, share: small glass buttons, no captions, so the rail
/// stays out of the picture's way.
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
          semantic: liked ? 'Unlike' : 'Like',
          onTap: () {
            Haptics.commit();
            toggleLikeWithToast(context, ref, outfit.id);
          },
        ),
        _RailButton(
          icon: Icons.mode_comment_outlined,
          semantic: 'Comments',
          onTap: () => showAfterBeta(context, 'Comments'),
        ),
        _RailButton(
          icon: saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
          color: saved ? context.palette.accent : AppColors.cream,
          semantic: saved ? 'Remove from saved' : 'Save',
          onTap: () {
            Haptics.commit();
            toggleSaveWithToast(context, ref, outfit.id);
          },
        ),
        _RailButton(
          icon: Icons.ios_share_rounded,
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
    required this.semantic,
    required this.onTap,
    this.color = AppColors.cream,
  });

  final IconData icon;
  final Color color;
  final String semantic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Tap(
        onTap: onTap,
        scale: 0.88,
        semanticLabel: semantic,
        // A 44pt target around a 40pt glass disc.
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: SizedBox(
              width: 40,
              height: 40,
              child: Glass(
                radius: 20,
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
                      size: 21,
                      color: color,
                    ),
                  ),
                ),
              ),
            ),
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
            bottom: bottom + 8,
            right: 84,
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Skeleton(width: 34, height: 34, circle: true),
                    SizedBox(width: 10),
                    Skeleton(width: 90, height: 14, radius: 7),
                  ],
                ),
                SizedBox(height: 12),
                Skeleton(width: 200, height: 12, radius: 6),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
