import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/pills.dart';
import '../../core/widgets/states.dart';
import '../../core/widgets/tap.dart';
import '../../core/widgets/top_bar.dart';
import '../../core/utils/format.dart';
import '../../data/repositories/outfit_repository.dart';
import '../../routing/main_shell.dart';
import '../outfits/outfit_card.dart';
import '../social/creator_tile.dart';
import 'product_sheet.dart';
import 'search_controller.dart';

class SearchResultsScreen extends ConsumerStatefulWidget {
  const SearchResultsScreen({super.key, required this.query});
  final String query;

  @override
  ConsumerState<SearchResultsScreen> createState() =>
      _SearchResultsScreenState();
}

class _SearchResultsScreenState extends ConsumerState<SearchResultsScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(searchResultsProvider(widget.query));
    final pieces = ref.watch(productSearchProvider(widget.query)).value;

    return ShellPage(
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.elevated)),
            ),
            child: DripTopBar(
              title: 'SEARCH RESULTS',
              height: 50,
              leading: const BackGlyph(),
              trailing: GlyphButton(
                '+',
                mono: true,
                onTap: () => showImportLinkSheet(context, ref),
                label: 'Add a piece by link',
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Tap(
              onTap: () => context.pop(),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.elevated),
                ),
                child: Row(
                  children: [
                    Text(
                      '⌕',
                      style: AppText.mono(
                        16,
                        color: AppColors.cyan,
                        weight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '"${widget.query}"',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.manrope(13),
                      ),
                    ),
                    Text(
                      '${(results.value?.total ?? 0) + (pieces?.products.length ?? 0)} RESULTS',
                      style: AppText.mono(11, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: results.whenDrip(
              onRetry: () =>
                  ref.invalidate(searchResultsProvider(widget.query)),
              data: (r) => _Body(
                query: widget.query,
                results: r,
                pieceCount: pieces?.products.length,
                tab: _tab,
                onTab: (i) => setState(() => _tab = i),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.query,
    required this.results,
    required this.pieceCount,
    required this.tab,
    required this.onTab,
  });
  final String query;
  final SearchResults results;
  final int? pieceCount;
  final int tab;
  final ValueChanged<int> onTab;

  @override
  Widget build(BuildContext context) {
    final r = results;
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterPill(
                label: pieceCount == null ? 'PIECES' : 'PIECES ($pieceCount)',
                selected: tab == 0,
                onTap: () => onTab(0),
              ),
              FilterPill(
                label: 'FITS (${r.fits.length})',
                selected: tab == 1,
                onTap: () => onTab(1),
              ),
              FilterPill(
                label: 'CREATORS (${r.creatorHandles.length})',
                selected: tab == 2,
                onTap: () => onTab(2),
              ),
              FilterPill(
                label: 'COLLECTIONS',
                selected: tab == 3,
                onTap: () => onTab(3),
              ),
            ],
          ),
        ),
        if (tab == 0) _PiecesTab(query: query),
        if (tab == 1) ...[
          if (r.fits.isEmpty)
            const EmptyState(
              title: 'NO FITS FOUND',
              message:
                  'Nothing matches that search. Try another vibe or creator.',
            )
          else
            OutfitMasonry(
              outfits: r.fits,
              style: OutfitCardStyle.plate,
              gap: 12,
              tall: 220,
              short: 190,
            ),
          if (r.creatorHandles.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SectionLabel(
                'FEATURED CREATOR FOR THIS VIBE',
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: CreatorTile(handle: r.creatorHandles.first),
            ),
          ],
        ],
        if (tab == 2)
          if (r.creatorHandles.isEmpty)
            const EmptyState(
              title: 'NO CREATORS FOUND',
              message: 'No creators match this search yet.',
            )
          else
            for (final h in r.creatorHandles)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: CreatorTile(handle: h),
              ),
        if (tab == 3)
          if (r.collections.isEmpty)
            const EmptyState(
              title: 'NO COLLECTIONS',
              message: 'No curated collections match this search.',
            )
          else
            for (final c in r.collections)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: AppColors.cream.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.title, style: AppText.display(13)),
                            const SizedBox(height: 4),
                            Text(
                              '${c.count} FITS · #${c.tag}',
                              style: AppText.mono(9, color: AppColors.cyan),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ],
    );
  }
}

/// Pieces from across stores for this search, within the user's budget.
/// What's ready shows at once; pieces Drip is still cutting out show the
/// store's photo with a shimmer and swap to the cut-out when done.
class _PiecesTab extends ConsumerWidget {
  const _PiecesTab({required this.query});
  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final search = ref.watch(productSearchProvider(query));
    return search.when(
      loading: () => const Padding(
        padding: EdgeInsets.only(top: 40),
        child: LoadingState(compact: true, label: 'FINDING PIECES...'),
      ),
      error: (e, _) => ErrorState.from(
        e,
        onRetry: () => ref.invalidate(productSearchProvider(query)),
      ),
      data: (s) {
        if (s.products.isEmpty) {
          return EmptyState(
            title: s.pending ? 'LOOKING ACROSS STORES' : 'NO PIECES FOUND',
            message: s.pending
                ? 'Drip is finding and cutting out pieces for this. They land here in a moment.'
                : s.maxPrice != null
                ? 'Nothing within your budget yet. Try other words, or paste a product link with +.'
                : 'Try other words, or paste a product link with +.',
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (s.pending || s.maxPrice != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Text(
                  [
                    if (s.maxPrice != null)
                      'UNDER ${formatPrice(s.maxPrice!)} A PIECE',
                    if (s.pending) 'MORE ON THE WAY…',
                  ].join(' · '),
                  style: AppText.mono(
                    9,
                    color: AppColors.muted,
                    letterSpacing: 1,
                  ),
                ),
              ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 12,
                childAspectRatio: 0.62,
              ),
              itemCount: s.products.length,
              itemBuilder: (context, i) => ProductCard(
                key: ValueKey(s.products[i].id),
                product: s.products[i],
                onTap: () => showProductSheet(context, ref, s.products[i]),
              ),
            ),
          ],
        );
      },
    );
  }
}
