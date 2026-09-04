import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:karastudio/core/ffmpeg/ffmpeg_service.dart';

void main() {
  test('probes a real generated audio file', () async {
    final service = FfmpegService();
    String ffmpegPath;
    try {
      ffmpegPath = await service.getFfmpegPath();
    } catch (_) {
      // Skip if ffmpeg is not installed on this test environment
      return;
    }

    final directory = await Directory.systemTemp.createTemp(
      'karastudio-audio-test-',
    );
    final audioPath = '${directory.path}/sample.wav';
    try {
      final generated = await Process.run(ffmpegPath, [
        '-v',
        'error',
        '-f',
        'lavfi',
        '-i',
        'sine=frequency=440:duration=0.25',
        '-ar',
        '48000',
        '-ac',
        '2',
        audioPath,
      ]);
      expect(generated.exitCode, 0, reason: generated.stderr.toString());

      final asset = await service.probeAudio(audioPath);

      expect(asset.durationUs, closeTo(250000, 2000));
      expect(asset.sampleRate, 48000);
      expect(asset.channels, 2);
      expect(asset.codec, 'pcm_s16le');

      final waveform = await service.loadOrGenerateWaveform(
        asset.copyWith(
          waveformCachePath: '${directory.path}/sample.waveform.json',
        ),
      );
      expect(waveform.baseIntervalUs, 10000);
      expect(waveform.levels.first.length, inInclusiveRange(24, 26));
      expect(waveform.levels.first.any((peak) => peak > 0), isTrue);
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('probes a real generated song video', () async {
    final service = FfmpegService();
    String ffmpegPath;
    try {
      ffmpegPath = await service.getFfmpegPath();
    } catch (_) {
      return;
    }

    final directory = await Directory.systemTemp.createTemp(
      'karastudio-video-test-',
    );
    final videoPath = '${directory.path}/sample.mp4';
    try {
      final generated = await Process.run(ffmpegPath, [
        '-v',
        'error',
        '-f',
        'lavfi',
        '-i',
        'color=c=blue:s=320x180:d=0.3',
        '-f',
        'lavfi',
        '-i',
        'sine=frequency=440:duration=0.3',
        '-shortest',
        '-c:v',
        'mpeg4',
        '-pix_fmt',
        'yuv420p',
        '-c:a',
        'aac',
        videoPath,
      ]);
      expect(generated.exitCode, 0, reason: generated.stderr.toString());

      final asset = await service.probeVideo(videoPath);

      expect(asset.durationUs, closeTo(300000, 50000));
      expect(asset.codec, 'mpeg4');
      expect(asset.metadata['width'], '320');
      expect(asset.metadata['height'], '180');
    } finally {
      await directory.delete(recursive: true);
    }
  });
}
