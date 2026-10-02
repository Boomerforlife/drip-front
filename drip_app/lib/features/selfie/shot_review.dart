import 'guidance_models.dart';
import 'selfie_intent.dart';

/// A lightweight photography critique of one finished shot.
///
/// It judges composition, light and focus only. It never rates the person.
class ShotReview {
  const ShotReview({required this.score, required this.notes});

  /// 0 … 1, only meaningful for comparing shots from the same session.
  final double score;

  /// Short lines, the things worth changing first and then what worked.
  final List<String> notes;

  static const unknown = ShotReview(
    score: 0.5,
    notes: ['Couldn’t check this one, but it’s yours to use.'],
  );
}

/// Reviews one shot from its [stats] (and [face], when a detector provided it).
ShotReview reviewShot(
  FrameStats s, {
  FaceGeometry? face,
  SelfieIntent intent = SelfieIntent.instagram,
}) {
  var score = 1.0;
  final fixes = <String>[];
  final wins = <String>[];

  // Framing needs a face box, so it's only commented on when we have one.
  if (face != null) {
    final framingFixes = <String>[];
    if (face.headroom < intent.headroomMin) {
      framingFixes.add('Your face is slightly too close to the top edge.');
    } else if (face.headroom > intent.headroomMax) {
      framingFixes.add('There’s a lot of empty space above you.');
    }
    if (face.faceHeight > intent.faceMax) {
      framingFixes.add('This one is a little too close.');
    } else if (face.faceHeight < intent.faceMin) {
      framingFixes.add('Move in a little. There’s a lot of empty frame.');
    }
    if ((face.centerX - 0.5).abs() > 0.16) {
      framingFixes.add('You’re sitting off to one side.');
    }
    if (face.rollDeg.abs() > 12) {
      framingFixes.add('The camera angle is a bit tilted.');
    }
    if (framingFixes.isEmpty) {
      wins.add('Strong framing.');
    } else {
      score -= 0.12 * framingFixes.length;
      fixes.addAll(framingFixes);
    }
  }

  // Exposure and light.
  if (s.meanLuma < 0.28) {
    score -= 0.22;
    fixes.add('A little dark. Try facing a window.');
  } else if (s.meanLuma > 0.76) {
    score -= 0.2;
    fixes.add('Slightly overexposed. Step out of the direct light.');
  } else if (s.highlightClip > 0.2) {
    score -= 0.16;
    fixes.add('Lighting is a little harsh.');
  } else if (s.lightBias.abs() > 0.3) {
    score -= 0.14;
    fixes.add('The light is uneven. Try turning toward the window.');
  } else if (s.shadowClip > 0.35) {
    score -= 0.1;
    fixes.add('Deep shadows. A little more light would help.');
  } else {
    wins.add('Lighting is soft and even.');
  }

  // Focus.
  if (s.sharpness < 0.4) {
    score -= 0.28;
    fixes.add('A touch soft. Hold steady or tap to focus.');
  } else {
    wins.add('Nice and crisp.');
  }

  // Background.
  if (s.backgroundBusy > 0.45) {
    score -= 0.1;
    fixes.add('The background is a little busy.');
  }

  final notes = [...fixes.take(2), ...wins].take(3).toList();
  if (notes.isEmpty) notes.add('A clean, simple shot.');
  return ShotReview(score: score.clamp(0.0, 1.0), notes: notes);
}

/// Index of the best-composed shot. Ties go to the latest, which is usually the
/// one the user settled into.
int bestShotIndex(List<ShotReview> reviews) {
  var best = 0;
  for (var i = 1; i < reviews.length; i++) {
    if (reviews[i].score >= reviews[best].score) best = i;
  }
  return best;
}
