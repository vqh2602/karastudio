import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/playback/playback_clock.dart';
import '../../core/waveform/waveform_cache.dart';
import '../../models/project_model.dart';

enum _DragMode { none, moveToken, resizeTokenStart, resizeTokenEnd, seek }

class WaveformTimeline extends StatefulWidget {
  const WaveformTimeline({
    super.key,
    required this.clock,
    required this.waveform,
    required this.project,
    required this.durationUs,
    this.onLinesUpdated,
    this.onAddMarker,
    this.onLineSelected,
  });

  final PlaybackClock clock;
  final WaveformCache? waveform;
  final ProjectModel? project;
  final int durationUs;
  final void Function(List<LyricLine> updatedLines, {String? description})?
  onLinesUpdated;
  final void Function(int timeUs)? onAddMarker;
  final ValueChanged<int>? onLineSelected;

  @override
  State<WaveformTimeline> createState() => _WaveformTimelineState();
}

class _WaveformTimelineState extends State<WaveformTimeline> {
  double zoom = 1.0;
  double scroll = 0.0;

  // Drag interaction state
  _DragMode _dragMode = _DragMode.none;
  int? _activeLineIndex;
  int? _activeTokenIndex;
  int _dragAnchorTimeUs = 0;
  int _initialStartUs = 0;
  int _initialEndUs = 0;
  List<LyricLine>? _draggingLinesSnapshot;

  MouseCursor _cursor = MouseCursor.defer;
  DateTime _manualNavigationUntil = DateTime.fromMillisecondsSinceEpoch(0);

  static const double rulerHeight = 22.0;
  static const double markersHeight = 18.0;
  static const double subtitleTrackHeight = 56.0;
  double get waveTop => rulerHeight + markersHeight + subtitleTrackHeight;

  @override
  void initState() {
    super.initState();
    widget.clock.addListener(_followPlayhead);
  }

  @override
  void didUpdateWidget(covariant WaveformTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.clock != widget.clock) {
      oldWidget.clock.removeListener(_followPlayhead);
      widget.clock.addListener(_followPlayhead);
    }
  }

  @override
  void dispose() {
    widget.clock.removeListener(_followPlayhead);
    super.dispose();
  }

  void _followPlayhead() {
    if (!mounted ||
        !widget.clock.isPlaying ||
        zoom <= 1.0 ||
        _dragMode != _DragMode.none ||
        DateTime.now().isBefore(_manualNavigationUntil) ||
        widget.durationUs <= 0) {
      return;
    }

    final positionUs = widget.clock.positionUs;
    final viewStartUs = _viewStartUs;
    final leftGuardUs = viewStartUs + (_visibleDurationUs * 0.12).round();
    final rightGuardUs = viewStartUs + (_visibleDurationUs * 0.82).round();
    if (positionUs >= leftGuardUs && positionUs <= rightGuardUs) return;

    final maxStartUs = widget.durationUs - _visibleDurationUs;
    if (maxStartUs <= 0) return;
    final desiredStartUs = (positionUs - _visibleDurationUs * 0.2).clamp(
      0,
      maxStartUs,
    );
    final nextScroll = desiredStartUs / maxStartUs;
    if ((nextScroll - scroll).abs() < 0.0001) return;
    setState(() => scroll = nextScroll.clamp(0.0, 1.0));
  }

  void _pauseAutoFollow() {
    _manualNavigationUntil = DateTime.now().add(
      const Duration(milliseconds: 1500),
    );
  }

  int get _visibleDurationUs => widget.durationUs <= 0
      ? 10000000
      : math.max(500000, (widget.durationUs / zoom).round());

  int get _viewStartUs =>
      ((math.max(0, widget.durationUs - _visibleDurationUs)) * scroll).round();

  int _xToTimeUs(double x, double width) {
    if (width <= 0) return 0;
    return _viewStartUs +
        ((x.clamp(0.0, width) / width) * _visibleDurationUs).round();
  }

  double _timeUsToX(int timeUs, double width) {
    if (_visibleDurationUs <= 0) return 0;
    return (timeUs - _viewStartUs) / _visibleDurationUs * width;
  }

  void _onPointerSignal(PointerSignalEvent event, double width) {
    if (event is! PointerScrollEvent || widget.durationUs <= 0) return;
    _pauseAutoFollow();

    if (HardwareKeyboard.instance.isShiftPressed ||
        event.scrollDelta.dx.abs() > event.scrollDelta.dy.abs()) {
      final delta = event.scrollDelta.dx.abs() > event.scrollDelta.dy.abs()
          ? event.scrollDelta.dx
          : event.scrollDelta.dy;
      setState(() {
        scroll = (scroll + delta / math.max(200, width)).clamp(0.0, 1.0);
      });
      return;
    }

    final pointerFraction = (event.localPosition.dx / width).clamp(0.0, 1.0);
    final anchorTimeUs = _viewStartUs + (_visibleDurationUs * pointerFraction);
    setState(() {
      zoom = (zoom * (event.scrollDelta.dy > 0 ? 0.86 : 1.16)).clamp(
        1.0,
        128.0,
      );
      if (zoom == 1.0) {
        scroll = 0.0;
      } else {
        final newVisibleUs = _visibleDurationUs;
        final maxStartUs = math.max(1, widget.durationUs - newVisibleUs);
        final desiredStartUs = anchorTimeUs - newVisibleUs * pointerFraction;
        scroll = (desiredStartUs / maxStartUs).clamp(0.0, 1.0);
      }
    });
  }

  void _onHover(PointerHoverEvent event, double width) {
    if (_dragMode != _DragMode.none) return;
    final pos = event.localPosition;

    if (pos.dy >= rulerHeight + markersHeight && pos.dy <= waveTop) {
      final hit = _hitTestToken(pos.dx, width, pos.dy);
      if (hit != null) {
        if (hit.isLeftEdge || hit.isRightEdge) {
          if (_cursor != SystemMouseCursors.resizeColumn) {
            setState(() => _cursor = SystemMouseCursors.resizeColumn);
          }
          return;
        } else {
          if (_cursor != SystemMouseCursors.grab) {
            setState(() => _cursor = SystemMouseCursors.grab);
          }
          return;
        }
      }
    }

    if (_cursor != MouseCursor.defer) {
      setState(() => _cursor = MouseCursor.defer);
    }
  }

  _TokenHitResult? _hitTestToken(double x, double width, [double? y]) {
    final project = widget.project;
    if (project == null || project.lyricLines.isEmpty) return null;

    const edgeTolerancePx = 6.0;

    // Search lines in reverse order so topmost rendered element is prioritized
    for (var l = project.lyricLines.length - 1; l >= 0; l--) {
      final line = project.lyricLines[l];
      for (var t = line.tokens.length - 1; t >= 0; t--) {
        final token = line.tokens[t];
        if (token.startUs != null) {
          final effectiveEndUs = token.endUs ?? (token.startUs! + 500000);
          final startX = _timeUsToX(token.startUs!, width);
          final rawEndX = _timeUsToX(effectiveEndUs, width);
          final endX = math.max(startX + 8.0, rawEndX);

          if (x >= startX - edgeTolerancePx && x <= endX + edgeTolerancePx) {
            final isLeft = (x - startX).abs() <= edgeTolerancePx;
            final isRight = (x - endX).abs() <= edgeTolerancePx;
            return _TokenHitResult(
              lineIndex: l,
              tokenIndex: t,
              isLeftEdge: isLeft,
              isRightEdge: isRight,
            );
          }
        }
      }
    }
    return null;
  }

  void _onPanStart(DragStartDetails details, double width) {
    final pos = details.localPosition;

    // 1. Subtitle Track Hit Testing
    if (pos.dy >= rulerHeight + markersHeight && pos.dy <= waveTop) {
      final hit = _hitTestToken(pos.dx, width, pos.dy);
      if (hit != null && widget.project != null) {
        widget.onLineSelected?.call(hit.lineIndex);
        final line = widget.project!.lyricLines[hit.lineIndex];
        final token = line.tokens[hit.tokenIndex];

        setState(() {
          _activeLineIndex = hit.lineIndex;
          _activeTokenIndex = hit.tokenIndex;
          _dragAnchorTimeUs = _xToTimeUs(pos.dx, width);
          _initialStartUs = token.startUs ?? line.startUs ?? 0;
          _initialEndUs =
              token.endUs ?? line.endUs ?? (_initialStartUs + 500000);
          _draggingLinesSnapshot = List<LyricLine>.from(
            widget.project!.lyricLines,
          );

          if (hit.isLeftEdge) {
            _dragMode = _DragMode.resizeTokenStart;
            _cursor = SystemMouseCursors.resizeColumn;
          } else if (hit.isRightEdge) {
            _dragMode = _DragMode.resizeTokenEnd;
            _cursor = SystemMouseCursors.resizeColumn;
          } else {
            _dragMode = _DragMode.moveToken;
            _cursor = SystemMouseCursors.grabbing;
          }
        });
        return;
      }
    }

    // 2. Playhead Seek
    _dragMode = _DragMode.seek;
    final time = _xToTimeUs(pos.dx, width);
    widget.clock.seek(Duration(microseconds: time));
  }

  void _onPanUpdate(DragUpdateDetails details, double width) {
    if (_dragMode == _DragMode.seek) {
      final time = _xToTimeUs(details.localPosition.dx, width);
      widget.clock.seek(Duration(microseconds: time));
      return;
    }

    if (_activeLineIndex == null ||
        _activeTokenIndex == null ||
        _draggingLinesSnapshot == null) {
      return;
    }

    final currentTimeUs = _xToTimeUs(details.localPosition.dx, width);
    final deltaUs = currentTimeUs - _dragAnchorTimeUs;

    final updatedLines = List<LyricLine>.from(_draggingLinesSnapshot!);
    final line = updatedLines[_activeLineIndex!];
    final token = line.tokens[_activeTokenIndex!];

    var newStartUs = _initialStartUs;
    var newEndUs = _initialEndUs;
    const minimumDurationUs = 50000;
    final previousEndUs = _previousTimedEnd(line, _activeTokenIndex!) ?? 0;
    final nextStartUs =
        _nextTimedStart(line, _activeTokenIndex!) ??
        (widget.durationUs > 0
            ? widget.durationUs
            : _initialEndUs + _visibleDurationUs);

    if (_dragMode == _DragMode.moveToken) {
      final durationUs = math.max(
        minimumDurationUs,
        _initialEndUs - _initialStartUs,
      );
      final latestStartUs = math.max(previousEndUs, nextStartUs - durationUs);
      newStartUs = (_initialStartUs + deltaUs).clamp(
        previousEndUs,
        latestStartUs,
      );
      newEndUs = newStartUs + durationUs;
    } else if (_dragMode == _DragMode.resizeTokenStart) {
      newStartUs = (_initialStartUs + deltaUs).clamp(
        previousEndUs,
        math.max(previousEndUs, _initialEndUs - minimumDurationUs),
      );
    } else if (_dragMode == _DragMode.resizeTokenEnd) {
      newEndUs = (_initialEndUs + deltaUs).clamp(
        _initialStartUs + minimumDurationUs,
        math.max(_initialStartUs + minimumDurationUs, nextStartUs),
      );
    }

    // Snapping to playhead or grid (within 30ms)
    final playheadUs = widget.clock.positionUs;
    if ((newStartUs - playheadUs).abs() < 30000) newStartUs = playheadUs;
    if ((newEndUs - playheadUs).abs() < 30000) newEndUs = playheadUs;
    newStartUs = math.max(previousEndUs, newStartUs);
    newEndUs = math.min(nextStartUs, newEndUs);
    if (newEndUs - newStartUs < minimumDurationUs) {
      if (_dragMode == _DragMode.resizeTokenStart) {
        newStartUs = math.max(previousEndUs, newEndUs - minimumDurationUs);
      } else {
        newEndUs = math.min(nextStartUs, newStartUs + minimumDurationUs);
      }
    }

    final updatedTokens = List<LyricToken>.from(line.tokens);
    updatedTokens[_activeTokenIndex!] = token.copyWith(
      startUs: newStartUs,
      endUs: newEndUs,
    );

    // Auto update parent line start/end from all tokens
    int? minStart;
    int? maxEnd;
    for (final t in updatedTokens) {
      if (t.startUs != null) {
        minStart = (minStart == null)
            ? t.startUs!
            : math.min(minStart, t.startUs!);
      }
      if (t.endUs != null) {
        maxEnd = (maxEnd == null) ? t.endUs! : math.max(maxEnd, t.endUs!);
      }
    }

    updatedLines[_activeLineIndex!] = line.copyWith(
      startUs: minStart ?? line.startUs,
      endUs: maxEnd ?? line.endUs,
      tokens: updatedTokens,
    );

    widget.onLinesUpdated?.call(
      updatedLines,
      description: 'Chỉnh sửa timeline token',
    );
  }

  int? _previousTimedEnd(LyricLine line, int tokenIndex) {
    for (var index = tokenIndex - 1; index >= 0; index--) {
      final endUs = line.tokens[index].endUs;
      if (endUs != null) return endUs;
    }
    return null;
  }

  int? _nextTimedStart(LyricLine line, int tokenIndex) {
    for (var index = tokenIndex + 1; index < line.tokens.length; index++) {
      final startUs = line.tokens[index].startUs;
      if (startUs != null) return startUs;
    }
    return null;
  }

  void _onTapDown(TapDownDetails details, double width) {
    final pos = details.localPosition;
    if (pos.dy < rulerHeight + markersHeight || pos.dy > waveTop) return;
    final hit = _hitTestToken(pos.dx, width, pos.dy);
    if (hit == null) return;
    widget.onLineSelected?.call(hit.lineIndex);
    setState(() {
      _activeLineIndex = hit.lineIndex;
      _activeTokenIndex = hit.tokenIndex;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() {
      _dragMode = _DragMode.none;
      _activeLineIndex = null;
      _activeTokenIndex = null;
      _draggingLinesSnapshot = null;
      _cursor = MouseCursor.defer;
    });
  }

  void _onDoubleTapDown(TapDownDetails details, double width) {
    final pos = details.localPosition;
    if (pos.dy >= rulerHeight + markersHeight && pos.dy <= waveTop) {
      final hit = _hitTestToken(pos.dx, width, pos.dy);
      if (hit != null && widget.project != null) {
        widget.onLineSelected?.call(hit.lineIndex);
        final line = widget.project!.lyricLines[hit.lineIndex];
        final token = line.tokens[hit.tokenIndex];
        _showQuickEditDialog(
          context,
          hit.lineIndex,
          hit.tokenIndex,
          line,
          token,
        );
      }
    }
  }

  Future<void> _showQuickEditDialog(
    BuildContext context,
    int lineIndex,
    int tokenIndex,
    LyricLine line,
    LyricToken token,
  ) async {
    final startSec = (token.startUs ?? 0) / Duration.microsecondsPerSecond;
    final endSec =
        (token.endUs ?? (token.startUs ?? 0) + 500000) /
        Duration.microsecondsPerSecond;

    final startController = TextEditingController(
      text: startSec.toStringAsFixed(3),
    );
    final endController = TextEditingController(
      text: endSec.toStringAsFixed(3),
    );
    final textController = TextEditingController(text: token.text);

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.edit_note, color: Color(0xFFFFB300)),
              const SizedBox(width: 8),
              Text('Chỉnh Sửa Timing: "${token.text}"'),
            ],
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: textController,
                  decoration: const InputDecoration(
                    labelText: 'Chữ / Từ',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: startController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Bắt đầu (giây)',
                          suffixText: 's',
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: endController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Kết thúc (giây)',
                          suffixText: 's',
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Nudge Buttons
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ActionChip(
                      label: const Text(
                        '-100ms',
                        style: TextStyle(fontSize: 11),
                      ),
                      onPressed: () {
                        final cur = double.tryParse(startController.text) ?? 0;
                        startController.text = math
                            .max(0.0, cur - 0.1)
                            .toStringAsFixed(3);
                        final curE = double.tryParse(endController.text) ?? 0;
                        endController.text = math
                            .max(0.0, curE - 0.1)
                            .toStringAsFixed(3);
                      },
                    ),
                    ActionChip(
                      label: const Text(
                        '-50ms',
                        style: TextStyle(fontSize: 11),
                      ),
                      onPressed: () {
                        final cur = double.tryParse(startController.text) ?? 0;
                        startController.text = math
                            .max(0.0, cur - 0.05)
                            .toStringAsFixed(3);
                        final curE = double.tryParse(endController.text) ?? 0;
                        endController.text = math
                            .max(0.0, curE - 0.05)
                            .toStringAsFixed(3);
                      },
                    ),
                    ActionChip(
                      label: const Text(
                        '+50ms',
                        style: TextStyle(fontSize: 11),
                      ),
                      onPressed: () {
                        final cur = double.tryParse(startController.text) ?? 0;
                        startController.text = (cur + 0.05).toStringAsFixed(3);
                        final curE = double.tryParse(endController.text) ?? 0;
                        endController.text = (curE + 0.05).toStringAsFixed(3);
                      },
                    ),
                    ActionChip(
                      label: const Text(
                        '+100ms',
                        style: TextStyle(fontSize: 11),
                      ),
                      onPressed: () {
                        final cur = double.tryParse(startController.text) ?? 0;
                        startController.text = (cur + 0.1).toStringAsFixed(3);
                        final curE = double.tryParse(endController.text) ?? 0;
                        endController.text = (curE + 0.1).toStringAsFixed(3);
                      },
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.my_location, size: 12),
                      label: const Text(
                        'Gán vào Playhead',
                        style: TextStyle(fontSize: 11),
                      ),
                      onPressed: () {
                        final pSec =
                            widget.clock.positionUs /
                            Duration.microsecondsPerSecond;
                        final dur =
                            (double.tryParse(endController.text) ?? 0) -
                            (double.tryParse(startController.text) ?? 0);
                        startController.text = pSec.toStringAsFixed(3);
                        endController.text = (pSec + math.max(0.2, dur))
                            .toStringAsFixed(3);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
              icon: const Icon(Icons.timer_off_outlined, size: 14),
              label: const Text('Xóa timing từ này'),
              onPressed: () {
                if (widget.project != null) {
                  final updatedLines = List<LyricLine>.from(
                    widget.project!.lyricLines,
                  );
                  final targetLine = updatedLines[lineIndex];
                  final updatedTokens = List<LyricToken>.from(
                    targetLine.tokens,
                  );
                  updatedTokens[tokenIndex] = token.copyWith(clearTiming: true);

                  int? minStart;
                  int? maxEnd;
                  for (final t in updatedTokens) {
                    if (t.startUs != null) {
                      minStart = (minStart == null)
                          ? t.startUs!
                          : math.min(minStart, t.startUs!);
                    }
                    if (t.endUs != null) {
                      maxEnd = (maxEnd == null)
                          ? t.endUs!
                          : math.max(maxEnd, t.endUs!);
                    }
                  }

                  updatedLines[lineIndex] = targetLine.copyWith(
                    startUs: minStart,
                    endUs: maxEnd,
                    tokens: updatedTokens,
                  );
                  widget.onLinesUpdated?.call(
                    updatedLines,
                    description: 'Xóa timing từ "${token.text}"',
                  );
                }
                Navigator.pop(context);
              },
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () {
                final sSec = double.tryParse(startController.text);
                final eSec = double.tryParse(endController.text);
                if (sSec != null &&
                    eSec != null &&
                    eSec > sSec &&
                    widget.project != null) {
                  final sUs = (sSec * Duration.microsecondsPerSecond).round();
                  final eUs = (eSec * Duration.microsecondsPerSecond).round();

                  final updatedLines = List<LyricLine>.from(
                    widget.project!.lyricLines,
                  );
                  final targetLine = updatedLines[lineIndex];
                  final updatedTokens = List<LyricToken>.from(
                    targetLine.tokens,
                  );

                  updatedTokens[tokenIndex] = token.copyWith(
                    text: textController.text.trim().isEmpty
                        ? token.text
                        : textController.text.trim(),
                    startUs: sUs,
                    endUs: eUs,
                  );

                  int? minStart;
                  int? maxEnd;
                  for (final t in updatedTokens) {
                    if (t.startUs != null) {
                      minStart = (minStart == null)
                          ? t.startUs!
                          : math.min(minStart, t.startUs!);
                    }
                    if (t.endUs != null) {
                      maxEnd = (maxEnd == null)
                          ? t.endUs!
                          : math.max(maxEnd, t.endUs!);
                    }
                  }

                  updatedLines[lineIndex] = targetLine.copyWith(
                    startUs: minStart ?? targetLine.startUs,
                    endUs: maxEnd ?? targetLine.endUs,
                    tokens: updatedTokens,
                  );

                  widget.onLinesUpdated?.call(
                    updatedLines,
                    description: 'Sửa timing "${token.text}"',
                  );
                }
                Navigator.pop(context);
              },
              child: const Text('Lưu Thay Đổi'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Top Toolbar (Zoom, Marker, Audio title)
        Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainer,
            border: Border(
              bottom: BorderSide(color: Theme.of(context).dividerColor),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.graphic_eq, size: 15, color: Color(0xFFFFB300)),
              const SizedBox(width: 6),
              const Text(
                'TIMELINE (Cuộn chuột: zoom • Shift+cuộn: di chuyển)',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  minimumSize: const Size(24, 20),
                ),
                onPressed: () =>
                    widget.onAddMarker?.call(widget.clock.positionUs),
                icon: const Icon(Icons.bookmark_add_outlined, size: 12),
                label: const Text(
                  'Add Marker (M)',
                  style: TextStyle(fontSize: 10),
                ),
              ),
              const Spacer(),
              const Icon(Icons.zoom_out, size: 14),
              SizedBox(
                width: 110,
                child: Slider(
                  value: math.log(zoom) / math.log(128),
                  onChanged: (value) => setState(() {
                    _pauseAutoFollow();
                    zoom = math.pow(128, value).toDouble();
                    if (zoom < 1.01) {
                      zoom = 1.0;
                      scroll = 0.0;
                    }
                  }),
                ),
              ),
              const Icon(Icons.zoom_in, size: 14),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  '${zoom.toStringAsFixed(1)}×',
                  style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
                ),
              ),
            ],
          ),
        ),

        // Main Multi-Track Area
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => MouseRegion(
              cursor: _cursor,
              onHover: (e) => _onHover(e, constraints.maxWidth),
              child: Listener(
                onPointerSignal: (event) =>
                    _onPointerSignal(event, constraints.maxWidth),
                child: GestureDetector(
                  key: const Key('timeline_gesture_detector'),
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (d) => _onTapDown(d, constraints.maxWidth),
                  onDoubleTapDown: (d) =>
                      _onDoubleTapDown(d, constraints.maxWidth),
                  onPanStart: (d) => _onPanStart(d, constraints.maxWidth),
                  onPanUpdate: (d) => _onPanUpdate(d, constraints.maxWidth),
                  onPanEnd: _onPanEnd,
                  child: ListenableBuilder(
                    listenable: widget.clock,
                    builder: (context, _) => CustomPaint(
                      size: Size.infinite,
                      painter: _MultiTrackTimelinePainter(
                        waveform: widget.waveform,
                        project: widget.project,
                        durationUs: widget.durationUs,
                        viewStartUs: _viewStartUs,
                        visibleDurationUs: _visibleDurationUs,
                        positionUs: widget.clock.positionUs,
                        colors: Theme.of(context).colorScheme,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        // Horizontal Scrollbar if zoomed
        if (zoom > 1.0)
          SizedBox(
            height: 14,
            child: Slider(
              value: scroll,
              onChanged: (value) => setState(() {
                _pauseAutoFollow();
                scroll = value;
              }),
            ),
          ),
      ],
    );
  }
}

class _TokenHitResult {
  const _TokenHitResult({
    required this.lineIndex,
    required this.tokenIndex,
    required this.isLeftEdge,
    required this.isRightEdge,
  });

  final int lineIndex;
  final int tokenIndex;
  final bool isLeftEdge;
  final bool isRightEdge;
}

class _MultiTrackTimelinePainter extends CustomPainter {
  const _MultiTrackTimelinePainter({
    required this.waveform,
    required this.project,
    required this.durationUs,
    required this.viewStartUs,
    required this.visibleDurationUs,
    required this.positionUs,
    required this.colors,
  });

  final WaveformCache? waveform;
  final ProjectModel? project;
  final int durationUs;
  final int viewStartUs;
  final int visibleDurationUs;
  final int positionUs;
  final ColorScheme colors;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF13151A),
    );

    const rulerHeight = 22.0;
    const markersHeight = 18.0;
    const subtitleTrackHeight = 56.0;
    final waveTop = rulerHeight + markersHeight + subtitleTrackHeight;
    final waveHeight = size.height - waveTop;

    // 1. Time Ruler
    _paintRuler(canvas, size, rulerHeight);

    // 2. Markers Track
    _paintMarkersTrack(canvas, size, rulerHeight, markersHeight);

    // 3. Subtitle Lines Track
    _paintSubtitleTrack(
      canvas,
      size,
      rulerHeight + markersHeight,
      subtitleTrackHeight,
    );

    // 4. Audio Waveform Track
    final waveRect = Rect.fromLTWH(
      0,
      waveTop,
      size.width,
      math.max(10, waveHeight),
    );
    _paintWaveform(canvas, waveRect);

    // 5. Playhead
    final playheadX =
        (positionUs - viewStartUs) / visibleDurationUs * size.width;
    if (playheadX >= 0 && playheadX <= size.width) {
      canvas.drawLine(
        Offset(playheadX, 0),
        Offset(playheadX, size.height),
        Paint()
          ..color = const Color(0xFFFFB300)
          ..strokeWidth = 2.0,
      );
      final path = Path()
        ..moveTo(playheadX - 6, 0)
        ..lineTo(playheadX + 6, 0)
        ..lineTo(playheadX, 8)
        ..close();
      canvas.drawPath(path, Paint()..color = const Color(0xFFFFB300));
    }
  }

  void _paintRuler(Canvas canvas, Size size, double height) {
    final secondsVisible = visibleDurationUs / Duration.microsecondsPerSecond;
    const candidates = [0.1, 0.2, 0.5, 1.0, 2.0, 5.0, 10.0, 30.0, 60.0];
    var step = candidates.last;
    for (final value in candidates) {
      if (size.width / (secondsVisible / value) >= 72) {
        step = value;
        break;
      }
    }
    final startSeconds = viewStartUs / Duration.microsecondsPerSecond;
    final first = (startSeconds / step).ceil() * step;
    final paint = Paint()..color = const Color(0xFF383C45);

    for (
      var second = first;
      second <= startSeconds + secondsVisible;
      second += step
    ) {
      final x = (second - startSeconds) / secondsVisible * size.width;
      canvas.drawLine(Offset(x, height - 6), Offset(x, height), paint);
      final duration = Duration(milliseconds: (second * 1000).round());
      final text =
          '${duration.inMinutes.remainder(60).toString().padLeft(2, '0')}:${duration.inSeconds.remainder(60).toString().padLeft(2, '0')}.${(duration.inMilliseconds.remainder(1000) ~/ 100).toString()}';
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 9,
            fontFamily: 'monospace',
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(canvas, Offset(x + 3, 2));
    }
    canvas.drawLine(Offset(0, height), Offset(size.width, height), paint);
  }

  void _paintMarkersTrack(Canvas canvas, Size size, double top, double height) {
    final rect = Rect.fromLTWH(0, top, size.width, height);
    canvas.drawRect(rect, Paint()..color = const Color(0xFF181B22));

    if (project != null) {
      for (final marker in project!.markers) {
        final x =
            (marker.timeUs - viewStartUs) / visibleDurationUs * size.width;
        if (x >= -40 && x <= size.width + 40) {
          canvas.drawRect(
            Rect.fromLTWH(x - 2, top + 2, 4, height - 4),
            Paint()..color = Color(marker.colorValue),
          );

          final painter = TextPainter(
            text: TextSpan(
              text: marker.name,
              style: TextStyle(
                color: Color(marker.colorValue),
                fontSize: 8,
                fontWeight: FontWeight.bold,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          painter.paint(canvas, Offset(x + 4, top + 2));
        }
      }
    }

    canvas.drawLine(
      Offset(0, top + height),
      Offset(size.width, top + height),
      Paint()..color = const Color(0xFF2E323B),
    );
  }

  void _paintSubtitleTrack(
    Canvas canvas,
    Size size,
    double top,
    double height,
  ) {
    final rect = Rect.fromLTWH(0, top, size.width, height);
    canvas.drawRect(rect, Paint()..color = const Color(0xFF1A1D24));

    if (project != null && project!.lyricLines.isNotEmpty) {
      for (var l = 0; l < project!.lyricLines.length; l++) {
        final line = project!.lyricLines[l];
        int? minStart = line.startUs;
        int? maxEnd = line.endUs;

        for (final t in line.tokens) {
          if (t.startUs != null) {
            minStart = (minStart == null)
                ? t.startUs!
                : math.min(minStart, t.startUs!);
          }
          if (t.endUs != null) {
            maxEnd = (maxEnd == null) ? t.endUs! : math.max(maxEnd, t.endUs!);
          }
        }

        if (minStart == null) continue; // Bỏ qua câu chưa có timing!
        final lineStart = minStart;
        final lineEnd = maxEnd ?? (lineStart + 3000000);

        final startX =
            (lineStart - viewStartUs) / visibleDurationUs * size.width;
        final endX = (lineEnd - viewStartUs) / visibleDurationUs * size.width;
        final width = math.max(12.0, endX - startX);

        if (startX + width >= 0 && startX <= size.width) {
          final actor = project!.actors.firstWhere(
            (a) => a.id == line.actorId,
            orElse: () => project!.actors.first,
          );

          final blockRect = Rect.fromLTWH(startX, top + 3, width, height - 6);
          final rrect = RRect.fromRectAndRadius(
            blockRect,
            const Radius.circular(5),
          );

          // Draw Line Container Block
          canvas.drawRRect(
            rrect,
            Paint()..color = Color(actor.colorValue).withValues(alpha: 0.20),
          );
          canvas.drawRRect(
            rrect,
            Paint()
              ..color = Color(actor.colorValue).withValues(alpha: 0.6)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.0,
          );

          // Draw Individual Tokens inside block
          for (final token in line.tokens) {
            if (token.startUs != null) {
              final isUntimedEnd = token.endUs == null;
              final effectiveEndUs = token.endUs ?? (token.startUs! + 500000);
              final tokX =
                  (token.startUs! - viewStartUs) /
                  visibleDurationUs *
                  size.width;
              final tokEndX =
                  (effectiveEndUs - viewStartUs) / visibleDurationUs * size.width;
              final tokW = math.max(6.0, tokEndX - tokX);

              final tokRect = Rect.fromLTWH(tokX, top + 5, tokW, height - 10);
              final tokRRect = RRect.fromRectAndRadius(
                tokRect,
                const Radius.circular(4),
              );

              // Token Body Fill
              canvas.drawRRect(
                tokRRect,
                Paint()
                  ..color = isUntimedEnd
                      ? Colors.amber.withValues(alpha: 0.40)
                      : Color(actor.colorValue).withValues(alpha: 0.45),
              );

              // Token Border
              canvas.drawRRect(
                tokRRect,
                Paint()
                  ..color = isUntimedEnd
                      ? Colors.amberAccent
                      : Color(actor.colorValue).withValues(alpha: 0.9)
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 1.2,
              );

              // Token Resize Edge Handles (Left & Right indicators)
              canvas.drawRect(
                Rect.fromLTWH(tokX, top + 8, 2.5, height - 16),
                Paint()..color = Colors.white70,
              );
              canvas.drawRect(
                Rect.fromLTWH(tokX + tokW - 2.5, top + 8, 2.5, height - 16),
                Paint()..color = Colors.white70,
              );

              // Token Label
              if (tokW > 16) {
                final painter = TextPainter(
                  text: TextSpan(
                    text: token.text,
                    style: TextStyle(
                      color: isUntimedEnd ? Colors.amberAccent : Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      shadows: const [Shadow(color: Colors.black87, blurRadius: 3)],
                    ),
                  ),
                  textDirection: TextDirection.ltr,
                  maxLines: 1,
                  ellipsis: '…',
                )..layout(maxWidth: math.max(10.0, tokW - 6));
                painter.paint(canvas, Offset(tokX + 4, top + (height / 2) - 6));
              }
            }
          }
        }
      }
    }

    canvas.drawLine(
      Offset(0, top + height),
      Offset(size.width, top + height),
      Paint()..color = const Color(0xFF2E323B),
    );
  }

  void _paintWaveform(Canvas canvas, Rect rect) {
    canvas.save();
    canvas.clipRect(rect);

    if (waveform == null || durationUs <= 0) {
      final painter = TextPainter(
        text: const TextSpan(
          text: 'Import Audio để hiển thị biểu đồ Waveform',
          style: TextStyle(color: Colors.white38, fontSize: 11),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(canvas, Offset(16, rect.top + (rect.height / 2) - 6));
    } else {
      final cache = waveform!;
      final level = cache.levelFor(visibleDurationUs, rect.width);
      final intervalUs = cache.intervalForLevel(level);
      final startIndex = math.max(0, viewStartUs ~/ intervalUs);
      final endIndex = math.min(
        level.length,
        (viewStartUs + visibleDurationUs) ~/ intervalUs + 2,
      );
      final center = rect.center.dy;
      final amplitude = rect.height * 0.42;
      final barWidth = math.max(
        1.0,
        rect.width / (visibleDurationUs / intervalUs) * 0.75,
      );

      final paint = Paint()
        ..color = const Color(0xFF4FC3F7)
        ..strokeWidth = barWidth;

      for (var index = startIndex; index < endIndex; index++) {
        final timeUs = index * intervalUs;
        final x = (timeUs - viewStartUs) / visibleDurationUs * rect.width;
        final peak = level[index];
        canvas.drawLine(
          Offset(x, center - peak * amplitude),
          Offset(x, center + peak * amplitude),
          paint,
        );
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MultiTrackTimelinePainter old) =>
      old.positionUs != positionUs ||
      old.viewStartUs != viewStartUs ||
      old.visibleDurationUs != visibleDurationUs ||
      old.waveform != waveform ||
      old.project != project ||
      old.colors != colors;
}
