import 'package:flutter_test/flutter_test.dart';
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
}
