import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:karastudio/core/renderer/karaoke_renderer.dart';
import 'package:karastudio/models/project_model.dart';

void main() {
  test('last words use exact recorded boundaries with linear sweep', () {
    const beforeLast = LyricToken(
      id: 'a',
      text: 'nhớ',
      index: 0,
      startUs: 1000000,
      endUs: 1500000,
    );
    const last = LyricToken(
      id: 'b',
      text: 'em',
      index: 1,
      startUs: 1500000,
      endUs: 6000000,
    );
    expect(tokenSweepProgress(beforeLast, 1250000), 0.5);
    expect(tokenSweepProgress(beforeLast, 1500000), 1);
    expect(tokenSweepProgress(last, 1499999), 0);
    expect(tokenSweepProgress(last, 1500000), 0);
    expect(tokenSweepProgress(last, 3750000), 0.5);
    expect(tokenSweepProgress(last, 6000000), 1);
    expect(tokenSweepProgress(last.copyWith(clearTiming: true), 6000000), 0);
  });
  testWidgets('preview renderer keeps the media background transparent', (
    tester,
  ) async {
    final alpha = await tester.runAsync(() async {
      final project = ProjectModel.create('Background').copyWith(
        backgroundImage: const MediaAsset(
          id: 'background',
          type: MediaType.image,
          path: '/tmp/background.png',
        ),
      );
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);

      KaraokeRenderer().render(
        canvas: canvas,
        canvasSize: const ui.Size(2, 2),
        project: project,
        timeUs: 0,
        isPreview: true,
      );

      final image = await recorder.endRecording().toImage(2, 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final result = bytes?.getUint8(3);
      image.dispose();
      return result;
    });

    expect(alpha, 0);
  });
}
