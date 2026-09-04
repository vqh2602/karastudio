import 'dart:math' as math;

/// Non-destructive monitoring effects; source files and export stay unchanged.
class AudioEffects {
  const AudioEffects({
    this.semitones = 0,
    this.reverb = 0,
    this.tuningHz = 440,
  });

  final int semitones;
  final double reverb;
  final double tuningHz;

  double get pitchRatio => math.pow(2, semitones / 12) * tuningHz / 440;

  String get mpvFilters {
    final filters = <String>[];
    if ((pitchRatio - 1).abs() > 0.000001) {
      // Bundled libmpv does not include Rubber Band on all desktops.
      // Shift sample rate, then compensate tempo in two supported stages.
      final tempo = math.sqrt(1 / pitchRatio).toStringAsFixed(8);
      filters.addAll([
        'aresample=48000',
        'asetrate=${(48000 * pitchRatio).round()}',
        'aresample=48000',
        'atempo=$tempo',
        'atempo=$tempo',
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
      filters.add('aecho=0.7:0.8:37|61|89|127:$decays');
    }
    return filters.isEmpty ? '' : 'lavfi=[${filters.join(',')}]';
  }

  Map<String, Object?> toJson() => {
    'semitones': semitones,
    'reverb': reverb,
    'tuningHz': tuningHz,
  };

  factory AudioEffects.fromJson(Map<String, Object?> json) => AudioEffects(
    semitones: ((json['semitones'] as num?)?.toInt() ?? 0).clamp(-12, 12),
    reverb: ((json['reverb'] as num?)?.toDouble() ?? 0).clamp(0, 100),
    tuningHz: ((json['tuningHz'] as num?)?.toDouble() ?? 440).clamp(
      415.3,
      466.2,
    ),
  );
}
