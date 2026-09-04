import 'package:flutter_test/flutter_test.dart';
import 'package:karastudio/models/audio_effects.dart';
import 'package:karastudio/models/project_model.dart';

void main() {
  test('pitch tuning uses semitone ratio without changing speed', () {
    expect(const AudioEffects(semitones: 12).pitchRatio, closeTo(2, 1e-8));
    expect(const AudioEffects(semitones: -12).pitchRatio, closeTo(0.5, 1e-8));
    expect(
      const AudioEffects(tuningHz: 442).pitchRatio,
      closeTo(442 / 440, 1e-8),
    );
    expect(const AudioEffects().mpvFilters, isEmpty);
    expect(const AudioEffects(reverb: 100).mpvFilters, contains('aecho'));
  });
  test(
    'project round trips monitoring effects and supports older projects',
    () {
      const settings = ProjectSettings(
        audioEffects: AudioEffects(semitones: -3, reverb: 35, tuningHz: 442),
      );
      final restored = ProjectSettings.fromJson(settings.toJson());
      expect(restored.audioEffects.semitones, -3);
      expect(restored.audioEffects.reverb, 35);
      expect(restored.audioEffects.tuningHz, 442);
      expect(ProjectSettings.fromJson({}).audioEffects.mpvFilters, isEmpty);
    },
  );
}
