import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/motion.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/overlays.dart';
import '../../core/widgets/peek_carousel.dart';
import '../../core/widgets/slide_up_sheet.dart';
import '../../core/widgets/tap.dart';
import '../../data/api/api_client.dart';
import '../../data/models/outfit.dart';
import '../../data/models/stylist.dart';
import '../../data/providers.dart';
import '../outfits/shop_sheet.dart';
import '../studio/studio_controller.dart';
import '../wardrobe/wardrobe_controller.dart';

/// Catalogue pieces of one Studio category, optionally one subcategory
/// ("jeans"), cached for matching a fit's pieces to their garments.
final catalogPiecesProvider =
    FutureProvider.family<List<StudioPiece>, (String, String?)>(
      (ref, key) => ref
          .watch(studioRepositoryProvider)
          .pieces(key.$1, subcategory: key.$2),
    );

/// The catalogue garment behind one of a fit's pieces, as a Studio piece:
/// by id when the API sends one, else by its cut-out (or name) among the
/// catalogue pieces of its kind. Null when the Studio can't see it.
final garmentForPieceProvider = FutureProvider.autoDispose
    .family<StudioPiece?, OutfitPiece>((ref, p) async {
      final category = StudioSlots.label(p.slot.toLowerCase());
      if (p.id != null) {
        return StudioPiece(
          id: p.id!,
          name: p.name,
          category: category,
          image: p.image ?? '',
          price: p.price,
          brand: p.brand.isEmpty ? null : p.brand,
          subcategory: p.subcategory,
        );
      }
      StudioPiece? match(List<StudioPiece> list) {
        for (final g in list) {
          if (p.image != null && g.image == p.image) return g;
        }
        final name = p.name.toLowerCase();
        for (final g in list) {
          if (name.isNotEmpty && g.name.toLowerCase() == name) return g;
        }
        return null;
      }

      if (p.subcategory != null) {
        final hit = match(
          await ref.watch(
            catalogPiecesProvider((category, p.subcategory)).future,
          ),
        );
        if (hit != null) return hit;
      }
      return match(
        await ref.watch(catalogPiecesProvider((category, null)).future),
      );
    });

/// Shop the look, in the Scroll: the fit's pieces one at a time in the
/// Pinterest-style carousel, each with its store and price, BUY, and saving
/// it to the Studio canvas or the wardrobe. Sits in a [SlideUpSheet].
class FitPiecesSheet extends StatefulWidget {
  const FitPiecesSheet({
    super.key,
    required this.pieces,
    required this.initial,
    required this.onClose,
  });

  /// The fit's pieces that have a cut-out to show.
  final List<OutfitPiece> pieces;
  final int initial;
  final VoidCallback onClose;

  @override
  State<FitPiecesSheet> createState() => _FitPiecesSheetState();
}

class _FitPiecesSheetState extends State<FitPiecesSheet> {
  late int _index = widget.initial.clamp(0, widget.pieces.length - 1);

  @override
  Widget build(BuildContext context) {
    final pieces = widget.pieces;
    final piece = pieces[_index];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 8, 18, 6),
          child: Column(
            children: [
              const SheetHandle(),
              Row(
                children: [
                  Tap(
                    onTap: widget.onClose,
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
                    'SHOP THE LOOK',
                    style: AppText.mono(
                      11,
                      weight: FontWeight.w500,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const Spacer(),
                  if (pieces.length > 1)
                    Text(
                      '${_index + 1} / ${pieces.length}',
                      style: AppText.mono(10, color: AppColors.muted),
                    ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: PeekCarousel(
            count: pieces.length,
            initial: _index,
            onFocus: (i) => setState(() => _index = i),
            onTapFocused: (i) => openProductPage(context, pieces[i]),
            semanticLabel: (i) => pieces[i].name,
            itemBuilder: (context, i) => PieceCard(
              image: pieces[i].image ?? '',
              semanticLabel: pieces[i].name,
            ),
          ),
        ),
        SizedBox(
          height: 170,
          child: AnimatedSwitcher(
            duration: Motion.dur(context, Motion.quick),
            child: _PieceDetails(key: ValueKey(_index), piece: piece),
          ),
        ),
      ],
    );
  }
}

/// The piece in focus: store and price, name, what it is; + STUDIO and
/// + WARDROBE, and BUY on the store's page.
class _PieceDetails extends ConsumerStatefulWidget {
  const _PieceDetails({super.key, required this.piece});
  final OutfitPiece piece;

  @override
  ConsumerState<_PieceDetails> createState() => _PieceDetailsState();
}

class _PieceDetailsState extends ConsumerState<_PieceDetails> {
  bool _studioBusy = false;
  bool _wardrobeBusy = false;

  /// The garment, or null (with a note) when it isn't in the catalogue.
  Future<StudioPiece?> _garment() async {
    try {
      final g = await ref.read(garmentForPieceProvider(widget.piece).future);
      if (g == null && mounted) {
        showDripToast(context, "This piece isn't in the Drip catalogue yet");
      }
      return g;
    } catch (e) {
      if (mounted) {
        showDripToast(
          context,
          e is ApiException ? e.friendly : "Couldn't reach Drip. Try again.",
        );
      }
      return null;
    }
  }

  Future<void> _toStudio(bool onCanvas) async {
    if (onCanvas) {
      context.push('/studio/builder');
      return;
    }
    setState(() => _studioBusy = true);
    final g = await _garment();
    if (!mounted) return;
    setState(() => _studioBusy = false);
    if (g == null) return;
    final c = ref.read(studioProvider.notifier)..setCategory(g.category);
    final note = c.select(g);
    Haptics.commit();
    // The button turns into OPEN CANVAS; a toast would cover the sheet.
    if (note != null) showDripToast(context, note);
  }

  Future<void> _toWardrobe() async {
    setState(() => _wardrobeBusy = true);
    final g = await _garment();
    if (g == null) {
      if (mounted) setState(() => _wardrobeBusy = false);
      return;
    }
    try {
      await ref.read(wardrobeProvider.notifier).saveGarment(g.id);
      Haptics.commit();
    } on ApiException catch (e) {
      if (mounted) showDripToast(context, e.friendly);
    } finally {
      if (mounted) setState(() => _wardrobeBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final piece = widget.piece;
    final garment = ref.watch(garmentForPieceProvider(piece)).value;
    final onCanvas =
        garment != null &&
        ref.watch(studioProvider).worn.values.any((p) => p.id == garment.id);
    final inWardrobe =
        garment != null &&
        (ref.watch(wardrobeProvider).value ?? const []).any(
          (i) => i.garmentId == garment.id,
        );
    final store = piece.brand.toUpperCase();
    final kind = (piece.subcategory ?? piece.slot).toUpperCase();
    final link = piece.buyUrl;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            [
              if (store.isNotEmpty) store,
              if (piece.price > 0) formatPrice(piece.price),
            ].join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.mono(10, color: AppColors.cyan),
          ),
          const SizedBox(height: 3),
          Text(
            piece.name.isEmpty ? kind : piece.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.manrope(15, weight: FontWeight.w700),
          ),
          const SizedBox(height: 3),
          Text(
            '$kind · IN THIS FIT',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.mono(9, color: AppColors.muted, letterSpacing: 1),
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: onCanvas ? 'OPEN CANVAS →' : '+ STUDIO',
                  style: AppButtonStyle.outline,
                  height: 40,
                  loading: _studioBusy,
                  onPressed: () => _toStudio(onCanvas),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppButton(
                  label: inWardrobe ? 'IN WARDROBE ✓' : '+ WARDROBE',
                  style: AppButtonStyle.outline,
                  height: 40,
                  loading: _wardrobeBusy,
                  onPressed: inWardrobe ? null : _toWardrobe,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          AppButton(
            label: link == null
                ? 'NO STORE LINK YET'
                : store.isEmpty
                ? 'BUY'
                : 'BUY ON $store',
            height: 42,
            onPressed: link == null
                ? null
                : () => openProductPage(context, piece),
          ),
        ],
      ),
    );
  }
}
