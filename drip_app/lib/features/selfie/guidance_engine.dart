import 'guidance_models.dart';
import 'selfie_intent.dart';

/// Turns analysed frames into one calm instruction at a time.
///
/// This is the seam between "what the camera sees" and "what the user hears".
/// The UI only ever calls [update] and reads [ready]; how frames are measured
/// (plain luma analysis today, a face-landmark detector later) is hidden
/// behind [FrameObservation].
abstract interface class SelfieGuidanceEngine {
  /// The line to show right now, or null for silence. Safe to call on every
  /// frame: the engine paces itself so the line never flickers.
  Guidance? update(FrameObservation observation, DateTime now);

  /// True while the framing and light are good enough to shoot.
  bool get ready;

  /// Forget everything (a new camera session).
  void reset();
}

/// Builds the engine for a camera session. Swap this provider's value to plug
/// in a different implementation.
typedef GuidanceEngineFactory = SelfieGuidanceEngine Function(
  SelfieIntent intent, {
  String? setupTip,
});

/// A photographer's pacing: a short setup tip, then at most one correction at a
/// time (only once it has persisted, and held long enough to read), a quiet
/// "hold there" when things are right, then occasional pose ideas.
///
/// Face geometry is optional. Without it the engine can only judge light and
/// steadiness, and says so honestly rather than praising a framing it can't see.
class PhotographerGuidanceEngine implements SelfieGuidanceEngine {
  PhotographerGuidanceEngine({required this.intent, String? setupTip})
    : _setupTip = setupTip ?? intent.setupTip;

  final SelfieIntent intent;
  final String _setupTip;

  // Pacing. Chosen so a line can be read, and so jitter never changes it.
  static const settle = Duration(milliseconds: 2400);
  static const persist = Duration(milliseconds: 700);
  static const minHold = Duration(milliseconds: 1800);
  static const goodAfter = Duration(milliseconds: 500);
  static const perfectFor = Duration(milliseconds: 1800);
  static const poseFor = Duration(milliseconds: 3500);
  static const poseGap = Duration(milliseconds: 1400);

  DateTime? _startedAt;
  Guidance? _shown;
  DateTime _shownAt = DateTime.fromMillisecondsSinceEpoch(0);

  Guidance? _candidate;
  DateTime _candidateSince = DateTime.fromMillisecondsSinceEpoch(0);

  DateTime? _goodSince;
  DateTime? _perfectAt;
  int _poseIndex = 0;
  bool _ready = false;

  @override
  bool get ready => _ready;

  @override
  void reset() {
    _startedAt = null;
    _shown = null;
    _candidate = null;
    _goodSince = null;
    _perfectAt = null;
    _poseIndex = 0;
    _ready = false;
  }

  @override
  Guidance? update(FrameObservation o, DateTime now) {
    final started = _startedAt ??= now;
    if (now.difference(started) < settle) {
      _ready = false;
      return _show(Guidance('setup', _setupTip, GuidanceTone.setup), now);
    }

    final issue = _detect(o);
    if (issue != null) return _onIssue(issue, now);
    return _onGood(o, now);
  }

  Guidance? _show(Guidance g, DateTime now) {
    if (_shown?.id != g.id) {
      _shown = g;
      _shownAt = now;
    }
    return _shown;
  }

  Guidance? _onIssue(Guidance issue, DateTime now) {
    _ready = false;
    _goodSince = null;
    _perfectAt = null;

    if (_candidate?.id != issue.id) {
      _candidate = issue;
      _candidateSince = now;
    }
    final steady = now.difference(_candidateSince) >= persist;
    final current = _shown;
    final holding =
        current != null &&
        current.tone == GuidanceTone.adjust &&
        now.difference(_shownAt) < minHold;

    if (current?.id == issue.id) return current;
    if (steady && !holding) return _show(issue, now);
    // Not yet sure, or the last correction hasn't been readable long enough.
    return current?.tone == GuidanceTone.adjust ? current : _quiet(current);
  }

  /// While a correction is still pending, a stale "perfect" or pose line would
  /// be wrong, so it clears rather than lingering.
  Guidance? _quiet(Guidance? current) {
    if (current == null) return null;
    if (current.tone == GuidanceTone.setup) return current;
    _shown = null;
    return null;
  }

  Guidance? _onGood(FrameObservation o, DateTime now) {
    _candidate = null;
    final since = _goodSince ??= now;
    if (now.difference(since) < goodAfter) {
      // Corrections that were just satisfied fade out rather than snapping.
      return _shown?.tone == GuidanceTone.adjust ? _shown : _quiet(_shown);
    }
    _ready = true;

    final perfectAt = _perfectAt ??= now;
    final elapsed = now.difference(perfectAt);
    if (elapsed < perfectFor) {
      final text = o.face != null
          ? 'Perfect. Hold there.'
          : 'Light looks good. Hold there.';
      return _show(Guidance('good', text, GuidanceTone.good), now);
    }

    // Pose ideas, one at a time with silence in between.
    final tips = intent.poseTips;
    final cycle = poseFor + poseGap;
    final t = elapsed - perfectFor;
    final index = (_poseIndex + t.inMilliseconds ~/ cycle.inMilliseconds) %
        tips.length;
    final within = t.inMilliseconds % cycle.inMilliseconds;
    if (within >= poseFor.inMilliseconds) {
      _shown = null;
      return null;
    }
    return _show(
      Guidance('pose$index', tips[index], GuidanceTone.pose),
      now,
    );
  }

  // ── detection ────────────────────────────────────────────────────────────

  /// The single most useful correction, or null when all is well.
  ///
  /// The shown correction gets a looser bound than a new one would (hysteresis),
  /// so a value hovering at a threshold can't make the line flip on and off.
  Guidance? _detect(FrameObservation o) {
    final active = _shown?.tone == GuidanceTone.adjust ? _shown!.id : null;
    bool over(String id, double v, double limit) =>
        v > (active == id ? limit * 0.8 : limit);
    bool under(String id, double v, double limit) =>
        v < (active == id ? limit * 1.2 : limit);
    Guidance adjust(String id, String text) =>
        Guidance(id, text, GuidanceTone.adjust);

    final f = o.face;
    final s = o.stats;

    if (f != null) {
      if (under('closer', f.faceHeight, intent.faceMin)) {
        return adjust('closer', 'Move a little closer.');
      }
      if (over('back', f.faceHeight, intent.faceMax)) {
        return adjust('back', 'Move back a little.');
      }
      if (under('higher', f.headroom, intent.headroomMin)) {
        return adjust('higher', 'Bring the camera slightly higher.');
      }
      if (over('lower', f.headroom, intent.headroomMax)) {
        return adjust('lower', 'Lower the phone a little.');
      }
      final dx = f.centerX - 0.5;
      if (over('shiftL', dx, 0.14)) {
        return adjust('shiftL', 'Shift a little to the left.');
      }
      if (over('shiftR', -dx, 0.14)) {
        return adjust('shiftR', 'Shift a little to the right.');
      }
      if (over('roll', f.rollDeg.abs(), 12)) {
        return adjust('roll', 'Straighten up a touch.');
      }
      if (over('yawR', f.yawDeg, 28)) {
        return adjust('yawR', 'Turn slightly left.');
      }
      if (over('yawL', -f.yawDeg, 28)) {
        return adjust('yawL', 'Turn slightly right.');
      }
    }

    if (under('dark', s.meanLuma, 0.24)) {
      return adjust('dark', 'Find a little more light.');
    }
    if (over('bright', s.meanLuma, 0.80) ||
        over('clip', s.highlightClip, 0.28)) {
      return adjust('bright', 'Step out of the direct light.');
    }
    if (over('bias', s.lightBias.abs(), 0.25)) {
      return adjust('bias', 'Turn a little toward the light.');
    }
    if (over('shake', s.motion, 0.07)) {
      return adjust('shake', 'Hold the phone steady.');
    }
    return null;
  }
}
