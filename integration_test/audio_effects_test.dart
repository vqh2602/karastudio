import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:karastudio/core/ffmpeg/ffmpeg_service.dart';
import 'package:karastudio/core/playback/playback_clock.dart';
import 'package:karastudio/models/audio_effects.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  testWidgets('native player accepts pitch and echo monitoring filters', (
    tester,
  ) async {
    final dir = await Directory.systemTemp.createTemp('kara-fx-test-');
    final file = '${dir.path}/tone.wav';
    final ffmpeg = await FfmpegService().getFfmpegPath();
    final result = await Process.run(ffmpeg, [
      '-v',
      'error',
      '-f',
      'lavfi',
      '-i',
      'sine=frequency=440:duration=3',
      file,
    ]);
    expect(result.exitCode, 0);
    final clock = PlaybackClock();
    try {
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pump();
      await clock.open(file);
      final processedPath = await FfmpegService().renderProcessedAudio(
        file,
        const AudioEffects(semitones: -3, reverb: 25),
      );
      expect(File(processedPath).existsSync(), isTrue);
      await clock.switchAudioSource(processedPath);
      await clock.play();
      await Future<void>.delayed(const Duration(milliseconds: 500));
      expect(clock.isPlaying, isTrue);
      await clock.pause();
      await clock.switchAudioSource(file);
      final native = clock.player.platform as NativePlayer;
      for (final speed in [0.5, 0.75, 1.25, 2.0]) {
        await clock.pause();
        await clock.seek(Duration.zero);
        await clock.setSpeed(speed);
        await clock.play();
        await Future<void>.delayed(const Duration(milliseconds: 200));
        final before = double.parse(await native.getProperty('time-pos'));
        final elapsed = Stopwatch()..start();
        await Future<void>.delayed(const Duration(milliseconds: 700));
        final after = double.parse(await native.getProperty('time-pos'));
        final wallSeconds = elapsed.elapsedMicroseconds / 1000000;
        expect(
          after - before,
          closeTo(wallSeconds * speed, 0.2),
          reason: 'Native source clock at $speed x',
        );
        expect(
          clock.positionUs / 1000000,
          closeTo(after, 0.3),
          reason: 'Recording clock at $speed x',
        );
      }
      await clock.pause();
    } finally {
      await clock.dispose();
      await dir.delete(recursive: true);
    }
  });
}
