import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/motion.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/brand.dart';
import '../../core/widgets/drip_image.dart';
import '../../core/widgets/fit_hero.dart';
import '../../core/widgets/glass.dart';
import '../../core/widgets/overlays.dart';
import '../../core/widgets/skeleton.dart';
import '../../core/widgets/states.dart';
import '../../core/widgets/tap.dart';
import '../../data/mock/mock_weather.dart';
import '../../data/models/outfit.dart';
import '../../routing/main_shell.dart';
import '../bag/bag_controller.dart';
import '../bag/bag_sheet.dart';
import '../outfits/outfit_controller.dart';
import '../social/social_controller.dart';
import 'feed_controller.dart';

/// Home: brand + inbox → stories → today (weather, pick, Ask Taylor) →
/// tools → today's drip (into the Scroll) → a staggered wall of fresh fits.
///
/// The fits are the first page of the Fashion Scroll feed (`GET /scroll`).
/// Stories and the inbox are the social layer, which comes after the beta.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(feedProvider);

    return ShellPage(
      child: Column(
        children: [
          const _HomeHeader(),
          Expanded(
            child: feed.when(
              // Placeholders shaped like the real layout, not a spinner.
              loading: () => const _HomeSkeleton(),
              error: (e, _) => ErrorState.from(
                e,
                onRetry: () => ref.invalidate(feedProvider),
              ),
              data: (state) => _HomeBody(fits: state.items),
            ),
          ),
        ],
      ),
    );
  }
}

/// Opens a fit in the Fashion Scroll from a card. The image expands into place
/// (Hero), so the page itself must not slide: direction 0 means "no tab move".
void _openInScroll(BuildContext context, String id) {
  TabDirection.value = 0;
  context.push('/scroll?id=$id');
}

// ───────────────────────────────────────────────────────────────── header

class _HomeHeader extends StatelessWidget {
  const _HomeHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: SizedBox(
        height: 48,
        child: Stack(
          alignment: Alignment.center,
          children: [
            const DripWordmark(height: 30),
            Align(
              alignment: Alignment.centerLeft,
              // Like Instagram: + opens the camera (swiping right does too).
              child: GlassIconButton(
                semanticLabel: 'Open the camera',
                onTap: openCamera(context),
                child: const Icon(
                  Icons.add_rounded,
                  size: 24,
                  color: AppColors.cream,
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: GlassIconButton(
                semanticLabel: 'Messages and notifications',
                onTap: () => showAfterBeta(context, 'Messages & notifications'),
                child: const Icon(
                  Icons.mail_outline_rounded,
                  size: 20,
                  color: AppColors.cream,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The app's camera: garment capture, full screen. Opened from the + on Home
/// or by swiping right on Home.
VoidCallback openCamera(BuildContext context) =>
    () => context.push('/wardrobe/capture');

// ──────────────────────────────────────────────────────────────────── body

class _HomeBody extends ConsumerWidget {
  const _HomeBody({required this.fits});
  final List<Outfit> fits;

  Future<void> _refresh(WidgetRef ref) async {
    ref
      ..invalidate(storiesProvider)
      ..invalidate(libraryProvider)
      ..invalidate(feedProvider);
    await ref.read(feedProvider.future);
    Haptics.tick();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todaysPick = fits.isEmpty ? null : fits.first;

    final tiles = <_GridItem>[
      for (final o in fits)
        _GridItem(
          key: o.id,
          image: o.image,
          title: o.title,
          handle: o.creatorHandle,
          score: o.rate,
          price: o.price,
          heroId: o.id,
          onTap: () => _openInScroll(context, o.id),
        ),
    ];

    final bottom = MediaQuery.paddingOf(context).bottom;
    return RefreshIndicator(
      color: context.palette.accent,
      backgroundColor: AppColors.surface,
      onRefresh: () => _refresh(ref),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          const SliverToBoxAdapter(child: _StoriesStrip()),
          // The pick's portrait rises out of the card's top edge, so the
          // card sits a little lower than the stories' baseline.
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
              child: _TodayCard(outfit: todaysPick),
            ),
          ),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _FeatureBlocks(),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _DripBar(fits: fits),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 32, 12, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text('FRESH FITS', style: AppText.display(15)),
                  const SizedBox(width: 8),
                  Text(
                    tiles.length.toString().padLeft(2, '0'),
                    style: AppText.mono(10, color: AppColors.dim),
                  ),
                  const Spacer(),
                  Tap(
                    onTap: () => showAfterBeta(context, 'Search & Discover'),
                    semanticLabel: 'Search and discover fits',
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 12,
                      ),
                      child: Text(
                        'SEARCH & DISCOVER  →',
                        style: AppText.mono(
                          10,
                          color: AppColors.muted,
                          weight: FontWeight.w500,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, bottom + 16),
            sliver: SliverToBoxAdapter(
              child: tiles.isEmpty
                  ? const _NoFitsYet()
                  : _StaggeredGrid(tiles: tiles),
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────── stories

class _StoriesStrip extends ConsumerWidget {
  const _StoriesStrip();

  static const _avatar = 76.0;
  static const _height = 118.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Stories from other people are out for v1 (they come back later); only
    // the user's own circle stays.
    final me = ref.watch(myProfileProvider).value;
    return SizedBox(
      height: _height,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
          child: _StoryBubble(
            label: 'Your story',
            avatar: me?.avatar,
            isYou: true,
            onTap: () => showAfterBeta(context, 'Stories'),
          ),
        ),
      ),
    );
  }
}

/// A story: bigger than the old bubbles, with an accent→secondary ring when
/// unseen and a hairline ring once seen, so state never depends on colour
/// alone (the ring is also thicker).
class _StoryBubble extends StatelessWidget {
  const _StoryBubble({
    required this.label,
    required this.avatar,
    required this.onTap,
    this.isYou = false,
  });

  final String label;
  final String? avatar;
  /// Story rings return with the social layer; none is unseen in v1.
  bool get unseen => false;
  final bool isYou;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    const size = _StoriesStrip._avatar;
    return Tap(
      onTap: onTap,
      scale: 0.94,
      semanticLabel: isYou
          ? 'Add to your story'
          : '$label story${unseen ? ', new' : ''}',
      child: SizedBox(
        width: size + 4,
        child: Column(
          children: [
            SizedBox(
              width: size,
              height: size,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: size,
                    height: size,
                    padding: EdgeInsets.all(unseen ? 3 : 2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: unseen
                          ? SweepGradient(
                              colors: [
                                p.accent,
                                p.secondary,
                                p.accent,
                                p.secondary,
                                p.accent,
                              ],
                            )
                          : null,
                      color: unseen ? null : AppColors.elevated,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(2.5),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.base,
                      ),
                      child: ClipOval(
                        child: avatar == null || avatar!.isEmpty
                            ? ColoredBox(color: AppColors.elevated)
                            : DripImage(avatar!, logicalWidth: size),
                      ),
                    ),
                  ),
                  if (isYou)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: p.accent,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.base, width: 2.5),
                        ),
                        child: const Icon(
                          Icons.add_rounded,
                          size: 16,
                          color: AppColors.base,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isYou ? label : '@$label',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.manrope(
                11,
                weight: unseen ? FontWeight.w700 : FontWeight.w500,
                color: unseen ? AppColors.cream : AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────── today card

const _weekdays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
const _months = [
  'JAN',
  'FEB',
  'MAR',
  'APR',
  'MAY',
  'JUN',
  'JUL',
  'AUG',
  'SEP',
  'OCT',
  'NOV',
  'DEC',
];

/// The Home hero: today's (mocked) weather, what it means for your fit, and
/// the day's pick, with Taylor one tap away. It's the only stylist entry on
/// Home: the whole card leads there, "Ask Taylor" just names the door.
///
/// The pick's portrait breaks out of the card's top edge, like a photo tucked
/// under a paper clip: the one deliberate overlap on the screen.
class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.outfit});
  final Outfit? outfit;

  static const _portraitW = 92.0;
  static const _portraitH = 124.0;
  static const _rise = 18.0;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final weather = MockWeather.today();
    final now = DateTime.now();
    final date =
        '${_weekdays[now.weekday - 1]} ${now.day} ${_months[now.month - 1]}';
    final corner = (26 * p.roundness).clamp(14.0, 30.0);
    // Four clearly different chips (the skin's wash is near-black, so it's
    // lifted toward cream to stay visible on the card).
    final swatches = [
      p.accent,
      p.secondary,
      Color.lerp(p.wash, AppColors.cream, 0.55)!,
      AppColors.cream,
    ];
    final pick = outfit;

    final card = Glass(
      radius: corner,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(right: pick == null ? 0 : _portraitW + 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TODAY, $date',
                  style: AppText.mono(
                    10,
                    color: AppColors.muted,
                    letterSpacing: 1.6,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${weather.tempF}°',
                      style: AppText.display(40, lineHeight: 42),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Scales down on narrow phones instead of overflowing.
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: _DayColours(colors: swatches),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${weather.glyph}  ${weather.condition}'
                                  .toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.mono(
                                10,
                                color: AppColors.cream,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  weather.advice,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.manrope(
                    13,
                    color: AppColors.cream.withValues(alpha: 0.78),
                    lineHeight: 19,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            height: 0.75,
            color: AppColors.cream.withValues(alpha: 0.10),
          ),
          SizedBox(
            height: 56,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pick == null ? 'YOUR STYLIST' : "TODAY'S PICK",
                        style: AppText.mono(
                          10,
                          color: AppColors.dim,
                          letterSpacing: 1.4,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        pick?.title ?? 'Plan a look for today',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.manrope(14, weight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'ASK TAYLOR  →',
                  style: AppText.mono(
                    11,
                    color: p.accent,
                    weight: FontWeight.w500,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return Tap(
      onTap: () => context.push('/stylist'),
      semanticLabel:
          "Today, ${weather.tempF} degrees, ${weather.condition}. "
          "${pick == null ? '' : "Today's pick: ${pick.title}. "}Ask Taylor",
      scale: 0.985,
      child: pick == null
          ? card
          : Stack(
              clipBehavior: Clip.none,
              children: [
                card,
                Positioned(
                  top: -_rise,
                  right: 18,
                  width: _portraitW,
                  height: _portraitH,
                  child: _Portrait(image: pick.image, radius: corner * 0.55),
                ),
              ],
            ),
    );
  }
}

/// The day's pick as a small print: hairline frame, a soft drop so it reads
/// as lifted off the card rather than cut into it.
class _Portrait extends StatelessWidget {
  const _Portrait({required this.image, required this.radius});
  final String image;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: r,
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: r,
        child: Stack(
          fit: StackFit.expand,
          children: [
            DripImage(
              image,
              alignment: Alignment.topCenter,
              logicalWidth: _TodayCard._portraitW,
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: r,
                border: Border.all(
                  color: AppColors.cream.withValues(alpha: 0.18),
                  width: 0.75,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The day's colours: four separate, clearly sized chips with a caption,
/// instead of tiny overlapping dots.
class _DayColours extends StatelessWidget {
  const _DayColours({required this.colors});
  final List<Color> colors;

  static const _d = 24.0;
  static const _gap = 8.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'COLOURS OF THE DAY',
          style: AppText.mono(9, color: AppColors.muted, letterSpacing: 1.2),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < colors.length; i++) ...[
              if (i > 0) const SizedBox(width: _gap),
              Container(
                width: _d,
                height: _d,
                decoration: BoxDecoration(
                  color: colors[i],
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.cream.withValues(alpha: 0.45),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colors[i].withValues(alpha: 0.35),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────── feature blocks

class _Feature {
  const _Feature(this.index, this.icon, this.label, {this.soon = false});
  final String index;
  final IconData icon;
  final String label;

  /// No screen behind it yet: the tile says so up front instead of pretending.
  final bool soon;
}

const _features = [
  _Feature(
    '01',
    Icons.face_retouching_natural_rounded,
    'Selfie Coordinator',
    soon: true,
  ),
  _Feature('02', Icons.palette_outlined, 'Colour Theory'),
  _Feature('03', Icons.shopping_bag_outlined, 'Shop List'),
  _Feature('04', Icons.quiz_outlined, 'Style Quiz', soon: true),
];

/// Four tools, 2×2, numbered like the index of a lookbook.
class _FeatureBlocks extends ConsumerWidget {
  const _FeatureBlocks();

  void _open(BuildContext context, _Feature f) {
    if (f.soon) {
      showAfterBeta(context, f.label);
      return;
    }
    switch (f.index) {
      case '02':
        context.push('/me/colour-theory');
      case '03':
        showBagSheet(context);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inBag = ref.watch(bagProvider).length;
    Widget tile(_Feature f) => Expanded(
      child: _FeatureTile(
        feature: f,
        meta: f.soon
            ? 'AFTER BETA'
            : f.index == '03'
            ? (inBag == 0 ? 'EMPTY' : '$inBag IN BAG')
            : 'YOUR PALETTE',
        onTap: () => _open(context, f),
      ),
    );
    return Column(
      children: [
        Row(
          children: [
            tile(_features[0]),
            const SizedBox(width: 14),
            tile(_features[1]),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            tile(_features[2]),
            const SizedBox(width: 14),
            tile(_features[3]),
          ],
        ),
      ],
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({
    required this.feature,
    required this.meta,
    required this.onTap,
  });
  final _Feature feature;
  final String meta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final soon = feature.soon;
    final radius = (18 * p.roundness).clamp(12.0, 22.0);
    // Visible, not loud: a lifted surface with a hairline edge. Live tiles get
    // a soft accent edge and an accent-tinted icon chip; "after beta" tiles
    // stay calm and neutral.
    return Tap(
      onTap: onTap,
      semanticLabel: soon
          ? '${feature.label}, coming after beta'
          : feature.label,
      scale: 0.97,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.cream.withValues(alpha: soon ? 0.07 : 0.11),
              AppColors.cream.withValues(alpha: soon ? 0.03 : 0.05),
            ],
          ),
          border: Border.all(
            color: soon
                ? AppColors.cream.withValues(alpha: 0.12)
                : p.accent.withValues(alpha: 0.38),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  feature.index,
                  style: AppText.mono(10, color: AppColors.muted),
                ),
                const Spacer(),
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: (soon ? AppColors.cream : p.accent).withValues(
                      alpha: soon ? 0.08 : 0.16,
                    ),
                  ),
                  child: Icon(
                    feature.icon,
                    size: 17,
                    color: soon ? AppColors.muted : p.accent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              feature.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.manrope(
                14,
                weight: FontWeight.w700,
                color: soon
                    ? AppColors.cream.withValues(alpha: 0.72)
                    : AppColors.cream,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              meta,
              style: AppText.mono(
                10,
                color: soon ? AppColors.dim : AppColors.muted,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────── info bar

/// Today's drip: how many new fits are waiting, shown as a fan of their
/// photos, and the door into the Fashion Scroll where they play.
class _DripBar extends StatelessWidget {
  const _DripBar({required this.fits});
  final List<Outfit> fits;

  static const _thumb = 34.0;
  static const _overlap = 12.0;

  @override
  Widget build(BuildContext context) {
    final shown = fits.take(3).toList();
    final count = fits.length;
    return Tap(
      onTap: () {
        TabDirection.value = 1;
        context.go('/scroll');
      },
      semanticLabel: "Today's drip: $count new fits. Watch in the scroll",
      scale: 0.98,
      child: Glass(
        radius: 20,
        thickness: GlassThickness.thin,
        shadow: false,
        padding: const EdgeInsets.fromLTRB(12, 11, 16, 11),
        child: Row(
          children: [
            SizedBox(
              width: _thumb + (_thumb - _overlap) * (shown.length - 1),
              height: _thumb,
              child: Stack(
                children: [
                  for (var i = shown.length - 1; i >= 0; i--)
                    Positioned(
                      left: i * (_thumb - _overlap),
                      child: Container(
                        width: _thumb,
                        height: _thumb,
                        padding: const EdgeInsets.all(1.5),
                        decoration: const BoxDecoration(
                          color: AppColors.base,
                          shape: BoxShape.circle,
                        ),
                        child: ClipOval(
                          child: DripImage(
                            shown[i].image,
                            alignment: Alignment.topCenter,
                            logicalWidth: _thumb,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "TODAY'S DRIP",
                    style: AppText.mono(
                      10,
                      color: AppColors.muted,
                      letterSpacing: 1.6,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    count == 0
                        ? 'Fresh fits are on their way'
                        : '$count fresh ${count == 1 ? 'fit' : 'fits'} picked for you',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.manrope(13, weight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.play_arrow_rounded,
              size: 20,
              color: AppColors.cream,
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────── grid

class _GridItem {
  const _GridItem({
    required this.key,
    required this.image,
    required this.title,
    required this.handle,
    required this.score,
    required this.price,
    required this.onTap,
    this.heroId,
  });

  final String key;
  final String image;
  final String title;
  final String handle;
  final int score;

  /// INR total; 0 when unpriced.
  final int price;
  final String? heroId;
  final VoidCallback onTap;
}

/// Two columns whose tiles alternate tall and short, offset from each other,
/// so the feed reads like a pinned-up wall instead of a spreadsheet. Both
/// columns carry the same total height (tall + short per pair).
class _StaggeredGrid extends StatelessWidget {
  const _StaggeredGrid({required this.tiles});
  final List<_GridItem> tiles;

  static const _gap = 12.0;
  static const _tall = 1.42; // height ÷ width
  static const _short = 1.12;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final w = (box.maxWidth - _gap) / 2;
        Widget column(int side) {
          final items = <Widget>[];
          for (var i = side, n = 0; i < tiles.length; i += 2, n++) {
            // Left starts tall, right starts short: the columns interlock.
            final tall = (n + side).isEven;
            if (items.isNotEmpty) items.add(const SizedBox(height: _gap));
            items.add(
              SizedBox(
                height: w * (tall ? _tall : _short),
                child: _GridTile(item: tiles[i]),
              ),
            );
          }
          return Column(children: items);
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: w, child: column(0)),
            const SizedBox(width: _gap),
            SizedBox(width: w, child: column(1)),
          ],
        );
      },
    );
  }
}

class _GridTile extends StatelessWidget {
  const _GridTile({required this.item});
  final _GridItem item;

  @override
  Widget build(BuildContext context) {
    final radius = (20 * context.palette.roundness).clamp(12.0, 24.0);
    final photo = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Stack(
        fit: StackFit.expand,
        children: [
          DripImage(item.image, alignment: Alignment.topCenter),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment(0, 0.1),
                colors: [Color(0xD90E1018), Color(0x000E1018)],
              ),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.manrope(
                    13,
                    weight: FontWeight.w700,
                    lineHeight: 17,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.price > 0
                      ? '@${item.handle}  ·  ${formatPrice(item.price)}'
                      : '@${item.handle}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.mono(
                    10,
                    color: AppColors.cream.withValues(alpha: 0.72),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 10,
            right: 10,
            // Plain translucent chip: many tiles scroll at once, so no
            // per-tile backdrop blur here.
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.base.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
              ),
              child: Text(
                '${item.score}',
                style: AppText.mono(10, weight: FontWeight.w500),
              ),
            ),
          ),
        ],
      ),
    );

    return Tap(
      onTap: item.onTap,
      scale: 0.97,
      semanticLabel: '${item.title} by ${item.handle}',
      child: item.heroId == null
          ? photo
          : FitHero(ootdId: item.heroId!, radius: radius, child: photo),
    );
  }
}

// ──────────────────────────────────────────────────────────── loading state

class _StoriesSkeleton extends StatelessWidget {
  const _StoriesSkeleton();

  @override
  Widget build(BuildContext context) {
    return ShimmerScope(
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
        itemCount: 5,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (_, _) => const Column(
          children: [
            Skeleton(width: 76, height: 76, circle: true),
            SizedBox(height: 8),
            Skeleton(width: 52, height: 9, radius: 5),
          ],
        ),
      ),
    );
  }
}

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width - 32;
    final half = (width - 10) / 2;
    return ShimmerScope(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(
              height: _StoriesStrip._height,
              child: _StoriesSkeleton(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
              child: Skeleton(width: width, height: 210, radius: 26),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  Skeleton(width: half, height: 84, radius: 18),
                  const SizedBox(width: 10),
                  Skeleton(width: half, height: 84, radius: 18),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Skeleton(width: width, height: 58, radius: 20),
            ),
          ],
        ),
      ),
    );
  }
}

/// Home before the catalogue has any fits: says so, and offers the stylist.
class _NoFitsYet extends StatelessWidget {
  const _NoFitsYet();

  @override
  Widget build(BuildContext context) {
    return Glass(
      radius: 20,
      thickness: GlassThickness.thin,
      shadow: false,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('FRESH FITS INCOMING', style: AppText.display(14)),
          const SizedBox(height: 6),
          Text(
            "Drip's catalogue is still being stocked. Pull down to check "
            'again. Meanwhile, digitize your own pieces in the Wardrobe.',
            style: AppText.manrope(
              13,
              color: AppColors.muted,
              lineHeight: 19,
            ),
          ),
          const SizedBox(height: 12),
          Tap(
            onTap: () => context.push('/wardrobe/capture'),
            semanticLabel: 'Add a garment to your wardrobe',
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                'ADD A GARMENT  →',
                style: AppText.mono(
                  11,
                  color: context.palette.accent,
                  weight: FontWeight.w500,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
