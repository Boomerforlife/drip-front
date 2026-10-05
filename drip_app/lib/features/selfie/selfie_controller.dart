import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/api_client.dart';
import '../onboarding/local_selfie.dart';
import 'selfie_camera.dart';
import 'selfie_intent.dart';
import 'shot_review.dart';

enum SelfieStep { intent, camera, review }

class SelfieShot {
  const SelfieShot({
    required this.bytes,
    required this.review,
    this.contentType = 'image/jpeg',
  });
  final Uint8List bytes;
  final ShotReview review;
  final String contentType;
}

class SelfieState {
  const SelfieState({
    this.step = SelfieStep.intent,
    this.intent = SelfieIntent.instagram,
    this.shots = const [],
    this.selected = 0,
    this.angleRound = 0,
    this.uploading = false,
  });

  final SelfieStep step;
  final SelfieIntent intent;
  final List<SelfieShot> shots;
  final int selected;

  /// How many times the user asked for "another angle" (rotates the tip).
  final int angleRound;
  final bool uploading;

  static const maxShots = 6;

  bool get full => shots.length >= maxShots;
  SelfieShot? get current => shots.isEmpty ? null : shots[selected];

  /// The shot with the cleanest composition (only meaningful with 2+ shots).
  int get best => bestShotIndex([for (final s in shots) s.review]);

  /// What to say first when the camera reopens for another angle.
  String? get angleTip => angleRound == 0
      ? null
      : const [
          'Try turning your face a little to the left.',
          'Try turning your face a little to the right.',
          'Try holding the camera a little higher.',
          'Try a different light, near a window.',
        ][(angleRound - 1) % 4];

  SelfieState copyWith({
    SelfieStep? step,
    SelfieIntent? intent,
    List<SelfieShot>? shots,
    int? selected,
    int? angleRound,
    bool? uploading,
  }) => SelfieState(
    step: step ?? this.step,
    intent: intent ?? this.intent,
    shots: shots ?? this.shots,
    selected: selected ?? this.selected,
    angleRound: angleRound ?? this.angleRound,
    uploading: uploading ?? this.uploading,
  );
}

/// One run of the Selfie Coordinator. It lives only as long as the screen.
class SelfieController extends Notifier<SelfieState> {
  @override
  SelfieState build() => const SelfieState();

  void chooseIntent(SelfieIntent intent) =>
      state = state.copyWith(intent: intent, step: SelfieStep.camera);

  /// Back to the intent picker (changing the kind of photo).
  void changeIntent() => state = state.copyWith(step: SelfieStep.intent);

  /// Reviews and stores a finished photo, then selects it.
  Future<void> addShot(
    Uint8List bytes, {
    String contentType = 'image/jpeg',
  }) async {
    final stats = await ref.read(selfieStillAnalyzerProvider)(bytes);
    if (!ref.mounted) return;
    final review = stats == null
        ? ShotReview.unknown
        : reviewShot(stats, intent: state.intent);
    final shots = [
      ...state.shots,
      SelfieShot(bytes: bytes, review: review, contentType: contentType),
    ];
    state = state.copyWith(shots: shots, selected: shots.length - 1);
  }

  void showReview() {
    if (state.shots.isEmpty) return;
    state = state.copyWith(
      step: SelfieStep.review,
      // Open on the best-composed shot.
      selected: state.shots.length > 1 ? state.best : state.selected,
    );
  }

  void select(int i) {
    if (i >= 0 && i < state.shots.length) state = state.copyWith(selected: i);
  }

  /// Drop the selected shot and go back to the camera.
  void retake() {
    final shots = [...state.shots]..removeAt(state.selected);
    state = state.copyWith(shots: shots, selected: 0, step: SelfieStep.camera);
  }

  void backToCamera() => state = state.copyWith(step: SelfieStep.camera);

  /// Keep every shot and go back to the camera with a fresh suggestion.
  void anotherAngle() => state = state.copyWith(
    step: SelfieStep.camera,
    angleRound: state.angleRound + 1,
  );

  /// Keeps the selected photo as the user's selfie, on this device only
  /// (`LocalSelfie`). Nothing is uploaded.
  Future<void> useSelected() async {
    final shot = state.current;
    if (shot == null || state.uploading) return;
    state = state.copyWith(uploading: true);
    try {
      await ref
          .read(localSelfieProvider.notifier)
          .save(shot.bytes, contentType: shot.contentType);
    } finally {
      if (ref.mounted) state = state.copyWith(uploading: false);
    }
  }
}

final selfieProvider =
    NotifierProvider.autoDispose<SelfieController, SelfieState>(
      SelfieController.new,
    );

/// Why saving failed, in words for a toast.
String selfieUploadError(Object e) =>
    e is ApiException ? e.friendly : 'Couldn’t save your selfie. Try again.';
