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
import '../../core/undo_redo/undo_redo_manager.dart';
import '../../core/waveform/waveform_cache.dart';
import '../../models/project_model.dart';

final projectSerializerProvider = Provider((ref) => const ProjectSerializer());
final ffmpegServiceProvider = Provider((ref) => FfmpegService());
final playbackClockProvider = ChangeNotifierProvider((ref) => PlaybackClock());

final editorControllerProvider = ChangeNotifierProvider<EditorController>((
  ref,
) {
  final controller = EditorController(
    serializer: ref.watch(projectSerializerProvider),
    ffmpeg: ref.watch(ffmpegServiceProvider),
    playback: ref.watch(playbackClockProvider),
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

  ProjectModel? project;
  String? projectPath;
  WaveformCache? waveform;
  bool isDirty = false;
  bool isBusy = false;
  double taskProgress = 0;
  String status = 'Sẵn sàng';
  String? lastError;
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
      _scheduleAutosave();
      status = 'Đã mở ${loaded.name}';
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
          },
          onUndo: () {
            project = before;
            waveform = beforeWaveform;
          },
        ),
      );
      await playback.open(path);
      isDirty = true;
      status = 'Đã import ${p.basename(path)}';
    });
  }

  void undo() {
    if (!history.canUndo) return;
    history.undo();
    isDirty = true;
    final audio = project?.audio;
    if (audio == null) {
      unawaited(playback.closeMedia());
    } else if (playback.mediaPath != audio.path) {
      unawaited(playback.open(audio.path));
    }
    status = 'Đã hoàn tác';
    notifyListeners();
  }

  void redo() {
    if (!history.canRedo) return;
    history.redo();
    isDirty = true;
    final audio = project?.audio;
    if (audio != null && playback.mediaPath != audio.path) {
      unawaited(playback.open(audio.path));
    }
    status = 'Đã làm lại';
    notifyListeners();
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

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    super.dispose();
  }
}
