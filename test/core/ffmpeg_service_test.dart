import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:karastudio/core/ffmpeg/ffmpeg_service.dart';

void main() {
  test('probes a real generated audio file', () async {
    final directory = await Directory.systemTemp.createTemp(
      'karastudio-audio-test-',
    );
    final audioPath = '${directory.path}/sample.wav';
    try {
      final generated = await Process.run('ffmpeg', [
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

      final service = FfmpegService();
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
}
