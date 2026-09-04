import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/playback/playback_clock.dart';
import '../../models/project_model.dart';
import '../editor/editor_controller.dart';

class RecordingOverlay extends ConsumerStatefulWidget {
  const RecordingOverlay({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  ConsumerState<RecordingOverlay> createState() => _RecordingOverlayState();
}

class _RecordingOverlayState extends ConsumerState<RecordingOverlay> {
  int _currentLineIndex = 0;
  int _currentTokenIndex = 0;
  bool _isRecording = false;
  int? _keyPressStartUs;
  int? _pressedTokenIndex;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    final editor = ref.read(editorControllerProvider);
    final sel = editor.selectedLyricLineIndex;
    if (sel != null &&
        sel >= 0 &&
        sel < (editor.project?.lyricLines.length ?? 0)) {
      _currentLineIndex = sel;
    }
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _startRecording(EditorController editor, PlaybackClock playback) async {
    final project = editor.project;
    if (project == null || project.lyricLines.isEmpty) return;

    setState(() {
      _isRecording = true;
      _currentTokenIndex = 0;
      _keyPressStartUs = null;
      _pressedTokenIndex = null;
    });

    final anchorUs = _recordingAnchorUs(project, _currentLineIndex);
    final preRollUs =
        project.settings.preRollSeconds * Duration.microsecondsPerSecond;
    final seekTo = Duration(microseconds: math.max(0, anchorUs - preRollUs));
    await playback.seek(seekTo);
    await playback.play();
    _focusNode.requestFocus();
  }

  int _recordingAnchorUs(ProjectModel project, int lineIndex) {
    final line = project.lyricLines[lineIndex];
    if (line.startUs != null) return line.startUs!;
    for (final token in line.tokens) {
      if (token.startUs != null) return token.startUs!;
    }
    for (var index = lineIndex - 1; index >= 0; index--) {
      final previous = project.lyricLines[index];
      if (previous.endUs != null) return previous.endUs!;
    }
    return 0;
  }

  Future<void> _selectLine(
    ProjectModel project,
    PlaybackClock playback,
    int lineIndex,
  ) async {
    setState(() {
      _currentLineIndex = lineIndex;
      _currentTokenIndex = 0;
      _keyPressStartUs = null;
      _pressedTokenIndex = null;
    });
    final anchorUs = _recordingAnchorUs(project, lineIndex);
    await playback.seek(Duration(microseconds: anchorUs));
    _focusNode.requestFocus();
  }

  Future<void> _confirmResetTiming(
    EditorController editor, {
    required int startLineIndex,
  }) async {
    final resetAll = startLineIndex == 0;
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            icon: const Icon(Icons.restart_alt, color: Colors.orangeAccent),
            title: Text(
              resetAll
                  ? 'Reset toàn bộ timing?'
                  : 'Reset từ câu ${startLineIndex + 1}?',
            ),
            content: Text(
              resetAll
                  ? 'Mọi timing của tất cả câu và từ sẽ bị xóa. Có thể Undo sau thao tác này.'
                  : 'Timing từ câu ${startLineIndex + 1} đến cuối bài sẽ bị xóa. Các câu trước đó được giữ nguyên.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Hủy'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Reset timing'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;
    editor.resetRecordingTiming(startLineIndex: startLineIndex);
    setState(() {
      _currentLineIndex = startLineIndex;
      _currentTokenIndex = 0;
      _keyPressStartUs = null;
      _pressedTokenIndex = null;
    });
    _focusNode.requestFocus();
  }

  void _stopRecording(PlaybackClock playback) {
    playback.pause();
    if (_keyPressStartUs != null) {
      final editor = ref.read(editorControllerProvider);
      final project = editor.project;
      if (project != null && _currentLineIndex < project.lyricLines.length) {
        final line = project.lyricLines[_currentLineIndex];
        final targetIdx = _pressedTokenIndex ?? _currentTokenIndex;
        if (targetIdx < line.tokens.length) {
          final offsetUs = (project.settings.inputTimingOffsetMs * 1000);
          final nowUs = math.max(
            _keyPressStartUs! + 50000,
            playback.positionUs + offsetUs,
          );
          final tokens = List<LyricToken>.from(line.tokens);
          tokens[targetIdx] = tokens[targetIdx].copyWith(
            startUs: tokens[targetIdx].startUs ?? _keyPressStartUs,
            endUs: nowUs,
          );
          final lineStart = line.startUs ?? _keyPressStartUs;
          final updatedLine = line.copyWith(
            startUs: lineStart,
            endUs: nowUs,
            tokens: tokens,
          );
          final updatedLines = List<LyricLine>.from(project.lyricLines);
          updatedLines[_currentLineIndex] = updatedLine;
          editor.updateLyricLines(
            updatedLines,
            description: 'Chốt timing từ khi dừng ghi',
          );
        }
      }
    }
    setState(() {
      _isRecording = false;
      _keyPressStartUs = null;
      _pressedTokenIndex = null;
    });
  }

  void _advanceToNextLine(EditorController editor, PlaybackClock playback) {
    final project = editor.project;
    final totalLines = project?.lyricLines.length ?? 0;

    setState(() {
      _keyPressStartUs = null;
      _pressedTokenIndex = null;
      if (_currentLineIndex + 1 < totalLines) {
        _currentLineIndex++;
        _currentTokenIndex = 0;
      } else {
        _stopRecording(playback);
      }
    });

    if (_currentLineIndex < totalLines) {
      editor.selectLyricLine(_currentLineIndex);
    }
  }

  void _finalizeLastWordAndAdvance(
    EditorController editor,
    PlaybackClock playback,
    int endUs,
  ) {
    final project = editor.project;
    if (project == null || _currentLineIndex >= project.lyricLines.length) {
      return;
    }

    final line = project.lyricLines[_currentLineIndex];
    if (line.tokens.isEmpty) {
      _advanceToNextLine(editor, playback);
      return;
    }

    final lastIdx = line.tokens.length - 1;
    final tokens = List<LyricToken>.from(line.tokens);
    final startUs =
        tokens[lastIdx].startUs ?? (_keyPressStartUs ?? (endUs - 300000));
    final finalEndUs = math.max(startUs + 50000, endUs);

    tokens[lastIdx] = tokens[lastIdx].copyWith(
      startUs: startUs,
      endUs: finalEndUs,
    );

    final lineStart = line.startUs ?? startUs;
    final updatedLine = line.copyWith(
      startUs: lineStart,
      endUs: finalEndUs,
      tokens: tokens,
    );

    final updatedLines = List<LyricLine>.from(project.lyricLines);
    updatedLines[_currentLineIndex] = updatedLine;
    editor.updateLyricLines(updatedLines, description: 'Chốt timing chữ cuối');

    _advanceToNextLine(editor, playback);
  }

  void _handleKeyDown(EditorController editor, PlaybackClock playback) {
    if (!_isRecording) return;
    final project = editor.project;
    if (project == null || _currentLineIndex >= project.lyricLines.length) {
      return;
    }

    final offsetUs = (project.settings.inputTimingOffsetMs * 1000);
    final nowUs = math.max(0, playback.positionUs + offsetUs);

    final mode = project.settings.recordingMode;
    if (mode == 'hold') {
      _keyPressStartUs ??= nowUs;
      _pressedTokenIndex = _currentTokenIndex;
    } else {
      // Tap Mode
      _handleTap(editor, playback, nowUs);
    }
  }

  void _handleKeyUp(EditorController editor, PlaybackClock playback) {
    if (!_isRecording || _keyPressStartUs == null) return;
    final project = editor.project;
    if (project == null || _currentLineIndex >= project.lyricLines.length) {
      return;
    }

    final offsetUs = (project.settings.inputTimingOffsetMs * 1000);
    final nowUs = math.max(
      _keyPressStartUs! + 50000,
      playback.positionUs + offsetUs,
    );

    final mode = project.settings.recordingMode;
    if (mode == 'tap') {
      // A release must not end the final word: wait for the next tap or Stop.
      return;
    }

    // Hold Mode
    final line = project.lyricLines[_currentLineIndex];
    if (_currentTokenIndex < line.tokens.length) {
      final isLastTokenOfLine = _currentTokenIndex + 1 >= line.tokens.length;
      final tokens = List<LyricToken>.from(line.tokens);
      tokens[_currentTokenIndex] = tokens[_currentTokenIndex].copyWith(
        startUs: _keyPressStartUs,
        endUs: nowUs,
      );

      final lineStart = line.startUs ?? _keyPressStartUs;
      final updatedLine = line.copyWith(
        startUs: lineStart,
        endUs: nowUs,
        tokens: tokens,
      );

      final updatedLines = List<LyricLine>.from(project.lyricLines);
      updatedLines[_currentLineIndex] = updatedLine;
      editor.updateLyricLines(updatedLines, description: 'Ghi timing từ');

      setState(() {
        _keyPressStartUs = null;
        _pressedTokenIndex = null;
        if (!isLastTokenOfLine) {
          _currentTokenIndex++;
        } else {
          // Line complete, advance to next line
          if (_currentLineIndex + 1 < project.lyricLines.length) {
            _currentLineIndex++;
            _currentTokenIndex = 0;
          } else {
            _stopRecording(playback);
          }
        }
      });

      if (isLastTokenOfLine && _currentLineIndex < project.lyricLines.length) {
        editor.selectLyricLine(_currentLineIndex);
      }
    }
  }

  void _handleTap(EditorController editor, PlaybackClock playback, int nowUs) {
    final project = editor.project;
    if (project == null || _currentLineIndex >= project.lyricLines.length) {
      return;
    }

    final line = project.lyricLines[_currentLineIndex];
    if (line.tokens.isEmpty) {
      _advanceToNextLine(editor, playback);
      return;
    }

    if (_pressedTokenIndex == line.tokens.length - 1 &&
        _keyPressStartUs != null) {
      _finalizeLastWordAndAdvance(editor, playback, nowUs);
      return;
    }

    final updatedLine = editor.timingEngine.beginTappedToken(
      line,
      _currentTokenIndex,
      nowUs,
    );
    final updatedLines = List<LyricLine>.from(project.lyricLines);
    updatedLines[_currentLineIndex] = updatedLine;
    editor.updateLyricLines(updatedLines, description: 'Tap timing');
    setState(() {
      _keyPressStartUs = updatedLine.tokens[_currentTokenIndex].startUs;
      _pressedTokenIndex = _currentTokenIndex;
      if (_currentTokenIndex < line.tokens.length - 1) _currentTokenIndex++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final editor = ref.watch(editorControllerProvider);
    final playback = ref.watch(playbackClockProvider);
    final project = editor.project;

    if (project == null || project.lyricLines.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xEE1E2127),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white24),
        ),
        child: const Text('Hãy import lời bài hát trước khi ghi timing.'),
      );
    }

    final currentLine = (_currentLineIndex < project.lyricLines.length)
        ? project.lyricLines[_currentLineIndex]
        : null;
    final nextLine = _currentLineIndex + 1 < project.lyricLines.length
        ? project.lyricLines[_currentLineIndex + 1]
        : null;

    final actor = currentLine != null
        ? project.actors.firstWhere(
            (a) => a.id == currentLine.actorId,
            orElse: () => project.actors.first,
          )
        : null;

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event.logicalKey == LogicalKeyboardKey.space) {
          if (event is KeyDownEvent) {
            _handleKeyDown(editor, playback);
          } else if (event is KeyRepeatEvent) {
            return KeyEventResult.handled;
          } else if (event is KeyUpEvent) {
            _handleKeyUp(editor, playback);
          }
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.escape &&
            event is KeyDownEvent) {
          _stopRecording(playback);
          widget.onClose();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xF2181A20),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isRecording ? Colors.redAccent : const Color(0xFFFFB300),
            width: 1.5,
          ),
          boxShadow: const [
            BoxShadow(color: Colors.black87, blurRadius: 20, spreadRadius: 4),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top HUD Bar
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _isRecording
                          ? Colors.red.withValues(alpha: 0.2)
                          : Colors.amber.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: _isRecording ? Colors.redAccent : Colors.amber,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _isRecording ? Icons.fiber_manual_record : Icons.mic,
                          size: 14,
                          color: _isRecording ? Colors.redAccent : Colors.amber,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isRecording ? 'RECORDING' : 'RECORD TIMING',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: _isRecording
                                ? Colors.redAccent
                                : Colors.amber,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (actor != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Color(actor.colorValue).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        actor.name,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(actor.colorValue),
                        ),
                      ),
                    ),
                  const Spacer(),
                  Text(
                    'Câu ${_currentLineIndex + 1} / ${project.lyricLines.length}',
                    style: const TextStyle(fontSize: 11, color: Colors.white70),
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    tooltip: 'Đóng (Esc)',
                    onPressed: () {
                      _stopRecording(playback);
                      widget.onClose();
                    },
                  ),
                ],
              ),

              const SizedBox(height: 7),

              // Select the exact line where this recording pass starts.
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.format_list_numbered,
                      size: 15,
                      color: Color(0xFFFFB300),
                    ),
                    const SizedBox(width: 7),
                    const Text(
                      'Bắt đầu từ:',
                      style: TextStyle(fontSize: 11, color: Colors.white70),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _currentLineIndex,
                          isExpanded: true,
                          isDense: true,
                          onChanged: _isRecording
                              ? null
                              : (value) {
                                  if (value != null) {
                                    _selectLine(project, playback, value);
                                  }
                                },
                          items: [
                            for (
                              var index = 0;
                              index < project.lyricLines.length;
                              index++
                            )
                              DropdownMenuItem(
                                value: index,
                                child: Text(
                                  '${index + 1}. ${project.lyricLines[index].text}',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    PopupMenuButton<String>(
                      enabled: !_isRecording,
                      tooltip: 'Reset timing để ghi lại',
                      onSelected: (value) {
                        _confirmResetTiming(
                          editor,
                          startLineIndex: value == 'all'
                              ? 0
                              : _currentLineIndex,
                        );
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'all',
                          child: Text('Reset toàn bộ timing'),
                        ),
                        PopupMenuItem(
                          value: 'from_here',
                          child: Text(
                            'Reset từ câu ${_currentLineIndex + 1} đến cuối',
                          ),
                        ),
                      ],
                      child: const Padding(
                        padding: EdgeInsets.all(5),
                        child: Icon(Icons.restart_alt, size: 17),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 7),

              // Compact prompter: current tokens + the full upcoming line.
              if (currentLine != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 7,
                    horizontal: 9,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    children: [
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: currentLine.tokens.map((token) {
                            final isCurrent = token.index == _currentTokenIndex;
                            final isPassed = token.index < _currentTokenIndex;

                            return Padding(
                              padding: const EdgeInsets.only(right: 5),
                              child: InkWell(
                                onTap: () => setState(
                                  () => _currentTokenIndex = token.index,
                                ),
                                borderRadius: BorderRadius.circular(5),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 100),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isCurrent ? 8 : 5,
                                    vertical: isCurrent ? 4 : 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isCurrent
                                        ? const Color(0xFFFFB300)
                                        : (isPassed
                                              ? Colors.white12
                                              : Colors.transparent),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Text(
                                    token.text,
                                    style: TextStyle(
                                      fontSize: isCurrent ? 15 : 12,
                                      fontWeight: isCurrent
                                          ? FontWeight.w900
                                          : FontWeight.w600,
                                      color: isCurrent
                                          ? Colors.black
                                          : (isPassed
                                                ? Colors.white54
                                                : Colors.white),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            const Text(
                              'TIẾP THEO',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFFFB300),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                nextLine?.text ?? '— Hết bài —',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 8),

              // Mode & Controls Bar
              if (project.settings.recordingMode == 'tap')
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _isRecording &&
                            _pressedTokenIndex ==
                                (currentLine?.tokens.length ?? 0) - 1 &&
                            _keyPressStartUs != null
                        ? 'Đang ngân từ cuối — gõ Space khi hát xong để kết thúc câu.'
                        : 'Gõ Space ở đầu mỗi từ. Ngân từ cuối xong, gõ thêm một lần để kết thúc câu.',
                    style: const TextStyle(fontSize: 11, color: Colors.amber),
                  ),
                ),
              Row(
                children: [
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'hold', label: Text('Giữ')),
                      ButtonSegment(value: 'tap', label: Text('Gõ nhịp')),
                    ],
                    selected: {project.settings.recordingMode},
                    onSelectionChanged: _isRecording
                        ? null
                        : (set) {
                            final updatedSettings = project.settings.copyWith(
                              recordingMode: set.first,
                            );
                            editor.updateProjectSettings(updatedSettings);
                            _focusNode.requestFocus();
                          },
                  ),
                  const Spacer(),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<double>(
                      value: playback.speed,
                      isDense: true,
                      icon: const Icon(Icons.speed, size: 15),
                      items:
                          ({0.5, 0.75, 1.0, 1.25, playback.speed}.toList()
                                ..sort())
                              .map(
                                (speed) => DropdownMenuItem(
                                  value: speed,
                                  child: Text(
                                    '$speed×',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ),
                              )
                              .toList(),
                      onChanged: (speed) {
                        if (speed != null) playback.setSpeed(speed);
                        _focusNode.requestFocus();
                      },
                    ),
                  ),
                  IconButton.filledTonal(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.replay_5, size: 14),
                    tooltip: 'Lùi 3 giây',
                    onPressed: () {
                      playback.seek(
                        Duration(
                          microseconds: math.max(
                            0,
                            playback.positionUs - 3000000,
                          ),
                        ),
                      );
                      _focusNode.requestFocus();
                    },
                  ),
                  const SizedBox(width: 6),
                  if (!_isRecording)
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFFB300),
                        foregroundColor: Colors.black,
                      ),
                      icon: const Icon(
                        Icons.fiber_manual_record,
                        size: 16,
                        color: Colors.red,
                      ),
                      label: const Text(
                        'GHI (Space)',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: () => _startRecording(editor, playback),
                    )
                  else
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                      ),
                      icon: const Icon(Icons.stop, size: 16),
                      label: const Text(
                        'DỪNG GHI',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: () => _stopRecording(playback),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
