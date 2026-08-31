import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../app/app.dart';
import '../../core/playback/playback_clock.dart';
import '../../models/project_model.dart';
import '../timeline/waveform_timeline.dart';
import 'editor_controller.dart';

class EditorPage extends ConsumerStatefulWidget {
  const EditorPage({super.key});

  @override
  ConsumerState<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends ConsumerState<EditorPage> {
  double leftWidth = 282;
  double rightWidth = 292;
  double timelineHeight = 245;
  bool showLyrics = true;
  bool showInspector = true;
  bool showTimeline = true;

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
        const SingleActivator(LogicalKeyboardKey.space): () {
          if (editor.project?.audio != null) playback.toggle();
        },
        const SingleActivator(LogicalKeyboardKey.home): () =>
            playback.seek(Duration.zero),
        const SingleActivator(LogicalKeyboardKey.end): () =>
            playback.seek(playback.duration),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: Column(
            children: [
              _MenuStrip(
                editor: editor,
                modifier: modifier,
                onNew: () => _newProject(editor),
                onOpen: () => _openProject(editor),
                onSave: () => _run(editor.save()),
                onSaveAs: () => _run(editor.saveAs()),
                onImportAudio: () => _run(editor.importAudio()),
                onToggleLyrics: () => setState(() => showLyrics = !showLyrics),
                onToggleInspector: () =>
                    setState(() => showInspector = !showInspector),
                onToggleTimeline: () =>
                    setState(() => showTimeline = !showTimeline),
              ),
              _Toolbar(
                editor: editor,
                playback: playback,
                onNew: () => _newProject(editor),
                onOpen: () => _openProject(editor),
                onSave: () => _run(editor.save()),
                onImportAudio: () => _run(editor.importAudio()),
              ),
              if (editor.isBusy)
                LinearProgressIndicator(
                  value: editor.taskProgress > 0 ? editor.taskProgress : null,
                ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final maxSide = constraints.maxWidth * .38;
                    leftWidth = leftWidth.clamp(210, maxSide);
                    rightWidth = rightWidth.clamp(230, maxSide);
                    timelineHeight = timelineHeight.clamp(
                      150,
                      constraints.maxHeight * .55,
                    );
                    return Column(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              if (showLyrics) ...[
                                SizedBox(
                                  width: leftWidth,
                                  child: _LyricsPanel(project: editor.project),
                                ),
                                _VerticalHandle(
                                  onDrag: (delta) =>
                                      setState(() => leftWidth += delta),
                                ),
                              ],
                              Expanded(
                                child: _PreviewPanel(
                                  project: editor.project,
                                  playback: playback,
                                ),
                              ),
                              if (showInspector) ...[
                                _VerticalHandle(
                                  onDrag: (delta) =>
                                      setState(() => rightWidth -= delta),
                                ),
                                SizedBox(
                                  width: rightWidth,
                                  child: _InspectorPanel(
                                    project: editor.project,
                                  ),
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
                              durationUs:
                                  editor.project?.audio?.durationUs ??
                                  playback.durationUs,
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
            title: const Text('Unsaved changes'),
            content: const Text(
              'Project hiện tại có thay đổi chưa lưu. Bạn có muốn bỏ các thay đổi này?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Discard'),
              ),
            ],
          ),
        ) ??
        false;
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

class _MenuStrip extends StatelessWidget {
  const _MenuStrip({
    required this.editor,
    required this.modifier,
    required this.onNew,
    required this.onOpen,
    required this.onSave,
    required this.onSaveAs,
    required this.onImportAudio,
    required this.onToggleLyrics,
    required this.onToggleInspector,
    required this.onToggleTimeline,
  });

  final EditorController editor;
  final String modifier;
  final VoidCallback onNew;
  final VoidCallback onOpen;
  final VoidCallback onSave;
  final VoidCallback onSaveAs;
  final VoidCallback onImportAudio;
  final VoidCallback onToggleLyrics;
  final VoidCallback onToggleInspector;
  final VoidCallback onToggleTimeline;

  @override
  Widget build(BuildContext context) {
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
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
    return Container(
      height: 34,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: MenuBar(
        style: const MenuStyle(
          padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 4)),
          backgroundColor: WidgetStatePropertyAll(Colors.transparent),
          elevation: WidgetStatePropertyAll(0),
        ),
        children: [
          SubmenuButton(
            menuChildren: [
              item('New Project', onNew, '${modifier}N'),
              item('Open Project…', onOpen, '${modifier}O'),
              const Divider(),
              item('Save', editor.hasProject ? onSave : null, '${modifier}S'),
              item(
                'Save As…',
                editor.hasProject ? onSaveAs : null,
                '$modifier⇧S',
              ),
              const Divider(),
              item('Import Audio…', editor.hasProject ? onImportAudio : null),
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
            ],
            child: const Text('Edit'),
          ),
          SubmenuButton(
            menuChildren: [
              item('Lyrics Panel', onToggleLyrics),
              item('Inspector Panel', onToggleInspector),
              item('Timeline', onToggleTimeline),
            ],
            child: const Text('View'),
          ),
        ],
      ),
    );
  }
}

class _Toolbar extends ConsumerWidget {
  const _Toolbar({
    required this.editor,
    required this.playback,
    required this.onNew,
    required this.onOpen,
    required this.onSave,
    required this.onImportAudio,
  });

  final EditorController editor;
  final PlaybackClock playback;
  final VoidCallback onNew;
  final VoidCallback onOpen;
  final VoidCallback onSave;
  final VoidCallback onImportAudio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.subtitles_rounded, color: Color(0xFFFFB300)),
          const SizedBox(width: 8),
          Text(
            editor.windowTitle,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 16),
          _ToolButton(
            icon: Icons.note_add_outlined,
            tooltip: 'New Project',
            onPressed: onNew,
          ),
          _ToolButton(
            icon: Icons.folder_open,
            tooltip: 'Open Project',
            onPressed: onOpen,
          ),
          _ToolButton(
            icon: Icons.save_outlined,
            tooltip: 'Save Project',
            onPressed: editor.hasProject ? onSave : null,
          ),
          const VerticalDivider(indent: 8, endIndent: 8),
          _ToolButton(
            icon: Icons.audio_file_outlined,
            tooltip: 'Import Audio',
            onPressed: editor.hasProject ? onImportAudio : null,
          ),
          const VerticalDivider(indent: 8, endIndent: 8),
          _ToolButton(
            icon: Icons.undo,
            tooltip: 'Undo',
            onPressed: editor.history.canUndo ? editor.undo : null,
          ),
          _ToolButton(
            icon: Icons.redo,
            tooltip: 'Redo',
            onPressed: editor.history.canRedo ? editor.redo : null,
          ),
          const Spacer(),
          if (editor.project?.audio != null)
            Text(
              p.basename(editor.project!.audio!.path),
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          const SizedBox(width: 8),
          _ToolButton(
            icon: dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
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

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    icon: Icon(icon, size: 19),
    tooltip: tooltip,
    onPressed: onPressed,
  );
}

class _LyricsPanel extends StatelessWidget {
  const _LyricsPanel({required this.project});
  final ProjectModel? project;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _PanelHeader(icon: Icons.lyrics_outlined, title: 'LYRICS'),
          Container(
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainer,
              border: Border.symmetric(
                horizontal: BorderSide(color: Theme.of(context).dividerColor),
              ),
            ),
            child: const Text(
              'No.     Actor      Text',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: project == null
                ? const _EmptyPanel(
                    icon: Icons.music_note,
                    text: 'Create or open a project',
                  )
                : project!.lyricLines.isEmpty
                ? const _EmptyPanel(
                    icon: Icons.format_align_left,
                    text: 'Lyrics editing arrives in Phase 3',
                  )
                : ListView.builder(
                    itemCount: project!.lyricLines.length,
                    itemBuilder: (context, index) {
                      final line = project!.lyricLines[index];
                      return ListTile(
                        dense: true,
                        leading: Text('${index + 1}'),
                        title: Text(line.text),
                        subtitle: Text(line.actorId),
                      );
                    },
                  ),
          ),
          if (project != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Wrap(
                spacing: 8,
                children: project!.actors
                    .map(
                      (actor) => Chip(
                        avatar: CircleAvatar(
                          backgroundColor: Color(actor.colorValue),
                        ),
                        label: Text(
                          actor.name,
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _PreviewPanel extends StatelessWidget {
  const _PreviewPanel({required this.project, required this.playback});
  final ProjectModel? project;
  final PlaybackClock playback;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      child: Column(
        children: [
          const _PanelHeader(
            icon: Icons.ondemand_video_outlined,
            title: 'PREVIEW',
          ),
          Expanded(
            child: Center(
              child: project == null
                  ? _WelcomeCard()
                  : AspectRatio(
                      aspectRatio: project!.canvasWidth / project!.canvasHeight,
                      child: Container(
                        margin: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                          boxShadow: const [
                            BoxShadow(color: Colors.black54, blurRadius: 18),
                          ],
                        ),
                        child: CustomPaint(
                          painter: const _CheckerboardPainter(),
                          child: Stack(
                            children: [
                              const Center(
                                child: Icon(
                                  Icons.subtitles_rounded,
                                  size: 64,
                                  color: Colors.white24,
                                ),
                              ),
                              Positioned(
                                left: 12,
                                top: 10,
                                child: Text(
                                  '${project!.canvasWidth} × ${project!.canvasHeight}  •  ${project!.fps} fps',
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                              if (project!.audio != null)
                                Positioned(
                                  left: 16,
                                  right: 16,
                                  bottom: 16,
                                  child: Text(
                                    project!.audio!.metadata['title'] ??
                                        p.basename(project!.audio!.path),
                                    textAlign: TextAlign.center,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black,
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
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
            'Desktop karaoke subtitle editor',
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

class _InspectorPanel extends StatelessWidget {
  const _InspectorPanel({required this.project});
  final ProjectModel? project;

  @override
  Widget build(BuildContext context) {
    final audio = project?.audio;
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Column(
        children: [
          const _PanelHeader(icon: Icons.tune, title: 'INSPECTOR'),
          Expanded(
            child: project == null
                ? const _EmptyPanel(icon: Icons.tune, text: 'Nothing selected')
                : ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      _SectionTitle('PROJECT'),
                      _Property(label: 'Name', value: project!.name),
                      _Property(
                        label: 'Canvas',
                        value:
                            '${project!.canvasWidth} × ${project!.canvasHeight}',
                      ),
                      _Property(
                        label: 'Frame rate',
                        value: '${project!.fps} fps',
                      ),
                      _Property(
                        label: 'Autosave',
                        value: '${project!.settings.autosaveSeconds} seconds',
                      ),
                      const SizedBox(height: 16),
                      _SectionTitle('AUDIO'),
                      if (audio == null)
                        const Text(
                          'No audio imported',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        )
                      else ...[
                        _Property(label: 'File', value: p.basename(audio.path)),
                        _Property(
                          label: 'Duration',
                          value: _formatTime(
                            Duration(microseconds: audio.durationUs),
                          ),
                        ),
                        _Property(
                          label: 'Codec',
                          value: audio.codec ?? 'Unknown',
                        ),
                        _Property(
                          label: 'Sample rate',
                          value: audio.sampleRate == null
                              ? 'Unknown'
                              : '${audio.sampleRate} Hz',
                        ),
                        _Property(
                          label: 'Channels',
                          value: '${audio.channels ?? 'Unknown'}',
                        ),
                        if (audio.metadata['artist'] != null)
                          _Property(
                            label: 'Artist',
                            value: audio.metadata['artist']!,
                          ),
                      ],
                    ],
                  ),
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
      height: 43,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: ListenableBuilder(
        listenable: playback,
        builder: (context, _) {
          final enabled = editor.project?.audio != null;
          return Row(
            children: [
              IconButton(
                onPressed: enabled ? () => playback.seek(Duration.zero) : null,
                icon: const Icon(Icons.skip_previous, size: 19),
                tooltip: 'Timeline start',
              ),
              IconButton(
                onPressed: enabled ? playback.stop : null,
                icon: const Icon(Icons.stop, size: 19),
                tooltip: 'Stop',
              ),
              IconButton.filled(
                onPressed: enabled ? playback.toggle : null,
                icon: Icon(
                  playback.isPlaying ? Icons.pause : Icons.play_arrow,
                  size: 20,
                ),
                tooltip: 'Play / Pause (Space)',
              ),
              IconButton(
                onPressed: enabled
                    ? () => playback.seek(playback.duration)
                    : null,
                icon: const Icon(Icons.skip_next, size: 19),
                tooltip: 'Timeline end',
              ),
              const SizedBox(width: 14),
              Text(
                '${_formatTime(playback.position)}  /  ${_formatTime(playback.duration)}',
                style: const TextStyle(
                  fontFeatures: [FontFeature.tabularFigures()],
                  fontSize: 12,
                ),
              ),
              if (playback.isBuffering) ...[
                const SizedBox(width: 10),
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
              const Spacer(),
              PopupMenuButton<double>(
                tooltip: 'Playback speed',
                onSelected: playback.setSpeed,
                itemBuilder: (context) => [.25, .5, .75, 1.0, 1.25, 1.5, 2.0]
                    .map(
                      (speed) =>
                          PopupMenuItem(value: speed, child: Text('$speed×')),
                    )
                    .toList(),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    '${playback.speed}×',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ),
              const SizedBox(width: 14),
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
    padding: const EdgeInsets.symmetric(horizontal: 9),
    alignment: Alignment.centerLeft,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainer,
      border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
    ),
    child: Row(
      children: [
        Icon(icon, size: 15),
        const SizedBox(width: 7),
        Text(
          title,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: .8,
          ),
        ),
      ],
    ),
  );
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            size: 30,
          ),
          const SizedBox(height: 10),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        ],
      ),
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        color: Theme.of(context).colorScheme.primary,
      ),
    ),
  );
}

class _Property extends StatelessWidget {
  const _Property({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 86,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
            style: const TextStyle(fontSize: 11),
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
      child: Container(width: 5, color: Theme.of(context).dividerColor),
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
      child: Container(height: 5, color: Theme.of(context).dividerColor),
    ),
  );
}

class _CheckerboardPainter extends CustomPainter {
  const _CheckerboardPainter();
  @override
  void paint(Canvas canvas, Size size) {
    const cell = 14.0;
    final light = Paint()..color = const Color(0xFF34373D);
    final dark = Paint()..color = const Color(0xFF26292E);
    for (var y = 0.0; y < size.height; y += cell) {
      for (var x = 0.0; x < size.width; x += cell) {
        canvas.drawRect(
          Rect.fromLTWH(x, y, cell, cell),
          ((x ~/ cell + y ~/ cell).isEven ? light : dark),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, controller.text),
        child: const Text('Create'),
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
