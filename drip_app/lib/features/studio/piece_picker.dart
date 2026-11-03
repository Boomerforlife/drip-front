import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/motion.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/peek_carousel.dart';
import '../../core/widgets/skeleton.dart';
import '../../core/widgets/slide_up_sheet.dart';
import '../../core/widgets/tap.dart';
import '../../data/models/stylist.dart';
import '../outfits/shop_sheet.dart';
import 'studio_controller.dart';
import 'studio_layouts.dart';

/// Where the picker's pieces come from.
enum PieceSource { saved, wardrobe, catalogue }

/// What the picker is open for: adding a piece of [category], or swapping the
/// piece under [swapKey] for another of its kind.
class PickerRequest {
  const PickerRequest(this.category, {this.swapKey});
  final String category;
  final String? swapKey;
}

/// The Studio's piece picker, the Pinterest way: a sheet up from the bottom
/// with one big piece in the middle and its neighbours peeking either side.
/// Swipe through them; the details and VISIT / PUT ON CANVAS follow the one in
/// focus. Pieces come from what the user saved, their wardrobe, or all of
/// Drip. It sits in a [SlideUpSheet].
class PiecePicker extends ConsumerStatefulWidget {
  const PiecePicker({
    super.key,
    required this.request,
    required this.onClose,
    required this.onWear,
  });

  final PickerRequest request;
  final VoidCallback onClose;

  /// Put on (or, if it's worn, take off) [piece] as a [category] piece.
  final void Function(String category, StudioPiece piece) onWear;

  static const categories = [
    ('TOPS', 'Tops'),
    ('BOTTOMS', 'Bottoms'),
    ('FOOTWEAR', 'Shoes'),
    ('ACCESSORIES', 'Extras'),
    ('OUTERWEAR', 'Layers'),
    ('DRESSES', 'Dresses'),
  ];

  static String label(String category) => categories
      .firstWhere((c) => c.$1 == category, orElse: () => (category, category))
      .$2;

  @override
  ConsumerState<PiecePicker> createState() => _PiecePickerState();
}

class _PiecePickerState extends ConsumerState<PiecePicker> {
  late String _category = baseCategory(widget.request.category);

  /// The source picked by hand this session, kept for the next opening.
  static PieceSource? _chosen;
  StudioPiece? _focus;

  bool get _swapping => widget.request.swapKey != null;

  AsyncValue<List<StudioPiece>> _pieces(PieceSource source) => switch (source) {
    PieceSource.saved => ref.watch(savedStudioPiecesProvider(_category)),
    PieceSource.wardrobe => ref.watch(studioPiecesProvider((_category, true))),
    PieceSource.catalogue => ref.watch(
      studioPiecesProvider((_category, false)),
    ),
  };

  /// Until the user picks a tab: their wardrobe if they started from it,
  /// else their saved pieces, or all of Drip while they've saved none here.
  PieceSource _source() {
    final chosen = _chosen;
    if (chosen != null) return chosen;
    if (ref.watch(studioProvider).fromWardrobe) return PieceSource.wardrobe;
    final saved = ref.watch(savedStudioPiecesProvider(_category));
    return saved.value?.isEmpty ?? false
        ? PieceSource.catalogue
        : PieceSource.saved;
  }

  void _setCategory(String c) {
    if (c == _category) return;
    Haptics.tick();
    setState(() {
      _category = c;
      _focus = null;
    });
  }

  void _setSource(PieceSource s) {
    Haptics.tick();
    setState(() {
      _chosen = s;
      _focus = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final studio = ref.watch(studioProvider);
    final source = _source();
    final pieces = _pieces(source);
    final worn = {
      for (final e in studio.worn.entries)
        if (baseCategory(e.key) == _category) e.value.id,
    };
    final startId = _swapping
        ? studio.worn[widget.request.swapKey]?.id
        : (worn.isEmpty ? null : worn.first);
    final label = PiecePicker.label(_category);
    final list = pieces.value ?? const <StudioPiece>[];
    final focus = list.contains(_focus)
        ? _focus
        : list.isEmpty
        ? null
        : list.firstWhere((p) => p.id == startId, orElse: () => list.first);

    return Column(
      children: [
        _Header(
          title: _swapping
              ? 'SWAP ${label.toUpperCase()}'
              : 'ADD ${label.toUpperCase()}',
          counter: focus == null || list.length < 2
              ? null
              : '${list.indexOf(focus) + 1} / ${list.length}',
          onClose: widget.onClose,
        ),
        if (!_swapping)
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: PiecePicker.categories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final (id, name) = PiecePicker.categories[i];
                return _Chip(
                  label: name,
                  selected: id == _category,
                  filled: studio.worn.keys.any((k) => baseCategory(k) == id),
                  onTap: () => _setCategory(id),
                );
              },
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: _SourceTabs(source: source, onChanged: _setSource),
        ),
        Expanded(
          child: pieces.when(
            loading: () => const _CarouselSkeleton(),
            error: (_, _) => _Message(
              title: "COULDN'T LOAD ${label.toUpperCase()}",
              action: 'TRY AGAIN',
              onAction: () => source == PieceSource.saved
                  ? ref.invalidate(savedStudioPiecesProvider(_category))
                  : ref.invalidate(
                      studioPiecesProvider((
                        _category,
                        source == PieceSource.wardrobe,
                      )),
                    ),
            ),
            data: (list) => list.isEmpty
                ? _empty(source, label)
                : PeekCarousel(
                    key: ValueKey('$_category-${source.name}'),
                    count: list.length,
                    initial: list.indexOf(focus!),
                    onFocus: (i) => setState(() => _focus = list[i]),
                    onTapFocused: (i) => widget.onWear(_category, list[i]),
                    semanticLabel: (i) => worn.contains(list[i].id)
                        ? '${list[i].name}, on the canvas'
                        : list[i].name,
                    itemBuilder: (context, i) => PieceCard(
                      image: list[i].image,
                      semanticLabel: list[i].name,
                      highlighted: worn.contains(list[i].id),
                      badge: worn.contains(list[i].id) ? 'ON CANVAS' : null,
                    ),
                  ),
          ),
        ),
        SizedBox(
          height: 128,
          child: focus == null
              ? null
              : AnimatedSwitcher(
                  duration: Motion.dur(context, Motion.quick),
                  child: _Details(
                    key: ValueKey(focus.id),
                    piece: focus,
                    source: source,
                    worn: worn.contains(focus.id),
                    swapping: _swapping,
                    onWear: () => widget.onWear(_category, focus),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _empty(PieceSource source, String label) {
    final what = label.toUpperCase();
    return switch (source) {
      PieceSource.saved => _Message(
        title: 'NO SAVED $what YET',
        body: 'Pieces from fits you save or like in the Scroll show up here.',
        action: 'BROWSE ALL DRIP',
        onAction: () => _setSource(PieceSource.catalogue),
      ),
      PieceSource.wardrobe => _Message(
        title: 'NO $what IN YOUR WARDROBE YET',
        action: 'ADD ONE',
        onAction: () => context.push('/wardrobe/capture'),
      ),
      PieceSource.catalogue => _Message(title: 'NO $what IN THE CATALOGUE YET'),
    };
  }
}

/// Grab handle, close, title and "3 / 24".
class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.counter,
    required this.onClose,
  });
  final String title;
  final String? counter;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 8, 18, 6),
      child: Column(
        children: [
          const SheetHandle(),
          Row(
            children: [
              Tap(
                onTap: onClose,
                semanticLabel: 'Close',
                child: const SizedBox(
                  width: 44,
                  height: 40,
                  child: Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: AppColors.cream,
                  ),
                ),
              ),
              Text(
                title,
                style: AppText.mono(
                  11,
                  weight: FontWeight.w500,
                  letterSpacing: 1.4,
                ),
              ),
              const Spacer(),
              if (counter != null)
                Text(counter!, style: AppText.mono(10, color: AppColors.muted)),
            ],
          ),
        ],
      ),
    );
  }
}

/// The piece in focus: store and price, name, what it is and where it's
/// from; VISIT its store page (when known) and PUT ON CANVAS.
class _Details extends ConsumerWidget {
  const _Details({
    super.key,
    required this.piece,
    required this.source,
    required this.worn,
    required this.swapping,
    required this.onWear,
  });
  final StudioPiece piece;
  final PieceSource source;
  final bool worn;
  final bool swapping;
  final VoidCallback onWear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final links = ref.watch(pieceLinksProvider);
    final link =
        piece.buyUrl ?? links[piece.image] ?? links[piece.name.toLowerCase()];
    final store = piece.brand?.toUpperCase();
    final kind = piece.subcategory?.toUpperCase();
    final from = switch (source) {
      PieceSource.saved => 'FROM YOUR SAVED FITS',
      PieceSource.wardrobe => 'YOUR WARDROBE',
      PieceSource.catalogue => 'DRIP CATALOGUE',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            [?store, if (piece.price > 0) formatPrice(piece.price)].join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.mono(10, color: AppColors.cyan),
          ),
          const SizedBox(height: 3),
          Text(
            piece.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.manrope(15, weight: FontWeight.w700),
          ),
          const SizedBox(height: 3),
          Text(
            [?kind, from].join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.mono(9, color: AppColors.muted, letterSpacing: 1),
          ),
          const Spacer(),
          Row(
            children: [
              if (link != null) ...[
                Expanded(
                  child: AppButton(
                    label: 'VISIT',
                    style: AppButtonStyle.outline,
                    height: 42,
                    onPressed: () =>
                        openStoreLink(context, link, store: piece.brand ?? ''),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                flex: 2,
                child: AppButton(
                  label: worn
                      ? 'TAKE OFF'
                      : swapping
                      ? 'SWAP IN'
                      : 'PUT ON CANVAS',
                  style: worn ? AppButtonStyle.subtle : AppButtonStyle.primary,
                  height: 42,
                  onPressed: onWear,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SourceTabs extends StatelessWidget {
  const _SourceTabs({required this.source, required this.onChanged});
  final PieceSource source;
  final ValueChanged<PieceSource> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget tab(String label, PieceSource value) {
      final on = source == value;
      return Expanded(
        child: Tap(
          onTap: () => onChanged(value),
          semanticLabel: label,
          child: AnimatedContainer(
            duration: Motion.quick,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: on ? AppColors.elevated : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              label,
              style: AppText.mono(
                9,
                letterSpacing: 1,
                color: on ? AppColors.cream : AppColors.muted,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AppColors.base,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.elevated),
      ),
      child: Row(
        children: [
          tab('SAVED', PieceSource.saved),
          tab('MY WARDROBE', PieceSource.wardrobe),
          tab('ALL DRIP', PieceSource.catalogue),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.filled,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = context.palette.accent;
    return Tap(
      onTap: onTap,
      scale: 0.95,
      semanticLabel: '$label${filled ? ', on the canvas' : ''}',
      child: AnimatedContainer(
        duration: Motion.quick,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.cream : AppColors.base,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color: selected ? AppColors.cream : AppColors.elevated,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label.toUpperCase(),
              style: AppText.mono(
                10,
                weight: FontWeight.w500,
                letterSpacing: 1,
                color: selected ? AppColors.base : AppColors.cream,
              ),
            ),
            if (filled) ...[
              const SizedBox(width: 6),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.title, this.body, this.action, this.onAction});
  final String title;
  final String? body;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppText.mono(10, letterSpacing: 1.2),
            ),
            if (body != null) ...[
              const SizedBox(height: 8),
              Text(
                body!,
                textAlign: TextAlign.center,
                style: AppText.manrope(12, color: AppColors.muted),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 14),
              AppButton(
                label: action!,
                style: AppButtonStyle.outline,
                height: 38,
                expand: false,
                onPressed: onAction,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CarouselSkeleton extends StatelessWidget {
  const _CarouselSkeleton();

  @override
  Widget build(BuildContext context) {
    return ShimmerScope(
      child: LayoutBuilder(
        builder: (context, c) => Center(
          child: Skeleton(
            width: c.maxWidth * 0.62 - 12,
            height: c.maxHeight - 12,
            radius: 24,
          ),
        ),
      ),
    );
  }
}
