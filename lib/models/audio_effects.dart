import 'dart:math' as math;

/// Non-destructive audio settings shared by playback and video export.
class AudioEffects {
  const AudioEffects({
    this.semitones = 0,
    this.reverb = 0,
    this.tuningHz = 440,
    this.speed = 1,
  });

  final int semitones;
  final double reverb;
  final double tuningHz;
  final double speed;

  bool get hasPitchOrReverb =>
      semitones != 0 || reverb > 0 || (tuningHz - 440).abs() >= 0.01;

  double get pitchRatio => math.pow(2, semitones / 12) * tuningHz / 440;

  String get filterGraph {
    final filters = <String>[];
    if ((pitchRatio - 1).abs() > 0.000001) {
      final tempo = math.sqrt(1 / pitchRatio).toStringAsFixed(8);
      filters.addAll([
        'aresample=sample_rate=48000',
        'asetrate=sample_rate=${(48000 * pitchRatio).round()}',
        'aresample=sample_rate=48000',
        'atempo=tempo=$tempo',
        'atempo=tempo=$tempo',
      ]);
    }
    if (reverb > 0) {
      final wet = reverb.clamp(0, 100) / 100;
      final decays = [
        0.28,
        0.20,
        0.14,
        0.09,
      ].map((decay) => (decay * wet).toStringAsFixed(4)).join('|');
      filters.add(
        'aecho=in_gain=0.7:out_gain=0.8:delays=37|61|89|127:decays=$decays',
      );
    }
    return filters.join(',');
  }

  String get mpvFilters => filterGraph.isEmpty ? '' : 'lavfi=[$filterGraph]';

  String get exportFilterGraph => [
    if (filterGraph.isNotEmpty) filterGraph,
    if (speed != 1) ...[
      'atempo=tempo=${math.sqrt(speed).toStringAsFixed(8)}',
      'atempo=tempo=${math.sqrt(speed).toStringAsFixed(8)}',
    ],
  ].join(',');

  Map<String, Object?> toJson() => {
    'semitones': semitones,
    'reverb': reverb,
    'tuningHz': tuningHz,
    'speed': speed,
  };

  factory AudioEffects.fromJson(Map<String, Object?> json) => AudioEffects(
    speed: ((json['speed'] as num?)?.toDouble() ?? 1).clamp(0.25, 4),
    semitones: ((json['semitones'] as num?)?.toInt() ?? 0).clamp(-12, 12),
    reverb: ((json['reverb'] as num?)?.toDouble() ?? 0).clamp(0, 100),
    tuningHz: ((json['tuningHz'] as num?)?.toDouble() ?? 440).clamp(
      415.3,
      466.2,
    ),
  );
}
