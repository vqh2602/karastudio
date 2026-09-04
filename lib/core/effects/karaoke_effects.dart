import 'dart:math' as math;
import 'package:flutter/animation.dart';
import 'package:flutter/material.dart';

import '../../models/project_model.dart';

class EffectContext {
  const EffectContext({
    required this.line,
    required this.style,
    required this.actor,
    required this.timeUs,
    required this.canvasSize,
    required this.lineBounds,
  });

  final LyricLine line;
  final SubtitleStyle style;
  final Actor actor;
  final int timeUs;
  final Size canvasSize;
  final Rect lineBounds;
}

class EffectTransform {
  const EffectTransform({
    this.translation = Offset.zero,
    this.scale = const Offset(1.0, 1.0),
    this.rotation = 0.0, // degrees
    this.opacity = 1.0,
    this.blur = 0.0,
  });

  final Offset translation;
  final Offset scale;
  final double rotation;
  final double opacity;
  final double blur;
}

class KaraokeEffectsEngine {
  const KaraokeEffectsEngine();

  EffectTransform evaluate(EffectContext context) {
    final line = context.line;
    final startUs = line.startUs ?? 0;
    final endUs = line.endUs ?? (startUs + 4000000);
    final timeUs = context.timeUs;

    var translation = Offset.zero;
    var scale = const Offset(1.0, 1.0);
    var rotation = 0.0;
    var opacity = 1.0;
    var blur = 0.0;

    const transitionDurationUs = 350000; // 350ms

    // 1. Evaluate Transition In (before line starts)
    if (timeUs < startUs) {
      final inProgress =
          ((timeUs - (startUs - transitionDurationUs)) / transitionDurationUs)
              .clamp(0.0, 1.0);
      final curveValue = Curves.easeOutCubic.transform(inProgress);

      switch (line.transitionIn.toLowerCase()) {
        case 'fade':
          opacity = curveValue;
        case 'slideleft':
          translation = Offset((1.0 - curveValue) * -80.0, 0);
          opacity = curveValue;
        case 'slideright':
          translation = Offset((1.0 - curveValue) * 80.0, 0);
          opacity = curveValue;
        case 'slideup':
          translation = Offset(0, (1.0 - curveValue) * 40.0);
          opacity = curveValue;
        case 'slidedown':
          translation = Offset(0, (1.0 - curveValue) * -40.0);
          opacity = curveValue;
        case 'zoom':
        case 'scale':
          final s = 0.5 + 0.5 * curveValue;
          scale = Offset(s, s);
          opacity = curveValue;
        case 'bounce':
          final bounceCurve = Curves.bounceOut.transform(inProgress);
          scale = Offset(bounceCurve, bounceCurve);
          opacity = inProgress;
        default:
          opacity = 1.0;
      }
    }
    // 2. Evaluate Transition Out (after line ends)
    else if (timeUs > endUs) {
      final outProgress = ((timeUs - endUs) / transitionDurationUs).clamp(
        0.0,
        1.0,
      );
      final curveValue = Curves.easeInCubic.transform(outProgress);

      switch (line.transitionOut.toLowerCase()) {
        case 'fade':
          opacity = 1.0 - curveValue;
        case 'slidedown':
          translation = Offset(0, curveValue * 40.0);
          opacity = 1.0 - curveValue;
        case 'slideright':
          translation = Offset(curveValue * 80.0, 0);
          opacity = 1.0 - curveValue;
        case 'zoom':
        case 'scale':
          final s = 1.0 + 0.3 * curveValue;
          scale = Offset(s, s);
          opacity = 1.0 - curveValue;
        default:
          opacity = (1.0 - outProgress).clamp(0.0, 1.0);
      }
    }

    // 3. Line Active Effects (e.g. bounce, pulse, pop)
    if (timeUs >= startUs && timeUs <= endUs) {
      final effectName = line.lineEffect.toLowerCase();
      final lineProgress = (endUs > startUs)
          ? (timeUs - startUs) / (endUs - startUs)
          : 0.0;

      if (effectName.contains('bounce')) {
        final bounceOffset = math.sin(lineProgress * math.pi * 8) * 4.0;
        translation = translation + Offset(0, -bounceOffset.abs());
      } else if (effectName.contains('pulse')) {
        final pulseScale = 1.0 + 0.03 * math.sin(lineProgress * math.pi * 6);
        scale = Offset(scale.dx * pulseScale, scale.dy * pulseScale);
      } else if (effectName.contains('pop')) {
        // Pop current active token
        for (final token in line.tokens) {
          if (token.startUs != null &&
              token.endUs != null &&
              timeUs >= token.startUs! &&
              timeUs <= token.endUs!) {
            final tProgress =
                (timeUs - token.startUs!) / (token.endUs! - token.startUs!);
            final tokenPop = 1.0 + 0.08 * math.sin(tProgress * math.pi);
            scale = Offset(scale.dx * tokenPop, scale.dy * tokenPop);
            break;
          }
        }
      }
    }

    return EffectTransform(
      translation: translation,
      scale: scale,
      rotation: rotation,
      opacity: opacity.clamp(0.0, 1.0),
      blur: blur,
    );
  }
}
