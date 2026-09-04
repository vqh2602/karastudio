import 'package:flutter_test/flutter_test.dart';
import 'package:karastudio/core/presets/style_preset_manager.dart';

void main() {
  const manager = StylePresetManager();

  test('validates built-in presets list', () {
    final presets = manager.getBuiltInPresets();
    expect(presets.length, greaterThanOrEqualTo(5));
    expect(presets.any((p) => p.name.contains('Classic')), isTrue);
    expect(presets.any((p) => p.name.contains('Neon')), isTrue);
  });

  test('serializes and deserializes .kstyle JSON format', () {
    final original = manager.getBuiltInPresets().first;
    final json = manager.exportStyleToJson(original);
    final deserialized = manager.importStyleFromJson(json);

    expect(deserialized.name, original.name);
    expect(deserialized.fontSize, original.fontSize);
    expect(deserialized.activeColorValue, original.activeColorValue);
  });
}
