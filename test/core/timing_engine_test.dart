import 'package:flutter_test/flutter_test.dart';
import 'package:karastudio/core/timing/timing_engine.dart';
import 'package:karastudio/models/project_model.dart';

void main() {
  const engine = TimingEngine();

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
    expect(fixed.tokens[1].startUs, 1800000);
    expect(fixed.tokens[2].startUs, 2100000);
  });
}
