import 'package:flutter_test/flutter_test.dart';
import 'package:karastudio/core/playback/source_time.dart';

void main() {
  for (final speed in [0.25, 0.5, 0.75, 1.0, 1.25, 2.0, 4.0]) {
    test('source position and input latency at $speed x', () {
      expect(
        estimateSourceTime(
          anchorUs: 10000000,
          elapsedWallUs: 100000,
          speed: speed,
          advancing: true,
        ),
        10000000 + (100000 * speed).round(),
      );
      expect(
        recordingSourceTime(
          sourcePositionUs: 10000000,
          speed: speed,
          inputOffsetMs: -80,
        ),
        10000000 - (80000 * speed).round(),
      );
    });
  }
  test(
    'buffering freezes time but sparse position events do not freeze playback',
    () {
      expect(
        estimateSourceTime(
          anchorUs: 10000000,
          elapsedWallUs: 5000000,
          speed: 2,
          advancing: false,
        ),
        10000000,
      );
      expect(
        estimateSourceTime(
          anchorUs: 10000000,
          elapsedWallUs: 5000000,
          speed: 2,
          advancing: true,
        ),
        20000000,
      );
    },
  );
}
