import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/playback/playback_clock.dart';
import '../../core/waveform/waveform_cache.dart';

class WaveformTimeline extends StatefulWidget {
  const WaveformTimeline({
    super.key,
    required this.clock,
    required this.waveform,
    required this.durationUs,
  });

  final PlaybackClock clock;
  final WaveformCache? waveform;
  final int durationUs;

  @override
  State<WaveformTimeline> createState() => _WaveformTimelineState();
}

class _WaveformTimelineState extends State<WaveformTimeline> {
  double zoom = 1;
  double scroll = 0;

  int get _visibleDurationUs => widget.durationUs <= 0
      ? 1
      : math.max(1, (widget.durationUs / zoom).round());
  int get _viewStartUs =>
      ((widget.durationUs - _visibleDurationUs) * scroll).round();

  void _seek(Offset local, double width) {
    if (widget.durationUs <= 0 || width <= 0) return;
    final time =
        _viewStartUs + local.dx.clamp(0, width) / width * _visibleDurationUs;
    widget.clock.seek(Duration(microseconds: time.round()));
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent ||
        !HardwareKeyboard.instance.isControlPressed) {
      return;
    }
    setState(() {
      zoom = (zoom * (event.scrollDelta.dy > 0 ? .8 : 1.25)).clamp(1, 64);
      if (zoom == 1) scroll = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 24,
          child: Row(
            children: [
              const SizedBox(width: 8),
              const Icon(Icons.graphic_eq, size: 15),
              const SizedBox(width: 6),
              const Text(
                'AUDIO',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              const Icon(Icons.zoom_out, size: 15),
              SizedBox(
                width: 120,
                child: Slider(
                  value: math.log(zoom) / math.log(64),
                  onChanged: (value) => setState(() {
                    zoom = math.pow(64, value).toDouble();
                    if (zoom < 1.01) {
                      zoom = 1;
                      scroll = 0;
                    }
                  }),
                ),
              ),
              const Icon(Icons.zoom_in, size: 15),
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Text(
                  '${zoom.toStringAsFixed(1)}×',
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => Listener(
              onPointerSignal: _onPointerSignal,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (details) =>
                    _seek(details.localPosition, constraints.maxWidth),
                onHorizontalDragUpdate: (details) =>
                    _seek(details.localPosition, constraints.maxWidth),
                child: ListenableBuilder(
                  listenable: widget.clock,
                  builder: (context, _) => CustomPaint(
                    size: Size.infinite,
                    painter: _WaveformPainter(
                      waveform: widget.waveform,
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
        if (zoom > 1)
          SizedBox(
            height: 16,
            child: Slider(
              value: scroll,
              onChanged: (value) => setState(() => scroll = value),
            ),
          ),
      ],
    );
  }
}

class _WaveformPainter extends CustomPainter {
  const _WaveformPainter({
    required this.waveform,
    required this.durationUs,
    required this.viewStartUs,
    required this.visibleDurationUs,
    required this.positionUs,
    required this.colors,
  });

  final WaveformCache? waveform;
  final int durationUs;
  final int viewStartUs;
  final int visibleDurationUs;
  final int positionUs;
  final ColorScheme colors;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = colors.surfaceContainerLowest,
    );
    const rulerHeight = 24.0;
    _paintRuler(canvas, size, rulerHeight);
    final waveRect = Rect.fromLTRB(0, rulerHeight, size.width, size.height);
    canvas.save();
    canvas.clipRect(waveRect);
    if (waveform == null || durationUs <= 0) {
      final painter = TextPainter(
        text: TextSpan(
          text: 'Import audio để tạo waveform',
          style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(canvas, Offset(12, rulerHeight + 12));
    } else {
      _paintPeaks(canvas, waveRect);
    }
    final playheadX =
        (positionUs - viewStartUs) / visibleDurationUs * size.width;
    if (playheadX >= 0 && playheadX <= size.width) {
      canvas.drawLine(
        Offset(playheadX, 0),
        Offset(playheadX, size.height),
        Paint()
          ..color = colors.primary
          ..strokeWidth = 1.5,
      );
      final path = Path()
        ..moveTo(playheadX - 5, 0)
        ..lineTo(playheadX + 5, 0)
        ..lineTo(playheadX, 7)
        ..close();
      canvas.drawPath(path, Paint()..color = colors.primary);
    }
    canvas.restore();
  }

  void _paintRuler(Canvas canvas, Size size, double height) {
    final secondsVisible = visibleDurationUs / Duration.microsecondsPerSecond;
    const candidates = [.1, .2, .5, 1.0, 2.0, 5.0, 10.0, 30.0, 60.0];
    var step = candidates.last;
    for (final value in candidates) {
      if (size.width / (secondsVisible / value) >= 72) {
        step = value;
        break;
      }
    }
    final startSeconds = viewStartUs / Duration.microsecondsPerSecond;
    final first = (startSeconds / step).ceil() * step;
    final paint = Paint()..color = colors.outlineVariant;
    for (
      var second = first;
      second <= startSeconds + secondsVisible;
      second += step
    ) {
      final x = (second - startSeconds) / secondsVisible * size.width;
      canvas.drawLine(Offset(x, height - 7), Offset(x, height), paint);
      final duration = Duration(milliseconds: (second * 1000).round());
      final text =
          '${duration.inMinutes.remainder(60).toString().padLeft(2, '0')}:${duration.inSeconds.remainder(60).toString().padLeft(2, '0')}.${duration.inMilliseconds.remainder(1000).toString().padLeft(3, '0')}';
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(color: colors.onSurfaceVariant, fontSize: 9),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(canvas, Offset(x + 3, 3));
    }
    canvas.drawLine(Offset(0, height), Offset(size.width, height), paint);
  }

  void _paintPeaks(Canvas canvas, Rect rect) {
    final cache = waveform!;
    final level = cache.levelFor(visibleDurationUs, rect.width);
    final intervalUs = cache.intervalForLevel(level);
    final startIndex = math.max(0, viewStartUs ~/ intervalUs);
    final endIndex = math.min(
      level.length,
      (viewStartUs + visibleDurationUs) ~/ intervalUs + 2,
    );
    final center = rect.center.dy;
    final amplitude = rect.height * .43;
    final paint = Paint()
      ..color = colors.tertiary
      ..strokeWidth = math.max(
        1,
        rect.width / (visibleDurationUs / intervalUs) * .72,
      );
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

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) =>
      oldDelegate.positionUs != positionUs ||
      oldDelegate.viewStartUs != viewStartUs ||
      oldDelegate.visibleDurationUs != visibleDurationUs ||
      oldDelegate.waveform != waveform ||
      oldDelegate.colors != colors;
}
