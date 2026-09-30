import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/assets.dart';
import '../../core/motion.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/drip_image.dart';
import '../../core/widgets/overlays.dart';
import '../../core/widgets/tap.dart';
import '../session/session_controller.dart';

/// Sign in (or sign up: the first sign-in creates the account). Google only
/// for the beta; phone OTP and Apple slot in as more buttons later.
///
/// Google opens in the browser and comes back through the
/// `com.drip.drip://login-callback` deep link; the router then moves on by
/// itself as soon as the session exists.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  bool _waiting = false;
  late final AppLifecycleListener _lifecycle;
  Timer? _resumeTimer;

  @override
  void initState() {
    super.initState();
    // Back from the browser without a session (closed, or cancelled): give
    // the deep link a moment to land, then let the user try again.
    _lifecycle = AppLifecycleListener(
      onResume: () {
        if (!_waiting) return;
        _resumeTimer?.cancel();
        _resumeTimer = Timer(const Duration(seconds: 3), () {
          if (mounted && !ref.read(sessionProvider).signedIn) {
            setState(() => _waiting = false);
          }
        });
      },
    );
  }

  @override
  void dispose() {
    _resumeTimer?.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _google() async {
    Haptics.commit();
    setState(() => _waiting = true);
    try {
      await ref.read(sessionProvider.notifier).signInWithGoogle();
    } catch (e) {
      if (!mounted) return;
      setState(() => _waiting = false);
      showDripToast(context, "Couldn't open Google sign-in. Try again.");
    }
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/welcome');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = math.max(MediaQuery.paddingOf(context).bottom, 8.0);
    return Scaffold(
      backgroundColor: AppColors.base,
      body: Stack(
        fit: StackFit.expand,
        children: [
          DripImage(Assets.image('welcome_bg')),
          const ColoredBox(color: Color(0xE60E1018)),
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Tap(
                    onTap: _back,
                    semanticLabel: 'Back',
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 18,
                        color: AppColors.cream,
                      ),
                    ),
                  ),
                ),
                const Spacer(flex: 3),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SIGN IN · SIGN UP',
                        style: AppText.mono(
                          10,
                          color: AppColors.red,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'ONE TAP AND YOU’RE IN.',
                        style: AppText.display(36, lineHeight: 42),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Drip uses your Google account. No passwords to '
                        'remember. New here? Signing in creates your account.',
                        style: AppText.manrope(
                          15,
                          color: AppColors.muted,
                          lineHeight: 23,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(flex: 2),
                Padding(
                  padding: EdgeInsets.fromLTRB(24, 16, 24, bottom + 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedSwitcher(
                        duration: Motion.quick,
                        child: _waiting
                            ? const _WaitingNote(key: ValueKey('wait'))
                            : const SizedBox(key: ValueKey('idle'), height: 0),
                      ),
                      AppButton(
                        label: 'CONTINUE WITH GOOGLE',
                        loading: _waiting,
                        onPressed: _google,
                      ),
                      const SizedBox(height: 14),
                      AppButton(
                        label: 'CONTINUE WITH PHONE',
                        style: AppButtonStyle.outline,
                        onPressed: () =>
                            showAfterBeta(context, 'Phone sign-in'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WaitingNote extends StatelessWidget {
  const _WaitingNote({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        'FINISH SIGNING IN WITH GOOGLE, THEN COME BACK HERE',
        textAlign: TextAlign.center,
        style: AppText.mono(10, color: AppColors.muted, letterSpacing: 1),
      ),
    );
  }
}
