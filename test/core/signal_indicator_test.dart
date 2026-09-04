import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karastudio/core/indicators/signal_indicator.dart';
import 'package:karastudio/models/project_model.dart';
import 'dart:ui' as ui;

void main() {
  test('all four dots finish lighting before the line starts', () {
    expect(leadDotIntensity(3, 0.75), 0);
    expect(leadDotIntensity(3, 0.8), closeTo(0.5, 1e-9));
    for (var i = 0; i < 4; i++) {
      expect(leadDotIntensity(i, 0.9), 1);
    }
    expect(leadDotIntensity(1, 0.2), 0);
    expect(leadDotIntensity(0, 0.1), 1);
  });

  testWidgets('lamp draws a visible screw base and bulb', (tester) async {
    await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      const SignalIndicatorEngine().render(
        canvas: Canvas(recorder),
        position: const Offset(32, 32),
        actor: const Actor(
          id: 'a',
          name: 'Nam',
          colorValue: 0xFFFFB300,
          styleId: 'classic',
        ),
        progress: 0.9,
        indicatorId: 'lamp',
      );
      final picture = recorder.endRecording();
      final image = await picture.toImage(64, 64);
      final bytes = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      int alphaAt(int x, int y) => bytes.getUint8((y * 64 + x) * 4 + 3);
      expect(alphaAt(32, 26), greaterThan(0)); // Bulb
      expect(alphaAt(32, 42), greaterThan(0)); // Screw base, not a circle
      image.dispose();
      picture.dispose();
    });
  });
}
