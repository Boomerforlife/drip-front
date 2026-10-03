import '../settings/theme_bar.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/overlays.dart';
import '../../core/widgets/states.dart';
import '../../core/widgets/tap.dart';
import '../../core/widgets/top_bar.dart';
import '../../data/models/outfit.dart';
import '../../data/models/user.dart';
import '../../routing/main_shell.dart';
import '../outfits/outfit_controller.dart';
import '../photoshoot/photoshoot_controller.dart';
import '../social/social_controller.dart';
import 'profile_widgets.dart';

class MyProfileScreen extends ConsumerStatefulWidget {
  const MyProfileScreen({super.key});

  @override
  ConsumerState<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends ConsumerState<MyProfileScreen> {
  int _tab = 0;

  Future<void> _menu() async {
    await showDripSheet<void>(
      context,
      builder: (ctx) {
        Widget row(
          String glyph,
          String label,
          String? route, {
          String? badge,
        }) => Tap(
              onTap: () {
                Navigator.of(ctx).pop();
                if (route == null) {
                  showAfterBeta(context, label);
                } else if (route == '/studio') {
                  context.go(route); // a tab now
                } else {
                  context.push(route);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.elevated)),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 28,
                      child: Text(glyph, style: AppText.inter(16)),
                    ),
                    Expanded(
                      child: Text(
                        label,
                        style: AppText.manrope(14, weight: FontWeight.w500),
                      ),
                    ),
                    if (badge != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          badge,
                          style: AppText.mono(9, color: AppColors.base),
                        ),
                      ),
                  ],
                ),
              ),
            );
        return SheetContent(
          title: 'MENU',
          children: [
            row('🔔', 'Notifications', null, badge: 'AFTER BETA'),
            row('📁', 'Saved looks', '/saved'),
            row('🛠', 'Drip Studio', '/studio'),
            row('✦', 'Followers', null),
            row('✦', 'Following', null),
            row('🎨', 'Colour theory', '/me/colour-theory'),
            row('⚙', 'Settings', '/settings'),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(myProfileProvider);
    return ShellPage(
      child: Column(
        children: [
          DripTopBar(
            title: 'PORTFOLIO',
            leading: GlyphButton('☰', onTap: _menu, label: 'Menu'),
            trailing: GlyphButton(
              '⚙',
              onTap: () => context.push('/settings'),
              label: 'Settings',
            ),
          ),
          Expanded(
            child: profile.whenDrip(
              onRetry: () => ref.invalidate(myProfileProvider),
              data: (me) => _Body(
                user: me,
                tab: _tab,
                onTab: (i) => setState(() => _tab = i),
                onEdit: () => showAfterBeta(context, 'Editing your profile'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({
    required this.user,
    required this.tab,
    required this.onTab,
    required this.onEdit,
  });
  final DripUser user;
  final int tab;
  final ValueChanged<int> onTab;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fits = ref.watch(savedOutfitsProvider).value ?? const <Outfit>[];
    final photos = ref.watch(photosProvider);

    final tiles = switch (tab) {
      0 => [for (final o in fits) PhotoTile(o.image, '/outfit/${o.id}')],
      1 => const <PhotoTile>[],
      _ => [for (final p in photos) PhotoTile(p)],
    };
    final emptyCopy = switch (tab) {
      0 => ('NO FITS YET', 'Save fits from the Scroll and they land here.'),
      1 => ('OOTDS AFTER BETA', 'Posting your outfit of the day is coming after beta.'),
      _ => (
        'NO PHOTOS YET',
        'Generate a shoot in the Studio to fill this tab.',
      ),
    };

    return ListView(
      padding: EdgeInsets.only(
        bottom: MediaQuery.paddingOf(context).bottom + 24,
      ),
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              ProfileIntro(
                user: user,
                ringColor: context.palette.secondary,
                onEdit: onEdit,
              ),
              const SizedBox(height: 12),
              ProfileStats(
                user: user,
                onFollowers: () => showAfterBeta(context, 'Followers'),
                onFollowing: () => showAfterBeta(context, 'Following'),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: ThemeBar(),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(child: SectionLabel('YOUR STYLE DNA')),
                  // The picks behind the DNA and palette, editable.
                  Tap(
                    onTap: () => context.push('/me/style'),
                    semanticLabel: 'Edit your style',
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 12,
                      ),
                      child: Text(
                        'EDIT',
                        style: AppText.mono(
                          11,
                          color: AppColors.cyan,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              DnaChips(tags: user.styleDna),
              const SizedBox(height: 12),
              Tap(
                onTap: () => context.push('/me/colour-theory'),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Text(
                        'MY PALETTE',
                        style: AppText.mono(9, color: AppColors.muted),
                      ),
                      const SizedBox(width: 12),
                      for (final c in user.palette) ...[
                        Container(
                          width: 20,
                          height: 20,
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: c == AppColors.base
                                ? Border.all(color: AppColors.elevated)
                                : null,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        ProfileTabs(
          labels: const ['FITS', 'OOTD', 'PHOTOS'],
          index: tab,
          onChanged: onTab,
        ),
        if (tiles.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: EmptyState(title: emptyCopy.$1, message: emptyCopy.$2),
          )
        else
          PhotoGrid(tiles: tiles),
      ],
    );
  }
}
