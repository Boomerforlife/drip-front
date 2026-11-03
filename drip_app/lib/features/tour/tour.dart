import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';

/// Marks a widget the tour can point at. Several may share an [id] (one per
/// page of the Scroll, say); the tour uses the one most on screen.
class TourAnchor extends StatefulWidget {
  const TourAnchor({super.key, required this.id, required this.child});
  final String id;
  final Widget child;

  /// Live anchors by id.
  static final _live = <String, Set<GlobalKey>>{};

  /// The on-screen rect (in [ancestor]'s coordinates) of the anchor [id] that
  /// is most visible inside [bounds], or null when none is laid out there.
  static Rect? rectOf(String id, RenderBox ancestor, Rect bounds) {
    Rect? best;
    var bestArea = 0.0;
    for (final key in _live[id] ?? const <GlobalKey>{}) {
      final box = key.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.attached || !box.hasSize) continue;
      final rect =
          box.localToGlobal(Offset.zero, ancestor: ancestor) & box.size;
      final seen = rect.intersect(bounds);
      final area = seen.isEmpty ? 0.0 : seen.width * seen.height;
      if (area > bestArea) {
        bestArea = area;
        best = rect;
      }
    }
    return best;
  }

  /// Scrolls the anchor [id] into view, if it sits in a scrollable.
  static Future<void> reveal(String id, Duration duration) async {
    for (final key in _live[id] ?? const <GlobalKey>{}) {
      final context = key.currentContext;
      if (context == null || !context.mounted) continue;
      await Scrollable.ensureVisible(
        context,
        alignment: 0.35,
        duration: duration,
        alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
      );
      return;
    }
  }

  @override
  State<TourAnchor> createState() => _TourAnchorState();
}

class _TourAnchorState extends State<TourAnchor> {
  final _key = GlobalKey();

  @override
  void initState() {
    super.initState();
    TourAnchor._live.putIfAbsent(widget.id, () => {}).add(_key);
  }

  @override
  void didUpdateWidget(TourAnchor old) {
    super.didUpdateWidget(old);
    if (old.id != widget.id) {
      TourAnchor._live[old.id]?.remove(_key);
      TourAnchor._live.putIfAbsent(widget.id, () => {}).add(_key);
    }
  }

  @override
  void dispose() {
    TourAnchor._live[widget.id]?.remove(_key);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      KeyedSubtree(key: _key, child: widget.child);
}

/// The gesture a step demonstrates with the animated finger.
enum TourGesture { none, tap, doubleTap, swipeUp, swipeSide }

/// The drawing on a step with nothing on screen to point at.
enum TourArt { none, welcome, canvas, afterBeta, done }

class TourStep {
  const TourStep({
    required this.route,
    required this.title,
    required this.body,
    this.anchor,
    this.gesture = TourGesture.none,
    this.art = TourArt.none,
  });

  /// The tab the step shows (the tour moves there).
  final String route;

  /// What it points at ([TourAnchor.id]); null for a card in the middle.
  final String? anchor;
  final String title;
  final String body;
  final TourGesture gesture;
  final TourArt art;
}

/// Features the app shows but that open after the beta, for the tour's
/// "coming after beta" card: (icon code point name, label).
const tourAfterBeta = [
  ('comments', 'Comments & sharing'),
  ('follow', 'Following creators'),
  ('post', 'Posting your OOTD & stories'),
  ('mail', 'Messages & notifications'),
  ('camera', 'AI photoshoots of your fits'),
  ('palette', 'Automatic colour analysis'),
  ('lock', 'Private accounts & controls'),
];

/// The first-run tour, tab by tab. Words are short: one idea a step.
const tourSteps = [
  TourStep(
    route: '/home',
    art: TourArt.welcome,
    title: 'WELCOME TO DRIP',
    body:
        'Fits picked for your taste, a studio to build your own, and a '
        'wardrobe that knows what you own. Here\'s a one-minute tour.',
  ),
  TourStep(
    route: '/home',
    anchor: 'nav',
    gesture: TourGesture.swipeSide,
    title: 'FIVE TABS',
    body:
        'Home, Scroll, Studio, Wardrobe and You. Swipe left or right anywhere '
        'to move between them.',
  ),
  TourStep(
    route: '/home',
    anchor: 'home.camera',
    gesture: TourGesture.tap,
    title: 'SNAP A PIECE',
    body:
        'Tap + (or swipe right on Home) to photograph something you own. '
        'Drip cuts it out and adds it to your wardrobe.',
  ),
  TourStep(
    route: '/home',
    anchor: 'home.tools',
    gesture: TourGesture.tap,
    title: 'YOUR TOOLS',
    body:
        'A guided selfie, your colour palette, your shop list, and a '
        'ten-tap style quiz that sharpens what the feed picks for you.',
  ),
  TourStep(
    route: '/home',
    anchor: 'home.occasions',
    gesture: TourGesture.tap,
    title: 'SHOP BY OCCASION',
    body: 'Date night, weddings, golf… tap a card for fits that suit it.',
  ),
  TourStep(
    route: '/scroll',
    anchor: 'scroll.stage',
    gesture: TourGesture.swipeUp,
    title: 'THE SCROLL',
    body:
        'Fits picked for you. Swipe up for the next, double-tap to like. It '
        'learns from what you like, save and skip.',
  ),
  TourStep(
    route: '/scroll',
    anchor: 'scroll.stage',
    gesture: TourGesture.tap,
    title: 'SHOP THE LOOK',
    body:
        'Tap any piece in a fit to see it up close: the store, the price, '
        'BUY, and + STUDIO or + WARDROBE.',
  ),
  TourStep(
    route: '/scroll',
    anchor: 'scroll.rail',
    gesture: TourGesture.tap,
    title: 'SAVE IT, OR TELL US',
    body:
        'Like and save fits to keep them. Spot something wrong? The bug '
        'button sends it straight to the Drip team.',
  ),
  TourStep(
    route: '/studio',
    anchor: 'studio.new',
    gesture: TourGesture.tap,
    title: 'THE STUDIO',
    body:
        'Build your own fit on a blank canvas, or ask Taylor, your stylist, '
        'to pick one for any occasion.',
  ),
  TourStep(
    route: '/studio',
    art: TourArt.canvas,
    title: 'HOW THE CANVAS WORKS',
    body:
        'Tap a + box and swipe through pieces from your saves, your wardrobe '
        'or all of Drip. Tap a piece to resize, swap or remove it. Save it '
        'and Drip rates the fit.',
  ),
  TourStep(
    route: '/wardrobe',
    anchor: 'wardrobe.add',
    gesture: TourGesture.tap,
    title: 'YOUR WARDROBE',
    body:
        'Add photos of what you own. Each piece is cut out and tagged, ready '
        'for the Studio and Taylor.',
  ),
  TourStep(
    route: '/me',
    anchor: 'me.style',
    gesture: TourGesture.tap,
    title: 'YOU',
    body:
        'Your style DNA and palette. Change your picks any time; settings '
        'and the privacy policy are here too.',
  ),
  TourStep(
    route: '/me',
    art: TourArt.afterBeta,
    title: 'COMING AFTER BETA',
    body: 'You\'ll see these in the app already. They open after the beta:',
  ),
  TourStep(
    route: '/home',
    art: TourArt.done,
    title: 'YOU\'RE SET',
    body: 'Replay this tour any time from Settings.',
  ),
];

/// Whether the tour starts by itself the first time Home shows (off in
/// tests, which start it by hand).
final tourAutoStartProvider = Provider<bool>((ref) => true);

/// The step showing, or null while the tour is closed.
class TourController extends Notifier<int?> {
  @override
  int? build() => null;

  bool get seen => ref.read(localStoreProvider).tourSeen;

  void start() => state = 0;

  void next() {
    final s = state;
    if (s == null) return;
    s + 1 < tourSteps.length ? state = s + 1 : finish();
  }

  void back() {
    final s = state;
    if (s != null && s > 0) state = s - 1;
  }

  /// Done or skipped: it won't start by itself again.
  void finish() {
    state = null;
    ref.read(localStoreProvider).setTourSeen(true);
  }
}

final tourProvider = NotifierProvider<TourController, int?>(TourController.new);
