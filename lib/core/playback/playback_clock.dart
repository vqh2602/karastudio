import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../models/audio_effects.dart';
import 'source_time.dart';

class PlaybackClock extends ChangeNotifier {
  PlaybackClock()
    : player = Player(configuration: const PlayerConfiguration()),
      videoPlayer = Player(
        configuration: const PlayerConfiguration(
          muted: true,
          bufferSize: 8 * 1024 * 1024,
        ),
      ) {
    videoController = VideoController(
      videoPlayer,
      configuration: const VideoControllerConfiguration(
        // Preview does not need the source's full 4K/8K texture. Decoding to a
        // half-size texture cuts GPU upload and composition work substantially.
        scale: 0.5,
        enableHardwareAcceleration: true,
      ),
    );

    _subscriptions.add(
      player.stream.position.listen((value) {
        if (mediaPath != null) {
          position = value;
          _anchorPosition = value;
          _interpolationStopwatch.reset();
          if (isPlaying) _interpolationStopwatch.start();
          _requestVideoSync(value);
          notifyListeners();
        }
      }),
    );
    _subscriptions.add(
      videoPlayer.stream.position.listen((value) {
        if (mediaPath == null && videoPath != null) {
          position = value;
          _anchorPosition = value;
          _interpolationStopwatch.reset();
          if (isPlaying) _interpolationStopwatch.start();
          notifyListeners();
        }
      }),
    );

    _subscriptions.add(
      player.stream.duration.listen((value) {
        if (mediaPath != null) {
          duration = value;
          notifyListeners();
        }
      }),
    );
    _subscriptions.add(
      videoPlayer.stream.duration.listen((value) {
        videoDuration = value;
        if (mediaPath == null && videoPath != null) {
          duration = value;
          notifyListeners();
        }
      }),
    );

    _subscriptions.add(
      player.stream.playing.listen((value) {
        if (mediaPath != null) {
          isPlaying = value;
          _anchorPosition = position;
          _interpolationStopwatch.reset();
          if (value) {
            _interpolationStopwatch.start();
          } else {
            _interpolationStopwatch.stop();
          }
          notifyListeners();
        }
      }),
    );
    _subscriptions.add(
      videoPlayer.stream.playing.listen((value) {
        if (mediaPath == null && videoPath != null) {
          isPlaying = value;
          _anchorPosition = position;
          _interpolationStopwatch.reset();
          if (value) {
            _interpolationStopwatch.start();
          } else {
            _interpolationStopwatch.stop();
          }
          notifyListeners();
        }
      }),
    );

    _subscriptions.add(
      player.stream.buffering.listen((value) {
        if (mediaPath != null && value != isBuffering) {
          position = Duration(microseconds: precisePositionUs);
          _anchorPosition = position;
          _interpolationStopwatch.reset();
        }
        isBuffering = value;
        notifyListeners();
      }),
    );

    _subscriptions.add(
      videoPlayer.stream.buffering.listen((value) {
        if (mediaPath == null && value != isVideoBuffering) {
          position = Duration(microseconds: precisePositionUs);
          _anchorPosition = position;
          _interpolationStopwatch.reset();
        }
        isVideoBuffering = value;
        notifyListeners();
      }),
    );

    _subscriptions.add(
      videoPlayer.stream.videoParams.listen((value) {
        if (value.w != null && value.h != null) {
          videoWidth = value.dw ?? value.w;
          videoHeight = value.dh ?? value.h;
          isVideoReady = true;
          videoError = null;
          notifyListeners();
        }
      }),
    );

    _subscriptions.add(
      videoPlayer.stream.error.listen((value) {
        videoError = value;
        isVideoReady = false;
        notifyListeners();
      }),
    );

    _subscriptions.add(
      player.stream.rate.listen((value) {
        _anchorPosition = Duration(microseconds: precisePositionUs);
        position = _anchorPosition;
        _interpolationStopwatch.reset();
        speed = value;
        notifyListeners();
      }),
    );
  }

  final Player player;
  final Player videoPlayer;
  late final VideoController videoController;
  final List<StreamSubscription<Object?>> _subscriptions = [];
  Duration position = Duration.zero;
  Duration duration = Duration.zero;
  Duration videoDuration = Duration.zero;
  bool isPlaying = false;
  bool isBuffering = false;
  bool isVideoBuffering = false;
  bool isVideoReady = false;
  double speed = 1;
  int? videoWidth;
  int? videoHeight;
  String? videoError;
  String? mediaPath;
  String? videoPath;
  bool _videoSyncInFlight = false;
  DateTime _lastVideoSyncAt = DateTime.fromMillisecondsSinceEpoch(0);
  final Stopwatch _interpolationStopwatch = Stopwatch();
  Duration _anchorPosition = Duration.zero;

  static const _videoDriftTolerance = Duration(milliseconds: 500);
  static const _videoSyncInterval = Duration(seconds: 2);

  int get positionUs => precisePositionUs;

  int get precisePositionUs {
    if (!isPlaying) {
      return position.inMicroseconds;
    }
    final totalUs = estimateSourceTime(
      anchorUs: _anchorPosition.inMicroseconds,
      elapsedWallUs: _interpolationStopwatch.elapsedMicroseconds,
      speed: speed,
      advancing: !(mediaPath != null ? isBuffering : isVideoBuffering),
    );
    final maxUs = duration.inMicroseconds;
    if (maxUs > 0 && totalUs > maxUs) return maxUs;
    return math.max(0, totalUs);
  }

  int get durationUs => duration.inMicroseconds;

  Future<void> open(String path) async {
    mediaPath = path;
    await player.open(Media(path), play: false);
    await player.setRate(speed);
    if (position > Duration.zero) {
      await player.seek(position);
    }
    _anchorPosition = position;
    _interpolationStopwatch.reset();
    notifyListeners();
  }

  Future<void> openVideo(String path) async {
    if (videoPath == path && videoPlayer.state.duration > Duration.zero) {
      await _synchronizeVideo(position, force: true);
      return;
    }
    videoPath = path;
    videoError = null;
    isVideoReady = false;
    videoWidth = null;
    videoHeight = null;
    videoDuration = Duration.zero;
    notifyListeners();

    await videoPlayer.open(Media(path), play: false);
    await videoPlayer.setRate(speed);
    await videoPlayer.setPlaylistMode(PlaylistMode.loop);
    await _synchronizeVideo(position, force: true);

    // Warm up the first frame without blocking import/project opening. The
    // preview keeps showing its loading state until the texture is ready.
    unawaited(_warmUpVideoFrame(path));
  }

  Future<void> _warmUpVideoFrame(String path) async {
    if (videoPath != path) return;
    if (!videoPlayer.state.playing) await videoPlayer.play();
    try {
      await videoController.waitUntilFirstFrameRendered.timeout(
        const Duration(milliseconds: 1200),
      );
      if (videoPath != path) return;
      isVideoReady = true;
    } on TimeoutException {
      if (videoPath != path) return;
      isVideoReady = videoPlayer.state.videoParams.w != null;
    }
    if (videoPath == path && !isPlaying) {
      await videoPlayer.pause();
    }
    notifyListeners();
  }

  Future<void> closeVideo() async {
    await videoPlayer.stop();
    videoPath = null;
    videoDuration = Duration.zero;
    isVideoReady = false;
    isVideoBuffering = false;
    videoWidth = null;
    videoHeight = null;
    videoError = null;
    notifyListeners();
  }

  Future<void> closeAudio() async {
    await player.stop();
    mediaPath = null;
    if (videoPath != null) {
      position = videoPlayer.state.position;
      duration = videoDuration;
      isPlaying = videoPlayer.state.playing;
    } else {
      position = Duration.zero;
      duration = Duration.zero;
      isPlaying = false;
    }
    notifyListeners();
  }

  Future<void> toggle() => isPlaying ? pause() : play();

  Future<void> play() async {
    _anchorPosition = position;
    _interpolationStopwatch.reset();
    _interpolationStopwatch.stop();
    if (mediaPath != null && videoPath != null) {
      await _synchronizeVideo(position, force: true);
    }
    if (mediaPath != null) {
      await player.play();
    }
    if (videoPath != null) {
      await videoPlayer.play();
    }
    if (mediaPath == null && videoPath != null) {
      isPlaying = true;
      _interpolationStopwatch.reset();
      _interpolationStopwatch.start();
      notifyListeners();
    }
  }

  Future<void> pause() async {
    _interpolationStopwatch.stop();
    if (mediaPath != null) {
      await player.pause();
    }
    if (videoPath != null) {
      await videoPlayer.pause();
    }
    if (mediaPath == null && videoPath != null) {
      isPlaying = false;
      notifyListeners();
    }
  }

  Future<void> stop() async {
    _interpolationStopwatch.stop();
    _anchorPosition = Duration.zero;
    if (mediaPath != null) {
      await player.pause();
    }
    if (videoPath != null) {
      await videoPlayer.pause();
      await videoPlayer.seek(Duration.zero);
    }
    await seek(Duration.zero);
    isPlaying = false;
    notifyListeners();
  }

  Future<void> seek(Duration value) async {
    final bounded = value < Duration.zero
        ? Duration.zero
        : (duration > Duration.zero && value > duration ? duration : value);
    position = bounded;
    _anchorPosition = bounded;
    _interpolationStopwatch.reset();
    if (isPlaying) _interpolationStopwatch.start();
    if (mediaPath != null) {
      await player.seek(bounded);
    }
    if (videoPath != null) {
      await _synchronizeVideo(bounded, force: true);
    }
    notifyListeners();
  }

  Future<void> setSpeed(double value) async {
    final anchor = positionUs;
    position = Duration(microseconds: anchor);
    _anchorPosition = position;
    _interpolationStopwatch.reset();
    value = value.clamp(0.25, 4.0);
    speed = value;
    if (mediaPath != null) {
      await player.setRate(value);
    }
    if (videoPath != null) {
      await videoPlayer.setRate(value);
    }
    notifyListeners();
  }

  Future<void> applyAudioEffects(AudioEffects effects) async {
    final native = player.platform;
    if (native is! NativePlayer) {
      throw UnsupportedError('Hiệu ứng âm thanh cần bộ phát desktop.');
    }
    await native.setProperty('af', effects.mpvFilters);
    final applied = await native.getProperty('af');
    if (effects.mpvFilters.isNotEmpty && !applied.contains('lavfi')) {
      throw StateError('Bộ phát chưa hỗ trợ bộ lọc âm thanh.');
    }
    await setSpeed(effects.speed);
  }

  Future<void> closeMedia() async {
    await applyAudioEffects(const AudioEffects());
    await player.stop();
    await videoPlayer.stop();
    mediaPath = null;
    videoPath = null;
    position = Duration.zero;
    duration = Duration.zero;
    videoDuration = Duration.zero;
    isVideoReady = false;
    isVideoBuffering = false;
    videoError = null;
    notifyListeners();
  }

  void _requestVideoSync(Duration masterPosition) {
    if (videoPath == null || mediaPath == null || _videoSyncInFlight) return;
    final now = DateTime.now();
    if (now.difference(_lastVideoSyncAt) < _videoSyncInterval) return;
    final target = _normalizedVideoPosition(masterPosition);
    final drift = (videoPlayer.state.position - target).abs();
    if (drift >= _videoDriftTolerance) {
      unawaited(_synchronizeVideo(masterPosition));
    }
  }

  Future<void> _synchronizeVideo(
    Duration masterPosition, {
    bool force = false,
  }) async {
    if (videoPath == null || _videoSyncInFlight) return;
    final target = _normalizedVideoPosition(masterPosition);
    if (!force &&
        (videoPlayer.state.position - target).abs() < _videoDriftTolerance) {
      return;
    }
    _videoSyncInFlight = true;
    _lastVideoSyncAt = DateTime.now();
    try {
      await videoPlayer.seek(target);
    } finally {
      _videoSyncInFlight = false;
    }
  }

  Duration _normalizedVideoPosition(Duration masterPosition) {
    final availableDuration = videoDuration > Duration.zero
        ? videoDuration
        : videoPlayer.state.duration;
    if (availableDuration <= Duration.zero ||
        masterPosition <= availableDuration) {
      return masterPosition;
    }
    return Duration(
      microseconds:
          masterPosition.inMicroseconds % availableDuration.inMicroseconds,
    );
  }

  @override
  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await player.dispose();
    await videoPlayer.dispose();
    super.dispose();
  }
}
