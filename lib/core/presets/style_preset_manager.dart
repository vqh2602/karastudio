import 'dart:convert';
import 'dart:io';
import '../../models/project_model.dart';

class StylePresetManager {
  const StylePresetManager();

  List<SubtitleStyle> getBuiltInPresets() => const [
    SubtitleStyle(
      id: 'classic',
      name: 'Classic Karaoke',
      fontFamily: 'Arial',
      fontSize: 58,
      fontWeight: 700,
      inactiveColorValue: 0xFFFFFFFF,
      activeColorValue: 0xFFFFC107,
      outlineColorValue: 0xFF000000,
      outlineWidth: 3.5,
      shadowColorValue: 0x99000000,
      shadowBlur: 6,
      shadowOffsetX: 2,
      shadowOffsetY: 3,
    ),
    SubtitleStyle(
      id: 'neon_cyan',
      name: 'Neon Cyan',
      fontFamily: 'Arial',
      fontSize: 60,
      fontWeight: 800,
      inactiveColorValue: 0xFFE0F7FA,
      activeColorValue: 0xFF00E5FF,
      activeSecondaryColorValue: 0xFF00B0FF,
      activeUseGradient: true,
      outlineColorValue: 0xFF002244,
      outlineWidth: 4.0,
      glowColorValue: 0xFF00E5FF,
      glowRadius: 10,
      glowIntensity: 0.8,
      shadowColorValue: 0xCC000000,
      shadowBlur: 8,
    ),
    SubtitleStyle(
      id: 'golden_sunset',
      name: 'Golden Sunset',
      fontFamily: 'Arial',
      fontSize: 62,
      fontWeight: 900,
      inactiveColorValue: 0xFFFFFDE7,
      activeColorValue: 0xFFFFD700,
      activeSecondaryColorValue: 0xFFFF3D00,
      activeUseGradient: true,
      outlineColorValue: 0xFF3E2723,
      outlineWidth: 4.0,
      outlineColorValue2: 0xFFFFAB00,
      outlineWidth2: 1.5,
      shadowColorValue: 0xAA000000,
      shadowBlur: 7,
      shadowOffsetX: 3,
      shadowOffsetY: 4,
    ),
    SubtitleStyle(
      id: 'tiktok_bold',
      name: 'TikTok Pop',
      fontFamily: 'Arial',
      fontSize: 68,
      fontWeight: 900,
      inactiveColorValue: 0xFFFFFFFF,
      activeColorValue: 0xFFFFEB3B,
      outlineColorValue: 0xFF000000,
      outlineWidth: 5.5,
      shadowColorValue: 0xDD000000,
      shadowBlur: 10,
      shadowOffsetX: 0,
      shadowOffsetY: 5,
    ),
    SubtitleStyle(
      id: 'concert_magenta',
      name: 'Concert Stage',
      fontFamily: 'Arial',
      fontSize: 60,
      fontWeight: 700,
      letterSpacing: 2.0,
      inactiveColorValue: 0xFFF3E5F5,
      activeColorValue: 0xFFE040FB,
      activeSecondaryColorValue: 0xFF7C4DFF,
      activeUseGradient: true,
      outlineColorValue: 0xFF210038,
      outlineWidth: 4.0,
      glowColorValue: 0xFFE040FB,
      glowRadius: 8,
      glowIntensity: 0.7,
      shadowColorValue: 0x99000000,
    ),
    SubtitleStyle(
      id: 'minimal_clean',
      name: 'Minimal Clean',
      fontFamily: 'Arial',
      fontSize: 52,
      fontWeight: 500,
      letterSpacing: 1.5,
      inactiveColorValue: 0xFFB0BEC5,
      activeColorValue: 0xFFFFFFFF,
      outlineColorValue: 0xFF263238,
      outlineWidth: 1.5,
      shadowColorValue: 0x00000000,
      shadowBlur: 0,
    ),
  ];

  String exportStyleToJson(SubtitleStyle style) {
    return const JsonEncoder.withIndent('  ').convert({
      'format': 'KaraStudioStyle',
      'version': 1,
      'style': style.toJson(),
    });
  }

  SubtitleStyle importStyleFromJson(String jsonString) {
    final map = jsonDecode(jsonString) as Map<String, Object?>;
    if (map['format'] != 'KaraStudioStyle') {
      throw const FormatException('File không phải định dạng .kstyle hợp lệ.');
    }
    final styleMap = (map['style'] as Map).cast<String, Object?>();
    return SubtitleStyle.fromJson(styleMap);
  }

  Future<void> saveStyleFile(SubtitleStyle style, String filePath) async {
    final file = File(filePath);
    await file.parent.create(recursive: true);
    await file.writeAsString(exportStyleToJson(style), flush: true);
  }

  Future<SubtitleStyle> loadStyleFile(String filePath) async {
    final file = File(filePath);
    return importStyleFromJson(await file.readAsString());
  }
}
