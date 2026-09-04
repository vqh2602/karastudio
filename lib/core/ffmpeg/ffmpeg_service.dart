import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../models/project_model.dart';
import '../../models/audio_effects.dart';
import '../waveform/waveform_cache.dart';

class FfmpegException implements Exception {
  const FfmpegException(this.message, {this.command, this.stderr});
  final String message;
  final String? command;
  final String? stderr;

  @override
  String toString() => message;
}

class FfmpegService {
  FfmpegService({this.ffmpegPath = 'ffmpeg', this.ffprobePath = 'ffprobe'});

  final String ffmpegPath;
  final String ffprobePath;
  String? _resolvedFfmpeg;
  String? _resolvedFfprobe;

  Future<String> _resolveExecutable(String configured, String name) async {
    final pathEnv = Platform.environment['PATH'] ?? '';
    final separator = Platform.isWindows ? ';' : ':';
    final pathDirs = pathEnv.split(separator).where((d) => d.trim().isNotEmpty);

    final candidates = <String>{
      configured,
      if (Platform.isMacOS) '/opt/homebrew/bin/$name',
      if (Platform.isMacOS) '/opt/homebrew/opt/ffmpeg/bin/$name',
      if (Platform.isMacOS) '/usr/local/bin/$name',
      if (Platform.isMacOS) '/usr/bin/$name',
      if (Platform.isLinux) '/usr/bin/$name',
      if (Platform.isLinux) '/usr/local/bin/$name',
      if (Platform.isWindows) 'C:\\Program Files\\ffmpeg\\bin\\$name.exe',
      if (Platform.isWindows) 'C:\\ffmpeg\\bin\\$name.exe',
      for (final dir in pathDirs)
        p.join(dir, Platform.isWindows ? '$name.exe' : name),
    };

    for (final candidate in candidates) {
      if (candidate.isEmpty) continue;
      try {
        if (File(candidate).existsSync()) {
          final result = await Process.run(candidate, ['-version']);
          if (result.exitCode == 0) return candidate;
        } else if (!candidate.contains(Platform.pathSeparator)) {
          // If pure command name without path
          final result = await Process.run(candidate, ['-version']);
          if (result.exitCode == 0) return candidate;
        }
      } on ProcessException {
        continue;
      } catch (_) {
        continue;
      }
    }
    throw FfmpegException(
      'Không tìm thấy $name. Hãy cài FFmpeg (ví dụ brew install ffmpeg trên macOS) hoặc cấu hình đường dẫn trong Settings.',
    );
  }

  Future<String> getFfmpegPath() async =>
      _resolvedFfmpeg ??= await _resolveExecutable(ffmpegPath, 'ffmpeg');

  Future<String> getFfprobePath() async =>
      _resolvedFfprobe ??= await _resolveExecutable(ffprobePath, 'ffprobe');

  Future<void> verifyAvailable() async {
    await getFfmpegPath();
    await getFfprobePath();
  }

  Future<MediaAsset> probeAudio(String filePath) async {
    final executable = await getFfprobePath();
    final args = [
      '-v',
      'error',
      '-show_entries',
      'format=duration:format_tags:stream=index,codec_type,codec_name,sample_rate,channels',
      '-of',
      'json',
      filePath,
    ];
    late ProcessResult result;
    try {
      result = await Process.run(executable, args);
    } on ProcessException catch (error) {
      throw FfmpegException('Không tìm thấy FFprobe: ${error.message}');
    }
    if (result.exitCode != 0) {
      throw FfmpegException(
        'FFmpeg không thể đọc tệp âm thanh.',
        command: '$executable ${args.join(' ')}',
        stderr: result.stderr.toString(),
      );
    }
    final root = (jsonDecode(result.stdout as String) as Map)
        .cast<String, Object?>();
    final streams = (root['streams'] as List?) ?? const [];
    final audio = streams
        .cast<Map>()
        .map((item) => item.cast<String, Object?>())
        .where((stream) => stream['codec_type'] == 'audio');
    if (audio.isEmpty) {
      throw const FfmpegException('Tệp đã chọn không có audio stream.');
    }
    final stream = audio.first;
    final format = ((root['format'] as Map?) ?? const {})
        .cast<String, Object?>();
    final durationSeconds =
        double.tryParse(format['duration']?.toString() ?? '') ?? 0;
    final tags = ((format['tags'] as Map?) ?? const {})
        .cast<Object?, Object?>();
    return MediaAsset(
      id: newId('audio'),
      type: MediaType.audio,
      path: filePath,
      durationUs: (durationSeconds * Duration.microsecondsPerSecond).round(),
      sampleRate: int.tryParse(stream['sample_rate']?.toString() ?? ''),
      channels: (stream['channels'] as num?)?.toInt(),
      codec: stream['codec_name'] as String?,
      metadata: {
        for (final entry in tags.entries)
          entry.key.toString().toLowerCase(): entry.value.toString(),
      },
    );
  }

  Future<MediaAsset> probeVideo(String filePath) async {
    final executable = await getFfprobePath();
    final args = [
      '-v',
      'error',
      '-show_entries',
      'format=duration:format_tags:stream=codec_type,codec_name,width,height,avg_frame_rate',
      '-of',
      'json',
      filePath,
    ];
    late ProcessResult result;
    try {
      result = await Process.run(executable, args);
    } on ProcessException catch (error) {
      throw FfmpegException('Không tìm thấy FFprobe: ${error.message}');
    }
    if (result.exitCode != 0) {
      throw FfmpegException(
        'FFmpeg không thể đọc tệp video.',
        command: '$executable ${args.join(' ')}',
        stderr: result.stderr.toString(),
      );
    }
    final root = (jsonDecode(result.stdout as String) as Map)
        .cast<String, Object?>();
    final streams = ((root['streams'] as List?) ?? const []).cast<Map>().map(
      (item) => item.cast<String, Object?>(),
    );
    final videos = streams.where((stream) => stream['codec_type'] == 'video');
    if (videos.isEmpty) {
      throw const FfmpegException('Tệp đã chọn không có video stream.');
    }
    final stream = videos.first;
    final format = ((root['format'] as Map?) ?? const {})
        .cast<String, Object?>();
    final durationSeconds =
        double.tryParse(format['duration']?.toString() ?? '') ?? 0;
    final tags = ((format['tags'] as Map?) ?? const {})
        .cast<Object?, Object?>();
    return MediaAsset(
      id: newId('video'),
      type: MediaType.video,
      path: filePath,
      durationUs: (durationSeconds * Duration.microsecondsPerSecond).round(),
      codec: stream['codec_name'] as String?,
      metadata: {
        for (final entry in tags.entries)
          entry.key.toString().toLowerCase(): entry.value.toString(),
        if (stream['width'] != null) 'width': stream['width'].toString(),
        if (stream['height'] != null) 'height': stream['height'].toString(),
        if (stream['avg_frame_rate'] != null)
          'frameRate': stream['avg_frame_rate'].toString(),
      },
    );
  }

  Future<String> waveformCachePath(String audioPath) async {
    final stat = await File(audioPath).stat();
    final key = sha1
        .convert(
          utf8.encode(
            '$audioPath|${stat.size}|${stat.modified.microsecondsSinceEpoch}',
          ),
        )
        .toString();
    final support = await getApplicationSupportDirectory();
    return p.join(support.path, 'waveforms', '$key.waveform.json');
  }

  Future<WaveformCache> loadOrGenerateWaveform(
    MediaAsset asset, {
    void Function(double progress)? onProgress,
  }) async {
    final cachePath =
        asset.waveformCachePath ?? await waveformCachePath(asset.path);
    final cached = File(cachePath);
    if (await cached.exists()) {
      try {
        return await WaveformCache.read(cachePath);
      } catch (_) {
        // Regenerate corrupt caches from the source media.
      }
    }
    final waveform = await _generateWaveform(asset, onProgress: onProgress);
    await waveform.write(cachePath);
    return waveform;
  }

  Future<WaveformCache> _generateWaveform(
    MediaAsset asset, {
    void Function(double progress)? onProgress,
  }) async {
    const outputRate = 8000;
    const samplesPerPeak = 80;
    const baseIntervalUs = 10000;
    final executable = await getFfmpegPath();
    final args = [
      '-v',
      'error',
      '-i',
      asset.path,
      '-map',
      '0:a:0',
      '-ac',
      '1',
      '-ar',
      '$outputRate',
      '-f',
      'f32le',
      'pipe:1',
    ];
    late Process process;
    try {
      process = await Process.start(executable, args);
    } on ProcessException catch (error) {
      throw FfmpegException('Không thể chạy FFmpeg: ${error.message}');
    }

    final stderrFuture = utf8.decoder.bind(process.stderr).join();
    final peaks = <double>[];
    var carry = Uint8List(0);
    var peak = 0.0;
    var samplesInPeak = 0;
    var totalSamples = 0;

    await for (final chunk in process.stdout) {
      final combined = Uint8List(carry.length + chunk.length)
        ..setRange(0, carry.length, carry)
        ..setRange(carry.length, carry.length + chunk.length, chunk);
      final completeLength = combined.length - (combined.length % 4);
      final data = ByteData.sublistView(combined, 0, completeLength);
      for (var offset = 0; offset < completeLength; offset += 4) {
        final value = data
            .getFloat32(offset, Endian.little)
            .abs()
            .clamp(0.0, 1.0);
        if (value > peak) peak = value;
        samplesInPeak++;
        totalSamples++;
        if (samplesInPeak == samplesPerPeak) {
          peaks.add(peak);
          peak = 0;
          samplesInPeak = 0;
        }
      }
      carry = Uint8List.fromList(combined.sublist(completeLength));
      if (asset.durationUs > 0) {
        final decodedUs =
            totalSamples * Duration.microsecondsPerSecond / outputRate;
        onProgress?.call((decodedUs / asset.durationUs).clamp(0.0, 1.0));
      }
    }
    if (samplesInPeak > 0) peaks.add(peak);
    final exitCode = await process.exitCode;
    final stderr = await stderrFuture;
    if (exitCode != 0) {
      throw FfmpegException(
        'Tạo waveform thất bại.',
        command: '$executable ${args.join(' ')}',
        stderr: stderr,
      );
    }
    if (peaks.isEmpty) {
      throw const FfmpegException('Audio không chứa mẫu âm thanh.');
    }

    final levels = <List<double>>[List.unmodifiable(peaks)];
    var current = peaks;
    while (current.length > 1000) {
      final next = <double>[];
      for (var index = 0; index < current.length; index += 2) {
        next.add(
          index + 1 < current.length
              ? (current[index] > current[index + 1]
                    ? current[index]
                    : current[index + 1])
              : current[index],
        );
      }
      levels.add(List.unmodifiable(next));
      current = next;
    }
    onProgress?.call(1);
    return WaveformCache(
      durationUs: asset.durationUs,
      baseIntervalUs: baseIntervalUs,
      levels: List.unmodifiable(levels),
    );
  }

  /// Khởi tạo Process FFmpeg để nhận các raw RGBA frame qua stdin và encode video
  Future<Process> startRawRgbaVideoEncoder({
    required String outputPath,
    required int width,
    required int height,
    required double fps,
    String? audioPath,
    String? backgroundVideoPath,
    AudioEffects audioEffects = const AudioEffects(),
    int startUs = 0,
    bool isTransparent = false,
    String format = 'mp4', // 'mp4', 'mov', 'webm'
  }) async {
    final executable = await getFfmpegPath();
    final args = <String>[
      '-y',
      '-v',
      'warning',
      '-f',
      'rawvideo',
      '-pix_fmt',
      'rgba',
      '-s',
      '${width}x$height',
      '-r',
      fps.toString(),
      '-i',
      'pipe:0', // Read raw RGBA frames from stdin
    ];

    final hasBackgroundVideo =
        !isTransparent &&
        backgroundVideoPath != null &&
        await File(backgroundVideoPath).exists();
    final hasAudio = audioPath != null && await File(audioPath).exists();
    final startSeconds = (startUs / Duration.microsecondsPerSecond)
        .toStringAsFixed(6);

    if (hasBackgroundVideo) {
      args.addAll([
        '-stream_loop',
        '-1',
        '-ss',
        startSeconds,
        '-i',
        backgroundVideoPath,
      ]);
    }

    if (hasAudio) {
      args.addAll(['-ss', startSeconds, '-i', audioPath]);
    }

    if (hasBackgroundVideo) {
      args.addAll([
        '-filter_complex',
        '[1:v]setpts=(PTS-STARTPTS)/${audioEffects.speed},scale=$width:$height:force_original_aspect_ratio=increase,'
            'crop=$width:$height,setsar=1[background];'
            '[background][0:v]overlay=0:0:shortest=1:format=auto[video]',
        '-map',
        '[video]',
      ]);
    } else {
      args.addAll(['-map', '0:v:0']);
    }

    if (hasAudio) {
      args.addAll(['-map', '${hasBackgroundVideo ? 2 : 1}:a:0?']);
      if (audioEffects.exportFilterGraph.isNotEmpty) {
        args.addAll(['-af', audioEffects.exportFilterGraph]);
      }
    }

    if (isTransparent) {
      if (format == 'mov') {
        // Apple ProRes 4444 with Alpha Channel
        args.addAll([
          '-c:v',
          'prores_ks',
          '-profile:v',
          '4',
          '-pix_fmt',
          'yuva444p10le',
        ]);
      } else if (format == 'webm') {
        // WebM VP9 with Alpha
        args.addAll([
          '-c:v',
          'libvpx-vp9',
          '-pix_fmt',
          'yuva420p',
          '-b:v',
          '0',
          '-crf',
          '18',
        ]);
      } else {
        // Fallback transparent MOV
        args.addAll(['-c:v', 'png', '-pix_fmt', 'rgba']);
      }
    } else {
      // Standard MP4 H.264
      args.addAll([
        '-c:v',
        'libx264',
        '-pix_fmt',
        'yuv420p',
        '-preset',
        'medium',
        '-crf',
        '18',
      ]);
    }

    if (hasAudio) {
      args.addAll(['-c:a', 'aac', '-b:a', '320k', '-shortest']);
    }

    args.add(outputPath);

    try {
      return await Process.start(executable, args);
    } on ProcessException catch (error) {
      throw FfmpegException(
        'Không thể bắt đầu encoder FFmpeg: ${error.message}',
      );
    }
  }
}
