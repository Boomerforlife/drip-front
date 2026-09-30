import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/overlays.dart';
import '../../core/widgets/states.dart';
import '../../core/widgets/tap.dart';
import '../../core/widgets/top_bar.dart';
import '../../data/api/api_client.dart';
import '../../data/providers.dart';
import '../../data/repositories/colour_repository.dart';
import '../../routing/main_shell.dart';

/// The 12-season palettes (`GET /colour/seasons`), kept for the session.
final colourSeasonsProvider = FutureProvider<List<ColourSeason>>((ref) {
  ref.keepAlive();
  return ref.watch(colourRepositoryProvider).seasons();
});

/// The season the user picked as theirs, stored in their onboarding prefs.
final mySeasonIdProvider = Provider<String?>((ref) {
  final prefs = ref.watch(accountProvider).value?.onboardingPrefs;
  final id = prefs?['colourSeason'];
  return id is String ? id : null;
});

/// Colour Theory: the seasonal palette system. Pick the season that suits
/// you and it's saved to your account (there's no automatic analysis yet).
class ColourTheoryProfileScreen extends ConsumerWidget {
  const ColourTheoryProfileScreen({super.key});

  static const _order = ['winter', 'spring', 'summer', 'autumn'];

  Future<void> _choose(
    BuildContext context,
    WidgetRef ref,
    ColourSeason season,
  ) async {
    try {
      final account = await ref.read(accountProvider.future);
      await ref
          .read(accountRepositoryProvider)
          .updateProfile(
            // PATCH replaces the whole object, so keep the other picks.
            onboardingPrefs: {
              ...account.onboardingPrefs,
              'colourSeason': season.id,
            },
          );
      ref.invalidate(accountProvider);
      if (context.mounted) {
        showDripToast(context, '${season.name} is your season');
      }
    } on ApiException catch (e) {
      if (context.mounted) showDripToast(context, e.friendly);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seasons = ref.watch(colourSeasonsProvider);
    final mine = ref.watch(mySeasonIdProvider);

    return ShellPage(
      child: Column(
        children: [
          DripTopBar(
            title: 'COLOUR THEORY',
            leading: const BackGlyph(),
            trailing: GlyphButton(
              '🎨',
              label: 'Palette analysis',
              onTap: () => showAfterBeta(context, 'Automatic colour analysis'),
            ),
          ),
          Expanded(
            child: seasons.whenDrip(
              onRetry: () => ref.invalidate(colourSeasonsProvider),
              data: (list) {
                final current = list.where((s) => s.id == mine).firstOrNull;
                final groups = <String, List<ColourSeason>>{};
                for (final s in list) {
                  groups.putIfAbsent(s.parentSeason, () => []).add(s);
                }
                final parents = [
                  ..._order.where(groups.containsKey),
                  ...groups.keys.where((k) => !_order.contains(k)),
                ];
                return ListView(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    8,
                    16,
                    24 + MediaQuery.paddingOf(context).bottom,
                  ),
                  children: [
                    if (current != null)
                      _MySeason(season: current)
                    else
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Every complexion has a season: the palette that '
                          'makes it glow. Tap the one that sounds like you.',
                          style: AppText.manrope(
                            13,
                            color: AppColors.muted,
                            lineHeight: 19,
                          ),
                        ),
                      ),
                    for (final parent in parents) ...[
                      const SizedBox(height: 20),
                      SectionLabel(parent.toUpperCase()),
                      const SizedBox(height: 10),
                      for (final s in groups[parent]!) ...[
                        _SeasonCard(
                          season: s,
                          selected: s.id == mine,
                          onTap: () => _choose(context, ref, s),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ],
                    const SizedBox(height: 16),
                    AppButton(
                      label: 'BUILD WITH MY PALETTE ✦',
                      height: 44,
                      onPressed: () => context.push('/studio'),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MySeason extends StatelessWidget {
  const _MySeason({required this.season});
  final ColourSeason season;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: season.accent),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'YOUR SEASON',
            style: AppText.mono(10, color: AppColors.muted, letterSpacing: 1.4),
          ),
          const SizedBox(height: 8),
          Text(season.name.toUpperCase(), style: AppText.display(22)),
          const SizedBox(height: 4),
          Text(
            season.tagline,
            style: AppText.mono(10, color: AppColors.cyan),
          ),
          const SizedBox(height: 10),
          Text(
            season.description,
            style: AppText.manrope(13, color: AppColors.muted, lineHeight: 19),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (final c in season.palette)
                Expanded(
                  child: Container(
                    height: 34,
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      color: c,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.elevated),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SeasonCard extends StatelessWidget {
  const _SeasonCard({
    required this.season,
    required this.selected,
    required this.onTap,
  });
  final ColourSeason season;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tap(
      onTap: onTap,
      semanticLabel: '${season.name}${selected ? ', your season' : ''}',
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? season.accent : AppColors.elevated,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    season.name,
                    style: AppText.manrope(14, weight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    season.tagline,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.mono(9, color: AppColors.muted),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (final c in season.palette.take(8))
                        Container(
                          width: 16,
                          height: 16,
                          margin: const EdgeInsets.only(right: 4),
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.elevated),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (selected)
              Text('✓', style: AppText.mono(16, color: season.accent)),
          ],
        ),
      ),
    );
  }
}
