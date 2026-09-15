// ignore_for_file: depend_on_referenced_packages

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:karastudio/core/ffmpeg/ffmpeg_service.dart';
import 'package:karastudio/models/audio_effects.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockPathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  MockPathProviderPlatform(this.path);
  final String path;

  @override
  Future<String?> getApplicationSupportPath() async => path;
}

void main() {
  test('video encoder applies pitch and speed to the exported audio', () async {
    final service = FfmpegService();
    final String ffmpeg;
    try {
      ffmpeg = await service.getFfmpegPath();
    } catch (_) {
      // Skip if ffmpeg is not installed on this test environment
      return;
    }
    final dir = await Directory.systemTemp.createTemp('kara-export-fx-');
    try {
      final audio = '${dir.path}/tone.wav';
      final output = '${dir.path}/out.mp4';
      final generated = await Process.run(ffmpeg, [
        '-v',
        'error',
        '-f',
        'lavfi',
        '-i',
        'sine=frequency=440:duration=2',
        audio,
      ]);
      expect(generated.exitCode, 0);
      final process = await service.startRawRgbaVideoEncoder(
        outputPath: output,
        width: 16,
        height: 16,
        fps: 10,
        audioPath: audio,
        audioEffects: const AudioEffects(semitones: 12, speed: 2),
      );
      final errors = process.stderr
          .transform(const SystemEncoding().decoder)
          .join();
      final stdoutDone = process.stdout.drain<void>();
      for (var i = 0; i < 10; i++) {
        process.stdin.add(Uint8List(16 * 16 * 4));
      }
      await process.stdin.close();
      expect(await process.exitCode, 0, reason: await errors);
      await stdoutDone;
      final metadata = await service.probeVideo(output);
      expect(metadata.durationUs, closeTo(1000000, 150000));
      final decoded = await Process.run(ffmpeg, [
        '-v',
        'error',
        '-i',
        output,
        '-ss',
        '0.2',
        '-t',
        '0.5',
        '-f',
        's16le',
        '-ac',
        '1',
        '-ar',
        '48000',
        'pipe:1',
      ], stdoutEncoding: null);
      expect(decoded.exitCode, 0);
      final bytes = ByteData.sublistView(
        Uint8List.fromList(decoded.stdout as List<int>),
      );
      var crossings = 0;
      for (var i = 2; i < bytes.lengthInBytes; i += 2) {
        if (bytes.getInt16(i - 2, Endian.little) <= 0 &&
            bytes.getInt16(i, Endian.little) > 0) {
          crossings++;
        }
      }
      final hz = crossings / (bytes.lengthInBytes / 2 / 48000);
      expect(hz, closeTo(880, 15));
    } finally {
      await dir.delete(recursive: true);
    }
  });
  test('renders processed audio with bass boost and caches result', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final service = FfmpegService();
    final String ffmpeg;
    try {
      ffmpeg = await service.getFfmpegPath();
    } catch (_) {
      // Skip if ffmpeg is not installed on this test environment
      return;
    }
    final dir = await Directory.systemTemp.createTemp('kara-bass-test-');
    PathProviderPlatform.instance = MockPathProviderPlatform(dir.path);
    try {
      final audio = '${dir.path}/tone.wav';
      final generated = await Process.run(ffmpeg, [
        '-v',
        'error',
        '-f',
        'lavfi',
        '-i',
        'sine=frequency=100:duration=1',
        audio,
      ]);
      expect(generated.exitCode, 0);
      final processed = await service.renderProcessedAudio(
        audio,
        const AudioEffects(bass: 10),
      );
      expect(File(processed).existsSync(), isTrue);
      expect(await File(processed).length(), greaterThan(0));
    } finally {
      await dir.delete(recursive: true);
    }
  });
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
