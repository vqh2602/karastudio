import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:karastudio/core/ffmpeg/ffmpeg_service.dart';
import 'package:karastudio/core/playback/playback_clock.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  testWidgets('renders and plays the first frame of a real MP4 on macOS', (
    tester,
  ) async {
    final service = FfmpegService();
    final ffmpeg = await service.getFfmpegPath();
    final directory = await Directory.systemTemp.createTemp(
      'karastudio-video-preview-',
    );
    final path = '${directory.path}/preview.mp4';
    final generated = await Process.run(ffmpeg, [
      '-y',
      '-v',
      'error',
      '-f',
      'lavfi',
      '-i',
      'testsrc2=size=640x360:rate=30:duration=2',
      '-c:v',
      'mpeg4',
      '-pix_fmt',
      'yuv420p',
      path,
    ]);
    expect(generated.exitCode, 0, reason: generated.stderr.toString());

    final clock = PlaybackClock();
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 640,
              height: 360,
              child: Video(
                controller: clock.videoController,
                controls: NoVideoControls,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await clock.openVideo(path);
      await tester.pump(const Duration(milliseconds: 250));

      expect(clock.videoError, isNull);
      expect(clock.isVideoReady, isTrue);
      expect(clock.videoWidth, 640);
      expect(clock.videoHeight, 360);

      await clock.play();
      await tester.pump(const Duration(milliseconds: 650));
      expect(clock.positionUs, greaterThan(0));
      await clock.pause();
    } finally {
      await clock.dispose();
      await directory.delete(recursive: true);
    }
  });
}
