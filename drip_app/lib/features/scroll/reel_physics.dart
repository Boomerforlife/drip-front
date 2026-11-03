import 'package:flutter/widgets.dart';

/// The page a reel feed rests on: where the next swipe is measured from.
/// [ReelPhysics] moves it on as each swipe lands; [settle] re-reads it when a
/// scroll ends some other way (back to the top, a jump).
class ReelPaging {
  ReelPaging([this.page = 0]);
  int page;

  void settle(ScrollMetrics m) {
    if (m.viewportDimension > 0) {
      page = (m.pixels / m.viewportDimension).round();
    }
  }
}

/// Paging the way Reels and TikTok do: any deliberate swipe moves exactly one
/// fit. A flick in either direction turns the page however short it was, and
/// a slow drag turns it once it has travelled [turnAt] of the screen, instead
/// of the stock half a screen that made a relaxed swipe spring back (and
/// needed a second go). The landing is a quick, critically damped spring.
///
/// Snapping lives here, so the PageView using it sets `pageSnapping: false`.
class ReelPhysics extends ScrollPhysics {
  const ReelPhysics(this.paging, {super.parent});

  final ReelPaging paging;

  /// Share of a page a slow drag has to cover to turn it.
  static const turnAt = 0.1;

  @override
  ReelPhysics applyTo(ScrollPhysics? ancestor) =>
      ReelPhysics(paging, parent: buildParent(ancestor));

  @override
  SpringDescription get spring =>
      SpringDescription.withDampingRatio(mass: 0.5, stiffness: 210, ratio: 1);

  /// The page a swipe released at [pixels] with [velocity] lands on.
  @visibleForTesting
  int target(ScrollMetrics position, double velocity) {
    final extent = position.viewportDimension;
    final last = (position.maxScrollExtent / extent).round();
    final at = position.pixels / extent;
    var from = paging.page.clamp(0, last);
    // Dragged past a whole page in one go: measure from the last one passed.
    if ((at - from).abs() >= 1) from = at > from ? at.floor() : at.ceil();
    final moved = at - from;
    final still = toleranceFor(position).velocity;
    final int to;
    if (velocity > still) {
      to = moved >= 0 ? from + 1 : from;
    } else if (velocity < -still) {
      to = moved <= 0 ? from - 1 : from;
    } else {
      to = moved >= turnAt
          ? from + 1
          : moved <= -turnAt
          ? from - 1
          : from;
    }
    return to.clamp(0, last);
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    final extent = position.viewportDimension;
    if (extent <= 0 || position.outOfRange) {
      return super.createBallisticSimulation(position, velocity);
    }
    final page = target(position, velocity);
    paging.page = page;
    final end = (page * extent).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    final tolerance = toleranceFor(position);
    if ((end - position.pixels).abs() < tolerance.distance) return null;
    return ScrollSpringSimulation(
      spring,
      position.pixels,
      end,
      velocity,
      tolerance: tolerance,
    );
  }
}
