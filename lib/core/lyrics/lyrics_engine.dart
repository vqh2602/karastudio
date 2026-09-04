import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import '../../models/project_model.dart';

enum TokenizeMode { line, word, syllable }

enum LyricEntryStatus { notAdded, missingWords, added }

class LyricTokenRepair {
  const LyricTokenRepair({required this.line, required this.addedWords});

  final LyricLine line;
  final List<String> addedWords;
}

class DetectedActorResult {
  const DetectedActorResult({
    required this.actorId,
    required this.cleanText,
    required this.matchedPrefix,
  });

  final String actorId;
  final String cleanText;
  final String? matchedPrefix;
}

class _TimedRawLine {
  const _TimedRawLine({required this.startUs, required this.body});
  final int startUs;
  final String body;
}

class LyricsEngine {
  const LyricsEngine();

  static final RegExp _actorPrefixRegex = RegExp(
    r'^(?:(?:\[\s*(nam|nữ|nu|anh|em|male|female|duet|hợp\s*ca|hop\s*ca|hợp|hop|song\s*ca|all|tất\s*cả|ca\s*sĩ)\s*\]|\(\s*(nam|nữ|nu|anh|em|male|female|duet|hợp\s*ca|hop\s*ca|hợp|hop|song\s*ca|all|tất\s*cả|ca\s*sĩ)\s*\))\s*[:：\-–]?\s*|(nam|nữ|nu|anh|em|male|female|duet|hợp\s*ca|hop\s*ca|hợp|hop|song\s*ca|all|tất\s*cả|ca\s*sĩ)\s*[:：\-–]\s*)',
    caseSensitive: false,
  );

  static final RegExp _lrcTimestampRegex = RegExp(
    r'\[(\d{1,2}):(\d{2})(?:\.(\d{2,3}))?\]',
  );

  static final RegExp _lrcWordTimingRegex = RegExp(
    r'<(\d{1,2}):(\d{2})(?:\.(\d{2,3}))?>([^<]+)',
  );

  static final RegExp _assKaraokeTagRegex = RegExp(
    r'\{\\[kK][fo]?(\d+)\}([^{]*)',
  );

  DetectedActorResult detectActor(
    String rawText, {
    List<Actor> actors = const [],
    bool keepPrefix = false,
  }) {
    final match = _actorPrefixRegex.firstMatch(rawText.trim());
    if (match == null) {
      return DetectedActorResult(
        actorId: actors.isNotEmpty ? actors.first.id : 'male',
        cleanText: rawText.trim(),
        matchedPrefix: null,
      );
    }

    final rawTag = (match.group(1) ?? match.group(2) ?? match.group(3) ?? '')
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '');
    String actorId = 'male';
    if (rawTag.contains('nữ') ||
        rawTag.contains('nu') ||
        rawTag.contains('em') ||
        rawTag.contains('female')) {
      actorId = 'female';
    } else if (rawTag.contains('duet') ||
        rawTag.contains('hợp') ||
        rawTag.contains('hop') ||
        rawTag.contains('songca') ||
        rawTag.contains('all')) {
      actorId = 'duet';
    } else {
      actorId = 'male';
    }

    // Match with existing actors if defined
    final matchedActor = actors.firstWhere(
      (a) =>
          a.id.toLowerCase() == actorId ||
          a.name.toLowerCase().contains(rawTag),
      orElse: () => actors.isNotEmpty
          ? actors.first
          : Actor(
              id: actorId,
              name: actorId,
              colorValue: 0xFF42A5F5,
              styleId: actorId,
            ),
    );

    final clean = keepPrefix
        ? rawText.trim()
        : rawText.substring(match.end).trim();
    return DetectedActorResult(
      actorId: matchedActor.id,
      cleanText: clean.isEmpty ? rawText.trim() : clean,
      matchedPrefix: match.group(0),
    );
  }

  List<LyricToken> tokenize(
    String text, {
    TokenizeMode mode = TokenizeMode.word,
    int? lineStartUs,
    int? lineEndUs,
  }) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return const [];

    if (mode == TokenizeMode.line) {
      return [
        LyricToken(
          id: newId('tok'),
          text: trimmed,
          index: 0,
          startUs: lineStartUs,
          endUs: lineEndUs,
        ),
      ];
    }

    if (mode == TokenizeMode.word) {
      final words = trimmed
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty)
          .toList();
      if (words.isEmpty) return const [];

      final count = words.length;
      final stepUs =
          (lineStartUs != null && lineEndUs != null && lineEndUs > lineStartUs)
          ? ((lineEndUs - lineStartUs) / count).round()
          : null;

      final tokens = <LyricToken>[];
      for (var i = 0; i < words.length; i++) {
        final start = (lineStartUs != null && stepUs != null)
            ? lineStartUs + i * stepUs
            : null;
        final end = (lineStartUs != null && stepUs != null)
            ? (i == count - 1 ? lineEndUs : lineStartUs + (i + 1) * stepUs)
            : null;
        tokens.add(
          LyricToken(
            id: newId('tok'),
            text: words[i],
            index: i,
            startUs: start,
            endUs: end,
          ),
        );
      }
      return tokens;
    }

    // Syllable Mode / Character grapheme mode
    final chars = trimmed.characters.toList();
    final tokens = <LyricToken>[];
    for (var i = 0; i < chars.length; i++) {
      tokens.add(LyricToken(id: newId('tok'), text: chars[i], index: i));
    }
    return tokens;
  }

  List<LyricLine> parseTxt(
    String content, {
    List<Actor> actors = const [],
    bool keepActorPrefix = false,
    TokenizeMode mode = TokenizeMode.word,
  }) {
    final lines = content.split(RegExp(r'\r?\n'));
    final result = <LyricLine>[];
    var rowIndex = 0;

    for (final raw in lines) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;

      final actorDetect = detectActor(
        trimmed,
        actors: actors,
        keepPrefix: keepActorPrefix,
      );

      final tokens = tokenize(actorDetect.cleanText, mode: mode);
      final rowAssignment = (rowIndex % 2 == 0) ? 'rowA' : 'rowB';

      result.add(
        LyricLine(
          id: newId('line'),
          text: actorDetect.cleanText,
          actorId: actorDetect.actorId,
          tokens: tokens,
          rowAssignment: rowAssignment,
        ),
      );
      rowIndex++;
    }
    return result;
  }

  List<LyricLine> parseLrc(
    String content, {
    List<Actor> actors = const [],
    bool keepActorPrefix = false,
  }) {
    final rawLines = content.split(RegExp(r'\r?\n'));
    final parsed = <_TimedRawLine>[];

    for (final line in rawLines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      final match = _lrcTimestampRegex.firstMatch(trimmed);
      if (match == null) continue;

      final min = int.parse(match.group(1)!);
      final sec = int.parse(match.group(2)!);
      final msStr = match.group(3) ?? '0';
      final ms = int.parse(msStr.padRight(3, '0').substring(0, 3));
      final startUs = (min * 60 + sec) * 1000000 + ms * 1000;

      final lyricBody = trimmed.substring(match.end).trim();
      if (lyricBody.isEmpty) continue;

      parsed.add(_TimedRawLine(startUs: startUs, body: lyricBody));
    }

    parsed.sort((a, b) => a.startUs.compareTo(b.startUs));
    final result = <LyricLine>[];

    for (var i = 0; i < parsed.length; i++) {
      final item = parsed[i];
      final nextStartUs = (i + 1 < parsed.length)
          ? parsed[i + 1].startUs
          : item.startUs + 4000000;
      final endUs = math.min(item.startUs + 6000000, nextStartUs);

      final actorDetect = detectActor(
        item.body,
        actors: actors,
        keepPrefix: keepActorPrefix,
      );

      // Check if enhanced LRC word timing is present
      final wordMatches = _lrcWordTimingRegex
          .allMatches(actorDetect.cleanText)
          .toList();
      List<LyricToken> tokens;
      String cleanText;

      if (wordMatches.isNotEmpty) {
        final buffer = StringBuffer();
        tokens = [];
        for (var w = 0; w < wordMatches.length; w++) {
          final wm = wordMatches[w];
          final wMin = int.parse(wm.group(1)!);
          final wSec = int.parse(wm.group(2)!);
          final wMsStr = wm.group(3) ?? '0';
          final wMs = int.parse(wMsStr.padRight(3, '0').substring(0, 3));
          final wStartUs = (wMin * 60 + wSec) * 1000000 + wMs * 1000;
          final wText = wm.group(4)!.trim();

          int? wEndUs;
          if (w + 1 < wordMatches.length) {
            final nwm = wordMatches[w + 1];
            final nwMin = int.parse(nwm.group(1)!);
            final nwSec = int.parse(nwm.group(2)!);
            final nwMsStr = nwm.group(3) ?? '0';
            final nwMs = int.parse(nwMsStr.padRight(3, '0').substring(0, 3));
            wEndUs = (nwMin * 60 + nwSec) * 1000000 + nwMs * 1000;
          } else {
            wEndUs = endUs;
          }

          if (buffer.isNotEmpty) buffer.write(' ');
          buffer.write(wText);
          tokens.add(
            LyricToken(
              id: newId('tok'),
              text: wText,
              index: w,
              startUs: wStartUs,
              endUs: wEndUs,
            ),
          );
        }
        cleanText = buffer.toString();
      } else {
        cleanText = actorDetect.cleanText;
        tokens = tokenize(
          cleanText,
          mode: TokenizeMode.word,
          lineStartUs: item.startUs,
          lineEndUs: endUs,
        );
      }

      result.add(
        LyricLine(
          id: newId('line'),
          text: cleanText,
          actorId: actorDetect.actorId,
          startUs: item.startUs,
          endUs: endUs,
          tokens: tokens,
          rowAssignment: (i % 2 == 0) ? 'rowA' : 'rowB',
        ),
      );
    }

    return result;
  }

  List<LyricLine> parseSrt(
    String content, {
    List<Actor> actors = const [],
    bool keepActorPrefix = false,
  }) {
    final blocks = content.split(RegExp(r'\r?\n\r?\n'));
    final result = <LyricLine>[];
    var rowIndex = 0;

    for (final block in blocks) {
      final lines = block
          .split(RegExp(r'\r?\n'))
          .where((l) => l.trim().isNotEmpty)
          .toList();
      if (lines.length < 2) continue;

      final timeLine = lines.firstWhere(
        (l) => l.contains('-->'),
        orElse: () => '',
      );
      if (timeLine.isEmpty) continue;

      final timeParts = timeLine.split('-->');
      if (timeParts.length != 2) continue;

      final startUs = _parseSrtTimestamp(timeParts[0].trim());
      final endUs = _parseSrtTimestamp(timeParts[1].trim());

      final timeIndex = lines.indexOf(timeLine);
      final textLines = lines.sublist(timeIndex + 1);
      final rawText = textLines
          .join(' ')
          .replaceAll(RegExp(r'<[^>]*>'), '')
          .trim();
      if (rawText.isEmpty) continue;

      final actorDetect = detectActor(
        rawText,
        actors: actors,
        keepPrefix: keepActorPrefix,
      );
      final tokens = tokenize(
        actorDetect.cleanText,
        mode: TokenizeMode.word,
        lineStartUs: startUs,
        lineEndUs: endUs,
      );

      result.add(
        LyricLine(
          id: newId('line'),
          text: actorDetect.cleanText,
          actorId: actorDetect.actorId,
          startUs: startUs,
          endUs: endUs,
          tokens: tokens,
          rowAssignment: (rowIndex % 2 == 0) ? 'rowA' : 'rowB',
        ),
      );
      rowIndex++;
    }
    return result;
  }

  List<LyricLine> parseAss(
    String content, {
    List<Actor> actors = const [],
    bool keepActorPrefix = false,
  }) {
    final lines = content.split(RegExp(r'\r?\n'));
    final result = <LyricLine>[];
    var rowIndex = 0;

    for (final line in lines) {
      if (!line.trim().startsWith('Dialogue:')) continue;
      final parts = line.substring('Dialogue:'.length).trim().split(',');
      if (parts.length < 10) continue;

      final startStr = parts[1].trim();
      final endStr = parts[2].trim();
      final actorStr = parts[4].trim();
      final textPart = parts.sublist(9).join(',').trim();

      final startUs = _parseAssTimestamp(startStr);
      final endUs = _parseAssTimestamp(endStr);

      final tokens = <LyricToken>[];
      final buffer = StringBuffer();
      var currentCursorUs = startUs;

      final kMatches = _assKaraokeTagRegex.allMatches(textPart).toList();
      if (kMatches.isNotEmpty) {
        for (var i = 0; i < kMatches.length; i++) {
          final m = kMatches[i];
          final durationCs = int.tryParse(m.group(1) ?? '0') ?? 0;
          final durationUs = durationCs * 10000;
          final word = m.group(2)!.trim();
          if (word.isEmpty) continue;

          final tokenStart = currentCursorUs;
          final tokenEnd = currentCursorUs + durationUs;
          currentCursorUs = tokenEnd;

          if (buffer.isNotEmpty) buffer.write(' ');
          buffer.write(word);
          tokens.add(
            LyricToken(
              id: newId('tok'),
              text: word,
              index: i,
              startUs: tokenStart,
              endUs: tokenEnd,
            ),
          );
        }
      }

      String cleanText = buffer.isNotEmpty
          ? buffer.toString()
          : textPart.replaceAll(RegExp(r'\{[^\}]*\}'), '').trim();
      if (tokens.isEmpty) {
        tokens.addAll(
          tokenize(
            cleanText,
            mode: TokenizeMode.word,
            lineStartUs: startUs,
            lineEndUs: endUs,
          ),
        );
      }

      String actorId = 'male';
      if (actorStr.isNotEmpty) {
        final match = actors.firstWhere(
          (a) =>
              a.name.toLowerCase() == actorStr.toLowerCase() ||
              a.id.toLowerCase() == actorStr.toLowerCase(),
          orElse: () => actors.isNotEmpty
              ? actors.first
              : const Actor(
                  id: 'male',
                  name: 'Nam',
                  colorValue: 0xFF42A5F5,
                  styleId: 'male',
                ),
        );
        actorId = match.id;
      } else {
        final detected = detectActor(
          cleanText,
          actors: actors,
          keepPrefix: keepActorPrefix,
        );
        actorId = detected.actorId;
        cleanText = detected.cleanText;
      }

      result.add(
        LyricLine(
          id: newId('line'),
          text: cleanText,
          actorId: actorId,
          startUs: startUs,
          endUs: endUs,
          tokens: tokens,
          rowAssignment: (rowIndex % 2 == 0) ? 'rowA' : 'rowB',
        ),
      );
      rowIndex++;
    }

    return result;
  }

  static int _parseSrtTimestamp(String text) {
    // 00:01:23,456
    final parts = text.split(':');
    if (parts.length != 3) return 0;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    final secParts = parts[2].split(RegExp(r'[,.]'));
    final s = int.tryParse(secParts[0]) ?? 0;
    final ms = (secParts.length > 1)
        ? (int.tryParse(secParts[1].padRight(3, '0').substring(0, 3)) ?? 0)
        : 0;
    return (h * 3600 + m * 60 + s) * 1000000 + ms * 1000;
  }

  static int _parseAssTimestamp(String text) {
    // 0:01:23.45
    final parts = text.split(':');
    if (parts.length != 3) return 0;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    final secParts = parts[2].split('.');
    final s = int.tryParse(secParts[0]) ?? 0;
    final cs = (secParts.length > 1)
        ? (int.tryParse(secParts[1].padRight(2, '0').substring(0, 2)) ?? 0)
        : 0;
    return (h * 3600 + m * 60 + s) * 1000000 + cs * 10000;
  }

  LyricLine splitToken(LyricLine line, int tokenIndex, int charOffset) {
    if (tokenIndex < 0 || tokenIndex >= line.tokens.length) return line;
    final target = line.tokens[tokenIndex];
    if (charOffset <= 0 || charOffset >= target.text.length) return line;

    final firstText = target.text.substring(0, charOffset);
    final secondText = target.text.substring(charOffset);

    int? firstEnd;
    int? secondStart;
    if (target.startUs != null && target.endUs != null) {
      final midUs =
          target.startUs! +
          ((target.endUs! - target.startUs!) *
                  (charOffset / target.text.length))
              .round();
      firstEnd = midUs;
      secondStart = midUs;
    }

    final newTokens = <LyricToken>[];
    for (var i = 0; i < line.tokens.length; i++) {
      if (i == tokenIndex) {
        newTokens.add(
          LyricToken(
            id: newId('tok'),
            text: firstText,
            index: newTokens.length,
            startUs: target.startUs,
            endUs: firstEnd,
          ),
        );
        newTokens.add(
          LyricToken(
            id: newId('tok'),
            text: secondText,
            index: newTokens.length,
            startUs: secondStart,
            endUs: target.endUs,
          ),
        );
      } else {
        newTokens.add(line.tokens[i].copyWith(index: newTokens.length));
      }
    }

    return line.copyWith(tokens: newTokens);
  }

  LyricLine mergeTokens(LyricLine line, int tokenIndex) {
    if (tokenIndex < 0 || tokenIndex >= line.tokens.length - 1) return line;
    final first = line.tokens[tokenIndex];
    final second = line.tokens[tokenIndex + 1];

    final mergedToken = LyricToken(
      id: newId('tok'),
      text:
          '${first.text}${second.text.startsWith(' ') ? '' : ' '}${second.text}'
              .trim(),
      index: tokenIndex,
      startUs: first.startUs ?? second.startUs,
      endUs: second.endUs ?? first.endUs,
    );

    final newTokens = <LyricToken>[];
    for (var i = 0; i < line.tokens.length; i++) {
      if (i == tokenIndex) {
        newTokens.add(mergedToken);
        i++; // skip second
      } else {
        newTokens.add(line.tokens[i].copyWith(index: newTokens.length));
      }
    }

    return line.copyWith(tokens: newTokens);
  }

  String normalizeText(String text) {
    return text
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '')
        .trim();
  }

  List<String> missingWords(LyricLine line) {
    final expected = tokenize(line.text, mode: TokenizeMode.word);
    final matches = _matchExpectedTokens(expected, line.tokens);
    return [
      for (var i = 0; i < expected.length; i++)
        if (matches[i] == null) expected[i].text,
    ];
  }

  LyricEntryStatus entryStatus(LyricLine line) {
    if (line.tokens.isEmpty) return LyricEntryStatus.notAdded;
    if (missingWords(line).isNotEmpty) return LyricEntryStatus.missingWords;
    final hasTiming = line.isTimed || line.tokens.any((token) => token.isTimed);
    return hasTiming ? LyricEntryStatus.added : LyricEntryStatus.notAdded;
  }

  /// Rebuilds the token list from the displayed lyric while retaining timing
  /// and ids for words that can be aligned. Newly recovered words receive a
  /// free nominal interval when one exists; otherwise they remain untimed.
  LyricTokenRepair repairMissingTokens(LyricLine line) {
    final expected = tokenize(line.text, mode: TokenizeMode.word);
    final matches = _matchExpectedTokens(expected, line.tokens);
    final added = <String>[];
    final rebuilt = <LyricToken>[];

    for (var i = 0; i < expected.length; i++) {
      final existingIndex = matches[i];
      if (existingIndex != null) {
        rebuilt.add(
          line.tokens[existingIndex].copyWith(text: expected[i].text, index: i),
        );
        continue;
      }

      added.add(expected[i].text);
      int? startUs;
      int? endUs;
      if (line.isTimed && line.durationUs >= expected.length * 50000) {
        final nominalStart =
            line.startUs! + (line.durationUs * i / expected.length).round();
        final nominalEnd =
            line.startUs! +
            (line.durationUs * (i + 1) / expected.length).round();
        final previousEnd = rebuilt.isEmpty
            ? line.startUs!
            : rebuilt.last.endUs;
        final nextExistingIndex = _nextMatchedTokenIndex(matches, i + 1);
        final nextStart = nextExistingIndex == null
            ? line.endUs!
            : line.tokens[nextExistingIndex].startUs;
        final lower = math.max(nominalStart, previousEnd ?? line.startUs!);
        final upper = math.min(nominalEnd, nextStart ?? line.endUs!);
        if (upper - lower >= 50000) {
          startUs = lower;
          endUs = upper;
        }
      }
      rebuilt.add(
        LyricToken(
          id: newId('tok'),
          text: expected[i].text,
          index: i,
          startUs: startUs,
          endUs: endUs,
        ),
      );
    }

    return LyricTokenRepair(
      line: line.copyWith(tokens: rebuilt),
      addedWords: added,
    );
  }

  List<int?> _matchExpectedTokens(
    List<LyricToken> expected,
    List<LyricToken> actual,
  ) {
    final expectedKeys = expected.map((token) => _wordKey(token.text)).toList();
    final actualKeys = actual.map((token) => _wordKey(token.text)).toList();
    final rows = expected.length + 1;
    final columns = actual.length + 1;
    final lcs = List.generate(rows, (_) => List<int>.filled(columns, 0));

    for (var i = expected.length - 1; i >= 0; i--) {
      for (var j = actual.length - 1; j >= 0; j--) {
        lcs[i][j] = expectedKeys[i] == actualKeys[j]
            ? lcs[i + 1][j + 1] + 1
            : math.max(lcs[i + 1][j], lcs[i][j + 1]);
      }
    }

    final result = List<int?>.filled(expected.length, null);
    var i = 0;
    var j = 0;
    while (i < expected.length && j < actual.length) {
      if (expectedKeys[i] == actualKeys[j]) {
        result[i] = j;
        i++;
        j++;
      } else if (lcs[i + 1][j] >= lcs[i][j + 1]) {
        i++;
      } else {
        j++;
      }
    }
    return result;
  }

  int? _nextMatchedTokenIndex(List<int?> matches, int fromIndex) {
    for (var i = fromIndex; i < matches.length; i++) {
      if (matches[i] != null) return matches[i];
    }
    return null;
  }

  String _wordKey(String word) => word.toLowerCase().replaceAll(
    RegExp(r'[^\p{L}\p{N}]', unicode: true),
    '',
  );
}
