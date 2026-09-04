import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:karastudio/core/renderer/karaoke_renderer.dart';
import 'package:karastudio/models/project_model.dart';

void main() {
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
