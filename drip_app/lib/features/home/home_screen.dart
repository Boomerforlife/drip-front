import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/motion.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/contrast.dart';
import '../../core/widgets/brand.dart';
import '../../core/widgets/drip_image.dart';
import '../../core/widgets/glass.dart';
import '../../core/widgets/overlays.dart';
import '../../core/widgets/skeleton.dart';
import '../../core/widgets/states.dart';
import '../../core/widgets/tap.dart';
import '../../data/models/outfit.dart';
import '../../routing/main_shell.dart';
import '../bag/bag_controller.dart';
import '../bag/bag_sheet.dart';
import '../outfits/outfit_controller.dart';
import '../session/session_controller.dart';
import '../social/social_controller.dart';
import 'feed_controller.dart';
import 'occasion_card.dart';
import 'occasions.dart';

/// Home: brand + inbox → stories → today (date, time, pick, Ask Taylor) →
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
    // The occasions picked in onboarding lead the wall, tagged as theirs.
    final picked = ref.watch(onboardingProvider.select((p) => p.occasions));
    final occasions = Occasions.pickedFirst(picked);

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
              padding: const EdgeInsets.fromLTRB(20, 32, 20, 12),
              child: Row(
                children: [
                  Text('SHOP BY OCCASION', style: AppText.display(15)),
                  const SizedBox(width: 8),
                  Text(
                    Occasions.all.length.toString().padLeft(2, '0'),
                    style: AppText.mono(10, color: AppColors.dim),
                  ),
                  if (picked.isNotEmpty) ...[
                    const Spacer(),
                    Text(
                      'YOURS FIRST',
                      style: AppText.mono(
                        10,
                        color: AppColors.cyan,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, bottom + 16),
            sliver: SliverToBoxAdapter(
              child: _StaggeredGrid(
                children: [
                  for (var i = 0; i < occasions.length; i++)
                    OccasionCard(
                      occasion: occasions[i],
                      index: Occasions.all.indexOf(occasions[i]),
                      forYou: picked.contains(occasions[i].id),
                      onTap: () => _openOccasion(context, occasions[i]),
                    ),
                ],
              ),
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

/// The clock the Home hero reads. Tests swap it to pin the time of day.
DateTime Function() homeClock = DateTime.now;

/// The Home hero: today's date, the time and whether it's day or night, with
/// the day's pick and Taylor one tap away. It's the only stylist entry on
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
    final corner = (26 * p.roundness).clamp(14.0, 30.0);
    final pick = outfit;

    final card = Glass(
      radius: corner,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(right: pick == null ? 0 : _portraitW + 12),
            child: const _DayClock(),
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

/// Date, time and day/night, live: re-reads the clock on every minute change.
/// Follows the phone's 12/24-hour setting.
class _DayClock extends StatefulWidget {
  const _DayClock();

  @override
  State<_DayClock> createState() => _DayClockState();
}

class _DayClockState extends State<_DayClock> {
  late DateTime _now = homeClock();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  /// Wakes on the next minute boundary, so the display is never a minute late.
  void _schedule() {
    final into = Duration(seconds: _now.second, milliseconds: _now.millisecond);
    _timer = Timer(const Duration(minutes: 1) - into, () {
      if (!mounted) return;
      setState(() => _now = homeClock());
      _schedule();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Daylight hours: 6 AM up to (not including) 6 PM.
  static bool _isDay(DateTime t) => t.hour >= 6 && t.hour < 18;

  @override
  Widget build(BuildContext context) {
    final now = _now;
    final h24 = MediaQuery.alwaysUse24HourFormatOf(context);
    final day = _isDay(now);
    final date =
        '${_weekdays[now.weekday - 1]} · '
        '${now.day.toString().padLeft(2, '0')} ${_months[now.month - 1]}';
    final minute = now.minute.toString().padLeft(2, '0');
    final hour = h24
        ? now.hour.toString().padLeft(2, '0')
        : (now.hour % 12 == 0 ? 12 : now.hour % 12).toString();
    final period = h24 ? '' : (now.hour < 12 ? 'AM' : 'PM');

    return Semantics(
      label: '$date, $hour:$minute $period, ${day ? 'day' : 'night'}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            date,
            style: AppText.mono(10, color: AppColors.muted, letterSpacing: 1.6),
          ),
          const SizedBox(height: 8),
          // Wraps instead of overflowing when the card is narrow.
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              // Scales down on the narrowest phones instead of overflowing.
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '$hour:$minute',
                      style: AppText.display(42, lineHeight: 44),
                    ),
                    if (period.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text(
                        period,
                        style: AppText.mono(
                          12,
                          color: AppColors.muted,
                          weight: FontWeight.w500,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              _DayNightChip(day: day),
            ],
          ),
        ],
      ),
    );
  }
}

/// A small pill: sun for day, moon for night.
class _DayNightChip extends StatelessWidget {
  const _DayNightChip({required this.day});
  final bool day;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.cream.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.cream.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            day ? Icons.wb_sunny_rounded : Icons.nightlight_round,
            size: 13,
            color: p.accent,
          ),
          const SizedBox(width: 6),
          Text(
            day ? 'DAY' : 'NIGHT',
            style: AppText.mono(
              10,
              color: AppColors.cream,
              weight: FontWeight.w500,
              letterSpacing: 1.2,
            ),
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
  _Feature('01', Icons.face_retouching_natural_rounded, 'Selfie Coordinator'),
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
      case '01':
        context.push('/selfie');
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
            : f.index == '01'
            ? 'GUIDED SELFIE'
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
    // Every colour is checked against what the tile actually sits on, so the
    // outline, icon and text stay legible whatever the theme's ground is.
    // Live tiles get an accent edge (never fainter than 3:1) and an
    // accent-tinted icon chip; "after beta" tiles stay calm and neutral.
    final backdrop = featureTileBackdrop(p);
    final border = soon
        ? AppColors.cream.withValues(alpha: 0.12)
        : selfieCoordinatorBorderColor(p);
    final chipFill = (soon ? AppColors.cream : p.accent).withValues(
      alpha: soon ? 0.08 : 0.16,
    );
    final chipBg = Color.alphaBlend(chipFill, backdrop);
    final iconColor = soon
        ? ensureContrast(AppColors.muted, chipBg, minRatio: 3)
        : ensureContrast(p.accent, chipBg, minRatio: 3);
    final labelColor = ensureContrast(
      soon ? AppColors.cream.withValues(alpha: 0.72) : AppColors.cream,
      backdrop,
      minRatio: 4.5,
    );
    final metaColor = ensureContrast(
      soon ? AppColors.dim : AppColors.muted,
      backdrop,
      minRatio: 4.5,
    );
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
          border: Border.all(color: border, width: soon ? 1 : 1.25),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(feature.index, style: AppText.mono(10, color: metaColor)),
                const Spacer(),
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: chipFill,
                  ),
                  child: Icon(feature.icon, size: 17, color: iconColor),
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
                color: labelColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              meta,
              style: AppText.mono(10, color: metaColor, letterSpacing: 1),
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

// ──────────────────────────────────────────────────────────────── occasions

/// Opens the Scroll on fits that suit [o].
void _openOccasion(BuildContext context, Occasion o) {
  Haptics.tick();
  TabDirection.value = 1;
  context.push('/scroll?occasion=${o.id}');
}

/// Two columns whose cards alternate tall and short, offset from each other,
/// so the wall reads like a pinned-up board instead of a spreadsheet. Both
/// columns carry the same total height (tall + short per pair).
class _StaggeredGrid extends StatelessWidget {
  const _StaggeredGrid({required this.children});
  final List<Widget> children;

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
          for (var i = side, n = 0; i < children.length; i += 2, n++) {
            // Left starts tall, right starts short: the columns interlock.
            final tall = (n + side).isEven;
            if (items.isNotEmpty) items.add(const SizedBox(height: _gap));
            items.add(
              SizedBox(height: w * (tall ? _tall : _short), child: children[i]),
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
