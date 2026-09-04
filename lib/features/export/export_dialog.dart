import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

import '../../core/export/export_engine.dart';
import '../../models/project_model.dart';
import '../editor/editor_controller.dart';

class ExportDialog extends ConsumerStatefulWidget {
  const ExportDialog({super.key});

  @override
  ConsumerState<ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends ConsumerState<ExportDialog> {
  final ExportEngine _exportEngine = ExportEngine();
  final CancellationToken _cancellationToken = CancellationToken();

  String _format =
      'mp4'; // 'mp4', 'mov', 'webm', 'png_seq', 'ass', 'srt', 'lrc'
  int _width = 1920;
  int _height = 1080;
  double _fps = 30.0;
  String? _outputPath;

  bool _isExporting = false;
  ExportProgress? _progress;
  String? _errorMessage;
  bool _isFinished = false;

  @override
  void initState() {
    super.initState();
    final project = ref.read(editorControllerProvider).project;
    if (project != null) {
      _width = project.canvasWidth;
      _height = project.canvasHeight;
      _fps = project.fps;
    }
  }

  void _selectResolutionPreset(String preset) {
    setState(() {
      switch (preset) {
        case '1080p':
          _width = 1920;
          _height = 1080;
        case '4k':
          _width = 3840;
          _height = 2160;
        case '720p':
          _width = 1280;
          _height = 720;
        case 'tiktok':
          _width = 1080;
          _height = 1920;
        case 'square':
          _width = 1080;
          _height = 1080;
      }
    });
  }

  Future<void> _browseOutputPath(ProjectModel project) async {
    if (_format == 'png_seq') {
      final dir = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Chọn thư mục lưu PNG Sequence',
        lockParentWindow: true,
      );
      if (dir != null) {
        setState(() => _outputPath = dir);
      }
    } else {
      final ext = _format;
      final selected = await FilePicker.platform.saveFile(
        dialogTitle: 'Chọn nơi xuất tệp',
        fileName: '${project.name}.$ext',
        type: FileType.custom,
        allowedExtensions: [ext],
        lockParentWindow: true,
      );
      if (selected != null) {
        setState(() {
          _outputPath = selected.endsWith('.$ext')
              ? selected
              : '$selected.$ext';
        });
      }
    }
  }

  Future<void> _startExport(ProjectModel project) async {
    if (_outputPath == null) {
      await _browseOutputPath(project);
      if (_outputPath == null) return;
    }

    setState(() {
      _isExporting = true;
      _isFinished = false;
      _errorMessage = null;
      _progress = null;
    });

    try {
      if (_format == 'ass') {
        final content = _exportEngine.exportAss(project);
        await File(_outputPath!).writeAsString(content);
      } else if (_format == 'srt') {
        final content = _exportEngine.exportSrt(project);
        await File(_outputPath!).writeAsString(content);
      } else if (_format == 'lrc') {
        final content = _exportEngine.exportLrc(project);
        await File(_outputPath!).writeAsString(content);
      } else {
        await _exportEngine.exportVideo(
          project: project,
          outputPath: _outputPath!,
          format: _format,
          width: _width,
          height: _height,
          fps: _fps,
          onProgress: (p) => setState(() => _progress = p),
          cancellationToken: _cancellationToken,
        );
      }

      setState(() {
        _isFinished = true;
        _isExporting = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isExporting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final editor = ref.watch(editorControllerProvider);
    final project = editor.project;

    if (project == null) {
      return const AlertDialog(
        title: Text('Không có project'),
        content: Text('Vui lòng tạo hoặc mở một project trước khi xuất.'),
      );
    }

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.movie_creation_outlined, color: Color(0xFFFFB300)),
          const SizedBox(width: 8),
          Text(_isExporting ? 'Đang xuất tệp…' : 'Xuất Phụ Đề / Video'),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: _isExporting
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LinearProgressIndicator(value: _progress?.progress),
                  const SizedBox(height: 16),
                  if (_progress != null) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Frame: ${_progress!.currentFrame} / ${_progress!.totalFrames} (${(_progress!.progress * 100).toStringAsFixed(1)}%)',
                        ),
                        Text('${_progress!.fps.toStringAsFixed(1)} FPS'),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Thời gian đã chạy: ${_formatDuration(_progress!.elapsed)}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ] else
                    const Text(
                      'Đang khởi tạo FFmpeg pipeline…',
                      style: TextStyle(fontSize: 12),
                    ),
                  const SizedBox(height: 20),
                  FilledButton.tonal(
                    onPressed: () {
                      _cancellationToken.cancel();
                      setState(() => _isExporting = false);
                    },
                    child: const Text('Hủy xuất'),
                  ),
                ],
              )
            : _isFinished
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: Colors.greenAccent,
                    size: 54,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Xuất hoàn tất thành công!',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _outputPath ?? '',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FilledButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                        label: const Text('Đóng'),
                      ),
                    ],
                  ),
                ],
              )
            : ListView(
                shrinkWrap: true,
                children: [
                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(8),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.redAccent),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 12,
                        ),
                      ),
                    ),

                  // Format Selection
                  const Text(
                    'ĐỊNH DẠNG XUẤT',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFFB300),
                    ),
                  ),
                  const SizedBox(height: 6),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'mp4', label: Text('MP4 Video')),
                      ButtonSegment(
                        value: 'mov',
                        label: Text('ProRes 4444 (Alpha)'),
                      ),
                      ButtonSegment(
                        value: 'png_seq',
                        label: Text('PNG Sequence'),
                      ),
                    ],
                    selected: {
                      _format.startsWith('mp4') ||
                              _format.startsWith('mov') ||
                              _format.startsWith('png_seq')
                          ? _format
                          : 'mp4',
                    },
                    onSelectionChanged: (set) =>
                        setState(() => _format = set.first),
                  ),
                  const SizedBox(height: 6),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'ass',
                        label: Text('ASS Subtitle (\\k tags)'),
                      ),
                      ButtonSegment(value: 'srt', label: Text('SRT')),
                      ButtonSegment(value: 'lrc', label: Text('LRC')),
                    ],
                    selected: {
                      _format == 'ass' || _format == 'srt' || _format == 'lrc'
                          ? _format
                          : 'ass',
                    },
                    onSelectionChanged: (set) =>
                        setState(() => _format = set.first),
                  ),

                  if (_format != 'ass' &&
                      _format != 'srt' &&
                      _format != 'lrc') ...[
                    const SizedBox(height: 16),
                    const Text(
                      'ĐỘ PHÂN GIẢI & KHUNG HÌNH',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFFB300),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('1080p FHD'),
                          selected: _width == 1920 && _height == 1080,
                          onSelected: (_) => _selectResolutionPreset('1080p'),
                        ),
                        ChoiceChip(
                          label: const Text('4K UHD'),
                          selected: _width == 3840 && _height == 2160,
                          onSelected: (_) => _selectResolutionPreset('4k'),
                        ),
                        ChoiceChip(
                          label: const Text('720p HD'),
                          selected: _width == 1280 && _height == 720,
                          onSelected: (_) => _selectResolutionPreset('720p'),
                        ),
                        ChoiceChip(
                          label: const Text('TikTok (9:16)'),
                          selected: _width == 1080 && _height == 1920,
                          onSelected: (_) => _selectResolutionPreset('tiktok'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: Text('Kích thước: $_width × $_height')),
                        const Text('FPS: '),
                        DropdownButton<double>(
                          value: _fps,
                          items: [24.0, 25.0, 30.0, 60.0]
                              .map(
                                (f) => DropdownMenuItem(
                                  value: f,
                                  child: Text('$f'),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setState(() => _fps = v ?? 30.0),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 16),
                  const Text(
                    'ĐƯỜNG DẪN ĐÍCH',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFFB300),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _outputPath == null
                              ? 'Chưa chọn đường dẫn'
                              : p.basename(_outputPath!),
                          style: TextStyle(
                            fontSize: 12,
                            color: _outputPath == null
                                ? Colors.grey
                                : Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _browseOutputPath(project),
                        icon: const Icon(Icons.folder_open, size: 14),
                        label: const Text('Duyệt…'),
                      ),
                    ],
                  ),
                ],
              ),
      ),
      actions: _isExporting || _isFinished
          ? null
          : [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Đóng'),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFFB300),
                  foregroundColor: Colors.black,
                ),
                onPressed: () => _startExport(project),
                icon: const Icon(Icons.output),
                label: const Text(
                  'Bắt Đầu Xuất',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
