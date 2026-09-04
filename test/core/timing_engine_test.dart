import 'package:flutter_test/flutter_test.dart';
import 'package:karastudio/core/timing/timing_engine.dart';
import 'package:karastudio/models/project_model.dart';

void main() {
  const engine = TimingEngine();

  test('fast taps do not accumulate delay on the final two words', () {
    var line = LyricLine(
      id: 'rapid',
      text: 'rapid words',
      actorId: 'male',
      tokens: List.generate(
        20,
        (i) => LyricToken(id: 't$i', text: '$i', index: i),
      ),
    );
    for (var i = 0; i < 20; i++) {
      line = engine.preventTokenOverlaps(
        engine.beginTappedToken(line, i, 1000000 + i * 30000),
      );
    }
    final tokens = [...line.tokens];
    tokens.last = tokens.last.copyWith(endUs: 5000000);
    line = engine.preventTokenOverlaps(line.copyWith(tokens: tokens));
    for (var i = 0; i < 20; i++) {
      expect(line.tokens[i].startUs, 1000000 + i * 30000);
      if (i < 19) expect(line.tokens[i].durationUs, 30000);
    }
    expect(line.tokens.last.endUs, 5000000);
  });

  test('tap leaves last word open and replaces stale penultimate timing', () {
    const original = LyricLine(
      id: 'tap',
      text: 'nhớ em',
      actorId: 'male',
      tokens: [
        LyricToken(id: 'a', text: 'nhớ', index: 0, startUs: 0, endUs: 9000000),
        LyricToken(
          id: 'b',
          text: 'em',
          index: 1,
          startUs: 9000000,
          endUs: 9500000,
        ),
      ],
    );
    final first = engine.preventTokenOverlaps(
      engine.beginTappedToken(original, 0, 1000000),
    );
    final last = engine.preventTokenOverlaps(
      engine.beginTappedToken(first, 1, 1500000),
    );
    expect(last.tokens.first.endUs, 1500000);
    expect(last.tokens.last.startUs, 1500000);
    expect(last.tokens.last.endUs, isNull);
    final finished = engine.preventTokenOverlaps(
      last.copyWith(
        tokens: [last.tokens.first, last.tokens.last.copyWith(endUs: 6000000)],
      ),
    );
    expect(finished.tokens.last.durationUs, 4500000);
    expect(finished.tokens.first.durationUs, 500000);
  });

  test('single-word tap has no default end', () {
    const line = LyricLine(
      id: 'solo',
      text: 'ơi',
      actorId: 'male',
      tokens: [LyricToken(id: 'a', text: 'ơi', index: 0)],
    );
    final opened = engine.beginTappedToken(line, 0, 1000000);
    expect(opened.tokens.single.startUs, 1000000);
    expect(opened.tokens.single.endUs, isNull);
  });

  final sampleLines = [
    const LyricLine(
      id: 'line-1',
      text: 'Anh nhớ em nhiều',
      actorId: 'male',
      startUs: 1000000,
      endUs: 3000000,
      tokens: [
        LyricToken(
          id: 'tok-1',
          text: 'Anh',
          index: 0,
          startUs: 1000000,
          endUs: 1500000,
        ),
        LyricToken(
          id: 'tok-2',
          text: 'nhớ',
          index: 1,
          startUs: 1500000,
          endUs: 2000000,
        ),
        LyricToken(
          id: 'tok-3',
          text: 'em',
          index: 2,
          startUs: 2000000,
          endUs: 2500000,
        ),
        LyricToken(
          id: 'tok-4',
          text: 'nhiều',
          index: 3,
          startUs: 2500000,
          endUs: 3000000,
        ),
      ],
    ),
    const LyricLine(
      id: 'line-2',
      text: 'Em ở nơi đâu',
      actorId: 'female',
      startUs: 4000000,
      endUs: 6000000,
      tokens: [
        LyricToken(
          id: 'tok-5',
          text: 'Em',
          index: 0,
          startUs: 4000000,
          endUs: 4500000,
        ),
        LyricToken(
          id: 'tok-6',
          text: 'ở',
          index: 1,
          startUs: 4500000,
          endUs: 5000000,
        ),
        LyricToken(
          id: 'tok-7',
          text: 'nơi',
          index: 2,
          startUs: 5000000,
          endUs: 5500000,
        ),
        LyricToken(
          id: 'tok-8',
          text: 'đâu',
          index: 3,
          startUs: 5500000,
          endUs: 6000000,
        ),
      ],
    ),
  ];

  group('TimingEngine Shift Tests', () {
    test('shifts all lines earlier by 80ms (-80000us)', () {
      final shifted = engine.shiftTiming(lines: sampleLines, deltaUs: -80000);

      expect(shifted[0].startUs, 920000);
      expect(shifted[0].endUs, 2920000);
      expect(shifted[0].tokens[0].startUs, 920000);
      expect(shifted[0].tokens[0].endUs, 1420000);

      expect(shifted[1].startUs, 3920000);
      expect(shifted[1].endUs, 5920000);
      expect(shifted[1].tokens[0].startUs, 3920000);
    });

    test('shifts timing only from specific line index', () {
      final shifted = engine.shiftTiming(
        lines: sampleLines,
        deltaUs: -50000,
        fromLineIndex: 1,
      );

      // Line 0 unchanged
      expect(shifted[0].startUs, 1000000);
      expect(shifted[0].tokens[0].startUs, 1000000);

      // Line 1 shifted
      expect(shifted[1].startUs, 3950000);
      expect(shifted[1].tokens[0].startUs, 3950000);
    });

    test('shifts timing only for single line index', () {
      final shifted = engine.shiftTiming(
        lines: sampleLines,
        deltaUs: 100000,
        singleLineIndex: 0,
      );

      // Line 0 shifted later by 100ms
      expect(shifted[0].startUs, 1100000);
      expect(shifted[0].tokens[0].startUs, 1100000);

      // Line 1 unchanged
      expect(shifted[1].startUs, 4000000);
    });
  });

  test('prevents word intervals in one line from overlapping', () {
    const line = LyricLine(
      id: 'overlap',
      text: 'một hai ba',
      actorId: 'male',
      tokens: [
        LyricToken(
          id: 'one',
          text: 'một',
          index: 0,
          startUs: 1000000,
          endUs: 1800000,
        ),
        LyricToken(
          id: 'two',
          text: 'hai',
          index: 1,
          startUs: 1500000,
          endUs: 2100000,
        ),
        LyricToken(
          id: 'three',
          text: 'ba',
          index: 2,
          startUs: 2050000,
          endUs: 2600000,
        ),
      ],
    );

    final fixed = engine.preventTokenOverlaps(line);
    for (var index = 1; index < fixed.tokens.length; index++) {
      expect(
        fixed.tokens[index].startUs,
        greaterThanOrEqualTo(fixed.tokens[index - 1].endUs!),
      );
    }
    expect(fixed.tokens[1].startUs, 1500000);
    expect(fixed.tokens[2].startUs, 2050000);
    expect(fixed.tokens[0].endUs, 1500000);
    expect(fixed.tokens[1].endUs, 2050000);
  });
}
