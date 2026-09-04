import 'package:flutter_test/flutter_test.dart';
import 'package:karastudio/core/export/export_engine.dart';
import 'package:karastudio/models/project_model.dart';

void main() {
  final exportEngine = ExportEngine();

  final testProject = ProjectModel.create('Test Song').copyWith(
    lyricLines: const [
      LyricLine(
        id: 'l-1',
        text: 'Ngày mai em đi',
        actorId: 'male',
        startUs: 1000000,
        endUs: 3000000,
        tokens: [
          LyricToken(
            id: 't-1',
            text: 'Ngày',
            index: 0,
            startUs: 1000000,
            endUs: 1500000,
          ),
          LyricToken(
            id: 't-2',
            text: 'mai',
            index: 1,
            startUs: 1500000,
            endUs: 2000000,
          ),
          LyricToken(
            id: 't-3',
            text: 'em',
            index: 2,
            startUs: 2000000,
            endUs: 2500000,
          ),
          LyricToken(
            id: 't-4',
            text: 'đi',
            index: 3,
            startUs: 2500000,
            endUs: 3000000,
          ),
        ],
      ),
    ],
  );

  group('ExportEngine Tests', () {
    test('exports ASS format with styles and \\k tags', () {
      final ass = exportEngine.exportAss(testProject);
      expect(ass.contains('[Script Info]'), isTrue);
      expect(ass.contains('Title: Test Song'), isTrue);
      expect(ass.contains('[V4+ Styles]'), isTrue);
      expect(ass.contains('[Events]'), isTrue);
      expect(
        ass.contains('{\\k50}Ngày {\\k50}mai {\\k50}em {\\k50}đi'),
        isTrue,
      );
    });

    test('exports SRT format with sequence numbers and timestamps', () {
      final srt = exportEngine.exportSrt(testProject);
      expect(srt.contains('1'), isTrue);
      expect(srt.contains('00:00:01,000 --> 00:00:03,000'), isTrue);
      expect(srt.contains('Ngày mai em đi'), isTrue);
    });

    test('exports LRC format with line timestamps', () {
      final lrc = exportEngine.exportLrc(testProject, includeWordTiming: false);
      expect(lrc.contains('[ti:Test Song]'), isTrue);
      expect(lrc.contains('[00:01.00] Ngày mai em đi'), isTrue);
    });
  });
}
