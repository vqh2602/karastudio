import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../app/app.dart';
import '../../core/playback/playback_clock.dart';
import '../../core/renderer/karaoke_renderer.dart';
import '../../models/project_model.dart';
import '../export/export_dialog.dart';
import '../inspector/inspector_panel.dart';
import '../lyrics/lyrics_panel.dart';
import '../palette/command_palette.dart';
import '../timeline/waveform_timeline.dart';
import '../timing/recording_overlay.dart';
import 'editor_controller.dart';
import 'audio_effects_dialog.dart';

class EditorPage extends ConsumerStatefulWidget {
  const EditorPage({super.key});

  @override
  ConsumerState<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends ConsumerState<EditorPage> {
  double leftWidth = 320;
  double rightWidth = 320;
  double timelineHeight = 250;
  bool showLyrics = true;
  bool showInspector = true;
  bool showTimeline = true;
  bool showRecordingOverlay = false;
  bool showSafeAreas = false;

  final KaraokeRenderer _renderer = KaraokeRenderer();

  @override
  Widget build(BuildContext context) {
    final editor = ref.watch(editorControllerProvider);
    final playback = ref.watch(playbackClockProvider);
    final modifier = Platform.isMacOS ? '⌘' : 'Ctrl+';

    return CallbackShortcuts(
      bindings: {
        SingleActivator(
          LogicalKeyboardKey.keyS,
          meta: Platform.isMacOS,
          control: !Platform.isMacOS,
        ): () =>
            _run(editor.save()),
        SingleActivator(
          LogicalKeyboardKey.keyS,
          shift: true,
          meta: Platform.isMacOS,
          control: !Platform.isMacOS,
        ): () =>
            _run(editor.saveAs()),
        SingleActivator(
          LogicalKeyboardKey.keyZ,
          meta: Platform.isMacOS,
          control: !Platform.isMacOS,
        ): editor.undo,
        SingleActivator(
          LogicalKeyboardKey.keyZ,
          shift: true,
          meta: Platform.isMacOS,
          control: !Platform.isMacOS,
        ): editor.redo,
        SingleActivator(
          LogicalKeyboardKey.keyK,
          meta: Platform.isMacOS,
          control: !Platform.isMacOS,
        ): () =>
            _openCommandPalette(editor, playback),
        SingleActivator(
          LogicalKeyboardKey.keyP,
          shift: true,
          meta: Platform.isMacOS,
          control: !Platform.isMacOS,
        ): () =>
            _openCommandPalette(editor, playback),
        SingleActivator(LogicalKeyboardKey.keyR): () =>
            setState(() => showRecordingOverlay = !showRecordingOverlay),
        SingleActivator(LogicalKeyboardKey.keyM): () =>
            editor.addMarker(playback.positionUs),
        const SingleActivator(LogicalKeyboardKey.space): () {
          if (!showRecordingOverlay && editor.project?.audio != null) {
            playback.toggle();
          }
        },
        const SingleActivator(LogicalKeyboardKey.home): () =>
            playback.seek(Duration.zero),
        const SingleActivator(LogicalKeyboardKey.end): () =>
            playback.seek(playback.duration),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: Stack(
            children: [
              Column(
                children: [
                  _MenuStrip(
                    editor: editor,
                    modifier: modifier,
                    onNew: () => _newProject(editor),
                    onOpen: () => _openProject(editor),
                    onSave: () => _run(editor.save()),
                    onSaveAs: () => _run(editor.saveAs()),
                    onImportAudio: () => _run(editor.importAudio()),
                    onImportVideo: () => _run(editor.importBackgroundVideo()),
                    onExport: () => _showExportDialog(context),
                    onToggleLyrics: () =>
                        setState(() => showLyrics = !showLyrics),
                    onToggleInspector: () =>
                        setState(() => showInspector = !showInspector),
                    onToggleTimeline: () =>
                        setState(() => showTimeline = !showTimeline),
                    onToggleRecord: () => setState(
                      () => showRecordingOverlay = !showRecordingOverlay,
                    ),
                    onToggleSafeAreas: () =>
                        setState(() => showSafeAreas = !showSafeAreas),
                    onCommandPalette: () =>
                        _openCommandPalette(editor, playback),
                  ),
                  if (editor.isBusy)
                    LinearProgressIndicator(
                      value: editor.taskProgress > 0
                          ? editor.taskProgress
                          : null,
                    ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final maxSide = constraints.maxWidth * 0.40;
                        leftWidth = leftWidth.clamp(240, maxSide);
                        rightWidth = rightWidth.clamp(240, maxSide);
                        timelineHeight = timelineHeight.clamp(
                          160,
                          constraints.maxHeight * 0.60,
                        );

                        return Column(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  if (showLyrics) ...[
                                    SizedBox(
                                      width: leftWidth,
                                      child: const LyricsPanel(),
                                    ),
                                    _VerticalHandle(
                                      onDrag: (delta) =>
                                          setState(() => leftWidth += delta),
                                    ),
                                  ],
                                  Expanded(
                                    child: _LivePreview(
                                      project: editor.project,
                                      playback: playback,
                                      renderer: _renderer,
                                      showSafeAreas: showSafeAreas,
                                      onToggleRecord: () => setState(
                                        () => showRecordingOverlay =
                                            !showRecordingOverlay,
                                      ),
                                    ),
                                  ),
                                  if (showInspector) ...[
                                    _VerticalHandle(
                                      onDrag: (delta) =>
                                          setState(() => rightWidth -= delta),
                                    ),
                                    SizedBox(
                                      width: rightWidth,
                                      child: const InspectorPanel(),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (showTimeline) ...[
                              _HorizontalHandle(
                                onDrag: (delta) =>
                                    setState(() => timelineHeight -= delta),
                              ),
                              SizedBox(
                                height: timelineHeight,
                                child: WaveformTimeline(
                                  clock: playback,
                                  waveform: editor.waveform,
                                  project: editor.project,
                                  durationUs:
                                      editor.project?.audio?.durationUs ??
                                      playback.durationUs,
                                  onLinesUpdated: (lines, {description}) =>
                                      editor.updateLyricLines(
                                        lines,
                                        description: description,
                                      ),
                                  onAddMarker: (t) => editor.addMarker(t),
                                  onLineSelected: editor.selectLyricLine,
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  ),
                  _Transport(editor: editor, playback: playback),
                ],
              ),

              // Recording HUD Overlay
              if (showRecordingOverlay)
                Positioned(
                  left: 12,
                  right: 12,
                  top: 78,
                  bottom: (showTimeline ? timelineHeight : 0) + 50,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: RecordingOverlay(
                        onClose: () =>
                            setState(() => showRecordingOverlay = false),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _newProject(EditorController editor) async {
    if (!await _confirmDiscard(editor)) return;
    if (!mounted) return;
    final name = await showDialog<String>(
      context: context,
      builder: (context) => const _NewProjectDialog(),
    );
    if (name != null && mounted) await editor.newProject(name);
  }

  Future<void> _openProject(EditorController editor) async {
    if (!await _confirmDiscard(editor)) return;
    await _run(editor.openProject());
  }

  Future<bool> _confirmDiscard(EditorController editor) async {
    if (!editor.hasProject || !editor.isDirty) return true;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            icon: const Icon(Icons.warning_amber_rounded),
            title: const Text('Thay đổi chưa lưu'),
            content: const Text(
              'Project hiện tại có thay đổi chưa lưu. Bạn có muốn bỏ các thay đổi này?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Hủy'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Bỏ thay đổi'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showExportDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => const ExportDialog(),
    );
  }

  void _openCommandPalette(EditorController editor, PlaybackClock playback) {
    showDialog<void>(
      context: context,
      builder: (context) => CommandPalette(
        items: [
          CommandPaletteItem(
            title: 'New Project',
            category: 'File',
            shortcut: 'Ctrl+N',
            icon: Icons.note_add_outlined,
            action: () => _newProject(editor),
          ),
          CommandPaletteItem(
            title: 'Open Project…',
            category: 'File',
            shortcut: 'Ctrl+O',
            icon: Icons.folder_open,
            action: () => _openProject(editor),
          ),
          CommandPaletteItem(
            title: 'Save Project',
            category: 'File',
            shortcut: 'Ctrl+S',
            icon: Icons.save_outlined,
            action: () => _run(editor.save()),
          ),
          CommandPaletteItem(
            title: 'Save Project As…',
            category: 'File',
            shortcut: 'Ctrl+Shift+S',
            icon: Icons.save_as_outlined,
            action: () => _run(editor.saveAs()),
          ),
          CommandPaletteItem(
            title: 'Import Audio…',
            category: 'Media',
            icon: Icons.audio_file_outlined,
            action: () => _run(editor.importAudio()),
          ),
          CommandPaletteItem(
            title: 'Import Video…',
            category: 'Media',
            icon: Icons.video_file_outlined,
            action: () => _run(editor.importBackgroundVideo()),
          ),
          CommandPaletteItem(
            title: 'Export Video / Subtitles…',
            category: 'Export',
            shortcut: 'Ctrl+E',
            icon: Icons.output,
            action: () => _showExportDialog(context),
          ),
          CommandPaletteItem(
            title: 'Toggle Record Timing HUD',
            category: 'Timing',
            shortcut: 'R',
            icon: Icons.mic,
            action: () =>
                setState(() => showRecordingOverlay = !showRecordingOverlay),
          ),
          CommandPaletteItem(
            title: 'Add Marker at Playhead',
            category: 'Timeline',
            shortcut: 'M',
            icon: Icons.bookmark_add_outlined,
            action: () => editor.addMarker(playback.positionUs),
          ),
          CommandPaletteItem(
            title: 'Fix Timing Overlaps',
            category: 'Timing',
            icon: Icons.auto_fix_high,
            action: editor.fixTimingOverlaps,
          ),
          CommandPaletteItem(
            title: 'Toggle Safe Area Guides',
            category: 'View',
            icon: Icons.grid_on,
            action: () => setState(() => showSafeAreas = !showSafeAreas),
          ),
          CommandPaletteItem(
            title: 'Undo',
            category: 'Edit',
            shortcut: 'Ctrl+Z',
            icon: Icons.undo,
            action: editor.undo,
          ),
          CommandPaletteItem(
            title: 'Redo',
            category: 'Edit',
            shortcut: 'Ctrl+Shift+Z',
            icon: Icons.redo,
            action: editor.redo,
          ),
        ],
      ),
    );
  }

  Future<void> _run(Future<bool> operation) async {
    await operation;
    if (!mounted) return;
    final error = ref.read(editorControllerProvider).takeError();
    if (error != null) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.error_outline),
          title: const Text('Không thể hoàn thành tác vụ'),
          content: SelectableText(error),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Đóng'),
            ),
          ],
        ),
      );
    }
  }
}

class _MenuStrip extends ConsumerWidget {
  const _MenuStrip({
    required this.editor,
    required this.modifier,
    required this.onNew,
    required this.onOpen,
    required this.onSave,
    required this.onSaveAs,
    required this.onImportAudio,
    required this.onImportVideo,
    required this.onExport,
    required this.onToggleLyrics,
    required this.onToggleInspector,
    required this.onToggleTimeline,
    required this.onToggleRecord,
    required this.onToggleSafeAreas,
    required this.onCommandPalette,
  });

  final EditorController editor;
  final String modifier;
  final VoidCallback onNew;
  final VoidCallback onOpen;
  final VoidCallback onSave;
  final VoidCallback onSaveAs;
  final VoidCallback onImportAudio;
  final VoidCallback onImportVideo;
  final VoidCallback onExport;
  final VoidCallback onToggleLyrics;
  final VoidCallback onToggleInspector;
  final VoidCallback onToggleTimeline;
  final VoidCallback onToggleRecord;
  final VoidCallback onToggleSafeAreas;
  final VoidCallback onCommandPalette;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget item(String label, VoidCallback? action, [String? shortcut]) =>
        MenuItemButton(
          onPressed: action,
          child: SizedBox(
            width: 220,
            child: Row(
              children: [
                Text(label),
                if (shortcut != null) ...[
                  const Spacer(),
                  Text(
                    shortcut,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );

    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 38,
      padding: const EdgeInsets.only(left: 10, right: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.subtitles_rounded,
            size: 18,
            color: Color(0xFFFFB300),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              editor.windowTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
          MenuBar(
            style: const MenuStyle(
              padding: WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 2),
              ),
              backgroundColor: WidgetStatePropertyAll(Colors.transparent),
              elevation: WidgetStatePropertyAll(0),
            ),
            children: [
              SubmenuButton(
                menuChildren: [
                  item('New Project', onNew, '${modifier}N'),
                  item('Open Project…', onOpen, '${modifier}O'),
                  const Divider(),
                  item(
                    'Save',
                    editor.hasProject ? onSave : null,
                    '${modifier}S',
                  ),
                  item(
                    'Save As…',
                    editor.hasProject ? onSaveAs : null,
                    '$modifier⇧S',
                  ),
                  const Divider(),
                  item(
                    'Import Audio…',
                    editor.hasProject ? onImportAudio : null,
                  ),
                  item(
                    'Import Video…',
                    editor.hasProject ? onImportVideo : null,
                  ),
                ],
                child: const Text('File'),
              ),
              SubmenuButton(
                menuChildren: [
                  item(
                    editor.history.undoDescription == null
                        ? 'Undo'
                        : 'Undo ${editor.history.undoDescription}',
                    editor.history.canUndo ? editor.undo : null,
                    '${modifier}Z',
                  ),
                  item(
                    editor.history.redoDescription == null
                        ? 'Redo'
                        : 'Redo ${editor.history.redoDescription}',
                    editor.history.canRedo ? editor.redo : null,
                    '$modifier⇧Z',
                  ),
                  const Divider(),
                  item('Command Palette…', onCommandPalette, '${modifier}K'),
                ],
                child: const Text('Edit'),
              ),
              SubmenuButton(
                menuChildren: [
                  item(
                    'Record Timing Mode',
                    editor.hasProject ? onToggleRecord : null,
                    'R',
                  ),
                  item(
                    'Fix Timing Overlaps',
                    editor.hasProject ? editor.fixTimingOverlaps : null,
                  ),
                ],
                child: const Text('Timing'),
              ),
              SubmenuButton(
                menuChildren: [
                  item('Lyrics Panel', onToggleLyrics),
                  item('Inspector Panel', onToggleInspector),
                  item('Timeline', onToggleTimeline),
                  const Divider(),
                  item('Safe Area Guides', onToggleSafeAreas),
                ],
                child: const Text('View'),
              ),
              SubmenuButton(
                menuChildren: [
                  item(
                    'Export Subtitle (ASS/SRT/LRC)…',
                    editor.hasProject ? onExport : null,
                  ),
                  item(
                    'Export Transparent Video (ProRes 4444)…',
                    editor.hasProject ? onExport : null,
                  ),
                  item(
                    'Export Video MP4…',
                    editor.hasProject ? onExport : null,
                  ),
                  item(
                    'Export PNG Sequence…',
                    editor.hasProject ? onExport : null,
                  ),
                ],
                child: const Text('Export'),
              ),
            ],
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(
              dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              size: 17,
            ),
            tooltip: dark ? 'Light mode' : 'Dark mode',
            onPressed: () => ref.read(themeModeProvider.notifier).state = dark
                ? ThemeMode.light
                : ThemeMode.dark,
          ),
        ],
      ),
    );
  }
}

class _LivePreview extends StatelessWidget {
  const _LivePreview({
    required this.project,
    required this.playback,
    required this.renderer,
    required this.showSafeAreas,
    required this.onToggleRecord,
  });

  final ProjectModel? project;
  final PlaybackClock playback;
  final KaraokeRenderer renderer;
  final bool showSafeAreas;
  final VoidCallback onToggleRecord;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      child: Column(
        children: [
          const _PanelHeader(
            icon: Icons.ondemand_video_outlined,
            title: 'REALTIME PREVIEW',
          ),
          Expanded(
            child: Center(
              child: project == null
                  ? _WelcomeCard()
                  : AspectRatio(
                      aspectRatio: project!.canvasWidth / project!.canvasHeight,
                      child: Container(
                        margin: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black87,
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // 1. Background Image layer
                            if (project!.backgroundImage != null &&
                                File(
                                  project!.backgroundImage!.path,
                                ).existsSync())
                              Image.file(
                                File(project!.backgroundImage!.path),
                                fit: BoxFit.cover,
                              ),

                            // 2. Background Video layer
                            if (project!.video != null)
                              Video(
                                key: ValueKey(project!.video!.path),
                                controller: playback.videoController,
                                fit: BoxFit.cover,
                                controls: NoVideoControls,
                              ),

                            if (project!.video != null)
                              ListenableBuilder(
                                listenable: playback,
                                builder: (context, _) {
                                  if (playback.videoError != null) {
                                    return Center(
                                      child: Container(
                                        constraints: const BoxConstraints(
                                          maxWidth: 420,
                                        ),
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: Colors.black87,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: Colors.redAccent,
                                          ),
                                        ),
                                        child: Text(
                                          'Không thể hiển thị video:\n${playback.videoError}',
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                  if (!playback.isVideoReady ||
                                      playback.isVideoBuffering) {
                                    return const Center(
                                      child: SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    );
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),

                            // 3. Realtime Karaoke Canvas overlay (Vsync 60fps/120fps smooth sub-millisecond)
                            _SmoothKaraokeCanvas(
                              playback: playback,
                              renderer: renderer,
                              project: project!,
                              showSafeAreas: showSafeAreas,
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SmoothKaraokeCanvas extends StatefulWidget {
  const _SmoothKaraokeCanvas({
    required this.playback,
    required this.renderer,
    required this.project,
    required this.showSafeAreas,
  });

  final PlaybackClock playback;
  final KaraokeRenderer renderer;
  final ProjectModel project;
  final bool showSafeAreas;

  @override
  State<_SmoothKaraokeCanvas> createState() => _SmoothKaraokeCanvasState();
}

class _SmoothKaraokeCanvasState extends State<_SmoothKaraokeCanvas>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<int> _repaint = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) => _repaint.value++);
    widget.playback.addListener(_onClockChanged);
    _onClockChanged();
  }

  void _onClockChanged() {
    if (widget.playback.isPlaying && !_ticker.isActive) {
      _ticker.start();
    } else if (!widget.playback.isPlaying && _ticker.isActive) {
      _ticker.stop();
    }
    _repaint.value++;
  }

  @override
  void didUpdateWidget(covariant _SmoothKaraokeCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playback != widget.playback) {
      oldWidget.playback.removeListener(_onClockChanged);
      widget.playback.addListener(_onClockChanged);
    }
    _onClockChanged();
  }

  @override
  void dispose() {
    widget.playback.removeListener(_onClockChanged);
    _ticker.dispose();
    _repaint.dispose();
    widget.renderer.clearCache();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(
      size: Size.infinite,
      painter: _KaraokeCanvasPainter(
        repaint: _repaint,
        playback: widget.playback,
        renderer: widget.renderer,
        project: widget.project,
        showSafeAreas: widget.showSafeAreas,
      ),
    ),
  );
}

class _KaraokeCanvasPainter extends CustomPainter {
  _KaraokeCanvasPainter({
    required Listenable repaint,
    required this.playback,
    required this.renderer,
    required this.project,
    required this.showSafeAreas,
  }) : super(repaint: repaint);

  final PlaybackClock playback;
  final KaraokeRenderer renderer;
  final ProjectModel project;
  final bool showSafeAreas;

  @override
  void paint(Canvas canvas, Size size) {
    renderer.render(
      canvas: canvas,
      canvasSize: size,
      project: project,
      timeUs: playback.precisePositionUs,
      isPreview: true,
      showSafeAreas: showSafeAreas,
    );
  }

  @override
  bool shouldRepaint(covariant _KaraokeCanvasPainter old) =>
      old.playback != playback ||
      old.project != project ||
      old.showSafeAreas != showSafeAreas;
}

class _WelcomeCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editor = ref.read(editorControllerProvider);
    return Container(
      width: 420,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.subtitles_rounded,
            size: 56,
            color: Color(0xFFFFB300),
          ),
          const SizedBox(height: 12),
          Text('KaraStudio', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 6),
          const Text(
            'Desktop Karaoke Subtitle Editor',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => editor.newProject('Untitled Project'),
            icon: const Icon(Icons.add),
            label: const Text('New Project'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: editor.openProject,
            icon: const Icon(Icons.folder_open),
            label: const Text('Open Project'),
          ),
        ],
      ),
    );
  }
}

class _Transport extends StatelessWidget {
  const _Transport({required this.editor, required this.playback});
  final EditorController editor;
  final PlaybackClock playback;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: ListenableBuilder(
        listenable: playback,
        builder: (context, _) {
          final enabled =
              editor.project?.audio != null || editor.project?.video != null;
          return Row(
            children: [
              IconButton(
                onPressed: enabled ? () => playback.seek(Duration.zero) : null,
                icon: const Icon(Icons.skip_previous, size: 18),
                tooltip: 'Timeline start',
              ),
              IconButton(
                onPressed: enabled ? playback.stop : null,
                icon: const Icon(Icons.stop, size: 18),
                tooltip: 'Stop',
              ),
              IconButton.filled(
                onPressed: enabled ? playback.toggle : null,
                icon: Icon(
                  playback.isPlaying ? Icons.pause : Icons.play_arrow,
                  size: 19,
                ),
                tooltip: 'Play / Pause (Space)',
              ),
              IconButton(
                onPressed: enabled
                    ? () => playback.seek(playback.duration)
                    : null,
                icon: const Icon(Icons.skip_next, size: 18),
                tooltip: 'Timeline end',
              ),
              const SizedBox(width: 14),
              Text(
                '${_formatTime(playback.position)}  /  ${_formatTime(playback.duration)}',
                style: const TextStyle(
                  fontFeatures: [FontFeature.tabularFigures()],
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
              const Spacer(),
              // Quick Speed Chips
              IconButton(
                tooltip: 'Đổi tông / Hiệu ứng âm thanh',
                onPressed: editor.project?.audio == null
                    ? null
                    : () => showAudioEffectsDialog(context, editor),
                icon: const Icon(Icons.equalizer, size: 20),
              ),
              Row(
                children: [
                  const Icon(Icons.speed, size: 14, color: Colors.white54),
                  const SizedBox(width: 4),
                  for (final s in [0.5, 0.75, 1.0, 1.25])
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: InkWell(
                        onTap: enabled ? () => playback.setSpeed(s) : null,
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: playback.speed == s
                                ? const Color(0xFFFFB300)
                                : Colors.white10,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '$s×',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: playback.speed == s
                                  ? Colors.black
                                  : (enabled ? Colors.white : Colors.white38),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 8),
              const SizedBox(width: 12),
              Text(
                editor.status,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) => Container(
    height: 32,
    padding: const EdgeInsets.symmetric(horizontal: 8),
    alignment: Alignment.centerLeft,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainer,
      border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
    ),
    child: Row(
      children: [
        Icon(icon, size: 15),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
      ],
    ),
  );
}

class _VerticalHandle extends StatelessWidget {
  const _VerticalHandle({required this.onDrag});
  final ValueChanged<double> onDrag;
  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.resizeColumn,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: (details) => onDrag(details.delta.dx),
      child: Container(width: 4, color: Theme.of(context).dividerColor),
    ),
  );
}

class _HorizontalHandle extends StatelessWidget {
  const _HorizontalHandle({required this.onDrag});
  final ValueChanged<double> onDrag;
  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.resizeRow,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: (details) => onDrag(details.delta.dy),
      child: Container(height: 4, color: Theme.of(context).dividerColor),
    ),
  );
}

class _NewProjectDialog extends StatefulWidget {
  const _NewProjectDialog();
  @override
  State<_NewProjectDialog> createState() => _NewProjectDialogState();
}

class _NewProjectDialogState extends State<_NewProjectDialog> {
  final controller = TextEditingController(text: 'Untitled Project');
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('New Project'),
    content: SizedBox(
      width: 380,
      child: TextField(
        controller: controller,
        autofocus: true,
        selectAllOnFocus: true,
        decoration: const InputDecoration(labelText: 'Project name'),
        onSubmitted: (value) => Navigator.pop(context, value),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, controller.text),
        child: const Text('Tạo'),
      ),
    ],
  );
}

String _formatTime(Duration value) {
  final hours = value.inHours.toString().padLeft(2, '0');
  final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
  final milliseconds = value.inMilliseconds
      .remainder(1000)
      .toString()
      .padLeft(3, '0');
  return '$hours:$minutes:$seconds.$milliseconds';
}
