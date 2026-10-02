import 'package:flutter/material.dart';

/// What the user is shooting for. It only tunes *photographic* targets
/// (framing, how much room to leave) and which pose ideas come first. It never
/// says anything about the person.
enum SelfieIntent {
  instagram(
    label: 'Instagram',
    blurb: 'Bright, a little space to breathe',
    icon: Icons.photo_camera_outlined,
    faceMin: 0.24,
    faceMax: 0.50,
    headroomMin: 0.06,
    headroomMax: 0.30,
    setupTip: 'Keep the camera around eye level.',
    poseTips: [
      'Relax your shoulders.',
      'Turn your face slightly.',
      'Look slightly past the camera.',
      'Tilt your head slightly.',
      'Try a relaxed expression.',
    ],
  ),
  dating(
    label: 'Dating profile',
    blurb: 'Warm, open, eye contact',
    icon: Icons.favorite_border_rounded,
    faceMin: 0.28,
    faceMax: 0.52,
    headroomMin: 0.06,
    headroomMax: 0.28,
    setupTip: 'Keep the camera around eye level.',
    poseTips: [
      'Try a relaxed expression.',
      'Look directly into the lens.',
      'Relax your shoulders.',
      'Lower your chin just a little.',
      'Turn your face slightly.',
    ],
  ),
  casual(
    label: 'Casual / natural',
    blurb: 'Easy, candid, unposed',
    icon: Icons.wb_sunny_outlined,
    faceMin: 0.22,
    faceMax: 0.52,
    headroomMin: 0.05,
    headroomMax: 0.34,
    setupTip: 'Hold the phone a little below eye level.',
    poseTips: [
      'Relax your shoulders.',
      'Try a relaxed expression.',
      'Look slightly past the camera.',
      'Tilt your head slightly.',
    ],
  ),
  fashion(
    label: 'Fashion',
    blurb: 'Wider, shows the outfit',
    icon: Icons.checkroom_rounded,
    faceMin: 0.10,
    faceMax: 0.30,
    headroomMin: 0.05,
    headroomMax: 0.30,
    setupTip: 'Hold the phone a little further away.',
    poseTips: [
      'Turn your face slightly.',
      'Angle your shoulders a little away.',
      'Lower your chin just a little.',
      'Look slightly past the camera.',
      'Relax your shoulders.',
    ],
  ),
  professional(
    label: 'Professional',
    blurb: 'Level, clean, composed',
    icon: Icons.work_outline_rounded,
    faceMin: 0.26,
    faceMax: 0.46,
    headroomMin: 0.07,
    headroomMax: 0.24,
    setupTip: 'Keep the camera at eye level.',
    poseTips: [
      'Relax your shoulders.',
      'Look directly into the lens.',
      'Lower your chin just a little.',
      'Angle your shoulders a little away.',
      'Try a relaxed expression.',
    ],
  );

  const SelfieIntent({
    required this.label,
    required this.blurb,
    required this.icon,
    required this.faceMin,
    required this.faceMax,
    required this.headroomMin,
    required this.headroomMax,
    required this.setupTip,
    required this.poseTips,
  });

  final String label;
  final String blurb;
  final IconData icon;

  /// Target face height, as a fraction of the frame height.
  final double faceMin;
  final double faceMax;

  /// Target space above the head, as a fraction of the frame height.
  final double headroomMin;
  final double headroomMax;

  /// The first thing said, before any live guidance.
  final String setupTip;
  final List<String> poseTips;
}
