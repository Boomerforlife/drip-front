import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/format.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/drip_image.dart';
import '../../core/widgets/pills.dart';
import '../../core/widgets/states.dart';
import '../../core/widgets/tap.dart';
import '../../core/widgets/top_bar.dart';
import '../../routing/main_shell.dart';
import '../../data/repositories/outfit_repository.dart';
import '../outfits/outfit_controller.dart';
import '../social/creator_tile.dart';
import 'search_controller.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  int _tab = 0;

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  String get _query => _controller.text.trim();

  Future<void> _submit([String? value]) async {
    final q = (value ?? _controller.text).trim();
    if (q.isEmpty) return;
    _controller.text = q;
    await ref.read(recentSearchesProvider.notifier).add(q);
    if (mounted) {
      context.push('/search/results?q=${Uri.encodeQueryComponent(q)}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = context.palette.accent;
    final query = _query;
    final results = query.isEmpty
        ? null
        : ref.watch(searchResultsProvider(query));
    final catalogCount = ref.watch(outfitCatalogProvider).value?.length ?? 0;

    final fitsCount = results?.value?.fits.length ?? catalogCount;
    final peopleCount = results?.value?.creatorHandles.length;
    final vibesCount = results?.value?.vibes.length;

    String label(String base, int? n) => n == null ? base : '$base ($n)';

    return ShellPage(
      child: Column(
        children: [
          DripTopBar(
            title: 'FIND DRIP',
            card: true,
            height: 50,
            leading: const BackGlyph(),
            trailing: GlyphButton(
              '✦',
              mono: true,
              onTap: () => context.push('/stylist'),
              label: 'Ask Taylor',
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: accent),
              ),
              child: Row(
                children: [
                  Text('⌕', style: AppText.inter(14, color: accent)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focus,
                      autofocus: true,
                      textInputAction: TextInputAction.search,
                      onChanged: (_) => setState(() {}),
                      onSubmitted: _submit,
                      cursorColor: accent,
                      style: AppText.manrope(13),
                      decoration: InputDecoration(
                        isCollapsed: true,
                        border: InputBorder.none,
                        hintText: 'Search fits, vibes, eras...',
                        hintStyle: AppText.manrope(13, color: AppColors.muted),
                      ),
                    ),
                  ),
                  if (query.isNotEmpty)
                    Tap(
                      onTap: () => setState(_controller.clear),
                      semanticLabel: 'Clear search',
                      child: Text(
                        '✕',
                        style: AppText.inter(14, color: AppColors.muted),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                children: [
                  FilterPill(
                    label: label('FITS', fitsCount),
                    selected: _tab == 0,
                    onTap: () => setState(() => _tab = 0),
                  ),
                  FilterPill(
                    label: label('PEOPLE', peopleCount),
                    selected: _tab == 1,
                    onTap: () => setState(() => _tab = 1),
                  ),
                  FilterPill(
                    label: label('VIBES', vibesCount),
                    selected: _tab == 2,
                    onTap: () => setState(() => _tab = 2),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                if (results == null) ...[
                  _RecentSearches(onPick: _submit),
                  const SizedBox(height: 8),
                  _TrendingVibes(onPick: _submit),
                ] else
                  results.when(
                    data: (r) =>
                        _LiveResults(results: r, tab: _tab, onVibe: _submit),
                    loading: () => const Padding(
                      padding: EdgeInsets.only(top: 48),
                      child: LoadingState(compact: true),
                    ),
                    error: (_, _) => ErrorState(
                      onRetry: () =>
                          ref.invalidate(searchResultsProvider(query)),
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

class _RecentSearches extends ConsumerWidget {
  const _RecentSearches({required this.onPick});
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recents = ref.watch(recentSearchesProvider);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.all(Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SectionLabel('RECENT SEARCHES'),
              if (recents.isNotEmpty)
                Tap(
                  onTap: () =>
                      ref.read(recentSearchesProvider.notifier).clear(),
                  child: Text(
                    'CLEAR',
                    style: AppText.mono(9, color: AppColors.cyan),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (recents.isEmpty)
            Text(
              'Nothing here yet. Your searches will show up here.',
              style: AppText.manrope(12, color: AppColors.muted),
            )
          else
            for (final r in recents)
              Container(
                padding: const EdgeInsets.only(bottom: 8),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  border: r == recents.last
                      ? null
                      : Border(bottom: BorderSide(color: AppColors.elevated)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Tap(
                        onTap: () => onPick(r),
                        child: Row(
                          children: [
                            Text(
                              '⏱',
                              style: AppText.inter(12, color: AppColors.muted),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                r,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.manrope(13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Tap(
                      onTap: () =>
                          ref.read(recentSearchesProvider.notifier).remove(r),
                      semanticLabel: 'Remove $r',
                      child: Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: Text(
                          '✕',
                          style: AppText.inter(12, color: AppColors.muted),
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

class _TrendingVibes extends ConsumerWidget {
  const _TrendingVibes({required this.onPick});
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vibes = ref.watch(trendingVibesProvider).value ?? const <String>[];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.all(Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('TRENDING VIBES'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final v in vibes)
                Tap(
                  onTap: () => onPick(v),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.elevated,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '✦ $v',
                      style: AppText.mono(9, color: AppColors.cyan),
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

class _LiveResults extends ConsumerWidget {
  const _LiveResults({
    required this.results,
    required this.tab,
    required this.onVibe,
  });
  final SearchResults results;
  final int tab;
  final ValueChanged<String> onVibe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fits = results.fits;
    final people = results.creatorHandles;
    final vibes = results.vibes;

    Widget empty(String what) => Padding(
      padding: const EdgeInsets.only(top: 32),
      child: EmptyState(
        title: 'NO $what FOUND',
        message:
            'Try a different word — or hit search to see everything close.',
      ),
    );

    switch (tab) {
      case 0:
        if (fits.isEmpty) return empty('FITS');
        return Column(
          children: [
            for (final o in fits.take(8))
              Tap(
                onTap: () => context.push('/outfit/${o.id}'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: 48,
                          height: 56,
                          child: DripImage(o.image),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(o.title, style: AppText.mono(11)),
                            const SizedBox(height: 2),
                            Text(
                              '${formatPrice(o.price)} · @${o.creatorHandle}',
                              style: AppText.mono(9, color: AppColors.cyan),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${o.rate}',
                        style: AppText.display(
                          14,
                          color: context.palette.accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      case 1:
        if (people.isEmpty) return empty('PEOPLE');
        return Column(
          children: [
            for (final h in people)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: CreatorTile(handle: h),
              ),
          ],
        );
      default:
        if (vibes.isEmpty) return empty('VIBES');
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final v in vibes)
              Tap(
                onTap: () => onVibe(v),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.elevated,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '✦ $v',
                    style: AppText.mono(9, color: AppColors.cyan),
                  ),
                ),
              ),
          ],
        );
    }
  }
}
