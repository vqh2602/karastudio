import 'package:flutter_test/flutter_test.dart';
import 'package:karastudio/core/lyrics/lyrics_engine.dart';
import 'package:karastudio/models/project_model.dart';

void main() {
  const engine = LyricsEngine();
  const actors = [
    Actor(id: 'male', name: 'Nam', colorValue: 0xFF42A5F5, styleId: 'classic'),
    Actor(id: 'female', name: 'Nữ', colorValue: 0xFFEC407A, styleId: 'female'),
    Actor(id: 'duet', name: 'Hợp ca', colorValue: 0xFFFFCA28, styleId: 'duet'),
  ];

  group('LyricsEngine Parser Tests', () {
    test('parses TXT with actor prefixes and strips prefixes properly', () {
      const txt = '''
Nam: Ngày mai em đi
Nữ: Em vẫn nhớ anh
Hợp: Ta mãi bên nhau
[Nam] Khi xưa ta bé
[Nữ] Em nhớ anh nhiều
Anh ơi mùa đông sang rồi
Em đi trên cỏ non
Nam quốc sơn hà Nam đế cư
''';

      final lines = engine.parseTxt(
        txt,
        actors: actors,
        keepActorPrefix: false,
      );
      expect(lines.length, 8);
      expect(lines[0].text, 'Ngày mai em đi');
      expect(lines[0].actorId, 'male');
      expect(lines[0].tokens.length, 4);
      expect(lines[0].tokens[0].text, 'Ngày');
      expect(lines[0].tokens[3].text, 'đi');

      expect(lines[1].text, 'Em vẫn nhớ anh');
      expect(lines[1].actorId, 'female');

      expect(lines[2].text, 'Ta mãi bên nhau');
      expect(lines[2].actorId, 'duet');

      expect(lines[3].text, 'Khi xưa ta bé');
      expect(lines[3].actorId, 'male');

      expect(lines[4].text, 'Em nhớ anh nhiều');
      expect(lines[4].actorId, 'female');

      // Crucial: Ordinary lines starting with "Anh", "Em", "Nam" MUST keep the first word!
      expect(lines[5].text, 'Anh ơi mùa đông sang rồi');
      expect(lines[5].tokens[0].text, 'Anh');

      expect(lines[6].text, 'Em đi trên cỏ non');
      expect(lines[6].tokens[0].text, 'Em');

      expect(lines[7].text, 'Nam quốc sơn hà Nam đế cư');
      expect(lines[7].tokens[0].text, 'Nam');
    });

    test('parses LRC with timestamps and calculates duration properly', () {
      const lrc = '''
[00:10.50]Dòng đầu tiên
[00:15.00]Dòng thứ hai
''';

      final lines = engine.parseLrc(lrc, actors: actors);
      expect(lines.length, 2);
      expect(lines[0].startUs, 10500000);
      expect(lines[0].endUs, 15000000);
      expect(lines[0].tokens.length, 3);
      expect(lines[1].startUs, 15000000);
    });

    test('parses SRT formatted subtitles', () {
      const srt = '''
1
00:00:05,000 --> 00:00:09,500
Ngày mai em đi

2
00:00:10,000 --> 00:00:14,200
Nữ: Em sẽ nhớ anh
''';

      final lines = engine.parseSrt(srt, actors: actors);
      expect(lines.length, 2);
      expect(lines[0].startUs, 5000000);
      expect(lines[0].endUs, 9500000);
      expect(lines[0].text, 'Ngày mai em đi');

      expect(lines[1].startUs, 10000000);
      expect(lines[1].endUs, 14200000);
      expect(lines[1].actorId, 'female');
      expect(lines[1].text, 'Em sẽ nhớ anh');
    });

    test('parses ASS subtitle with karaoke tags', () {
      const ass = '''
[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
Dialogue: 0,0:01:20.00,0:01:25.00,Default,Nam,0,0,0,,{\\k50}Ngày {\\k40}mai {\\k60}em {\\k50}đi
''';

      final lines = engine.parseAss(ass, actors: actors);
      expect(lines.length, 1);
      final line = lines.first;
      expect(line.startUs, 80000000);
      expect(line.endUs, 85000000);
      expect(line.tokens.length, 4);
      expect(line.tokens[0].text, 'Ngày');
      expect(line.tokens[0].startUs, 80000000);
      expect(line.tokens[0].endUs, 80500000); // 50 cs = 500ms = 500000us
    });
  });

  group('Token manipulation tests', () {
    test('finds and restores missing repeated words without losing timing', () {
      const line = LyricLine(
        id: 'line-missing',
        text: "You're the sun, you're the sun",
        actorId: 'male',
        startUs: 1000000,
        endUs: 4000000,
        tokens: [
          LyricToken(
            id: 't-1',
            text: "You're",
            index: 0,
            startUs: 1000000,
            endUs: 1400000,
          ),
          LyricToken(
            id: 't-2',
            text: 'the',
            index: 1,
            startUs: 1400000,
            endUs: 1800000,
          ),
          LyricToken(
            id: 't-3',
            text: 'sun,',
            index: 2,
            startUs: 1800000,
            endUs: 2200000,
          ),
          LyricToken(
            id: 't-4',
            text: "you're",
            index: 3,
            startUs: 2200000,
            endUs: 2700000,
          ),
          LyricToken(
            id: 't-5',
            text: 'sun',
            index: 4,
            startUs: 3300000,
            endUs: 4000000,
          ),
        ],
      );

      expect(engine.missingWords(line), ['the']);
      expect(engine.entryStatus(line), LyricEntryStatus.missingWords);

      final repaired = engine.repairMissingTokens(line);
      expect(repaired.addedWords, ['the']);
      expect(repaired.line.tokens.map((token) => token.text), [
        "You're",
        'the',
        'sun,',
        "you're",
        'the',
        'sun',
      ]);
      expect(repaired.line.tokens.first.id, 't-1');
      expect(engine.missingWords(repaired.line), isEmpty);
      expect(engine.entryStatus(repaired.line), LyricEntryStatus.added);
    });

    test('entry status separates untimed, missing, and added lines', () {
      expect(
        engine.entryStatus(
          const LyricLine(id: 'empty', text: 'Chưa tạo token', actorId: 'male'),
        ),
        LyricEntryStatus.notAdded,
      );
      const untimed = LyricLine(
        id: 'line-1',
        text: 'Anh nhớ em',
        actorId: 'male',
        tokens: [
          LyricToken(id: 'a', text: 'Anh', index: 0),
          LyricToken(id: 'b', text: 'nhớ', index: 1),
          LyricToken(id: 'c', text: 'em', index: 2),
        ],
      );
      expect(engine.entryStatus(untimed), LyricEntryStatus.notAdded);
      expect(
        engine.entryStatus(
          untimed.copyWith(
            tokens: [
              untimed.tokens[0].copyWith(startUs: 0, endUs: 100000),
              untimed.tokens[1],
              untimed.tokens[2],
            ],
          ),
        ),
        LyricEntryStatus.added,
      );
    });

    test('splits a token at character offset', () {
      const line = LyricLine(
        id: 'line-1',
        text: 'Karaoke',
        actorId: 'male',
        startUs: 1000000,
        endUs: 2000000,
        tokens: [
          LyricToken(
            id: 't-1',
            text: 'Karaoke',
            index: 0,
            startUs: 1000000,
            endUs: 2000000,
          ),
        ],
      );

      final split = engine.splitToken(line, 0, 4); // "Kara" and "oke"
      expect(split.tokens.length, 2);
      expect(split.tokens[0].text, 'Kara');
      expect(split.tokens[1].text, 'oke');
      expect(split.tokens[0].startUs, 1000000);
      expect(split.tokens[1].endUs, 2000000);
    });

    test('merges two adjacent tokens', () {
      const line = LyricLine(
        id: 'line-1',
        text: 'Ngày mai',
        actorId: 'male',
        tokens: [
          LyricToken(
            id: 't-1',
            text: 'Ngày',
            index: 0,
            startUs: 1000000,
            endUs: 1400000,
          ),
          LyricToken(
            id: 't-2',
            text: 'mai',
            index: 1,
            startUs: 1400000,
            endUs: 1800000,
          ),
        ],
      );

      final merged = engine.mergeTokens(line, 0);
      expect(merged.tokens.length, 1);
      expect(merged.tokens[0].text, 'Ngày mai');
      expect(merged.tokens[0].startUs, 1000000);
      expect(merged.tokens[0].endUs, 1800000);
    });
  });
}
