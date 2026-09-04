import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:karastudio/core/renderer/karaoke_renderer.dart';
import 'package:karastudio/models/project_model.dart';

void main() {
  test('pale preparation fades in without moving the recorded sweep onset', () {
    const token = LyricToken(
      id: 't',
      text: 'em',
      index: 0,
      startUs: 1000000,
      endUs: 3000000,
    );
    expect(tokenPreparationOpacity(token, 820000), 0);
    expect(tokenPreparationOpacity(token, 910000), closeTo(0.075, 1e-9));
    expect(tokenPreparationOpacity(token, 1000000), closeTo(0.15, 1e-9));
    expect(tokenSweepProgress(token, 999999), 0);
    expect(tokenSweepProgress(token, 1000000), 0);
    expect(tokenSweepProgress(token, 2000000), 0.5);
    double previous = 0;
    for (var time = 820000; time <= 1000000; time += 1000) {
      final opacity = tokenPreparationOpacity(token, time);
      expect(opacity, greaterThanOrEqualTo(previous));
      expect(opacity - previous, lessThan(0.005));
      previous = opacity;
    }
  });
  test('open final note stays visible until its actual closing tap', () {
    const line = LyricLine(
      id: 'sustain',
      text: 'nhớ em',
      actorId: 'male',
      startUs: 1000000,
      endUs: 1500000,
      tokens: [
        LyricToken(
          id: 'a',
          text: 'nhớ',
          index: 0,
          startUs: 1000000,
          endUs: 1500000,
        ),
        LyricToken(id: 'b', text: 'em', index: 1, startUs: 1500000),
      ],
    );
    final renderer = KaraokeRenderer();
    expect(renderer.lineTimingAt(line, timeUs: 7000000), (1000000, 7000000));
    final finished = line.copyWith(
      tokens: [line.tokens.first, line.tokens.last.copyWith(endUs: 7000000)],
    );
    expect(renderer.lineTimingAt(finished, timeUs: 8000000), (
      1000000,
      7000000,
    ));
  });
  testWidgets(
    'later words reuse shaped text instead of relayout on every frame',
    (tester) async {
      final renderer = KaraokeRenderer();
      final project = ProjectModel.create('cached').copyWith(
        settings: const ProjectSettings(layoutMode: LayoutMode.singleRow),
        lyricLines: [
          LyricLine(
            id: 'line',
            text: 'một hai ba bốn năm sáu bảy tám',
            actorId: 'male',
            startUs: 1000000,
            endUs: 5000000,
            tokens: [
              for (final (i, word)
                  in 'một hai ba bốn năm sáu bảy tám'.split(' ').indexed)
                LyricToken(
                  id: 't$i',
                  text: word,
                  index: i,
                  startUs: 1000000 + i * 500000,
                  endUs: 1500000 + i * 500000,
                ),
            ],
          ),
        ],
      );
      void frame(int time) {
        final recorder = ui.PictureRecorder();
        renderer.render(
          canvas: ui.Canvas(recorder),
          canvasSize: const ui.Size(960, 540),
          project: project,
          timeUs: time,
        );
        recorder.endRecording().dispose();
      }

      frame(1100000);
      final pictures = renderer.textPictureBuildCount;
      for (var time = 1116667; time < 4900000; time += 16667) {
        frame(time);
      }
      expect(renderer.layoutBuildCount, 1);
      expect(renderer.textPictureBuildCount, pictures);
      renderer.clearCache();
    },
  );
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
