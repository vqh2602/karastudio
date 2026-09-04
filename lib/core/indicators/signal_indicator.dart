import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/project_model.dart';

double leadDotIntensity(int index, double progress) {
  // Four beats START at 0%, 25%, 50%, 75%. Leave the last quarter
  // visible instead of lighting the fourth dot only when the line begins.
  final t = ((progress - index / 4) / 0.10).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

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
      final intensity = leadDotIntensity(i, progress);
      final isFilled = intensity > 0;

      // Glow on active/filling dot
      if (isFilled) {
        canvas.drawCircle(
          dotPos,
          dotRadius * 1.5,
          Paint()
            ..color = color.withValues(alpha: 0.4 * intensity)
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
            ..color = color.withValues(alpha: intensity)
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
    final t = progress.clamp(0.0, 1.0);
    final brightness = t * t * (3 - 2 * t);
    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.scale(scale);
    final bulb = Path()
      ..moveTo(-5, 7)
      ..cubicTo(-5, 2, -11, 1, -11, -6)
      ..cubicTo(-11, -20, 11, -20, 11, -6)
      ..cubicTo(11, 1, 5, 2, 5, 7)
      ..close();
    if (brightness > 0) {
      canvas.drawPath(
        bulb,
        Paint()
          ..color = color.withValues(alpha: 0.35 * brightness)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
      );
    }
    canvas.drawPath(
      bulb,
      Paint()
        ..color = Color.lerp(const Color(0xFF252A34), color, brightness * 0.8)!,
    );
    final stroke = Paint()
      ..color = Color.lerp(const Color(0xFF9099A8), color, brightness)!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(bulb, stroke);
    // Filament and stem.
    canvas.drawPath(
      Path()
        ..moveTo(-4, -4)
        ..lineTo(0, 0)
        ..lineTo(4, -4)
        ..moveTo(0, 0)
        ..lineTo(0, 6),
      stroke
        ..color = Color.lerp(
          const Color(0xFF9099A8),
          Colors.white,
          brightness,
        )!,
    );
    // Metallic screw base gives the icon an unmistakable light-bulb silhouette.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-5, 8, 10, 6),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xFF87919F),
    );
    canvas.drawLine(
      const Offset(-3, 11),
      const Offset(3, 11),
      Paint()
        ..color = const Color(0xFF343B47)
        ..strokeWidth = 1,
    );
    canvas.drawLine(
      const Offset(-2, 16),
      const Offset(2, 16),
      stroke..color = const Color(0xFF87919F),
    );
    // Steady rays brighten with the countdown, with no flashing.
    stroke.color = color.withValues(alpha: brightness);
    for (final angle in [
      -math.pi,
      -3 * math.pi / 4,
      -math.pi / 2,
      -math.pi / 4,
      0.0,
    ]) {
      final direction = Offset(math.cos(angle), math.sin(angle));
      const center = Offset(0, -6);
      canvas.drawLine(center + direction * 15, center + direction * 19, stroke);
    }
    canvas.restore();
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
    painter.dispose();
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
