import 'dart:math';

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

  MediaAsset copyWith({String? waveformCachePath}) => MediaAsset(
    id: id,
    type: type,
    path: path,
    durationUs: durationUs,
    sampleRate: sampleRate,
    channels: channels,
    codec: codec,
    waveformCachePath: waveformCachePath ?? this.waveformCachePath,
    proxyPath: proxyPath,
    metadata: metadata,
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

class LyricLine {
  const LyricLine({
    required this.id,
    required this.text,
    required this.actorId,
    this.startUs,
    this.endUs,
    this.tokens = const [],
    this.styleId = 'classic',
    this.positionX = .5,
    this.positionY = .84,
    this.lineEffect = 'runningColor',
    this.transitionIn = 'none',
    this.transitionOut = 'none',
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
      positionX: (position?['x'] as num?)?.toDouble() ?? .5,
      positionY: (position?['y'] as num?)?.toDouble() ?? .84,
      lineEffect: json['lineEffect'] as String? ?? 'runningColor',
      transitionIn: json['transitionIn'] as String? ?? 'none',
      transitionOut: json['transitionOut'] as String? ?? 'none',
    );
  }
}

class Actor {
  const Actor({
    required this.id,
    required this.name,
    required this.colorValue,
    required this.styleId,
    this.positionX = .5,
    this.positionY = .84,
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
      positionX: (position?['x'] as num?)?.toDouble() ?? .5,
      positionY: (position?['y'] as num?)?.toDouble() ?? .84,
      indicatorId: json['indicatorId'] as String? ?? 'dots',
      defaultEffect: json['defaultEffect'] as String? ?? 'runningColor',
    );
  }
}

class SubtitleStyle {
  const SubtitleStyle({
    required this.id,
    required this.name,
    this.fontFamily = 'Arial',
    this.fontSize = 58,
    this.fontWeight = 700,
    this.inactiveColorValue = 0xFFFFFFFF,
    this.activeColorValue = 0xFFFFC107,
    this.outlineColorValue = 0xFF000000,
    this.outlineWidth = 3,
    this.shadowColorValue = 0x99000000,
    this.shadowBlur = 6,
    this.shadowOffsetX = 2,
    this.shadowOffsetY = 3,
  });

  final String id;
  final String name;
  final String fontFamily;
  final double fontSize;
  final int fontWeight;
  final int inactiveColorValue;
  final int activeColorValue;
  final int outlineColorValue;
  final double outlineWidth;
  final int shadowColorValue;
  final double shadowBlur;
  final double shadowOffsetX;
  final double shadowOffsetY;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'fontFamily': fontFamily,
    'fontSize': fontSize,
    'fontWeight': fontWeight,
    'inactiveColorValue': inactiveColorValue,
    'activeColorValue': activeColorValue,
    'outlineColorValue': outlineColorValue,
    'outlineWidth': outlineWidth,
    'shadowColorValue': shadowColorValue,
    'shadowBlur': shadowBlur,
    'shadowOffsetX': shadowOffsetX,
    'shadowOffsetY': shadowOffsetY,
  };

  factory SubtitleStyle.fromJson(Map<String, Object?> json) => SubtitleStyle(
    id: json['id'] as String,
    name: json['name'] as String,
    fontFamily: json['fontFamily'] as String? ?? 'Arial',
    fontSize: (json['fontSize'] as num?)?.toDouble() ?? 58,
    fontWeight: (json['fontWeight'] as num?)?.toInt() ?? 700,
    inactiveColorValue:
        (json['inactiveColorValue'] as num?)?.toInt() ?? 0xFFFFFFFF,
    activeColorValue: (json['activeColorValue'] as num?)?.toInt() ?? 0xFFFFC107,
    outlineColorValue:
        (json['outlineColorValue'] as num?)?.toInt() ?? 0xFF000000,
    outlineWidth: (json['outlineWidth'] as num?)?.toDouble() ?? 3,
    shadowColorValue: (json['shadowColorValue'] as num?)?.toInt() ?? 0x99000000,
    shadowBlur: (json['shadowBlur'] as num?)?.toDouble() ?? 6,
    shadowOffsetX: (json['shadowOffsetX'] as num?)?.toDouble() ?? 2,
    shadowOffsetY: (json['shadowOffsetY'] as num?)?.toDouble() ?? 3,
  );
}

class ProjectSettings {
  const ProjectSettings({
    this.autosaveSeconds = 30,
    this.snapEnabled = true,
    this.snapThresholdMs = 20,
    this.inputTimingOffsetMs = 0,
    this.mediaMode = 'reference',
  });

  final int autosaveSeconds;
  final bool snapEnabled;
  final int snapThresholdMs;
  final int inputTimingOffsetMs;
  final String mediaMode;

  Map<String, Object?> toJson() => {
    'autosaveSeconds': autosaveSeconds,
    'snapEnabled': snapEnabled,
    'snapThresholdMs': snapThresholdMs,
    'inputTimingOffsetMs': inputTimingOffsetMs,
    'mediaMode': mediaMode,
  };

  factory ProjectSettings.fromJson(Map<String, Object?> json) =>
      ProjectSettings(
        autosaveSeconds: (json['autosaveSeconds'] as num?)?.toInt() ?? 30,
        snapEnabled: json['snapEnabled'] as bool? ?? true,
        snapThresholdMs: (json['snapThresholdMs'] as num?)?.toInt() ?? 20,
        inputTimingOffsetMs:
            (json['inputTimingOffsetMs'] as num?)?.toInt() ?? 0,
        mediaMode: json['mediaMode'] as String? ?? 'reference',
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
    this.actors = const [],
    this.lyricLines = const [],
    this.styles = const [],
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
  final List<Actor> actors;
  final List<LyricLine> lyricLines;
  final List<SubtitleStyle> styles;
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
      styles: const [
        SubtitleStyle(id: 'classic', name: 'Classic Karaoke'),
        SubtitleStyle(id: 'male', name: 'Male', activeColorValue: 0xFF42A5F5),
        SubtitleStyle(
          id: 'female',
          name: 'Female',
          activeColorValue: 0xFFEC407A,
        ),
        SubtitleStyle(id: 'duet', name: 'Duet', activeColorValue: 0xFFFFCA28),
      ],
      subtitleTracks: const [
        {'id': 'subtitle-main', 'name': 'Karaoke', 'visible': true},
      ],
    );
  }

  ProjectModel copyWith({
    String? name,
    DateTime? modifiedAt,
    MediaAsset? audio,
    bool clearAudio = false,
    List<LyricLine>? lyricLines,
  }) => ProjectModel(
    id: id,
    name: name ?? this.name,
    version: version,
    createdAt: createdAt,
    modifiedAt: modifiedAt ?? this.modifiedAt,
    canvasWidth: canvasWidth,
    canvasHeight: canvasHeight,
    fps: fps,
    audio: clearAudio ? null : (audio ?? this.audio),
    video: video,
    actors: actors,
    lyricLines: lyricLines ?? this.lyricLines,
    styles: styles,
    subtitleTracks: subtitleTracks,
    backgroundLayers: backgroundLayers,
    settings: settings,
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
    'actors': actors.map((actor) => actor.toJson()).toList(),
    'lyricLines': lyricLines.map((line) => line.toJson()).toList(),
    'styles': styles.map((style) => style.toJson()).toList(),
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
      actors: ((json['actors'] as List?) ?? const [])
          .map((item) => Actor.fromJson((item as Map).cast()))
          .toList(),
      lyricLines: ((json['lyricLines'] as List?) ?? const [])
          .map((item) => LyricLine.fromJson((item as Map).cast()))
          .toList(),
      styles: ((json['styles'] as List?) ?? const [])
          .map((item) => SubtitleStyle.fromJson((item as Map).cast()))
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
