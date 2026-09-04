import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import '../../models/project_model.dart';
import '../effects/karaoke_effects.dart';
import '../indicators/signal_indicator.dart';

class TokenRenderBounds {
  const TokenRenderBounds({
    required this.token,
    required this.rect,
    required this.charBounds,
  });

  final LyricToken token;
  final Rect rect;
  final List<Rect> charBounds;
}

class LineRenderLayout {
  const LineRenderLayout({
    required this.line,
    required this.style,
    required this.actor,
    required this.totalSize,
    required this.origin,
    required this.tokenBounds,
    required this.textPainter,
  });

  final LyricLine line;
  final SubtitleStyle style;
  final Actor actor;
  final Size totalSize;
  final Offset origin;
  final List<TokenRenderBounds> tokenBounds;
  final TextPainter textPainter;
}

class KaraokeRenderer {
  KaraokeRenderer({
    this.effectsEngine = const KaraokeEffectsEngine(),
    this.indicatorEngine = const SignalIndicatorEngine(),
  });

  final KaraokeEffectsEngine effectsEngine;
  final SignalIndicatorEngine indicatorEngine;

  void render({
    required Canvas canvas,
    required Size canvasSize,
    required ProjectModel project,
    required int timeUs,
    bool isPreview = false,
    bool showSafeAreas = false,
  }) {
    // Background media is composed by the preview/export pipeline. This
    // renderer must stay transparent so its canvas can safely sit on top of
    // either a photo or a video.

    // 1. Determine visible lines based on layoutMode
    final visibleLayouts = _evaluateVisibleLines(
      project: project,
      canvasSize: canvasSize,
      timeUs: timeUs,
    );

    // 2. Render each visible line
    for (final layout in visibleLayouts) {
      _renderLine(
        canvas: canvas,
        canvasSize: canvasSize,
        layout: layout,
        timeUs: timeUs,
        leadTimeUs: project.settings.leadTimeUs,
      );
    }

    // 3. Draw Safe Area Overlays if enabled
    if (showSafeAreas) {
      _drawSafeAreas(canvas, canvasSize);
    }
  }

  List<LineRenderLayout> _evaluateVisibleLines({
    required ProjectModel project,
    required Size canvasSize,
    required int timeUs,
  }) {
    final result = <LineRenderLayout>[];
    final leadTimeUs = project.settings.leadTimeUs;
    final lines = project.lyricLines;

    if (lines.isEmpty) return result;

    if (project.settings.layoutMode == LayoutMode.alternatingTwoRows) {
      // Find current and upcoming lines for Row A and Row B
      LyricLine? lineA;
      LyricLine? lineB;

      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        final (start, end) = _getLineTiming(line);
        if (start == null || end == null) continue; // Bỏ qua câu chưa có timing
        final appearTime = math.max(0, start - leadTimeUs);
        final disappearTime = end + 1200000; // transition out linger

        final isRowA =
            (line.rowAssignment == 'rowA') ||
            (line.rowAssignment == 'auto' && i % 2 == 0);

        if (timeUs >= appearTime && timeUs <= disappearTime) {
          if (isRowA && lineA == null) {
            lineA = line;
          } else if (!isRowA && lineB == null) {
            lineB = line;
          }
        }
      }

      if (lineA != null) {
        result.add(
          _layoutLine(
            project: project,
            line: lineA,
            canvasSize: canvasSize,
            overridePosX: project.settings.rowAPositionX,
            overridePosY: project.settings.rowAPositionY,
          ),
        );
      }
      if (lineB != null) {
        result.add(
          _layoutLine(
            project: project,
            line: lineB,
            canvasSize: canvasSize,
            overridePosX: project.settings.rowBPositionX,
            overridePosY: project.settings.rowBPositionY,
          ),
        );
      }
    } else {
      // Single Row or Multi-Row
      for (final line in lines) {
        final (start, end) = _getLineTiming(line);
        if (start == null || end == null) continue; // Bỏ qua câu chưa có timing
        final appearTime = math.max(0, start - leadTimeUs);
        final disappearTime = end + 1000000;

        if (timeUs >= appearTime && timeUs <= disappearTime) {
          result.add(
            _layoutLine(
              project: project,
              line: line,
              canvasSize: canvasSize,
              overridePosX: project.settings.layoutMode == LayoutMode.singleRow
                  ? project.settings.singleRowPositionX
                  : null,
              overridePosY: project.settings.layoutMode == LayoutMode.singleRow
                  ? project.settings.singleRowPositionY
                  : null,
            ),
          );
        }
      }
    }

    return result;
  }

  (int?, int?) _getLineTiming(LyricLine line) {
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

    if (minStart == null) return (null, null); // Câu chưa được ghi timing
    final effectiveStart = minStart;
    final effectiveEnd = maxEnd ?? (effectiveStart + 4000000);
    return (effectiveStart, math.max(effectiveStart + 500000, effectiveEnd));
  }

  LineRenderLayout _layoutLine({
    required ProjectModel project,
    required LyricLine line,
    required Size canvasSize,
    double? overridePosX,
    double? overridePosY,
  }) {
    final actor = project.actors.firstWhere(
      (a) => a.id == line.actorId,
      orElse: () => project.actors.isNotEmpty
          ? project.actors.first
          : const Actor(
              id: 'male',
              name: 'Nam',
              colorValue: 0xFF42A5F5,
              styleId: 'classic',
            ),
    );

    final style = project.styles.firstWhere(
      (s) => s.id == line.styleId || s.id == actor.styleId,
      orElse: () => project.styles.isNotEmpty
          ? project.styles.first
          : const SubtitleStyle(id: 'classic', name: 'Classic'),
    );

    // Scale font size according to target resolution relative to 1080p base
    final scaleFactor = canvasSize.height / 1080.0;
    final effectiveFontSize = style.fontSize * scaleFactor;

    final textStyle = TextStyle(
      fontFamily: style.fontFamily,
      fontSize: effectiveFontSize,
      fontWeight: FontWeight.values[(style.fontWeight ~/ 100).clamp(1, 9) - 1],
      fontStyle: style.isItalic ? FontStyle.italic : FontStyle.normal,
      letterSpacing: style.letterSpacing * scaleFactor,
      wordSpacing: style.wordSpacing * scaleFactor,
      height: style.lineHeight,
      decoration: style.isUnderline
          ? TextDecoration.underline
          : TextDecoration.none,
    );

    // Measure entire line
    final painter = TextPainter(
      text: TextSpan(text: line.text, style: textStyle),
      textDirection: TextDirection.ltr,
      textAlign: switch (style.alignment) {
        SubtitleAlignment.left => TextAlign.left,
        SubtitleAlignment.center => TextAlign.center,
        SubtitleAlignment.right => TextAlign.right,
      },
    )..layout(maxWidth: canvasSize.width * 0.94);

    final posY = (overridePosY ?? line.positionY) * canvasSize.height;
    final posX = (overridePosX ?? line.positionX) * canvasSize.width;

    double originX;
    switch (style.alignment) {
      case SubtitleAlignment.left:
        originX = posX;
      case SubtitleAlignment.center:
        originX = posX - (painter.width / 2);
      case SubtitleAlignment.right:
        originX = posX - painter.width;
    }
    final origin = Offset(originX, posY - (painter.height / 2));

    // Calculate bounding boxes for individual tokens
    final tokenBounds = <TokenRenderBounds>[];
    var searchStart = 0;

    for (final token in line.tokens) {
      final tokenIndexInLine = line.text.indexOf(token.text, searchStart);
      if (tokenIndexInLine >= 0) {
        searchStart = tokenIndexInLine + token.text.length;
        final startOffset = painter.getOffsetForCaret(
          TextPosition(offset: tokenIndexInLine),
          Rect.zero,
        );
        final endOffset = painter.getOffsetForCaret(
          TextPosition(offset: tokenIndexInLine + token.text.length),
          Rect.zero,
        );

        final tokenRect = Rect.fromLTWH(
          origin.dx + startOffset.dx,
          origin.dy + startOffset.dy,
          math.max(1, endOffset.dx - startOffset.dx),
          painter.height,
        );

        tokenBounds.add(
          TokenRenderBounds(
            token: token,
            rect: tokenRect,
            charBounds: const [],
          ),
        );
      }
    }

    return LineRenderLayout(
      line: line,
      style: style,
      actor: actor,
      totalSize: Size(painter.width, painter.height),
      origin: origin,
      tokenBounds: tokenBounds,
      textPainter: painter,
    );
  }

  void _renderLine({
    required Canvas canvas,
    required Size canvasSize,
    required LineRenderLayout layout,
    required int timeUs,
    required int leadTimeUs,
  }) {
    final line = layout.line;
    final style = layout.style;
    final actor = layout.actor;
    final scaleFactor = canvasSize.height / 1080.0;

    final lineStartUs = line.startUs ?? 0;

    // Evaluate Transition & Effects
    final effectContext = EffectContext(
      line: line,
      style: style,
      actor: actor,
      timeUs: timeUs,
      canvasSize: canvasSize,
      lineBounds: Rect.fromLTWH(
        layout.origin.dx,
        layout.origin.dy,
        layout.totalSize.width,
        layout.totalSize.height,
      ),
    );

    final effectTransform = effectsEngine.evaluate(effectContext);

    canvas.save();

    // Apply global transforms (Position, Rotation, Scale, Skew)
    final center =
        layout.origin +
        Offset(layout.totalSize.width / 2, layout.totalSize.height / 2);
    canvas.translate(
      center.dx + effectTransform.translation.dx,
      center.dy + effectTransform.translation.dy,
    );
    canvas.rotate(
      (style.rotationZ + effectTransform.rotation) * math.pi / 180.0,
    );
    canvas.scale(
      style.scaleX * effectTransform.scale.dx,
      style.scaleY * effectTransform.scale.dy,
    );
    if (style.skewX != 0 || style.skewY != 0) {
      final skewMatrix = Matrix4.identity()
        ..setEntry(0, 1, math.tan(style.skewX * math.pi / 180.0))
        ..setEntry(1, 0, math.tan(style.skewY * math.pi / 180.0));
      canvas.transform(skewMatrix.storage);
    }
    canvas.translate(-layout.totalSize.width / 2, -layout.totalSize.height / 2);

    // 1. Draw Glow if enabled
    if (style.glowRadius > 0 && style.glowColorValue != 0) {
      _paintTextWithStyle(
        canvas: canvas,
        layout: layout,
        paint: Paint()
          ..color = Color(style.glowColorValue)
          ..maskFilter = MaskFilter.blur(
            BlurStyle.normal,
            style.glowRadius * scaleFactor,
          )
          ..style = PaintingStyle.fill,
        alphaMultiplier: effectTransform.opacity,
      );
    }

    // 2. Draw Shadow
    if (style.shadowColorValue != 0) {
      canvas.save();
      canvas.translate(
        style.shadowOffsetX * scaleFactor,
        style.shadowOffsetY * scaleFactor,
      );
      _paintTextWithStyle(
        canvas: canvas,
        layout: layout,
        paint: Paint()
          ..color = Color(style.shadowColorValue)
          ..maskFilter = MaskFilter.blur(
            BlurStyle.normal,
            style.shadowBlur * scaleFactor,
          )
          ..style = PaintingStyle.fill,
        alphaMultiplier: effectTransform.opacity,
      );
      canvas.restore();
    }

    // 3. Draw Secondary Outer Outline (if specified)
    if (style.outlineWidth2 > 0 && style.outlineColorValue2 != 0) {
      _paintTextWithStyle(
        canvas: canvas,
        layout: layout,
        paint: Paint()
          ..color = Color(style.outlineColorValue2)
          ..strokeWidth =
              (style.outlineWidth + style.outlineWidth2) * 2 * scaleFactor
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
        alphaMultiplier: effectTransform.opacity,
      );
    }

    // 4. Draw Primary Outline
    if (style.outlineWidth > 0 && style.outlineColorValue != 0) {
      _paintTextWithStyle(
        canvas: canvas,
        layout: layout,
        paint: Paint()
          ..color = Color(style.outlineColorValue)
          ..strokeWidth = style.outlineWidth * 2 * scaleFactor
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
        alphaMultiplier: effectTransform.opacity,
      );
    }

    // 5. Draw Inactive Base Text Fill
    final inactivePaint = Paint()..style = PaintingStyle.fill;
    if (style.inactiveUseGradient) {
      inactivePaint.shader = ui.Gradient.linear(
        Offset(0, 0),
        Offset(0, layout.totalSize.height),
        [
          Color(style.inactiveColorValue),
          Color(style.inactiveSecondaryColorValue),
        ],
      );
    } else {
      inactivePaint.color = Color(style.inactiveColorValue);
    }
    _paintTextWithStyle(
      canvas: canvas,
      layout: layout,
      paint: inactivePaint,
      alphaMultiplier: effectTransform.opacity,
    );

    // 6. Draw Active Karaoke Running Fill with Progress Clipping
    if (timeUs >= lineStartUs) {
      final activePaint = Paint()..style = PaintingStyle.fill;
      if (style.activeUseGradient) {
        activePaint.shader = ui.Gradient.linear(
          Offset(0, 0),
          Offset(0, layout.totalSize.height),
          [
            Color(style.activeColorValue),
            Color(style.activeSecondaryColorValue),
          ],
        );
      } else {
        activePaint.color = Color(style.activeColorValue);
      }

      for (final tb in layout.tokenBounds) {
        final token = tb.token;
        final tStart = token.startUs ?? lineStartUs;
        final tEnd = token.endUs ?? (tStart + 500000);

        if (timeUs < tStart) continue; // Not started yet

        final progress = (tEnd > tStart)
            ? ((timeUs - tStart) / (tEnd - tStart)).clamp(0.0, 1.0)
            : 1.0;

        // Local coordinate relative to line layout
        final localX = tb.rect.left - layout.origin.dx;
        final localY = tb.rect.top - layout.origin.dy;
        final localW = tb.rect.width;
        final localH = tb.rect.height;

        Rect clipRect;
        switch (style.sweepDirection) {
          case SweepDirection.leftToRight:
            clipRect = Rect.fromLTWH(
              localX - 2,
              localY - 10,
              localW * progress + 4,
              localH + 20,
            );
          case SweepDirection.rightToLeft:
            clipRect = Rect.fromLTWH(
              localX + localW * (1 - progress),
              localY - 10,
              localW * progress + 4,
              localH + 20,
            );
          case SweepDirection.centerOut:
            final half = (localW / 2) * progress;
            clipRect = Rect.fromLTWH(
              localX + (localW / 2) - half,
              localY - 10,
              half * 2,
              localH + 20,
            );
          case SweepDirection.bottomToTop:
            clipRect = Rect.fromLTWH(
              localX - 2,
              localY + localH * (1 - progress),
              localW + 4,
              localH * progress + 20,
            );
          case SweepDirection.topToBottom:
            clipRect = Rect.fromLTWH(
              localX - 2,
              localY - 10,
              localW + 4,
              localH * progress + 20,
            );
        }

        canvas.save();
        canvas.clipRect(clipRect);
        _paintTextWithStyle(
          canvas: canvas,
          layout: layout,
          paint: activePaint,
          alphaMultiplier: effectTransform.opacity,
        );
        canvas.restore();
      }
    }

    canvas.restore();

    // 7. Render Lead Signal Indicator (if before line starts)
    if (line.indicatorEnabled &&
        timeUs < lineStartUs &&
        timeUs >= lineStartUs - leadTimeUs) {
      final leadProgress = ((timeUs - (lineStartUs - leadTimeUs)) / leadTimeUs)
          .clamp(0.0, 1.0);
      final indicatorPos = Offset(
        layout.origin.dx - (48 * scaleFactor),
        layout.origin.dy + (layout.totalSize.height / 2),
      );

      indicatorEngine.render(
        canvas: canvas,
        position: indicatorPos,
        actor: actor,
        progress: leadProgress,
        indicatorId: actor.indicatorId,
        scaleFactor: scaleFactor,
      );
    }
  }

  void _paintTextWithStyle({
    required Canvas canvas,
    required LineRenderLayout layout,
    required Paint paint,
    double alphaMultiplier = 1.0,
  }) {
    if (alphaMultiplier < 1.0) {
      paint.color = paint.color.withValues(
        alpha: paint.color.a * alphaMultiplier.clamp(0.0, 1.0),
      );
    }

    final originalSpan = layout.textPainter.text as TextSpan;
    final styledSpan = TextSpan(
      text: originalSpan.text,
      style: originalSpan.style?.copyWith(foreground: paint, color: null),
    );

    final painter = TextPainter(
      text: styledSpan,
      textDirection: layout.textPainter.textDirection,
      textAlign: layout.textPainter.textAlign,
    )..layout(maxWidth: layout.totalSize.width + 10);

    painter.paint(canvas, Offset.zero);
  }

  void _drawSafeAreas(Canvas canvas, Size size) {
    final titleSafe = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: size.width * 0.8,
      height: size.height * 0.8,
    );
    final actionSafe = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: size.width * 0.9,
      height: size.height * 0.9,
    );

    final guidePaint = Paint()
      ..color = const Color(0x6600E5FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawRect(titleSafe, guidePaint);
    canvas.drawRect(actionSafe, guidePaint..color = const Color(0x44FFAB00));

    // Center crosshairs
    final crossPaint = Paint()
      ..color = const Color(0x33FFFFFF)
      ..strokeWidth = 1.0;
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      crossPaint,
    );
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      crossPaint,
    );
  }
}
