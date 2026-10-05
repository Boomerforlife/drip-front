import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/motion.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/controls.dart';
import '../../core/widgets/overlays.dart';
import '../../core/widgets/tap.dart';
import '../../core/widgets/top_bar.dart';
import '../../data/api/api_client.dart';
import '../../data/models/stylist.dart';
import '../../routing/main_shell.dart';
import '../outfits/outfit_controller.dart';
import 'fit_canvas.dart';
import 'piece_picker.dart';
import 'studio_controller.dart';
import 'studio_layouts.dart';

/// The Studio canvas: the whole screen is the fit. Tap a "+" box to open the
/// piece picker (saved pieces, your wardrobe, or all of Drip) and put one on;
/// it lands where its layout says. Tap a piece to select it: a side bar
/// resizes, swaps or removes it, and it can be dragged anywhere. Save it as
/// your own fit; the server scores it.
class OutfitBuilderScreen extends ConsumerStatefulWidget {
  const OutfitBuilderScreen({super.key});

  @override
  ConsumerState<OutfitBuilderScreen> createState() =>
      _OutfitBuilderScreenState();
}

class _OutfitBuilderScreenState extends ConsumerState<OutfitBuilderScreen>
    with SingleTickerProviderStateMixin {
  bool _saving = false;

  /// The piece being edited (side bar showing), by canvas key.
  String? _selected;

  /// What the picker is open for; null while it's closed.
  PickerRequest? _request;

  /// The picker's slide: 0 down out of sight, 1 fully up.
  late final _sheet = AnimationController(vsync: this);
  double _sheetHeight = 1;

  @override
  void dispose() {
    _sheet.dispose();
    super.dispose();
  }

  void _openPicker(String category, {String? swapKey}) {
    Haptics.tick();
    setState(() {
      _request = PickerRequest(category, swapKey: swapKey);
      _selected = null;
    });
    _settle(1);
  }

  void _closePicker([double velocity = 0]) {
    if (_request == null) return;
    _settle(0, velocity).whenComplete(() {
      // Still closed (not reopened meanwhile): the spring rests within its
      // tolerance of 0, not exactly on it.
      if (mounted && _sheet.value < 0.02) {
        _sheet.value = 0;
        setState(() => _request = null);
      }
    });
  }

  /// Springs the sheet to [target] (no overshoot), carrying a flick's speed.
  TickerFuture _settle(double target, [double velocity = 0]) {
    if (Motion.reduced(context)) {
      _sheet.value = target;
      return TickerFuture.complete();
    }
    return _sheet.animateWith(
      SpringSimulation(Motion.snap, _sheet.value, target, velocity)
        ..tolerance = const Tolerance(distance: 0.001, velocity: 0.01),
    );
  }

  void _dragSheet(double dy) {
    _sheet.stop();
    _sheet.value = (_sheet.value - dy / _sheetHeight).clamp(0.0, 1.0);
  }

  void _releaseSheet(double velocity) {
    final v = -velocity / _sheetHeight;
    if (velocity > 650 || (_sheet.value < 0.6 && velocity >= 0)) {
      _closePicker(v);
    } else {
      _settle(1, v);
    }
  }

  void _wear(String category, StudioPiece piece) {
    final c = ref.read(studioProvider.notifier);
    final swapKey = _request?.swapKey;
    String? note;
    if (swapKey != null &&
        ref.read(studioProvider).worn[swapKey]?.id != piece.id) {
      c.swap(swapKey, piece);
    } else {
      c.setCategory(category);
      note = c.select(piece);
    }
    Haptics.commit();
    _closePicker();
    if (note != null) showDripToast(context, note);
  }

  void _tapPiece(String key) {
    Haptics.tick();
    setState(() => _selected = _selected == key ? null : key);
  }

  Future<void> _save() async {
    final studio = ref.read(studioProvider);
    if (studio.worn.isEmpty) {
      showDripToast(context, 'Add a piece to the canvas first');
      return;
    }
    setState(() => _selected = null);
    final mine = ref.read(libraryProvider).value?.mine.length ?? 0;
    final name = await _askName(studio.saved?.name ?? 'Fit #${mine + 1}');
    if (name == null || !mounted) return;
    setState(() => _saving = true);
    try {
      final fit = await ref.read(studioProvider.notifier).save(name: name);
      if (!mounted) return;
      showDripToast(
        context,
        fit.dripRate == null
            ? 'Saved to your Studio'
            : 'Saved · drip rate ${fit.dripRate}',
      );
    } on ApiException catch (e) {
      debugPrint('[studio] save failed: $e ${e.details}');
      final why = e.details.isEmpty ? '' : ' (${e.details.first})';
      if (mounted) showDripToast(context, '${e.friendly}$why');
    } catch (e, st) {
      debugPrint('[studio] save failed: $e $st');
      if (mounted) showDripToast(context, "Couldn't save the fit. Try again.");
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// The sheet owns its text controller, so it's disposed only once the
  /// sheet has finished closing (disposing it as the sheet's future completes
  /// broke the field mid-animation: the error seen on save).
  Future<String?> _askName(String initial) => showDripSheet<String>(
    context,
    builder: (_) => _NameSheet(initial: initial),
  );

  @override
  Widget build(BuildContext context) {
    final studio = ref.watch(studioProvider);
    final c = ref.read(studioProvider.notifier);
    final plan = FitLayouts.plan(studio.worn);
    final accent = context.palette.accent;
    final selected = studio.worn.containsKey(_selected) ? _selected : null;
    final request = _request;
    // "+ ADD" opens on the first empty required box, else on extras.
    final next = plan.missing.isEmpty
        ? 'ACCESSORIES'
        : categoryForLayoutSlot(plan.missing.first.slot);

    final page = Column(
      children: [
        DripTopBar(
          title: 'CANVAS',
          leading: const BackGlyph(),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _HeaderIcon(
                icon: Icons.undo_rounded,
                label: 'Undo',
                onTap: c.canUndo ? c.undo : null,
              ),
              _HeaderIcon(
                icon: Icons.shuffle_rounded,
                label: 'Surprise me',
                onTap: () {
                  Haptics.tick();
                  setState(() => _selected = null);
                  c.randomize();
                },
              ),
              _HeaderIcon(
                icon: Icons.restart_alt_rounded,
                label: 'Clear the canvas',
                onTap: studio.worn.isEmpty
                    ? null
                    : () {
                        setState(() => _selected = null);
                        c.reset();
                      },
              ),
              const SizedBox(width: 4),
              _SavePill(
                saving: _saving,
                saved: studio.saved != null && !studio.dirty,
                onTap: _save,
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Center(
              child: FitCanvas(
                worn: studio.worn,
                placed: studio.placed,
                stack: studio.stack,
                selected: selected,
                onSlotTap: _tapPiece,
                onAdd: _openPicker,
                onBackgroundTap: selected == null
                    ? null
                    : () => setState(() => _selected = null),
                onMoveStart: (key) {
                  c.beginMove(key);
                  if (_selected != key) setState(() => _selected = key);
                },
                onMove: c.move,
                onSwap: (key) => _openPicker(baseCategory(key), swapKey: key),
                onRemove: (key) {
                  Haptics.commit();
                  setState(() => _selected = null);
                  c.remove(key);
                },
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 16, 10),
          child: Row(
            children: [
              Flexible(
                child: Text(
                  'LAYOUT · ${plan.layout.label.toUpperCase()}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.mono(
                    9,
                    color: AppColors.muted,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              if (studio.placed.isNotEmpty)
                Tap(
                  onTap: c.snapBack,
                  semanticLabel: 'Snap every piece back into the layout',
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      'SNAP BACK ↺',
                      style: AppText.mono(9, color: accent, letterSpacing: 1.2),
                    ),
                  ),
                )
              else if (studio.worn.isNotEmpty && selected == null)
                Flexible(
                  child: Text(
                    'TAP A PIECE TO RESIZE',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.mono(
                      9,
                      color: AppColors.dim,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              const Spacer(),
              if (studio.total > 0)
                Text(
                  formatPrice(studio.total),
                  style: AppText.mono(11, weight: FontWeight.w500),
                ),
              if (studio.dripRate != null) ...[
                const SizedBox(width: 10),
                Text(
                  '✦ ${studio.dripRate}',
                  style: AppText.mono(
                    11,
                    color: accent,
                    weight: FontWeight.w500,
                  ),
                ),
              ],
              const SizedBox(width: 10),
              _AddPill(onTap: () => _openPicker(next)),
            ],
          ),
        ),
      ],
    );

    return PopScope(
      canPop: request == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _closePicker();
      },
      child: ShellPage(
        child: LayoutBuilder(
          builder: (context, box) {
            _sheetHeight = (box.maxHeight * 0.7).clamp(
              360.0,
              box.maxHeight - 40,
            );
            return Stack(
              children: [
                Positioned.fill(child: page),
                if (request != null) ...[
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: _closePicker,
                      behavior: HitTestBehavior.opaque,
                      child: FadeTransition(
                        opacity: _sheet,
                        child: const ColoredBox(color: Color(0x8C05070C)),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: _sheetHeight,
                    child: AnimatedBuilder(
                      animation: _sheet,
                      builder: (context, child) => Transform.translate(
                        offset: Offset(0, (1 - _sheet.value) * _sheetHeight),
                        child: child,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(28),
                          ),
                          border: Border(
                            top: BorderSide(color: AppColors.elevated),
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x66000000),
                              blurRadius: 30,
                              offset: Offset(0, -6),
                            ),
                          ],
                        ),
                        child: PiecePicker(
                          key: ValueKey(request),
                          request: request,
                          onClose: _closePicker,
                          onWear: _wear,
                          onDrag: _dragSheet,
                          onDragEnd: _releaseSheet,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

/// "+ ADD": opens the picker without hunting for a "+" box.
class _AddPill extends StatelessWidget {
  const _AddPill({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tap(
      onTap: onTap,
      scale: 0.95,
      semanticLabel: 'Add a piece',
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.cream.withValues(alpha: 0.3)),
        ),
        child: Text(
          '+ ADD',
          style: AppText.mono(9, letterSpacing: 1.2, weight: FontWeight.w500),
        ),
      ),
    );
  }
}

class _SavePill extends StatelessWidget {
  const _SavePill({
    required this.saving,
    required this.saved,
    required this.onTap,
  });
  final bool saving;
  final bool saved;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = context.palette.accent;
    return Tap(
      onTap: saving ? null : onTap,
      scale: 0.95,
      semanticLabel: saved ? 'Saved' : 'Save fit',
      child: AnimatedContainer(
        duration: Motion.quick,
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: saved ? Colors.transparent : accent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent),
        ),
        child: saving
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.base,
                ),
              )
            : Text(
                saved ? 'SAVED ✓' : 'SAVE',
                style: AppText.mono(
                  10,
                  weight: FontWeight.w500,
                  letterSpacing: 1.2,
                  color: saved ? accent : AppColors.base,
                ),
              ),
      ),
    );
  }
}

/// A 44px header action that dims (and stops responding) when unavailable.
class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tap(
      onTap: onTap,
      semanticLabel: label,
      scale: 0.9,
      child: SizedBox(
        width: 36,
        height: 44,
        child: AnimatedOpacity(
          duration: Motion.quick,
          opacity: onTap == null ? 0.35 : 1,
          child: Icon(icon, size: 20, color: AppColors.cream),
        ),
      ),
    );
  }
}

class _NameSheet extends StatefulWidget {
  const _NameSheet({required this.initial});
  final String initial;

  @override
  State<_NameSheet> createState() => _NameSheetState();
}

class _NameSheetState extends State<_NameSheet> {
  late final _c = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _done([String? v]) {
    final name = (v ?? _c.text).trim();
    Navigator.of(context).pop(name.isEmpty ? widget.initial : name);
  }

  @override
  Widget build(BuildContext context) {
    return SheetContent(
      title: 'NAME THIS FIT',
      subtitle: 'It lands in your Studio. Only you can see it.',
      children: [
        DripField(
          controller: _c,
          hint: 'e.g. Sunday cargo fit',
          radius: 14,
          autofocus: true,
          onSubmitted: _done,
        ),
        const SizedBox(height: 14),
        AppButton(label: 'SAVE FIT ✦', height: 44, onPressed: _done),
      ],
    );
  }
}
