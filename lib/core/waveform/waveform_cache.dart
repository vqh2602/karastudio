import 'dart:convert';
import 'dart:io';

class WaveformCache {
  const WaveformCache({
    required this.durationUs,
    required this.baseIntervalUs,
    required this.levels,
  });

  final int durationUs;
  final int baseIntervalUs;
  final List<List<double>> levels;

  List<double> levelFor(int visibleDurationUs, double width) {
    if (levels.isEmpty || width <= 0) return const [];
    final targetInterval = visibleDurationUs / width;
    var index = 0;
    var interval = baseIntervalUs.toDouble();
    while (index + 1 < levels.length && interval < targetInterval) {
      index++;
      interval *= 2;
    }
    return levels[index];
  }

  int intervalForLevel(List<double> level) {
    final index = levels.indexOf(level);
    return baseIntervalUs * (1 << (index < 0 ? 0 : index));
  }

  Map<String, Object?> toJson() => {
    'version': 1,
    'durationUs': durationUs,
    'baseIntervalUs': baseIntervalUs,
    'levels': levels,
  };

  static WaveformCache fromJson(Map<String, Object?> json) => WaveformCache(
    durationUs: (json['durationUs'] as num).toInt(),
    baseIntervalUs: (json['baseIntervalUs'] as num).toInt(),
    levels: (json['levels'] as List)
        .map(
          (level) => (level as List)
              .map((peak) => (peak as num).toDouble())
              .toList(growable: false),
        )
        .toList(growable: false),
  );

  static Future<WaveformCache> read(String path) async {
    final value = jsonDecode(await File(path).readAsString());
    return fromJson((value as Map).cast());
  }

  Future<void> write(String path) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(toJson()), flush: true);
  }
}
