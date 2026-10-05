import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/motion.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/overlays.dart';
import '../../core/widgets/top_bar.dart';
import '../../routing/main_shell.dart';
import '../home/feed_controller.dart';
import '../session/session_controller.dart';
import '../settings/settings_screen.dart';
import 'onboarding_steps.dart';
import 'onboarding_ticket.dart';

/// The parts of a user's style that onboarding asks about, editable later.
enum StylePart {
  dressFor('Dress me for', 'Dress me for', 'Whose fits lead your Scroll.'),
  eras('Eras', 'Your vibe', 'Every era you’d actually wear.'),
  colours('Colours', 'Colour theory', 'Tap every colour you wear.'),
  occasions('Occasions', 'Dressing for', 'Where the fit needs to show up.'),
  labels('Labels', 'Labels', 'The labels you wear.'),
  fit('Fit & budget', 'Fit & budget', 'How you wear it, what you spend.'),
  pieces('Pieces', 'Your pieces', 'What’s already in your closet.'),
  accessories('Accessories', 'Accessories', 'The ones you actually wear.');

  const StylePart(this.label, this.title, this.subtitle);
  final String label;
  final String title;
  final String subtitle;
}

/// Settings → Your style: the user's Drip ticket, live, with every part of it
/// one tap from being changed. The same picks onboarding made (one source of
/// truth, `onboardingProvider`), saved to the account.
class StyleScreen extends ConsumerWidget {
  const StyleScreen({super.key});

  static String _list(Iterable<String> items, {String none = 'None yet'}) {
    final l = items.toList();
    if (l.isEmpty) return none;
    return l.length <= 2
        ? l.join(', ')
        : '${l.take(2).join(', ')} +${l.length - 2}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final picks = ref.watch(onboardingProvider);
    final info = TicketInfo(picks);
    String value(StylePart p) => switch (p) {
      StylePart.dressFor => switch (picks.gender) {
        'male' => 'Male',
        'female' => 'Female',
        'unspecified' => 'Prefer not to say',
        _ => 'Not set',
      },
      StylePart.occasions => _list(info.occasionLabels),
      StylePart.eras => _list(info.eraLabels, none: 'Not set'),
      StylePart.colours => _list(
        info.colours.map((c) => c.$2),
        none: 'Not set',
      ),
      StylePart.pieces => _list(picks.clothes),
      StylePart.accessories => _list(picks.accessories),
      StylePart.labels => _list(info.brandLabels),
      StylePart.fit => '${info.fit.label}, ${info.budget}',
    };

    return ShellPage(
      child: Column(
        children: [
          const DripTopBar(title: 'YOUR STYLE', leading: BackGlyph()),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                0,
                8,
                0,
                24 + MediaQuery.paddingOf(context).bottom,
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                  child: Text(
                    'What your Scroll and Taylor are tuned to. Change '
                    'anything, any time.',
                    style: AppText.manrope(
                      14,
                      color: AppColors.muted,
                      lineHeight: 20,
                    ),
                  ),
                ),
                SettingsGroup(
                  children: [
                    for (final p in StylePart.values)
                      SettingsRow(
                        label: p.label,
                        value: value(p),
                        last: p == StylePart.values.last,
                        onTap: () => context.push('/style/${p.name}'),
                      ),
                  ],
                ),
                // The ticket these picks print, live: edits show up here.
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 26, 20, 12),
                  child: SectionLabel('YOUR TICKET'),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: DripTicket(info: info),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One part of the style, edited with the very controls onboarding uses.
/// Nothing reaches the account until SAVE; leaving with changes asks first,
/// and discarding puts every pick back as it was.
class StylePartScreen extends ConsumerStatefulWidget {
  const StylePartScreen({super.key, required this.part});
  final StylePart part;

  @override
  ConsumerState<StylePartScreen> createState() => _StylePartScreenState();
}

class _StylePartScreenState extends ConsumerState<StylePartScreen> {
  late final OnboardingState _before = ref.read(onboardingProvider);
  bool _saving = false;

  bool get _dirty =>
      jsonEncode(ref.read(onboardingProvider).toPrefs()) !=
      jsonEncode(_before.toPrefs());

  /// What's missing before this part can be saved (eras and colours need
  /// one pick, as in onboarding), or null.
  String? _missing(OnboardingState p) => switch (widget.part) {
    StylePart.eras when p.moodIds.isEmpty => 'PICK AN ERA TO SAVE',
    StylePart.colours when p.paletteIds.isEmpty => 'PICK A COLOUR TO SAVE',
    _ => null,
  };

  Future<void> _leave() async {
    if (_saving) return;
    if (_dirty) {
      final discard = await showDripConfirm(
        context,
        title: 'DISCARD CHANGES?',
        message: 'Your ${widget.part.label.toLowerCase()} stay as they were.',
        confirmLabel: 'DISCARD',
      );
      if (!discard || !mounted) return;
      await ref.read(onboardingProvider.notifier).restore(_before.toPrefs());
    }
    if (mounted) context.pop();
  }

  Future<void> _save() async {
    if (!_dirty) {
      context.pop();
      return;
    }
    Haptics.commit();
    setState(() => _saving = true);
    try {
      await ref.read(sessionProvider.notifier).savePicks();
      // The Scroll ranks on these: start it fresh.
      ref.invalidate(scrollFeedProvider);
      if (!mounted) return;
      showDripToast(context, 'Saved. Your feed is retuning');
      context.pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      showDripToast(
        context,
        "Couldn't save. Check your connection and try again",
      );
    }
  }

  Widget _body() => switch (widget.part) {
    StylePart.dressFor => DressForStep(
      onPick: ref.read(onboardingProvider.notifier).setGender,
    ),
    StylePart.occasions => const OccasionsStep(),
    StylePart.eras => ErasStep(onGlow: (_) {}),
    StylePart.colours => ColoursStep(onGlow: (_) {}),
    StylePart.pieces => const ClothesStep(),
    StylePart.accessories => const AccessoriesStep(),
    StylePart.labels => const BrandsStep(),
    StylePart.fit => const FitStep(),
  };

  @override
  Widget build(BuildContext context) {
    final picks = ref.watch(onboardingProvider);
    final missing = _missing(picks);
    final bottom = MediaQuery.paddingOf(context).bottom;
    return PopScope(
      canPop: !_dirty && !_saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        backgroundColor: AppColors.base,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              DripTopBar(
                title: widget.part.title.toUpperCase(),
                leading: BackGlyph(onTap: _leave),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
                  children: [
                    Text(
                      widget.part.subtitle,
                      style: AppText.manrope(
                        15,
                        weight: FontWeight.w800,
                        lineHeight: 20,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _body(),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(24, 8, 24, bottom + 16),
                child: AppButton(
                  label: missing ?? 'SAVE',
                  loading: _saving,
                  onPressed: missing == null ? _save : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// `/style/eras` → [StylePart.eras]; anything unknown → null.
StylePart? stylePartFrom(String? name) =>
    StylePart.values.where((p) => p.name == name).firstOrNull;
