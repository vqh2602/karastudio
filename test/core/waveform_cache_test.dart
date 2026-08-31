import 'package:flutter_test/flutter_test.dart';
import 'package:karastudio/core/waveform/waveform_cache.dart';

void main() {
  test('selects an appropriate peak resolution for zoom level', () {
    final cache = WaveformCache(
      durationUs: 80000,
      baseIntervalUs: 10000,
      levels: const [
        [.1, .2, .3, .4, .5, .6, .7, .8],
        [.2, .4, .6, .8],
        [.4, .8],
      ],
    );

    expect(cache.levelFor(80000, 2), const [.4, .8]);
    expect(cache.levelFor(20000, 2), cache.levels.first);
    expect(cache.intervalForLevel(cache.levels[1]), 20000);
  });
}
