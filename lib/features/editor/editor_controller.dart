import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/ffmpeg/ffmpeg_service.dart';
import '../../core/playback/playback_clock.dart';
import '../../core/serialization/project_serializer.dart';
import '../../core/timing/timing_engine.dart';
import '../../core/undo_redo/undo_redo_manager.dart';
import '../../core/waveform/waveform_cache.dart';
import '../../models/audio_effects.dart';
import '../../models/project_model.dart';

final projectSerializerProvider = Provider((ref) => const ProjectSerializer());
final ffmpegServiceProvider = Provider((ref) => FfmpegService());
final playbackClockProvider = ChangeNotifierProvider((ref) => PlaybackClock());

final editorControllerProvider = ChangeNotifierProvider<EditorController>((
  ref,
) {
  final controller = EditorController(
    serializer: ref.read(projectSerializerProvider),
    ffmpeg: ref.read(ffmpegServiceProvider),
    playback: ref.read(playbackClockProvider),
  );
  return controller;
});

class EditorController extends ChangeNotifier {
  EditorController({
    required this.serializer,
    required this.ffmpeg,
    required this.playback,
  });

  final ProjectSerializer serializer;
  final FfmpegService ffmpeg;
  final PlaybackClock playback;
  final UndoRedoManager history = UndoRedoManager(capacity: 100);
  final TimingEngine timingEngine = const TimingEngine();

  ProjectModel? project;
  String? projectPath;
  WaveformCache? waveform;
  bool isDirty = false;
  bool isBusy = false;
  double taskProgress = 0;
  String status = 'Sẵn sàng';
  String? lastError;
  String? selectedLyricLineId;
  Timer? _autosaveTimer;

  bool get hasProject => project != null;
  String get windowTitle => project == null
      ? 'KaraStudio'
      : '${project!.name}${isDirty ? ' •' : ''} — KaraStudio';

  Future<void> initialize() async {
    try {
      await ffmpeg.verifyAvailable();
      status = 'FFmpeg sẵn sàng';
    } catch (error) {
      status = 'FFmpeg chưa sẵn sàng';
      lastError = error.toString();
    }
    notifyListeners();
  }

  Future<void> newProject(String name) async {
    await playback.closeMedia();
    project = ProjectModel.create(
      name.trim().isEmpty ? 'Untitled Project' : name.trim(),
    );
    projectPath = null;
    waveform = null;
    selectedLyricLineId = null;
    history.clear();
    isDirty = true;
    status = 'Đã tạo project mới';
    _scheduleAutosave();
    notifyListeners();
  }

  Future<bool> openProject() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Mở KaraStudio Project',
      type: FileType.custom,
      allowedExtensions: ['karastudio'],
      lockParentWindow: true,
    );
    final path = result?.files.single.path;
    if (path == null) return false;
    return openProjectPath(path);
  }

  Future<bool> openProjectPath(String path) async {
    return _guarded('Đang mở project…', () async {
      final loaded = await serializer.load(path);
      await playback.closeMedia();
      project = loaded;
      selectedLyricLineId = null;
      projectPath = path;
      waveform = null;
      history.clear();
      isDirty = false;
      await _rememberRecent(path);
      final audio = loaded.audio;
      if (audio != null) {
        if (!await File(audio.path).exists()) {
          lastError = 'Không tìm thấy media tham chiếu: ${audio.path}';
        } else {
          final cachePath =
              audio.waveformCachePath ??
              await ffmpeg.waveformCachePath(audio.path);
          final cachedAudio = audio.copyWith(waveformCachePath: cachePath);
          if (audio.waveformCachePath == null) {
            project = loaded.copyWith(audio: cachedAudio);
            isDirty = true;
          }
          await playback.open(audio.path);
          waveform = await ffmpeg.loadOrGenerateWaveform(
            cachedAudio,
            onProgress: (progress) {
              taskProgress = progress;
              notifyListeners();
            },
          );
        }
      }
      final video = loaded.video;
      if (video != null && await File(video.path).exists()) {
        await playback.openVideo(video.path);
      } else {
        await playback.closeVideo();
        if (video != null) {
          final message = 'Không tìm thấy video tham chiếu: ${video.path}';
          lastError = lastError == null ? message : '$lastError\n$message';
        }
      }
      _scheduleAutosave();
      status = 'Đã mở ${loaded.name}';
      await _restoreAudioEffects();
    });
  }

  Future<bool> save() async {
    if (project == null) return false;
    if (projectPath == null) return saveAs();
    return _saveTo(projectPath!);
  }

  Future<bool> saveAs() async {
    if (project == null) return false;
    final selected = await FilePicker.platform.saveFile(
      dialogTitle: 'Lưu KaraStudio Project',
      fileName: '${_safeFileName(project!.name)}.karastudio',
      type: FileType.custom,
      allowedExtensions: ['karastudio'],
      lockParentWindow: true,
    );
    if (selected == null) return false;
    final path = selected.toLowerCase().endsWith('.karastudio')
        ? selected
        : '$selected.karastudio';
    return _saveTo(path);
  }

  Future<bool> _saveTo(String path) async {
    return _guarded('Đang lưu project…', () async {
      final updated = project!.copyWith(modifiedAt: DateTime.now().toUtc());
      await serializer.save(updated, path);
      project = updated;
      projectPath = path;
      isDirty = false;
      await serializer.clearRecovery(updated);
      await _rememberRecent(path);
      status = 'Đã lưu ${p.basename(path)}';
    });
  }

  Future<bool> importAudio() async {
    if (project == null) {
      lastError = 'Hãy tạo hoặc mở project trước khi import audio.';
      notifyListeners();
      return false;
    }
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Import Audio',
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wav', 'flac', 'aac', 'm4a', 'ogg', 'wma'],
      lockParentWindow: true,
    );
    final path = result?.files.single.path;
    if (path == null) return false;
    return importAudioPath(path);
  }

  Future<bool> importAudioPath(String path) async {
    if (project == null) return false;
    return _guarded('Đang phân tích audio…', () async {
      var asset = await ffmpeg.probeAudio(path);
      final cachePath = await ffmpeg.waveformCachePath(path);
      asset = asset.copyWith(waveformCachePath: cachePath);
      status = 'Đang tạo waveform…';
      taskProgress = 0;
      notifyListeners();
      final generated = await ffmpeg.loadOrGenerateWaveform(
        asset,
        onProgress: (progress) {
          taskProgress = progress;
          notifyListeners();
        },
      );
      final before = project!;
      final beforeWaveform = waveform;
      final after = before.copyWith(
        audio: asset,
        modifiedAt: DateTime.now().toUtc(),
      );
      history.execute(
        CallbackCommand(
          description: 'Import audio',
          onExecute: () {
            project = after;
            waveform = generated;
            notifyListeners();
          },
          onUndo: () {
            project = before;
            waveform = beforeWaveform;
            notifyListeners();
          },
        ),
      );
      await playback.open(path);
      await _restoreAudioEffects();
      isDirty = true;
      status = 'Đã import ${p.basename(path)}';
    });
  }

  Future<bool> importBackgroundVideo() async {
    if (project == null) {
      lastError = 'Hãy tạo hoặc mở project trước.';
      notifyListeners();
      return false;
    }
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Import Background Video (Tự động tắt tiếng)',
      type: FileType.custom,
      allowedExtensions: ['mp4', 'mov', 'mkv', 'webm', 'avi', 'm4v'],
      lockParentWindow: true,
    );
    final path = result?.files.single.path;
    if (path == null) return false;

    return _guarded('Đang import video nền…', () async {
      final videoAsset = await ffmpeg.probeVideo(path);
      final before = project!;
      final after = before.copyWith(
        video: videoAsset,
        clearBackgroundImage: true,
        modifiedAt: DateTime.now().toUtc(),
      );

      history.execute(
        CallbackCommand(
          description: 'Import video nền',
          onExecute: () {
            project = after;
            isDirty = true;
            notifyListeners();
          },
          onUndo: () {
            project = before;
            isDirty = true;
            notifyListeners();
          },
        ),
      );
      await playback.openVideo(path);
      status = 'Đã đặt video nền: ${p.basename(path)}';
    });
  }

  Future<bool> importBackgroundImage() async {
    if (project == null) {
      lastError = 'Hãy tạo hoặc mở project trước.';
      notifyListeners();
      return false;
    }
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Import Background Image',
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'bmp'],
      lockParentWindow: true,
    );
    final path = result?.files.single.path;
    if (path == null) return false;

    return _guarded('Đang import hình nền…', () async {
      final imageAsset = MediaAsset(
        id: newId('image'),
        type: MediaType.image,
        path: path,
      );
      final before = project!;
      final after = before.copyWith(
        backgroundImage: imageAsset,
        clearVideo: true,
        modifiedAt: DateTime.now().toUtc(),
      );

      history.execute(
        CallbackCommand(
          description: 'Import hình nền',
          onExecute: () {
            project = after;
            isDirty = true;
            notifyListeners();
          },
          onUndo: () {
            project = before;
            isDirty = true;
            notifyListeners();
          },
        ),
      );
      await playback.closeVideo();
      status = 'Đã đặt hình nền: ${p.basename(path)}';
    });
  }

  void removeBackground() {
    if (project == null) return;
    final before = project!;
    final after = before.copyWith(
      clearVideo: true,
      clearBackgroundImage: true,
      modifiedAt: DateTime.now().toUtc(),
    );

    history.execute(
      CallbackCommand(
        description: 'Xóa background nền',
        onExecute: () {
          project = after;
          isDirty = true;
          notifyListeners();
        },
        onUndo: () {
          project = before;
          isDirty = true;
          notifyListeners();
        },
      ),
    );
    playback.closeVideo();
    status = 'Đã xóa nền';
  }

  void updateLyricLines(List<LyricLine> newLines, {String? description}) {
    if (project == null) return;
    final before = project!;
    final safeLines = newLines
        .map(timingEngine.preventTokenOverlaps)
        .toList(growable: false);
    final after = before.copyWith(
      lyricLines: safeLines,
      modifiedAt: DateTime.now().toUtc(),
    );

    history.execute(
      CallbackCommand(
        description: description ?? 'Sửa lyrics',
        onExecute: () {
          project = after;
          isDirty = true;
          notifyListeners();
        },
        onUndo: () {
          project = before;
          isDirty = true;
          notifyListeners();
        },
      ),
    );
  }

  int? get selectedLyricLineIndex {
    final selectedId = selectedLyricLineId;
    final lines = project?.lyricLines;
    if (selectedId == null || lines == null) return null;
    final index = lines.indexWhere((line) => line.id == selectedId);
    return index < 0 ? null : index;
  }

  void selectLyricLine(int index) {
    final lines = project?.lyricLines;
    if (lines == null || index < 0 || index >= lines.length) return;
    final nextId = lines[index].id;
    if (selectedLyricLineId == nextId) return;
    selectedLyricLineId = nextId;
    notifyListeners();
  }

  void updateProjectStyles(
    List<SubtitleStyle> newStyles, {
    String? description,
  }) {
    if (project == null) return;
    final before = project!;
    final after = before.copyWith(
      styles: newStyles,
      modifiedAt: DateTime.now().toUtc(),
    );

    history.execute(
      CallbackCommand(
        description: description ?? 'Sửa styles',
        onExecute: () {
          project = after;
          isDirty = true;
          notifyListeners();
        },
        onUndo: () {
          project = before;
          isDirty = true;
          notifyListeners();
        },
      ),
    );
  }

  void updateProjectActors(List<Actor> newActors, {String? description}) {
    if (project == null) return;
    final before = project!;
    final after = before.copyWith(
      actors: newActors,
      modifiedAt: DateTime.now().toUtc(),
    );

    history.execute(
      CallbackCommand(
        description: description ?? 'Sửa actors',
        onExecute: () {
          project = after;
          isDirty = true;
          notifyListeners();
        },
        onUndo: () {
          project = before;
          isDirty = true;
          notifyListeners();
        },
      ),
    );
  }

  void updateProjectSettings(
    ProjectSettings newSettings, {
    String? description,
  }) {
    if (project == null) return;
    final before = project!;
    final after = before.copyWith(
      settings: newSettings,
      modifiedAt: DateTime.now().toUtc(),
    );

    history.execute(
      CallbackCommand(
        description: description ?? 'Sửa settings',
        onExecute: () {
          project = after;
          isDirty = true;
          notifyListeners();
        },
        onUndo: () {
          project = before;
          isDirty = true;
          notifyListeners();
        },
      ),
    );
  }

  void addMarker(int timeUs, {String? name}) {
    if (project == null) return;
    final markerName = name ?? 'Marker ${project!.markers.length + 1}';
    final newMarker = MarkerModel(
      id: newId('marker'),
      timeUs: timeUs,
      name: markerName,
    );
    final updated = List<MarkerModel>.from(project!.markers)..add(newMarker);
    final before = project!;
    final after = before.copyWith(markers: updated);

    history.execute(
      CallbackCommand(
        description: 'Thêm marker',
        onExecute: () {
          project = after;
          isDirty = true;
          notifyListeners();
        },
        onUndo: () {
          project = before;
          isDirty = true;
          notifyListeners();
        },
      ),
    );
  }

  void fixTimingOverlaps() {
    if (project == null) return;
    final fixed = timingEngine.autoFixOverlaps(project!);
    updateLyricLines(fixed.lyricLines, description: 'Tự động sửa lỗi overlap');
  }

  void resetRecordingTiming({int startLineIndex = 0}) {
    final current = project;
    if (current == null || current.lyricLines.isEmpty) return;
    final start = startLineIndex.clamp(0, current.lyricLines.length - 1);
    final updated = timingEngine.clearTimingFrom(
      current.lyricLines,
      startLineIndex: start,
    );
    updateLyricLines(
      updated,
      description: start == 0
          ? 'Reset toàn bộ timing'
          : 'Reset timing từ câu ${start + 1}',
    );
    status = start == 0
        ? 'Đã reset toàn bộ timing'
        : 'Đã reset timing từ câu ${start + 1}';
  }

  void shiftTiming({
    required int deltaMs,
    int? fromLineIndex,
    int? singleLineIndex,
  }) {
    final current = project;
    if (current == null || current.lyricLines.isEmpty || deltaMs == 0) return;

    final deltaUs = deltaMs * 1000;
    final updated = timingEngine.shiftTiming(
      lines: current.lyricLines,
      deltaUs: deltaUs,
      fromLineIndex: fromLineIndex,
      singleLineIndex: singleLineIndex,
    );

    final desc = deltaMs > 0
        ? 'Dịch chậm timing +${deltaMs}ms'
        : 'Dịch sớm timing ${deltaMs}ms';
    updateLyricLines(updated, description: desc);
    status = 'Đã dịch chuyển timing ($desc)';
  }

  void undo() {
    if (!history.canUndo) return;
    history.undo();
    isDirty = true;
    unawaited(_syncPlaybackMediaToProject());
    status = 'Đã hoàn tác';
    notifyListeners();
  }

  void redo() {
    if (!history.canRedo) return;
    history.redo();
    isDirty = true;
    unawaited(_syncPlaybackMediaToProject());
    status = 'Đã làm lại';
    notifyListeners();
  }

  Future<void> _syncPlaybackMediaToProject() async {
    final audio = project?.audio;
    if (audio == null) {
      if (playback.mediaPath != null) await playback.closeAudio();
    } else if (playback.mediaPath != audio.path &&
        await File(audio.path).exists()) {
      await playback.open(audio.path);
    }

    final video = project?.video;
    if (video == null) {
      if (playback.videoPath != null) await playback.closeVideo();
    } else if (playback.videoPath != video.path &&
        await File(video.path).exists()) {
      await playback.openVideo(video.path);
    }
    await _restoreAudioEffects();
  }

  Future<void> applyAudioEffects(
    AudioEffects effects, {
    bool startPlayback = false,
  }) async {
    final audio = project?.audio;
    if (audio == null) return;

    String targetPath = audio.path;
    if (effects.hasPitchOrReverb) {
      targetPath = await ffmpeg.renderProcessedAudio(audio.path, effects);
    }

    if (playback.mediaPath != targetPath) {
      await playback.switchAudioSource(targetPath);
    }
    await playback.setSpeed(effects.speed);

    updateProjectSettings(
      project!.settings.copyWith(audioEffects: effects),
      description: 'Hiệu ứng âm thanh',
    );

    if (startPlayback && !playback.isPlaying) {
      await playback.play();
    }
    notifyListeners();
  }

  Future<void> _restoreAudioEffects() async {
    final settings = project?.settings;
    final audio = project?.audio;
    if (settings == null || audio == null) return;
    try {
      if (settings.audioEffects.hasPitchOrReverb) {
        final targetPath = await ffmpeg.renderProcessedAudio(
          audio.path,
          settings.audioEffects,
        );
        if (playback.mediaPath != targetPath) {
          await playback.switchAudioSource(targetPath);
        }
      } else if (playback.mediaPath != audio.path) {
        await playback.switchAudioSource(audio.path);
      }
      await playback.setSpeed(settings.audioEffects.speed);
    } catch (error) {
      lastError = 'Không khôi phục được hiệu ứng âm thanh: $error';
      notifyListeners();
    }
  }

  String? takeError() {
    final value = lastError;
    lastError = null;
    return value;
  }

  Future<bool> _guarded(
    String busyStatus,
    Future<void> Function() action,
  ) async {
    isBusy = true;
    taskProgress = 0;
    status = busyStatus;
    lastError = null;
    notifyListeners();
    try {
      await action();
      return true;
    } catch (error, stackTrace) {
      debugPrint('$error\n$stackTrace');
      lastError = error.toString();
      status = 'Tác vụ thất bại';
      return false;
    } finally {
      isBusy = false;
      taskProgress = 0;
      notifyListeners();
    }
  }

  void _scheduleAutosave() {
    _autosaveTimer?.cancel();
    final seconds = project?.settings.autosaveSeconds ?? 0;
    if (seconds <= 0) return;
    _autosaveTimer = Timer.periodic(Duration(seconds: seconds), (_) async {
      final value = project;
      if (value == null || !isDirty || isBusy) return;
      try {
        await serializer.saveRecovery(
          value.copyWith(modifiedAt: DateTime.now().toUtc()),
        );
        status = 'Đã autosave bản khôi phục';
        notifyListeners();
      } catch (error) {
        lastError = 'Autosave thất bại: $error';
        notifyListeners();
      }
    });
  }

  Future<void> _rememberRecent(String path) async {
    final preferences = await SharedPreferences.getInstance();
    final recent = preferences.getStringList('recentProjects') ?? <String>[];
    recent.remove(path);
    recent.insert(0, path);
    await preferences.setStringList('recentProjects', recent.take(12).toList());
  }

  String _safeFileName(String value) => value
      .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');

  bool _isDisposed = false;

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _autosaveTimer?.cancel();
    super.dispose();
  }
}
