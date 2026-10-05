import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/motion.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/overlays.dart';
import '../../data/providers.dart';
import '../home/feed_controller.dart';
import '../session/session_controller.dart';
import 'onboarding_ticket.dart';
import 'onboarding_widgets.dart';

/// The first-run close: back from Google, the finished ticket is waiting,
/// "your Drip is ready", one button into Home. Shown once, after onboarding
/// on this device, and only to a new account: a returning user whose saved
/// picks were kept goes straight Home with a word that they stand.
class ReadyScreen extends ConsumerStatefulWidget {
  const ReadyScreen({super.key});

  @override
  ConsumerState<ReadyScreen> createState() => _ReadyScreenState();
}

class _ReadyScreenState extends ConsumerState<ReadyScreen> {
  /// Saving normally takes a moment; past this the button opens anyway and
  /// the picks keep syncing in the background.
  bool _waited = false;
  Timer? _wait;
  bool _left = false;

  @override
  void initState() {
    super.initState();
    _wait = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _waited = true);
    });
  }

  @override
  void dispose() {
    _wait?.cancel();
    super.dispose();
  }

  bool _resolving = false;

  Future<void> _home({String? note}) async {
    if (_left) return;
    _left = true;
    Haptics.commit();
    await ref.read(localStoreProvider).setFirstRunPending(false);
    // Home opens on a feed ranked by the picks just saved.
    ref.invalidate(scrollFeedProvider);
    if (!mounted) return;
    if (note != null) showDripToast(context, note);
    context.go('/home');
  }

  /// A returning user's choice: update the saved Drip with what they
  /// changed, or keep it exactly as it was.
  Future<void> _resolve({required bool update}) async {
    if (_resolving) return;
    setState(() => _resolving = true);
    try {
      await ref.read(sessionProvider.notifier).resolvePicks(update: update);
      await _home(
        note: update
            ? 'Your Drip is updated'
            : 'Welcome back. Your saved Drip is unchanged',
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _resolving = false);
      showDripToast(context, 'Couldn’t reach Drip. Check your connection');
    }
  }

  @override
  Widget build(BuildContext context) {
    final sync = ref.watch(picksSyncProvider);
    // A returning user who went through onboarding again: no celebration,
    // a question. Nothing on their account changes until they answer.
    final returning = sync == PicksSync.conflict;
    final info = TicketInfo(ref.watch(onboardingProvider));
    final saving = sync == PicksSync.syncing && !_waited;
    final glow = info.colours.isEmpty
        ? AppColors.red
        : Color(info.colours.first.$3);
    final (eyebrow, note) = switch (sync) {
      PicksSync.syncing => ('Saving your picks', 'One moment.'),
      PicksSync.conflict => (
        'Welcome back',
        'Your account already has a Drip. Update it with what you just '
            'picked? Only what you changed is replaced.',
      ),
      PicksSync.failed => (
        'Ticket issued',
        'Your picks are on this phone and sync when you’re back online.',
      ),
      _ => (
        'Ticket issued',
        'Your picks are saved. Change them any time in '
            'Settings.',
      ),
    };
    final bottom = math.max(MediaQuery.paddingOf(context).bottom, 8.0);

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.base,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // The same glow the onboarding ends on, in the user's colour.
            Positioned(
              top: -160,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Center(
                  child: Container(
                    width: 520,
                    height: 520,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          glow.withValues(alpha: 0.28),
                          glow.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(24, 20, 24, bottom + 16),
                // One composition on big screens, not a phone layout
                // stretched across a tablet.
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Semantics(
                          liveRegion: true,
                          child: Eyebrow(
                            eyebrow,
                            color: saving ? AppColors.red : AppColors.cyan,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Semantics(
                          header: true,
                          child: Text(
                            returning
                                ? 'YOU ALREADY\nHAVE A DRIP.'
                                : 'YOUR DRIP\nIS READY.',
                            style: AppText.display(34, lineHeight: 40),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // The ticket, issued: as large as the screen allows,
                        // never cropped.
                        Expanded(
                          child: Enter(
                            dy: 18,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: SizedBox(
                                width: math.min(
                                  420,
                                  math.min(
                                    520.0,
                                    MediaQuery.sizeOf(context).width - 48,
                                  ),
                                ),
                                child: DripTicket(info: info),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          note,
                          style: AppText.manrope(
                            14,
                            color: AppColors.muted,
                            lineHeight: 20,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (returning) ...[
                          AppButton(
                            label: 'UPDATE MY DRIP',
                            loading: _resolving,
                            onPressed: () => _resolve(update: true),
                          ),
                          const SizedBox(height: 12),
                          AppButton(
                            label: 'KEEP MY SAVED DRIP',
                            style: AppButtonStyle.outline,
                            onPressed: _resolving
                                ? null
                                : () => _resolve(update: false),
                          ),
                        ] else
                          AppButton(
                            label: 'EXPLORE DRIP →',
                            loading: saving,
                            onPressed: () => _home(),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
