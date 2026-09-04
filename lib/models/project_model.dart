import 'dart:math';
import 'audio_effects.dart';

String newId([String prefix = 'id']) {
  final now = DateTime.now().microsecondsSinceEpoch;
  final random = Random().nextInt(0xFFFFFF).toRadixString(16).padLeft(6, '0');
  return '$prefix-$now-$random';
}

enum MediaType { audio, video, image, imageSequence }

class MediaAsset {
  const MediaAsset({
    required this.id,
    required this.type,
    required this.path,
    this.durationUs = 0,
    this.sampleRate,
    this.channels,
    this.codec,
    this.waveformCachePath,
    this.proxyPath,
    this.metadata = const {},
  });

  final String id;
  final MediaType type;
  final String path;
  final int durationUs;
  final int? sampleRate;
  final int? channels;
  final String? codec;
  final String? waveformCachePath;
  final String? proxyPath;
  final Map<String, String> metadata;

  MediaAsset copyWith({
    String? id,
    MediaType? type,
    String? path,
    String? waveformCachePath,
    String? proxyPath,
    int? durationUs,
    int? sampleRate,
    int? channels,
    String? codec,
    Map<String, String>? metadata,
  }) => MediaAsset(
    id: id ?? this.id,
    type: type ?? this.type,
    path: path ?? this.path,
    durationUs: durationUs ?? this.durationUs,
    sampleRate: sampleRate ?? this.sampleRate,
    channels: channels ?? this.channels,
    codec: codec ?? this.codec,
    waveformCachePath: waveformCachePath ?? this.waveformCachePath,
    proxyPath: proxyPath ?? this.proxyPath,
    metadata: metadata ?? this.metadata,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'type': type.name,
    'path': path,
    'durationUs': durationUs,
    'sampleRate': sampleRate,
    'channels': channels,
    'codec': codec,
    'waveformCachePath': waveformCachePath,
    'proxyPath': proxyPath,
    'metadata': metadata,
  };

  factory MediaAsset.fromJson(Map<String, Object?> json) => MediaAsset(
    id: json['id'] as String,
    type: MediaType.values.byName(json['type'] as String),
    path: json['path'] as String,
    durationUs: (json['durationUs'] as num?)?.toInt() ?? 0,
    sampleRate: (json['sampleRate'] as num?)?.toInt(),
    channels: (json['channels'] as num?)?.toInt(),
    codec: json['codec'] as String?,
    waveformCachePath: json['waveformCachePath'] as String?,
    proxyPath: json['proxyPath'] as String?,
    metadata: Map<String, String>.from(
      (json['metadata'] as Map?) ?? const <String, String>{},
    ),
  );
}

class LyricToken {
  const LyricToken({
    required this.id,
    required this.text,
    required this.index,
    this.startUs,
    this.endUs,
  });

  final String id;
  final String text;
  final int index;
  final int? startUs;
  final int? endUs;

  bool get isTimed => startUs != null && endUs != null && endUs! >= startUs!;
  int get durationUs => (isTimed ? endUs! - startUs! : 0);

  LyricToken copyWith({
    String? id,
    String? text,
    int? index,
    int? startUs,
    int? endUs,
    bool clearTiming = false,
  }) => LyricToken(
    id: id ?? this.id,
    text: text ?? this.text,
    index: index ?? this.index,
    startUs: clearTiming ? null : (startUs ?? this.startUs),
    endUs: clearTiming ? null : (endUs ?? this.endUs),
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'text': text,
    'index': index,
    'startUs': startUs,
    'endUs': endUs,
  };

  factory LyricToken.fromJson(Map<String, Object?> json) => LyricToken(
    id: json['id'] as String,
    text: json['text'] as String,
    index: (json['index'] as num).toInt(),
    startUs: (json['startUs'] as num?)?.toInt(),
    endUs: (json['endUs'] as num?)?.toInt(),
  );
}

enum TimingStatus { untimed, lineTimed, wordTimed, error }

class LyricLine {
  const LyricLine({
    required this.id,
    required this.text,
    required this.actorId,
    this.startUs,
    this.endUs,
    this.tokens = const [],
    this.styleId = 'classic',
    this.positionX = 0.5,
    this.positionY = 0.84,
    this.lineEffect = 'runningColor',
    this.transitionIn = 'none',
    this.transitionOut = 'none',
    this.rowAssignment = 'auto',
    this.indicatorEnabled = true,
  });

  final String id;
  final String text;
  final String actorId;
  final int? startUs;
  final int? endUs;
  final List<LyricToken> tokens;
  final String styleId;
  final double positionX;
  final double positionY;
  final String lineEffect;
  final String transitionIn;
  final String transitionOut;
  final String rowAssignment;
  final bool indicatorEnabled;

  bool get isTimed => startUs != null && endUs != null && endUs! >= startUs!;
  int get durationUs => (isTimed ? endUs! - startUs! : 0);

  TimingStatus get timingStatus {
    if (startUs == null &&
        endUs == null &&
        tokens.every((t) => t.startUs == null)) {
      return TimingStatus.untimed;
    }
    if (startUs != null && endUs != null && endUs! < startUs!) {
      return TimingStatus.error;
    }
    for (final token in tokens) {
      if (token.startUs != null &&
          token.endUs != null &&
          token.endUs! < token.startUs!) {
        return TimingStatus.error;
      }
    }
    final timedTokensCount = tokens.where((t) => t.isTimed).length;
    if (timedTokensCount == tokens.length && tokens.isNotEmpty) {
      return TimingStatus.wordTimed;
    }
    if (isTimed) {
      return TimingStatus.lineTimed;
    }
    return TimingStatus.untimed;
  }

  LyricLine copyWith({
    String? id,
    String? text,
    String? actorId,
    int? startUs,
    int? endUs,
    List<LyricToken>? tokens,
    String? styleId,
    double? positionX,
    double? positionY,
    String? lineEffect,
    String? transitionIn,
    String? transitionOut,
    String? rowAssignment,
    bool? indicatorEnabled,
    bool clearTiming = false,
  }) => LyricLine(
    id: id ?? this.id,
    text: text ?? this.text,
    actorId: actorId ?? this.actorId,
    startUs: clearTiming ? null : (startUs ?? this.startUs),
    endUs: clearTiming ? null : (endUs ?? this.endUs),
    tokens: clearTiming
        ? (tokens ?? this.tokens)
              .map((t) => t.copyWith(clearTiming: true))
              .toList()
        : (tokens ?? this.tokens),
    styleId: styleId ?? this.styleId,
    positionX: positionX ?? this.positionX,
    positionY: positionY ?? this.positionY,
    lineEffect: lineEffect ?? this.lineEffect,
    transitionIn: transitionIn ?? this.transitionIn,
    transitionOut: transitionOut ?? this.transitionOut,
    rowAssignment: rowAssignment ?? this.rowAssignment,
    indicatorEnabled: indicatorEnabled ?? this.indicatorEnabled,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'text': text,
    'actorId': actorId,
    'startUs': startUs,
    'endUs': endUs,
    'tokens': tokens.map((token) => token.toJson()).toList(),
    'styleId': styleId,
    'position': {'x': positionX, 'y': positionY},
    'lineEffect': lineEffect,
    'transitionIn': transitionIn,
    'transitionOut': transitionOut,
    'rowAssignment': rowAssignment,
    'indicatorEnabled': indicatorEnabled,
  };

  factory LyricLine.fromJson(Map<String, Object?> json) {
    final position = (json['position'] as Map?)?.cast<String, Object?>();
    return LyricLine(
      id: json['id'] as String,
      text: json['text'] as String,
      actorId: json['actorId'] as String,
      startUs: (json['startUs'] as num?)?.toInt(),
      endUs: (json['endUs'] as num?)?.toInt(),
      tokens: ((json['tokens'] as List?) ?? const [])
          .map((item) => LyricToken.fromJson((item as Map).cast()))
          .toList(),
      styleId: json['styleId'] as String? ?? 'classic',
      positionX: (position?['x'] as num?)?.toDouble() ?? 0.5,
      positionY: (position?['y'] as num?)?.toDouble() ?? 0.84,
      lineEffect: json['lineEffect'] as String? ?? 'runningColor',
      transitionIn: json['transitionIn'] as String? ?? 'none',
      transitionOut: json['transitionOut'] as String? ?? 'none',
      rowAssignment: json['rowAssignment'] as String? ?? 'auto',
      indicatorEnabled: json['indicatorEnabled'] as bool? ?? true,
    );
  }
}

class Actor {
  const Actor({
    required this.id,
    required this.name,
    required this.colorValue,
    required this.styleId,
    this.positionX = 0.5,
    this.positionY = 0.84,
    this.indicatorId = 'dots',
    this.defaultEffect = 'runningColor',
  });

  final String id;
  final String name;
  final int colorValue;
  final String styleId;
  final double positionX;
  final double positionY;
  final String indicatorId;
  final String defaultEffect;

  Actor copyWith({
    String? id,
    String? name,
    int? colorValue,
    String? styleId,
    double? positionX,
    double? positionY,
    String? indicatorId,
    String? defaultEffect,
  }) => Actor(
    id: id ?? this.id,
    name: name ?? this.name,
    colorValue: colorValue ?? this.colorValue,
    styleId: styleId ?? this.styleId,
    positionX: positionX ?? this.positionX,
    positionY: positionY ?? this.positionY,
    indicatorId: indicatorId ?? this.indicatorId,
    defaultEffect: defaultEffect ?? this.defaultEffect,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'colorValue': colorValue,
    'styleId': styleId,
    'position': {'x': positionX, 'y': positionY},
    'indicatorId': indicatorId,
    'defaultEffect': defaultEffect,
  };

  factory Actor.fromJson(Map<String, Object?> json) {
    final position = (json['position'] as Map?)?.cast<String, Object?>();
    return Actor(
      id: json['id'] as String,
      name: json['name'] as String,
      colorValue: (json['colorValue'] as num).toInt(),
      styleId: json['styleId'] as String,
      positionX: (position?['x'] as num?)?.toDouble() ?? 0.5,
      positionY: (position?['y'] as num?)?.toDouble() ?? 0.84,
      indicatorId: json['indicatorId'] as String? ?? 'dots',
      defaultEffect: json['defaultEffect'] as String? ?? 'runningColor',
    );
  }
}

enum SubtitleAlignment { left, center, right }

enum SweepDirection {
  leftToRight,
  rightToLeft,
  centerOut,
  bottomToTop,
  topToBottom,
}

class SubtitleStyle {
  const SubtitleStyle({
    required this.id,
    required this.name,
    this.fontFamily = 'Arial',
    this.fontSize = 58,
    this.fontWeight = 700,
    this.isItalic = false,
    this.isUnderline = false,
    this.alignment = SubtitleAlignment.center,
    this.letterSpacing = 1.0,
    this.wordSpacing = 4.0,
    this.lineHeight = 1.2,
    this.inactiveColorValue = 0xFFFFFFFF,
    this.inactiveSecondaryColorValue = 0xFFB0BEC5,
    this.inactiveUseGradient = false,
    this.activeColorValue = 0xFFFFC107,
    this.activeSecondaryColorValue = 0xFFFF5722,
    this.activeUseGradient = false,
    this.outlineColorValue = 0xFF000000,
    this.outlineWidth = 3.5,
    this.outlineColorValue2 = 0x00000000,
    this.outlineWidth2 = 0.0,
    this.shadowColorValue = 0x99000000,
    this.shadowBlur = 6,
    this.shadowOffsetX = 2,
    this.shadowOffsetY = 3,
    this.glowColorValue = 0x00000000,
    this.glowRadius = 0,
    this.glowIntensity = 0.0,
    this.scaleX = 1.0,
    this.scaleY = 1.0,
    this.rotationZ = 0.0,
    this.skewX = 0.0,
    this.skewY = 0.0,
    this.sweepDirection = SweepDirection.leftToRight,
  });

  final String id;
  final String name;
  final String fontFamily;
  final double fontSize;
  final int fontWeight;
  final bool isItalic;
  final bool isUnderline;
  final SubtitleAlignment alignment;
  final double letterSpacing;
  final double wordSpacing;
  final double lineHeight;
  final int inactiveColorValue;
  final int inactiveSecondaryColorValue;
  final bool inactiveUseGradient;
  final int activeColorValue;
  final int activeSecondaryColorValue;
  final bool activeUseGradient;
  final int outlineColorValue;
  final double outlineWidth;
  final int outlineColorValue2;
  final double outlineWidth2;
  final int shadowColorValue;
  final double shadowBlur;
  final double shadowOffsetX;
  final double shadowOffsetY;
  final int glowColorValue;
  final double glowRadius;
  final double glowIntensity;
  final double scaleX;
  final double scaleY;
  final double rotationZ;
  final double skewX;
  final double skewY;
  final SweepDirection sweepDirection;

  SubtitleStyle copyWith({
    String? id,
    String? name,
    String? fontFamily,
    double? fontSize,
    int? fontWeight,
    bool? isItalic,
    bool? isUnderline,
    SubtitleAlignment? alignment,
    double? letterSpacing,
    double? wordSpacing,
    double? lineHeight,
    int? inactiveColorValue,
    int? inactiveSecondaryColorValue,
    bool? inactiveUseGradient,
    int? activeColorValue,
    int? activeSecondaryColorValue,
    bool? activeUseGradient,
    int? outlineColorValue,
    double? outlineWidth,
    int? outlineColorValue2,
    double? outlineWidth2,
    int? shadowColorValue,
    double? shadowBlur,
    double? shadowOffsetX,
    double? shadowOffsetY,
    int? glowColorValue,
    double? glowRadius,
    double? glowIntensity,
    double? scaleX,
    double? scaleY,
    double? rotationZ,
    double? skewX,
    double? skewY,
    SweepDirection? sweepDirection,
  }) => SubtitleStyle(
    id: id ?? this.id,
    name: name ?? this.name,
    fontFamily: fontFamily ?? this.fontFamily,
    fontSize: fontSize ?? this.fontSize,
    fontWeight: fontWeight ?? this.fontWeight,
    isItalic: isItalic ?? this.isItalic,
    isUnderline: isUnderline ?? this.isUnderline,
    alignment: alignment ?? this.alignment,
    letterSpacing: letterSpacing ?? this.letterSpacing,
    wordSpacing: wordSpacing ?? this.wordSpacing,
    lineHeight: lineHeight ?? this.lineHeight,
    inactiveColorValue: inactiveColorValue ?? this.inactiveColorValue,
    inactiveSecondaryColorValue:
        inactiveSecondaryColorValue ?? this.inactiveSecondaryColorValue,
    inactiveUseGradient: inactiveUseGradient ?? this.inactiveUseGradient,
    activeColorValue: activeColorValue ?? this.activeColorValue,
    activeSecondaryColorValue:
        activeSecondaryColorValue ?? this.activeSecondaryColorValue,
    activeUseGradient: activeUseGradient ?? this.activeUseGradient,
    outlineColorValue: outlineColorValue ?? this.outlineColorValue,
    outlineWidth: outlineWidth ?? this.outlineWidth,
    outlineColorValue2: outlineColorValue2 ?? this.outlineColorValue2,
    outlineWidth2: outlineWidth2 ?? this.outlineWidth2,
    shadowColorValue: shadowColorValue ?? this.shadowColorValue,
    shadowBlur: shadowBlur ?? this.shadowBlur,
    shadowOffsetX: shadowOffsetX ?? this.shadowOffsetX,
    shadowOffsetY: shadowOffsetY ?? this.shadowOffsetY,
    glowColorValue: glowColorValue ?? this.glowColorValue,
    glowRadius: glowRadius ?? this.glowRadius,
    glowIntensity: glowIntensity ?? this.glowIntensity,
    scaleX: scaleX ?? this.scaleX,
    scaleY: scaleY ?? this.scaleY,
    rotationZ: rotationZ ?? this.rotationZ,
    skewX: skewX ?? this.skewX,
    skewY: skewY ?? this.skewY,
    sweepDirection: sweepDirection ?? this.sweepDirection,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'fontFamily': fontFamily,
    'fontSize': fontSize,
    'fontWeight': fontWeight,
    'isItalic': isItalic,
    'isUnderline': isUnderline,
    'alignment': alignment.name,
    'letterSpacing': letterSpacing,
    'wordSpacing': wordSpacing,
    'lineHeight': lineHeight,
    'inactiveColorValue': inactiveColorValue,
    'inactiveSecondaryColorValue': inactiveSecondaryColorValue,
    'inactiveUseGradient': inactiveUseGradient,
    'activeColorValue': activeColorValue,
    'activeSecondaryColorValue': activeSecondaryColorValue,
    'activeUseGradient': activeUseGradient,
    'outlineColorValue': outlineColorValue,
    'outlineWidth': outlineWidth,
    'outlineColorValue2': outlineColorValue2,
    'outlineWidth2': outlineWidth2,
    'shadowColorValue': shadowColorValue,
    'shadowBlur': shadowBlur,
    'shadowOffsetX': shadowOffsetX,
    'shadowOffsetY': shadowOffsetY,
    'glowColorValue': glowColorValue,
    'glowRadius': glowRadius,
    'glowIntensity': glowIntensity,
    'scaleX': scaleX,
    'scaleY': scaleY,
    'rotationZ': rotationZ,
    'skewX': skewX,
    'skewY': skewY,
    'sweepDirection': sweepDirection.name,
  };

  factory SubtitleStyle.fromJson(Map<String, Object?> json) => SubtitleStyle(
    id: json['id'] as String,
    name: json['name'] as String,
    fontFamily: json['fontFamily'] as String? ?? 'Arial',
    fontSize: (json['fontSize'] as num?)?.toDouble() ?? 58,
    fontWeight: (json['fontWeight'] as num?)?.toInt() ?? 700,
    isItalic: json['isItalic'] as bool? ?? false,
    isUnderline: json['isUnderline'] as bool? ?? false,
    alignment: SubtitleAlignment.values.firstWhere(
      (e) => e.name == json['alignment'],
      orElse: () => SubtitleAlignment.center,
    ),
    letterSpacing: (json['letterSpacing'] as num?)?.toDouble() ?? 1.0,
    wordSpacing: (json['wordSpacing'] as num?)?.toDouble() ?? 4.0,
    lineHeight: (json['lineHeight'] as num?)?.toDouble() ?? 1.2,
    inactiveColorValue:
        (json['inactiveColorValue'] as num?)?.toInt() ?? 0xFFFFFFFF,
    inactiveSecondaryColorValue:
        (json['inactiveSecondaryColorValue'] as num?)?.toInt() ?? 0xFFB0BEC5,
    inactiveUseGradient: json['inactiveUseGradient'] as bool? ?? false,
    activeColorValue: (json['activeColorValue'] as num?)?.toInt() ?? 0xFFFFC107,
    activeSecondaryColorValue:
        (json['activeSecondaryColorValue'] as num?)?.toInt() ?? 0xFFFF5722,
    activeUseGradient: json['activeUseGradient'] as bool? ?? false,
    outlineColorValue:
        (json['outlineColorValue'] as num?)?.toInt() ?? 0xFF000000,
    outlineWidth: (json['outlineWidth'] as num?)?.toDouble() ?? 3.5,
    outlineColorValue2:
        (json['outlineColorValue2'] as num?)?.toInt() ?? 0x00000000,
    outlineWidth2: (json['outlineWidth2'] as num?)?.toDouble() ?? 0.0,
    shadowColorValue: (json['shadowColorValue'] as num?)?.toInt() ?? 0x99000000,
    shadowBlur: (json['shadowBlur'] as num?)?.toDouble() ?? 6,
    shadowOffsetX: (json['shadowOffsetX'] as num?)?.toDouble() ?? 2,
    shadowOffsetY: (json['shadowOffsetY'] as num?)?.toDouble() ?? 3,
    glowColorValue: (json['glowColorValue'] as num?)?.toInt() ?? 0x00000000,
    glowRadius: (json['glowRadius'] as num?)?.toDouble() ?? 0.0,
    glowIntensity: (json['glowIntensity'] as num?)?.toDouble() ?? 0.0,
    scaleX: (json['scaleX'] as num?)?.toDouble() ?? 1.0,
    scaleY: (json['scaleY'] as num?)?.toDouble() ?? 1.0,
    rotationZ: (json['rotationZ'] as num?)?.toDouble() ?? 0.0,
    skewX: (json['skewX'] as num?)?.toDouble() ?? 0.0,
    skewY: (json['skewY'] as num?)?.toDouble() ?? 0.0,
    sweepDirection: SweepDirection.values.firstWhere(
      (e) => e.name == json['sweepDirection'],
      orElse: () => SweepDirection.leftToRight,
    ),
  );
}

class MarkerModel {
  const MarkerModel({
    required this.id,
    required this.timeUs,
    required this.name,
    this.colorValue = 0xFFFFCA28,
    this.notes = '',
  });

  final String id;
  final int timeUs;
  final String name;
  final int colorValue;
  final String notes;

  MarkerModel copyWith({
    String? id,
    int? timeUs,
    String? name,
    int? colorValue,
    String? notes,
  }) => MarkerModel(
    id: id ?? this.id,
    timeUs: timeUs ?? this.timeUs,
    name: name ?? this.name,
    colorValue: colorValue ?? this.colorValue,
    notes: notes ?? this.notes,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'timeUs': timeUs,
    'name': name,
    'colorValue': colorValue,
    'notes': notes,
  };

  factory MarkerModel.fromJson(Map<String, Object?> json) => MarkerModel(
    id: json['id'] as String,
    timeUs: (json['timeUs'] as num).toInt(),
    name: json['name'] as String,
    colorValue: (json['colorValue'] as num?)?.toInt() ?? 0xFFFFCA28,
    notes: json['notes'] as String? ?? '',
  );
}

enum LayoutMode { alternatingTwoRows, singleRow, multiRow }

class ProjectSettings {
  const ProjectSettings({
    this.autosaveSeconds = 30,
    this.snapEnabled = true,
    this.snapThresholdMs = 20,
    this.inputTimingOffsetMs = -80,
    this.mediaMode = 'reference',
    this.layoutMode = LayoutMode.alternatingTwoRows,
    this.rowAPositionX = 0.5,
    this.rowAPositionY = 0.82,
    this.rowBPositionX = 0.5,
    this.rowBPositionY = 0.90,
    this.singleRowPositionX = 0.5,
    this.singleRowPositionY = 0.86,
    this.leadTimeUs = 2000000,
    this.keepActorPrefix = false,
    this.recordingMode = 'hold',
    this.preRollSeconds = 0,
    this.audioEffects = const AudioEffects(),
  });

  final int autosaveSeconds;
  final bool snapEnabled;
  final int snapThresholdMs;
  final int inputTimingOffsetMs;
  final String mediaMode;
  final LayoutMode layoutMode;
  final double rowAPositionX;
  final double rowAPositionY;
  final double rowBPositionX;
  final double rowBPositionY;
  final double singleRowPositionX;
  final double singleRowPositionY;
  final int leadTimeUs;
  final bool keepActorPrefix;
  final String recordingMode;
  final int preRollSeconds;
  final AudioEffects audioEffects;

  ProjectSettings copyWith({
    int? autosaveSeconds,
    bool? snapEnabled,
    int? snapThresholdMs,
    int? inputTimingOffsetMs,
    String? mediaMode,
    LayoutMode? layoutMode,
    double? rowAPositionX,
    double? rowAPositionY,
    double? rowBPositionX,
    double? rowBPositionY,
    double? singleRowPositionX,
    double? singleRowPositionY,
    int? leadTimeUs,
    bool? keepActorPrefix,
    String? recordingMode,
    int? preRollSeconds,
    AudioEffects? audioEffects,
  }) => ProjectSettings(
    autosaveSeconds: autosaveSeconds ?? this.autosaveSeconds,
    snapEnabled: snapEnabled ?? this.snapEnabled,
    snapThresholdMs: snapThresholdMs ?? this.snapThresholdMs,
    inputTimingOffsetMs: inputTimingOffsetMs ?? this.inputTimingOffsetMs,
    mediaMode: mediaMode ?? this.mediaMode,
    layoutMode: layoutMode ?? this.layoutMode,
    rowAPositionX: rowAPositionX ?? this.rowAPositionX,
    rowAPositionY: rowAPositionY ?? this.rowAPositionY,
    rowBPositionX: rowBPositionX ?? this.rowBPositionX,
    rowBPositionY: rowBPositionY ?? this.rowBPositionY,
    singleRowPositionX: singleRowPositionX ?? this.singleRowPositionX,
    singleRowPositionY: singleRowPositionY ?? this.singleRowPositionY,
    leadTimeUs: leadTimeUs ?? this.leadTimeUs,
    keepActorPrefix: keepActorPrefix ?? this.keepActorPrefix,
    recordingMode: recordingMode ?? this.recordingMode,
    preRollSeconds: preRollSeconds ?? this.preRollSeconds,
    audioEffects: audioEffects ?? this.audioEffects,
  );

  Map<String, Object?> toJson() => {
    'autosaveSeconds': autosaveSeconds,
    'snapEnabled': snapEnabled,
    'snapThresholdMs': snapThresholdMs,
    'inputTimingOffsetMs': inputTimingOffsetMs,
    'mediaMode': mediaMode,
    'layoutMode': layoutMode.name,
    'rowAPositionX': rowAPositionX,
    'rowAPositionY': rowAPositionY,
    'rowBPositionX': rowBPositionX,
    'rowBPositionY': rowBPositionY,
    'singleRowPositionX': singleRowPositionX,
    'singleRowPositionY': singleRowPositionY,
    'leadTimeUs': leadTimeUs,
    'keepActorPrefix': keepActorPrefix,
    'recordingMode': recordingMode,
    'preRollSeconds': preRollSeconds,
    'audioEffects': audioEffects.toJson(),
  };

  factory ProjectSettings.fromJson(
    Map<String, Object?> json,
  ) => ProjectSettings(
    autosaveSeconds: (json['autosaveSeconds'] as num?)?.toInt() ?? 30,
    snapEnabled: json['snapEnabled'] as bool? ?? true,
    snapThresholdMs: (json['snapThresholdMs'] as num?)?.toInt() ?? 20,
    inputTimingOffsetMs: (json['inputTimingOffsetMs'] as num?)?.toInt() ?? 0,
    mediaMode: json['mediaMode'] as String? ?? 'reference',
    layoutMode: LayoutMode.values.firstWhere(
      (e) => e.name == json['layoutMode'],
      orElse: () => LayoutMode.alternatingTwoRows,
    ),
    rowAPositionX: (json['rowAPositionX'] as num?)?.toDouble() ?? 0.5,
    rowAPositionY: (json['rowAPositionY'] as num?)?.toDouble() ?? 0.82,
    rowBPositionX: (json['rowBPositionX'] as num?)?.toDouble() ?? 0.5,
    rowBPositionY: (json['rowBPositionY'] as num?)?.toDouble() ?? 0.90,
    singleRowPositionX: (json['singleRowPositionX'] as num?)?.toDouble() ?? 0.5,
    singleRowPositionY:
        (json['singleRowPositionY'] as num?)?.toDouble() ?? 0.86,
    leadTimeUs: (json['leadTimeUs'] as num?)?.toInt() ?? 2000000,
    keepActorPrefix: json['keepActorPrefix'] as bool? ?? false,
    recordingMode: json['recordingMode'] as String? ?? 'hold',
    preRollSeconds: (json['preRollSeconds'] as num?)?.toInt() ?? 0,
    audioEffects: AudioEffects.fromJson(
      Map<String, Object?>.from(json['audioEffects'] as Map? ?? const {}),
    ),
  );
}

class ProjectModel {
  const ProjectModel({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.modifiedAt,
    this.version = 1,
    this.canvasWidth = 1920,
    this.canvasHeight = 1080,
    this.fps = 30,
    this.audio,
    this.video,
    this.backgroundImage,
    this.actors = const [],
    this.lyricLines = const [],
    this.styles = defaultSubtitleStyles,
    this.markers = const [],
    this.subtitleTracks = const [],
    this.backgroundLayers = const [],
    this.settings = const ProjectSettings(),
  });

  final String id;
  final String name;
  final int version;
  final DateTime createdAt;
  final DateTime modifiedAt;
  final int canvasWidth;
  final int canvasHeight;
  final double fps;
  final MediaAsset? audio;
  final MediaAsset? video;
  final MediaAsset? backgroundImage;
  final List<Actor> actors;
  final List<LyricLine> lyricLines;
  final List<SubtitleStyle> styles;
  final List<MarkerModel> markers;
  final List<Map<String, Object?>> subtitleTracks;
  final List<Map<String, Object?>> backgroundLayers;
  final ProjectSettings settings;

  factory ProjectModel.create(String name) {
    final now = DateTime.now().toUtc();
    return ProjectModel(
      id: newId('project'),
      name: name,
      createdAt: now,
      modifiedAt: now,
      actors: const [
        Actor(id: 'male', name: 'Nam', colorValue: 0xFF42A5F5, styleId: 'male'),
        Actor(
          id: 'female',
          name: 'Nữ',
          colorValue: 0xFFEC407A,
          styleId: 'female',
        ),
        Actor(
          id: 'duet',
          name: 'Hợp ca',
          colorValue: 0xFFFFCA28,
          styleId: 'duet',
        ),
      ],
      styles: defaultSubtitleStyles,
      markers: const [],
      subtitleTracks: const [
        {'id': 'subtitle-main', 'name': 'Karaoke', 'visible': true},
      ],
    );
  }

  ProjectModel copyWith({
    String? id,
    String? name,
    DateTime? modifiedAt,
    int? canvasWidth,
    int? canvasHeight,
    double? fps,
    MediaAsset? audio,
    bool clearAudio = false,
    MediaAsset? video,
    bool clearVideo = false,
    MediaAsset? backgroundImage,
    bool clearBackgroundImage = false,
    List<Actor>? actors,
    List<LyricLine>? lyricLines,
    List<SubtitleStyle>? styles,
    List<MarkerModel>? markers,
    List<Map<String, Object?>>? subtitleTracks,
    List<Map<String, Object?>>? backgroundLayers,
    ProjectSettings? settings,
  }) => ProjectModel(
    id: id ?? this.id,
    name: name ?? this.name,
    version: version,
    createdAt: createdAt,
    modifiedAt: modifiedAt ?? this.modifiedAt,
    canvasWidth: canvasWidth ?? this.canvasWidth,
    canvasHeight: canvasHeight ?? this.canvasHeight,
    fps: fps ?? this.fps,
    audio: clearAudio ? null : (audio ?? this.audio),
    video: clearVideo ? null : (video ?? this.video),
    backgroundImage: clearBackgroundImage
        ? null
        : (backgroundImage ?? this.backgroundImage),
    actors: actors ?? this.actors,
    lyricLines: lyricLines ?? this.lyricLines,
    styles: styles ?? this.styles,
    markers: markers ?? this.markers,
    subtitleTracks: subtitleTracks ?? this.subtitleTracks,
    backgroundLayers: backgroundLayers ?? this.backgroundLayers,
    settings: settings ?? this.settings,
  );

  Map<String, Object?> toJson() => {
    'format': 'KaraStudioProject',
    'id': id,
    'name': name,
    'version': version,
    'createdAt': createdAt.toIso8601String(),
    'modifiedAt': modifiedAt.toIso8601String(),
    'canvasWidth': canvasWidth,
    'canvasHeight': canvasHeight,
    'fps': fps,
    'audio': audio?.toJson(),
    'video': video?.toJson(),
    'backgroundImage': backgroundImage?.toJson(),
    'actors': actors.map((actor) => actor.toJson()).toList(),
    'lyricLines': lyricLines.map((line) => line.toJson()).toList(),
    'styles': styles.map((style) => style.toJson()).toList(),
    'markers': markers.map((marker) => marker.toJson()).toList(),
    'subtitleTracks': subtitleTracks,
    'backgroundLayers': backgroundLayers,
    'projectSettings': settings.toJson(),
  };

  factory ProjectModel.fromJson(Map<String, Object?> json) {
    if (json['format'] != 'KaraStudioProject') {
      throw const FormatException('Đây không phải project KaraStudio hợp lệ.');
    }
    final version = (json['version'] as num?)?.toInt() ?? 0;
    if (version > 1) {
      throw FormatException('Project version $version chưa được hỗ trợ.');
    }
    return ProjectModel(
      id: json['id'] as String,
      name: json['name'] as String,
      version: version,
      createdAt: DateTime.parse(json['createdAt'] as String),
      modifiedAt: DateTime.parse(json['modifiedAt'] as String),
      canvasWidth: (json['canvasWidth'] as num?)?.toInt() ?? 1920,
      canvasHeight: (json['canvasHeight'] as num?)?.toInt() ?? 1080,
      fps: (json['fps'] as num?)?.toDouble() ?? 30,
      audio: json['audio'] == null
          ? null
          : MediaAsset.fromJson((json['audio'] as Map).cast()),
      video: json['video'] == null
          ? null
          : MediaAsset.fromJson((json['video'] as Map).cast()),
      backgroundImage: json['backgroundImage'] == null
          ? null
          : MediaAsset.fromJson((json['backgroundImage'] as Map).cast()),
      actors: ((json['actors'] as List?) ?? const [])
          .map((item) => Actor.fromJson((item as Map).cast()))
          .toList(),
      lyricLines: ((json['lyricLines'] as List?) ?? const [])
          .map((item) => LyricLine.fromJson((item as Map).cast()))
          .toList(),
      styles: _subtitleStylesFromJson(json['styles']),
      markers: ((json['markers'] as List?) ?? const [])
          .map((item) => MarkerModel.fromJson((item as Map).cast()))
          .toList(),
      subtitleTracks: ((json['subtitleTracks'] as List?) ?? const [])
          .map((item) => Map<String, Object?>.from(item as Map))
          .toList(),
      backgroundLayers: ((json['backgroundLayers'] as List?) ?? const [])
          .map((item) => Map<String, Object?>.from(item as Map))
          .toList(),
      settings: ProjectSettings.fromJson(
        ((json['projectSettings'] as Map?) ?? const {}).cast(),
      ),
    );
  }
}

const defaultSubtitleStyles = <SubtitleStyle>[
  SubtitleStyle(id: 'classic', name: 'Classic Karaoke'),
  SubtitleStyle(
    id: 'male',
    name: 'Male Style',
    activeColorValue: 0xFF42A5F5,
    activeSecondaryColorValue: 0xFF1E88E5,
  ),
  SubtitleStyle(
    id: 'female',
    name: 'Female Style',
    activeColorValue: 0xFFEC407A,
    activeSecondaryColorValue: 0xFFD81B60,
  ),
  SubtitleStyle(
    id: 'duet',
    name: 'Duet Style',
    activeColorValue: 0xFFFFCA28,
    activeSecondaryColorValue: 0xFFFF8F00,
  ),
];

List<SubtitleStyle> _subtitleStylesFromJson(Object? value) {
  final styles = ((value as List?) ?? const [])
      .map((item) => SubtitleStyle.fromJson((item as Map).cast()))
      .toList();
  return styles.isEmpty ? defaultSubtitleStyles : styles;
}
