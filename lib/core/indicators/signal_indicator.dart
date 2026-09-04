import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/project_model.dart';

class SignalIndicatorEngine {
  const SignalIndicatorEngine();

  void render({
    required Canvas canvas,
    required Offset position,
    required Actor actor,
    required double progress, // 0.0 -> 1.0 (from lead start to line start)
    required String indicatorId,
    double scaleFactor = 1.0,
  }) {
    final color = Color(actor.colorValue);

    switch (indicatorId.toLowerCase()) {
      case 'circles':
        _renderCircles(canvas, position, color, progress, scaleFactor);
      case 'lamp':
        _renderLamp(canvas, position, color, progress, scaleFactor);
      case 'countdown':
        _renderCountdown(canvas, position, color, progress, scaleFactor);
      case 'pulse':
        _renderPulse(canvas, position, color, progress, scaleFactor);
      case 'dots':
      default:
        _renderDots(canvas, position, color, progress, scaleFactor);
    }
  }

  void _renderDots(
    Canvas canvas,
    Offset pos,
    Color color,
    double progress,
    double scale,
  ) {
    const dotCount = 4;
    final dotRadius = 5.0 * scale;
    final spacing = 16.0 * scale;
    final startX = pos.dx - ((dotCount - 1) * spacing) / 2;

    for (var i = 0; i < dotCount; i++) {
      final dotPos = Offset(startX + i * spacing, pos.dy);
      final stepThreshold = (i + 1) / dotCount;
      final isFilled = progress >= stepThreshold;

      // Glow on active/filling dot
      if (isFilled) {
        canvas.drawCircle(
          dotPos,
          dotRadius * 1.5,
          Paint()
            ..color = color.withValues(alpha: 0.4)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6 * scale),
        );
      }

      // Outer ring
      canvas.drawCircle(
        dotPos,
        dotRadius,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 * scale,
      );

      // Inner fill
      if (isFilled) {
        canvas.drawCircle(
          dotPos,
          dotRadius * 0.7,
          Paint()
            ..color = color
            ..style = PaintingStyle.fill,
        );
      }
    }
  }

  void _renderCircles(
    Canvas canvas,
    Offset pos,
    Color color,
    double progress,
    double scale,
  ) {
    final maxRadius = 24.0 * scale;
    final currentRadius = maxRadius * (1.0 - progress);

    // Expanding ripple
    canvas.drawCircle(
      pos,
      maxRadius * progress,
      Paint()
        ..color = color.withValues(alpha: (1.0 - progress) * 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0 * scale,
    );

    // Center target
    canvas.drawCircle(
      pos,
      currentRadius.clamp(4.0 * scale, maxRadius),
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
  }

  void _renderLamp(
    Canvas canvas,
    Offset pos,
    Color color,
    double progress,
    double scale,
  ) {
    final radius = 12.0 * scale;
    final glow = 8.0 * scale * (0.5 + 0.5 * math.sin(progress * math.pi * 4));

    // Glow halo
    canvas.drawCircle(
      pos,
      radius + glow,
      Paint()
        ..color = color.withValues(alpha: 0.5)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8 * scale),
    );

    // Core lamp
    canvas.drawCircle(pos, radius, Paint()..color = color);
  }

  void _renderCountdown(
    Canvas canvas,
    Offset pos,
    Color color,
    double progress,
    double scale,
  ) {
    final count = ((1.0 - progress) * 3).ceil().clamp(1, 3);
    final painter = TextPainter(
      text: TextSpan(
        text: '$count',
        style: TextStyle(
          color: color,
          fontSize: 22 * scale,
          fontWeight: FontWeight.w900,
          shadows: [
            Shadow(color: Colors.black, blurRadius: 4 * scale),
            Shadow(color: color, blurRadius: 10 * scale),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    painter.paint(canvas, pos - Offset(painter.width / 2, painter.height / 2));
  }

  void _renderPulse(
    Canvas canvas,
    Offset pos,
    Color color,
    double progress,
    double scale,
  ) {
    final pulseScale = 1.0 + 0.3 * math.sin(progress * math.pi * 6);
    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.scale(pulseScale, pulseScale);
    canvas.drawCircle(
      Offset.zero,
      10 * scale,
      Paint()
        ..color = color
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4 * scale),
    );
    canvas.drawCircle(Offset.zero, 6 * scale, Paint()..color = Colors.white);
    canvas.restore();
  }
}
