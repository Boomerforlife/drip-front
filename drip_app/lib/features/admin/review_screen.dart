import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/drip_image.dart';
import '../../core/widgets/overlays.dart';
import '../../core/widgets/states.dart';
import '../../core/widgets/top_bar.dart';
import '../../data/api/api_client.dart';
import '../../data/models/product.dart';
import '../../data/providers.dart';
import '../../routing/main_shell.dart';

/// Pieces discovered automatically that Drip wasn't sure enough about to
/// publish on its own (low confidence, or tagging failed). An admin checks
/// the cut-out and what Drip read, fixes it if needed, then approves
/// (publishes through the usual gate) or rejects (kept out for good).
final reviewQueueProvider = FutureProvider.autoDispose<List<DripProduct>>(
  (ref) => ref.watch(discoveryRepositoryProvider).reviewQueue(),
);

class ReviewScreen extends ConsumerWidget {
  const ReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(reviewQueueProvider);
    return ShellPage(
      child: Column(
        children: [
          const DripTopBar(title: 'REVIEW IMPORTS', leading: BackGlyph()),
          Expanded(
            child: queue.whenDrip(
              onRetry: () => ref.invalidate(reviewQueueProvider),
              data: (items) => items.isEmpty
                  ? const EmptyState(
                      title: 'ALL CLEAR',
                      message: 'Nothing is waiting for review.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 14),
                      itemBuilder: (_, i) => _ReviewCard(product: items[i]),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewCard extends ConsumerStatefulWidget {
  const _ReviewCard({required this.product});
  final DripProduct product;

  @override
  ConsumerState<_ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends ConsumerState<_ReviewCard> {
  static const _slots = [
    'top',
    'bottom',
    'outer',
    'dress',
    'shoes',
    'accessory',
  ];
  late String? _category = widget.product.category;
  late final _subcategory = TextEditingController(
    text: widget.product.subcategory ?? '',
  );
  late final _fit = TextEditingController(text: widget.product.fit ?? '');
  late final _colour = TextEditingController(text: widget.product.colour ?? '');
  bool _editing = false;
  bool _busy = false;

  @override
  void dispose() {
    _subcategory.dispose();
    _fit.dispose();
    _colour.dispose();
    super.dispose();
  }

  Future<void> _decide(bool approve) async {
    setState(() => _busy = true);
    final p = widget.product;
    String? changed(TextEditingController c, String? was) {
      final v = c.text.trim();
      return v == (was ?? '') ? null : v;
    }

    final edits = <String, String?>{
      if (_category != p.category) 'category': _category,
      if (changed(_subcategory, p.subcategory) case final v?)
        'subcategory': v.isEmpty ? null : v,
      if (changed(_fit, p.fit) case final v?) 'fit': v.isEmpty ? null : v,
      if (changed(_colour, p.colour) case final v?)
        'colour_family': v.isEmpty ? null : v,
    };
    try {
      await ref
          .read(discoveryRepositoryProvider)
          .review(p.id, approve: approve, edits: approve ? edits : const {});
      if (mounted) showDripToast(context, approve ? 'Published' : 'Rejected');
      ref.invalidate(reviewQueueProvider);
    } on ApiException catch (e) {
      if (mounted) {
        showDripToast(context, e.friendly);
        setState(() => _busy = false);
      }
    }
  }

  Widget _field(String label, TextEditingController c) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: TextField(
      controller: c,
      style: AppText.manrope(13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppText.mono(10, color: AppColors.muted),
        isDense: true,
        filled: true,
        fillColor: AppColors.base,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final conf = p.confidence == null
        ? '–'
        : '${(p.confidence! * 100).round()}%';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cream.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 110,
                height: 130,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE9E4DA),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: p.image == null
                    ? null
                    : DripImage(p.image!, fit: BoxFit.contain, backdrop: false),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (p.brand ?? '').toUpperCase(),
                      style: AppText.mono(9, color: AppColors.muted),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      p.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.manrope(13, weight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    for (final (k, v) in [
                      ('Category', p.category),
                      ('Type', p.subcategory),
                      ('Fit', p.fit),
                      ('Colour', p.colour),
                      (
                        'Style',
                        p.styleTags.isEmpty ? null : p.styleTags.join(', '),
                      ),
                    ])
                      Text(
                        '$k: ${v ?? '—'}',
                        style: AppText.mono(10, color: AppColors.cream),
                      ),
                    const SizedBox(height: 6),
                    Text(
                      'CONFIDENCE $conf',
                      style: AppText.mono(10, color: AppColors.cyan),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_editing) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final s in _slots)
                  ChoiceChip(
                    label: Text(s, style: AppText.mono(10)),
                    selected: _category == s,
                    onSelected: (_) => setState(() => _category = s),
                  ),
              ],
            ),
            _field('TYPE (t-shirt, cargos…)', _subcategory),
            _field('FIT (oversized, slim…)', _fit),
            _field('COLOUR FAMILY (black, navy…)', _colour),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'APPROVE',
                  height: 40,
                  loading: _busy,
                  onPressed: _busy ? null : () => _decide(true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppButton(
                  label: _editing ? 'DONE' : 'EDIT',
                  style: AppButtonStyle.outline,
                  height: 40,
                  onPressed: _busy
                      ? null
                      : () => setState(() => _editing = !_editing),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppButton(
                  label: 'REJECT',
                  style: AppButtonStyle.danger,
                  height: 40,
                  onPressed: _busy ? null : () => _decide(false),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
