import 'theme_bar.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/drip_skin.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/controls.dart';
import '../../core/widgets/drip_image.dart';
import '../../core/widgets/overlays.dart';
import '../../core/widgets/tap.dart';
import '../../core/widgets/top_bar.dart';
import '../../data/api/api_client.dart';
import '../../data/models/settings.dart';
import '../../routing/main_shell.dart';
import '../session/reset_app_state.dart';
import '../session/session_controller.dart';
import '../social/social_controller.dart';
import '../onboarding/onboarding_data.dart';
import 'settings_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  /// Deleting the account is permanent (the backend removes every row and
  /// private file), so it asks twice in plain words.
  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    final ok = await showDripConfirm(
      context,
      title: 'DELETE YOUR ACCOUNT?',
      message:
          'This permanently deletes your Drip account: your wardrobe photos, '
          'saved and liked fits, studio fits and Gen renders. It can\'t be '
          'undone.',
      confirmLabel: 'DELETE FOREVER',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    try {
      await ref.read(sessionProvider.notifier).deleteAccount();
    } on ApiException catch (e) {
      if (context.mounted) showDripToast(context, e.friendly);
      return;
    }
    resetAppState(ref);
    if (context.mounted) {
      showDripToast(context, 'Your account has been deleted');
      context.go('/welcome');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final me = ref.watch(myProfileProvider).value;
    final email = ref.watch(sessionProvider.select((s) => s.user?.email));
    final picks = ref.watch(onboardingProvider);

    Widget row(
      String label, {
      String? value,
      Widget? trailing,
      VoidCallback? onTap,
      bool last = false,
    }) => SettingsRow(
      label: label,
      value: value,
      trailing: trailing,
      onTap: onTap,
      last: last,
    );

    return ShellPage(
      child: Column(
        children: [
          DripTopBar(
            title: 'SETTINGS',
            height: 56,
            leading: BackGlyph(
              onTap: () => context.canPop() ? context.pop() : context.go('/me'),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                const _Section('01 · ACCOUNT'),
                SettingsGroup(
                  children: [
                    Tap(
                      onTap: () => context.go('/me'),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: AppColors.cream.withValues(alpha: 0.12),
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.cyan,
                                  width: 1.5,
                                ),
                              ),
                              child: ClipOval(
                                child: me == null || me.avatar.isEmpty
                                    ? ColoredBox(color: AppColors.elevated)
                                    : DripImage(me.avatar),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    me?.name ?? '',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppText.display(14),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'DRIP BETA MEMBER',
                                    style: AppText.mono(
                                      11,
                                      color: AppColors.cyan,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    row(
                      'Username',
                      value: me == null ? '' : '@${me.handle}',
                      onTap: () => showAfterBeta(context, 'Custom usernames'),
                    ),
                    row(
                      'Email',
                      value: email ?? '',
                      onTap: () => showDripToast(
                        context,
                        'Your email comes from your Google account',
                      ),
                    ),
                    row('Signed in with', value: 'Google', last: true),
                  ],
                ),
                const _Section('02 · YOUR STYLE'),
                SettingsGroup(
                  children: [
                    row(
                      'Style, colours & more',
                      value: _styleSummary(picks),
                      last: true,
                      onTap: () => context.push('/me/style'),
                    ),
                  ],
                ),
                const _Section('03 · PRIVACY'),
                SettingsGroup(
                  children: [
                    row(
                      'Private Account',
                      trailing: DripSwitch(
                        value: s.privateAccount,
                        onChanged: (_) =>
                            showAfterBeta(context, 'Private accounts'),
                      ),
                    ),
                    row(
                      'Who Can Interact',
                      value: s.whoCanInteract.label,
                      onTap: () =>
                          showAfterBeta(context, 'Interaction controls'),
                    ),
                    row(
                      'OOTD Visibility',
                      value: s.ootdVisibility.label,
                      last: true,
                      onTap: () => showAfterBeta(context, 'OOTD visibility'),
                    ),
                  ],
                ),
                const _Section('04 · APPEARANCE'),
                SettingsGroup(
                  children: [
                    row(
                      'Themes',
                      value: s.skin.label,
                      onTap: () => context.push('/themes'),
                    ),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(12, 4, 12, 12),
                      child: ThemeBar(),
                    ),
                    row(
                      'Match App Icon to Theme',
                      trailing: DripSwitch(
                        value: s.matchAppIcon,
                        onChanged: notifier.setMatchAppIcon,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Text(
                        'Your home-screen icon updates the next time you leave the app.',
                        style: AppText.manrope(11, color: AppColors.muted),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'SKIN COLOR DNA',
                            style: AppText.mono(11, color: AppColors.muted),
                          ),
                          _Swatches(skin: s.skin, size: 16),
                        ],
                      ),
                    ),
                  ],
                ),
                const _Section('05 · NOTIFICATIONS & DEV'),
                SettingsGroup(
                  children: [
                    row(
                      'Push Notifications',
                      trailing: DripSwitch(
                        value: s.pushNotifications,
                        onChanged: notifier.setPush,
                      ),
                    ),
                    row(
                      'Style Match Alerts',
                      trailing: DripSwitch(
                        value: s.styleMatchAlerts,
                        onChanged: notifier.setStyleAlerts,
                      ),
                    ),
                    row(
                      'Connected Accounts',
                      value: 'After beta',
                      last: true,
                      onTap: () => showAfterBeta(context, 'Connected accounts'),
                    ),
                  ],
                ),
                const _Section('06 · INFO'),
                SettingsGroup(
                  children: [
                    row(
                      'About DRIP',
                      value: 'v1.0.77',
                      onTap: () {
                        showDripSheet<void>(
                          context,
                          builder: (_) => SheetContent(
                            title: 'ABOUT DRIP',
                            subtitle: 'v1.0.77 · ESTD 2077',
                            children: [
                              Text(
                                'Drip is the outfit-of-the-day network: scroll editorial looks, save them to your vault, build fits in the Studio and let Taylor style you for any occasion.',
                                style: AppText.manrope(
                                  13,
                                  color: AppColors.muted,
                                  lineHeight: 19,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    row(
                      'Privacy & Terms',
                      last: true,
                      onTap: () {
                        showDripSheet<void>(
                          context,
                          builder: (_) => SheetContent(
                            title: 'PRIVACY & TERMS',
                            children: [
                              Text(
                                'Your saved fits, wardrobe photos, studio fits and Gen renders live on your Drip account. Wardrobe photos, selfies and renders are private to you. You can delete your account, and everything in it, at any time from this screen.',
                                style: AppText.manrope(
                                  13,
                                  color: AppColors.muted,
                                  lineHeight: 19,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                  child: AppButton(
                    label: 'LOG OUT OF DRIP',
                    style: AppButtonStyle.danger,
                    height: 52,
                    onPressed: () async {
                      final ok = await showDripConfirm(
                        context,
                        title: 'LOG OUT?',
                        message: 'You\'ll need to sign in again to see your feed and wardrobe.',
                        confirmLabel: 'LOG OUT',
                        destructive: true,
                      );
                      if (!ok) return;
                      await ref.read(sessionProvider.notifier).logout();
                      resetAppState(ref);
                      if (context.mounted) context.go('/welcome');
                    },
                  ),
                ),
                Center(
                  child: Tap(
                    onTap: () => _deleteAccount(context, ref),
                    semanticLabel: 'Delete your account',
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        'DELETE ACCOUNT',
                        style: AppText.mono(
                          10,
                          color: AppColors.red,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
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

/// "Y2K, Streetwear +1": what the user's style is, at a glance.
String _styleSummary(OnboardingState picks) {
  final eras = [
    for (final e in OnboardingData.eras)
      if (picks.moodIds.contains(e.id)) e.label,
  ];
  if (eras.isEmpty) return 'Not set';
  return eras.length <= 2
      ? eras.join(', ')
      : '${eras.take(2).join(', ')} +${eras.length - 2}';
}

class _Section extends StatelessWidget {
  const _Section(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
    child: SectionLabel(text),
  );
}

/// A rounded group of [SettingsRow]s (also used by the Your style screen).
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 2),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20 * context.palette.roundness),
        border: Border.all(color: AppColors.cream.withValues(alpha: 0.08)),
      ),
      child: Column(children: children),
    );
  }
}

/// One settings line: label, optional value, chevron when it opens something.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.label,
    this.value,
    this.trailing,
    this.onTap,
    this.last = false,
  });
  final String label;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Tap(
      onTap: onTap,
      scale: 1,
      child: Container(
        margin: const EdgeInsets.only(left: 16),
        padding: const EdgeInsets.fromLTRB(0, 12, 14, 12),
        constraints: const BoxConstraints(minHeight: 52),
        decoration: BoxDecoration(
          border: last
              ? null
              : Border(
                  bottom: BorderSide(
                    color: AppColors.cream.withValues(alpha: 0.07),
                  ),
                ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: AppText.manrope(14, weight: FontWeight.w500),
              ),
            ),
            if (value != null) ...[
              Flexible(
                child: Text(
                  value!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.mono(12, color: AppColors.muted),
                ),
              ),
            ],
            if (trailing != null)
              trailing!
            else if (onTap != null) ...[
              const SizedBox(width: 6),
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppColors.dim,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Swatches extends StatelessWidget {
  const _Swatches({required this.skin, required this.size});
  final DripSkin skin;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = [
      AppColors.base,
      AppColors.surface,
      skin.accent,
      skin.secondary,
      AppColors.cream,
    ];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (i, c) in colors.indexed)
          Container(
            width: size,
            height: size,
            margin: EdgeInsets.only(left: i == 0 ? 0 : 6),
            decoration: BoxDecoration(
              color: c,
              shape: BoxShape.circle,
              border: i == 0 ? Border.all(color: AppColors.elevated) : null,
            ),
          ),
      ],
    );
  }
}
