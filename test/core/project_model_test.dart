import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:karastudio/core/serialization/project_serializer.dart';
import 'package:karastudio/models/project_model.dart';

void main() {
  test(
    'project survives JSON serialization without losing integer timestamps',
    () {
      final project = ProjectModel.create('Bài hát').copyWith(
        audio: const MediaAsset(
          id: 'audio-1',
          type: MediaType.audio,
          path: '/music/song.mp3',
          durationUs: 301234567,
          sampleRate: 48000,
          channels: 2,
          codec: 'mp3',
        ),
        lyricLines: const [
          LyricLine(
            id: 'line-1',
            text: 'Ngày mai em đi',
            actorId: 'male',
            startUs: 1000123,
            endUs: 3500456,
            tokens: [
              LyricToken(
                id: 'token-1',
                text: 'Ngày',
                index: 0,
                startUs: 1000123,
                endUs: 1600789,
              ),
            ],
          ),
        ],
      );

      final loaded = ProjectModel.fromJson(project.toJson());

      expect(loaded.name, 'Bài hát');
      expect(loaded.audio?.durationUs, 301234567);
      expect(loaded.lyricLines.single.startUs, 1000123);
      expect(loaded.lyricLines.single.tokens.single.endUs, 1600789);
      expect(loaded.actors.length, 3);
    },
  );

  test('rejects unknown project formats', () {
    expect(
      () => ProjectModel.fromJson({'format': 'Other'}),
      throwsFormatException,
    );
  });

  test('restores built-in styles when opening a legacy project', () {
    final json = ProjectModel.create('Legacy').toJson()..remove('styles');

    final loaded = ProjectModel.fromJson(json);

    expect(loaded.styles, isNotEmpty);
    expect(loaded.styles.first.id, 'classic');
  });

  test('saves and reloads every subtitle style property', () async {
    const customStyle = SubtitleStyle(
      id: 'classic',
      name: 'My saved style',
      fontFamily: 'Avenir Next',
      fontSize: 73,
      fontWeight: 800,
      isItalic: true,
      isUnderline: true,
      alignment: SubtitleAlignment.right,
      letterSpacing: 2.5,
      wordSpacing: 7,
      lineHeight: 1.45,
      inactiveColorValue: 0xFF123456,
      inactiveSecondaryColorValue: 0xFF654321,
      inactiveUseGradient: true,
      activeColorValue: 0xFFABCDEF,
      activeSecondaryColorValue: 0xFF112233,
      activeUseGradient: true,
      outlineColorValue: 0xFF010203,
      outlineWidth: 5.5,
      outlineColorValue2: 0xFF040506,
      outlineWidth2: 1.5,
      shadowColorValue: 0x88070809,
      shadowBlur: 9,
      shadowOffsetX: 3,
      shadowOffsetY: 4,
      glowColorValue: 0xFF00EEFF,
      glowRadius: 11,
      glowIntensity: 0.75,
      scaleX: 1.1,
      scaleY: 0.9,
      rotationZ: 2,
      skewX: 1,
      skewY: -1,
      sweepDirection: SweepDirection.centerOut,
    );
    final project = ProjectModel.create(
      'Style persistence',
    ).copyWith(styles: const [customStyle]);
    final directory = await Directory.systemTemp.createTemp(
      'karastudio-style-test-',
    );
    final path = '${directory.path}/style.karastudio';

    try {
      const serializer = ProjectSerializer();
      await serializer.save(project, path);
      final loaded = await serializer.load(path);

      expect(loaded.styles, hasLength(1));
      expect(loaded.styles.single.toJson(), customStyle.toJson());
    } finally {
      await directory.delete(recursive: true);
    }
  });
}
