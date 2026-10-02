import 'dart:typed_data';

import 'package:drip/core/theme/app_theme.dart';
import 'package:drip/core/theme/drip_skin.dart';
import 'package:drip/features/selfie/selfie_camera.dart';
import 'package:drip/features/selfie/selfie_screen.dart';
import 'package:drip/features/selfie/guidance_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_fonts.dart';

class _DeniedCamera implements SelfieCameraService {
  @override
  Future<CameraOutcome> start() async => CameraOutcome.denied;
  @override
  Widget buildPreview() => const SizedBox();
  @override
  double get previewAspect => 0.75;
  @override
  Stream<SelfieFrame> get frames => const Stream.empty();
  @override
  bool get framesRotated => true;
  @override
  Future<Uint8List> capture() async => Uint8List(0);
  @override
  Future<void> suspend() async {}
  @override
  Future<void> dispose() async {}
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets('intent pick, then a denied camera falls back to photo upload', (
    t,
  ) async {
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          selfieCameraFactoryProvider.overrideWithValue(_DeniedCamera.new),
        ],
        child: MaterialApp(
          theme: AppTheme.build(DripSkin.retroCyber),
          home: const SelfieScreen(),
        ),
      ),
    );
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('INSTAGRAM'), findsOneWidget);
    expect(find.text('PROFESSIONAL'), findsOneWidget);

    await t.tap(find.text('DATING PROFILE'));
    await t.pump(const Duration(milliseconds: 300));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('CAMERA ACCESS IS OFF'), findsOneWidget);
    expect(find.text('TAKE A PHOTO'), findsOneWidget);
    expect(find.text('CHOOSE FROM LIBRARY'), findsOneWidget);
  });
}
