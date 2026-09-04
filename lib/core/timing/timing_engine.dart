import 'dart:math' as math;
import '../../models/project_model.dart';

enum IssueSeverity { warning, error, info }

class TimingIssue {
  const TimingIssue({
    required this.id,
    required this.lineIndex,
    required this.tokenIndex,
    required this.message,
    required this.severity,
    this.suggestedFix,
  });

  final String id;
  final int lineIndex;
  final int? tokenIndex;
  final String message;
  final IssueSeverity severity;
  final String? suggestedFix;
}

class TimingEngine {
  const TimingEngine();

  static const int minimumTokenDurationUs = 50000;

  /// A tap closes the previous word and opens the next without guessing its end.
  LyricLine beginTappedToken(LyricLine line, int index, int nowUs) {
    if (index < 0 || index >= line.tokens.length) return line;
    final tokens = List<LyricToken>.from(line.tokens);
    var boundaryUs = math.max(0, nowUs);
    if (index > 0 && tokens[index - 1].startUs != null) {
      boundaryUs = math.max(
        boundaryUs,
        tokens[index - 1].startUs! + minimumTokenDurationUs,
      );
      tokens[index - 1] = tokens[index - 1].copyWith(endUs: boundaryUs);
    }
    // Remove stale timing from the current and remaining words on re-record.
    for (var i = index; i < tokens.length; i++) {
      tokens[i] = tokens[i].copyWith(clearTiming: true);
    }
    tokens[index] = tokens[index].copyWith(startUs: boundaryUs);
    return line.copyWith(
      startUs: tokens.first.startUs ?? boundaryUs,
      endUs: boundaryUs,
      tokens: tokens,
    );
  }

  LyricLine preventTokenOverlaps(LyricLine line) {
    if (line.tokens.isEmpty) return line;
    final tokens = <LyricToken>[];
    int? previousEndUs;

    for (final token in line.tokens) {
      if (token.startUs == null || token.endUs == null) {
        tokens.add(token.copyWith(index: tokens.length));
        continue;
      }
      final startUs = math.max(token.startUs!, previousEndUs ?? 0);
      final endUs = math.max(startUs + minimumTokenDurationUs, token.endUs!);
      tokens.add(
        token.copyWith(index: tokens.length, startUs: startUs, endUs: endUs),
      );
      previousEndUs = endUs;
    }

    final timed = tokens.where((token) => token.isTimed).toList();
    if (timed.isEmpty) return line.copyWith(tokens: tokens);
    return line.copyWith(
      startUs: timed.map((token) => token.startUs!).reduce(math.min),
      endUs: timed.map((token) => token.endUs!).reduce(math.max),
      tokens: tokens,
    );
  }

  List<LyricLine> clearTimingFrom(
    List<LyricLine> lines, {
    int startLineIndex = 0,
  }) {
    if (lines.isEmpty) return const [];
    final start = startLineIndex.clamp(0, lines.length);
    return [
      for (var index = 0; index < lines.length; index++)
        index < start ? lines[index] : lines[index].copyWith(clearTiming: true),
    ];
  }

  /// Dịch chuyển timing hàng loạt (toàn bài, từ 1 câu, hoặc 1 câu cụ thể)
  List<LyricLine> shiftTiming({
    required List<LyricLine> lines,
    required int deltaUs,
    int? fromLineIndex,
    int? singleLineIndex,
  }) {
    if (lines.isEmpty || deltaUs == 0) return lines;

    return [
      for (var i = 0; i < lines.length; i++)
        () {
          final line = lines[i];
          if (singleLineIndex != null && i != singleLineIndex) return line;
          if (fromLineIndex != null && i < fromLineIndex) return line;

          return shiftLine(line, deltaUs);
        }(),
    ];
  }

  /// Shift timing by deltaUs (positive or negative microseconds)
  LyricLine shiftLine(LyricLine line, int deltaUs) {
    final newStart = line.startUs != null
        ? math.max(0, line.startUs! + deltaUs)
        : null;
    final newEnd = line.endUs != null
        ? math.max(0, line.endUs! + deltaUs)
        : null;

    final newTokens = line.tokens.map((token) {
      final tStart = token.startUs != null
          ? math.max(0, token.startUs! + deltaUs)
          : null;
      final tEnd = token.endUs != null
          ? math.max(0, token.endUs! + deltaUs)
          : null;
      return token.copyWith(startUs: tStart, endUs: tEnd);
    }).toList();

    return line.copyWith(startUs: newStart, endUs: newEnd, tokens: newTokens);
  }

  /// Nudge a specific token by deltaUs
  LyricLine nudgeToken({
    required LyricLine line,
    required int tokenIndex,
    required int deltaStartUs,
    required int deltaEndUs,
  }) {
    if (tokenIndex < 0 || tokenIndex >= line.tokens.length) return line;

    final target = line.tokens[tokenIndex];
    final newStart = target.startUs != null
        ? math.max(0, target.startUs! + deltaStartUs)
        : null;
    final newEnd = target.endUs != null
        ? math.max(0, target.endUs! + deltaEndUs)
        : null;

    if (newStart != null && newEnd != null && newEnd < newStart) return line;

    final updatedTokens = List<LyricToken>.from(line.tokens);
    updatedTokens[tokenIndex] = target.copyWith(
      startUs: newStart,
      endUs: newEnd,
    );

    // Also update line bounds if needed
    final timedTokens = updatedTokens.where((t) => t.isTimed).toList();
    int? lineStart = line.startUs;
    int? lineEnd = line.endUs;
    if (timedTokens.isNotEmpty) {
      lineStart = timedTokens.map((t) => t.startUs!).reduce(math.min);
      lineEnd = timedTokens.map((t) => t.endUs!).reduce(math.max);
    }

    return line.copyWith(
      startUs: lineStart,
      endUs: lineEnd,
      tokens: updatedTokens,
    );
  }

  /// Stretch or compress timing around an anchor point
  LyricLine stretchTiming(LyricLine line, int anchorUs, double ratio) {
    if (ratio <= 0) return line;

    int scaleTime(int t) =>
        math.max(0, anchorUs + ((t - anchorUs) * ratio).round());

    final newStart = line.startUs != null ? scaleTime(line.startUs!) : null;
    final newEnd = line.endUs != null ? scaleTime(line.endUs!) : null;

    final newTokens = line.tokens.map((token) {
      final tStart = token.startUs != null ? scaleTime(token.startUs!) : null;
      final tEnd = token.endUs != null ? scaleTime(token.endUs!) : null;
      return token.copyWith(startUs: tStart, endUs: tEnd);
    }).toList();

    return line.copyWith(startUs: newStart, endUs: newEnd, tokens: newTokens);
  }

  /// Quantize timestamps to a grid interval (e.g. 10000us = 10ms)
  LyricLine quantizeTiming(LyricLine line, int gridIntervalUs) {
    if (gridIntervalUs <= 0) return line;

    int quantize(int t) =>
        ((t + gridIntervalUs ~/ 2) ~/ gridIntervalUs) * gridIntervalUs;

    final newStart = line.startUs != null ? quantize(line.startUs!) : null;
    final newEnd = line.endUs != null ? quantize(line.endUs!) : null;

    final newTokens = line.tokens.map((token) {
      final tStart = token.startUs != null ? quantize(token.startUs!) : null;
      final tEnd = token.endUs != null ? quantize(token.endUs!) : null;
      return token.copyWith(startUs: tStart, endUs: tEnd);
    }).toList();

    return line.copyWith(startUs: newStart, endUs: newEnd, tokens: newTokens);
  }

  /// Check project for timing overlaps, inversions, or anomalies
  List<TimingIssue> validateProject(ProjectModel project) {
    final issues = <TimingIssue>[];

    for (var l = 0; l < project.lyricLines.length; l++) {
      final line = project.lyricLines[l];

      if (line.startUs != null &&
          line.endUs != null &&
          line.endUs! < line.startUs!) {
        issues.add(
          TimingIssue(
            id: newId('issue'),
            lineIndex: l,
            tokenIndex: null,
            message:
                'Dòng ${l + 1}: Thời điểm kết thúc sớm hơn thời điểm bắt đầu.',
            severity: IssueSeverity.error,
            suggestedFix: 'SwapStartEnd',
          ),
        );
      }

      for (var t = 0; t < line.tokens.length; t++) {
        final token = line.tokens[t];
        if (token.startUs != null &&
            token.endUs != null &&
            token.endUs! < token.startUs!) {
          issues.add(
            TimingIssue(
              id: newId('issue'),
              lineIndex: l,
              tokenIndex: t,
              message:
                  'Dòng ${l + 1}, từ "${token.text}": Kết thúc (${token.endUs! ~/ 1000}ms) < Bắt đầu (${token.startUs! ~/ 1000}ms).',
              severity: IssueSeverity.error,
              suggestedFix: 'FixInvertedToken',
            ),
          );
        }

        // Check overlap with next token
        if (t + 1 < line.tokens.length) {
          final next = line.tokens[t + 1];
          if (token.endUs != null &&
              next.startUs != null &&
              token.endUs! > next.startUs!) {
            final overlapMs = (token.endUs! - next.startUs!) ~/ 1000;
            issues.add(
              TimingIssue(
                id: newId('issue'),
                lineIndex: l,
                tokenIndex: t,
                message:
                    'Dòng ${l + 1}: Từ "${token.text}" đè lên từ "${next.text}" $overlapMs ms.',
                severity: IssueSeverity.warning,
                suggestedFix: 'ClampOverlap',
              ),
            );
          }
        }
      }

      // Check overlap with next line
      if (l + 1 < project.lyricLines.length) {
        final nextLine = project.lyricLines[l + 1];
        if (line.endUs != null &&
            nextLine.startUs != null &&
            line.endUs! > nextLine.startUs!) {
          final overlapMs = (line.endUs! - nextLine.startUs!) ~/ 1000;
          issues.add(
            TimingIssue(
              id: newId('issue'),
              lineIndex: l,
              tokenIndex: null,
              message: 'Dòng ${l + 1} đè lên dòng ${l + 2} $overlapMs ms.',
              severity: IssueSeverity.info,
              suggestedFix: 'ClampLineOverlap',
            ),
          );
        }
      }
    }

    return issues;
  }

  /// Automatically fix all clampable overlaps in a project
  ProjectModel autoFixOverlaps(ProjectModel project) {
    final updatedLines = project.lyricLines.map((line) {
      if (line.tokens.length <= 1) return line;
      final tokens = List<LyricToken>.from(line.tokens);
      for (var t = 0; t < tokens.length - 1; t++) {
        final current = tokens[t];
        final next = tokens[t + 1];
        if (current.endUs != null &&
            next.startUs != null &&
            current.endUs! > next.startUs!) {
          tokens[t] = current.copyWith(endUs: next.startUs);
        }
      }
      return line.copyWith(tokens: tokens);
    }).toList();

    return project.copyWith(lyricLines: updatedLines);
  }
}
