import 'package:flutter_test/flutter_test.dart';
import 'package:karastudio/models/audio_effects.dart';
import 'package:karastudio/models/project_model.dart';

void main() {
  test('export shares pitch and reverb, and compensates selected speed', () {
    const fx = AudioEffects(semitones: 12, reverb: 50, speed: 2);
    expect(fx.mpvFilters, 'lavfi=[${fx.filterGraph}]');
    expect(fx.exportFilterGraph, startsWith(fx.filterGraph));
    expect(fx.exportFilterGraph, contains('atempo=tempo=1.41421356'));
    expect(AudioEffects.fromJson(fx.toJson()).speed, 2);
  });
  test('pitch tuning uses semitone ratio without changing speed', () {
    expect(const AudioEffects(semitones: 12).pitchRatio, closeTo(2, 1e-8));
    expect(const AudioEffects(semitones: -12).pitchRatio, closeTo(0.5, 1e-8));
    expect(
      const AudioEffects(tuningHz: 442).pitchRatio,
      closeTo(442 / 440, 1e-8),
    );
    expect(const AudioEffects().mpvFilters, isEmpty);
    expect(const AudioEffects(reverb: 100).mpvFilters, contains('aecho'));
    expect(const AudioEffects(bass: 10).mpvFilters, contains('bass=g=10.0:f=100'));
    expect(const AudioEffects(bass: 10).hasPitchOrReverb, isTrue);
  });
  test('bass boost integrates into filterGraph and exportFilterGraph', () {
    const fx = AudioEffects(semitones: 2, bass: 6, reverb: 20, speed: 1.5);
    expect(fx.filterGraph, contains('bass=g=6.0:f=100'));
    expect(fx.filterGraph, contains('aecho'));
    expect(fx.exportFilterGraph, startsWith(fx.filterGraph));
    expect(fx.exportFilterGraph, contains('atempo'));
  });
  test(
    'project round trips monitoring effects and supports older projects',
    () {
      const settings = ProjectSettings(
        audioEffects: AudioEffects(
          semitones: -3,
          reverb: 35,
          tuningHz: 442,
          bass: 8,
        ),
      );
      final restored = ProjectSettings.fromJson(settings.toJson());
      expect(restored.audioEffects.semitones, -3);
      expect(restored.audioEffects.reverb, 35);
      expect(restored.audioEffects.tuningHz, 442);
      expect(restored.audioEffects.bass, 8);
      expect(ProjectSettings.fromJson({}).audioEffects.mpvFilters, isEmpty);
      expect(ProjectSettings.fromJson({}).audioEffects.bass, 0);
    },
  );
}
