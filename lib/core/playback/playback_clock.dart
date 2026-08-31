import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';

class PlaybackClock extends ChangeNotifier {
  PlaybackClock()
    : player = Player(configuration: const PlayerConfiguration()) {
    _subscriptions.add(
      player.stream.position.listen((value) {
        position = value;
        notifyListeners();
      }),
    );
    _subscriptions.add(
      player.stream.duration.listen((value) {
        duration = value;
        notifyListeners();
      }),
    );
    _subscriptions.add(
      player.stream.playing.listen((value) {
        isPlaying = value;
        notifyListeners();
      }),
    );
    _subscriptions.add(
      player.stream.buffering.listen((value) {
        isBuffering = value;
        notifyListeners();
      }),
    );
    _subscriptions.add(
      player.stream.rate.listen((value) {
        speed = value;
        notifyListeners();
      }),
    );
  }

  final Player player;
  final List<StreamSubscription<Object?>> _subscriptions = [];
  Duration position = Duration.zero;
  Duration duration = Duration.zero;
  bool isPlaying = false;
  bool isBuffering = false;
  double speed = 1;
  String? mediaPath;

  int get positionUs => position.inMicroseconds;
  int get durationUs => duration.inMicroseconds;

  Future<void> open(String path) async {
    mediaPath = path;
    await player.open(Media(path), play: false);
    await player.setRate(1);
  }

  Future<void> toggle() => isPlaying ? pause() : play();
  Future<void> play() => player.play();
  Future<void> pause() => player.pause();

  Future<void> stop() async {
    await player.pause();
    await seek(Duration.zero);
  }

  Future<void> seek(Duration value) async {
    final bounded = value < Duration.zero
        ? Duration.zero
        : (duration > Duration.zero && value > duration ? duration : value);
    await player.seek(bounded);
  }

  Future<void> setSpeed(double value) async {
    await player.setRate(value);
  }

  Future<void> closeMedia() async {
    await player.stop();
    mediaPath = null;
    position = Duration.zero;
    duration = Duration.zero;
    notifyListeners();
  }

  @override
  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await player.dispose();
    super.dispose();
  }
}
