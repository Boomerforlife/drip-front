import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/motion.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/brand.dart';
import '../../core/widgets/drip_image.dart';
import '../../data/providers.dart';
import '../home/feed_controller.dart';
import '../outfits/outfit_controller.dart';
import '../session/session_controller.dart';

/// Launch sequence, ~1.1s and skippable with a tap:
///
///   0.00–0.55  the wordmark resolves out of blur (blur → sharp, small → full)
///   0.36–0.66  the red drop pulses once: the brand's signature beat
///   0.46–0.78  "ESTD 2077 · FOR THE VIBE" settles in beneath
///   1.00       hand-off to Home (or Welcome), which cross-fades in
///
/// While it plays, the feed, stories and catalogue are already loading and the
/// first images are decoding, so Home appears with content, not placeholders.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  bool _left = false;

  @override
  void initState() {
    super.initState();
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed) _next();
    });
    _c.forward();
    _prewarm();
  }

  /// Start the data Home needs and decode its first images.
  void _prewarm() {
    if (!ref.read(sessionProvider).signedIn) return;
    ref.read(storiesProvider);
    ref.read(libraryProvider);
    ref.read(feedProvider.future).then((feed) {
      if (!mounted) return;
      for (final o in feed.items.take(3)) {
        if (o.image.isNotEmpty) {
          precacheImage(dripImageProvider(o.image), context);
        }
      }
    }, onError: (_) {});
  }

  void _next() {
    if (!mounted || _left) return;
    _left = true;
    final session = ref.read(sessionProvider);
    // Onboarding finished but its close never shown (the app was closed on
    // the way back from Google): open on it, so a returning user still gets
    // asked before anything on their account changes.
    final ready = ref.read(localStoreProvider).firstRunPending;
    context.go(
      !session.signedIn
          ? '/welcome'
          : ready
          ? '/ready'
          : '/home',
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  static double _seg(
    double t,
    double a,
    double b, [
    Curve curve = Curves.linear,
  ]) => curve.transform(((t - a) / (b - a)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    final reduced = Motion.reduced(context);
    return Scaffold(
      backgroundColor: AppColors.base,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _next,
        child: Semantics(
          label: 'Drip is loading. Tap to skip.',
          child: Center(
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) {
                final t = _c.value;
                final reveal = _seg(t, 0, 0.55, Motion.out);
                final drop = _seg(t, 0.36, 0.66);
                final tag = _seg(t, 0.46, 0.78, Curves.easeOut);
                final blur = reduced ? 0.0 : (1 - reveal) * 16;
                final scale = reduced ? 1.0 : 0.9 + 0.1 * reveal;
                // One soft swell of the red drop, peaking mid-segment.
                final pulse = reduced
                    ? 0.0
                    : Curves.easeInOut.transform(
                        drop < 0.5 ? drop * 2 : (1 - drop) * 2,
                      );

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Opacity(
                      opacity: reveal,
                      child: Transform.scale(
                        scale: scale,
                        child: ImageFiltered(
                          imageFilter: ImageFilter.blur(
                            sigmaX: blur,
                            sigmaY: blur,
                            tileMode: TileMode.decal,
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            clipBehavior: Clip.none,
                            children: [
                              // Warm halo behind the red drop as it pulses.
                              // (The drop sits ~63% across, ~7% down the wordmark.)
                              Positioned(
                                left: 168 * DripWordmark.aspect * 0.626 - 80,
                                top: 168 * 0.075 - 80,
                                child: Opacity(
                                  opacity: pulse,
                                  child: Container(
                                    width: 160,
                                    height: 160,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: RadialGradient(
                                        colors: [
                                          AppColors.red.withValues(alpha: 0.55),
                                          AppColors.red.withValues(alpha: 0),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const DripWordmark(height: 168),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Opacity(
                      opacity: tag,
                      child: Transform.translate(
                        offset: Offset(0, (1 - tag) * 6),
                        child: Text(
                          'ESTD 2077  ·  FOR THE VIBE',
                          style: AppText.mono(
                            10,
                            color: AppColors.muted,
                            letterSpacing: 3.2,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
