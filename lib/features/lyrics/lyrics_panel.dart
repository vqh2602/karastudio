import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

import '../../core/lyrics/lyrics_engine.dart';
import '../../models/project_model.dart';
import '../editor/editor_controller.dart';
import '../timing/shift_timing_dialog.dart';

class LyricsPanel extends ConsumerStatefulWidget {
  const LyricsPanel({super.key});

  @override
  ConsumerState<LyricsPanel> createState() => _LyricsPanelState();
}

class _LyricsPanelState extends ConsumerState<LyricsPanel> {
  final LyricsEngine _lyricsEngine = const LyricsEngine();
  final ScrollController _listController = ScrollController();
  String? _lastScrolledLineId;

  @override
  void dispose() {
    _listController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editor = ref.watch(editorControllerProvider);
    final project = editor.project;
    final selectedLineIndex = editor.selectedLyricLineIndex;
    _scheduleScrollToSelection(editor, selectedLineIndex);

    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          _PanelHeader(
            icon: Icons.lyrics_outlined,
            title: 'LYRICS',
            actions: [
              IconButton(
                icon: const Icon(Icons.add, size: 16),
                tooltip: 'Thêm dòng mới',
                onPressed: project == null ? null : () => _addNewLine(editor),
              ),
              IconButton(
                icon: const Icon(Icons.file_upload_outlined, size: 16),
                tooltip: 'Import Lời bài hát…',
                onPressed: project == null
                    ? null
                    : () => _showImportDialog(context, editor),
              ),
              IconButton(
                icon: const Icon(Icons.auto_fix_high, size: 16),
                tooltip: 'Chuẩn hóa lời bài hát',
                onPressed: project == null
                    ? null
                    : () => _normalizeLyrics(editor),
              ),
              IconButton(
                icon: const Icon(Icons.tune, size: 16),
                tooltip: 'Dịch chuyển timing… (Shift Timing)',
                onPressed: project == null || project.lyricLines.isEmpty
                    ? null
                    : () => showShiftTimingDialog(
                        context,
                        editor,
                        currentLineIndex: selectedLineIndex,
                      ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_sweep_outlined, size: 16),
                tooltip: 'Xóa toàn bộ lời bài hát…',
                onPressed: project == null || project.lyricLines.isEmpty
                    ? null
                    : () => _confirmClearAllLyrics(context, editor),
              ),
            ],
          ),

          // Column Headers
          Container(
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainer,
              border: Border.symmetric(
                horizontal: BorderSide(color: Theme.of(context).dividerColor),
              ),
            ),
            child: const Row(
              children: [
                SizedBox(
                  width: 32,
                  child: Text(
                    'No.',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
                SizedBox(
                  width: 64,
                  child: Text(
                    'Actor',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Lyrics Text',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
                SizedBox(
                  width: 68,
                  child: Text(
                    'Status',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          // Lines List
          Expanded(
            child: project == null
                ? const _EmptyView(
                    icon: Icons.music_note,
                    text: 'Tạo hoặc mở project',
                  )
                : project.lyricLines.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.format_align_left,
                          size: 32,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Chưa có lời bài hát',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.tonalIcon(
                          onPressed: () => _showImportDialog(context, editor),
                          icon: const Icon(
                            Icons.file_upload_outlined,
                            size: 16,
                          ),
                          label: const Text('Import Lời / Dán Clipboard'),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _listController,
                    itemCount: project.lyricLines.length,
                    itemBuilder: (context, index) {
                      final line = project.lyricLines[index];
                      final isSelected = selectedLineIndex == index;
                      final actor = project.actors.firstWhere(
                        (a) => a.id == line.actorId,
                        orElse: () => project.actors.first,
                      );

                      return InkWell(
                        onTap: () => editor.selectLyricLine(index),
                        onDoubleTap: () =>
                            _editLineText(context, editor, index),
                        onSecondaryTapUp: (details) => _showContextMenu(
                          details.globalPosition,
                          editor,
                          index,
                        ),
                        child: Container(
                          height: 36,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primaryContainer
                                      .withValues(alpha: 0.35)
                                : null,
                            border: Border(
                              bottom: BorderSide(
                                color: Theme.of(
                                  context,
                                ).dividerColor.withValues(alpha: 0.4),
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 32,
                                child: Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 64,
                                child: PopupMenuButton<String>(
                                  tooltip: 'Đổi Actor',
                                  initialValue: line.actorId,
                                  onSelected: (newActorId) => _changeLineActor(
                                    editor,
                                    index,
                                    newActorId,
                                  ),
                                  itemBuilder: (context) =>
                                      project.actors.map((a) {
                                        return PopupMenuItem(
                                          value: a.id,
                                          child: Row(
                                            children: [
                                              CircleAvatar(
                                                radius: 5,
                                                backgroundColor: Color(
                                                  a.colorValue,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                a.name,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Color(
                                        actor.colorValue,
                                      ).withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: Color(
                                          actor.colorValue,
                                        ).withValues(alpha: 0.5),
                                      ),
                                    ),
                                    child: Text(
                                      actor.name,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Color(actor.colorValue),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  line.text,
                                  style: const TextStyle(fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              SizedBox(
                                width: 68,
                                child: _LyricStatusBadge(
                                  status: _lyricsEngine.entryStatus(line),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Bottom Actor summary bar
          if (project != null && project.actors.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainer,
                border: Border(
                  top: BorderSide(color: Theme.of(context).dividerColor),
                ),
              ),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: project.actors.map((actor) {
                  return Chip(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                    avatar: CircleAvatar(
                      radius: 4,
                      backgroundColor: Color(actor.colorValue),
                    ),
                    label: Text(
                      actor.name,
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  void _scheduleScrollToSelection(EditorController editor, int? selectedIndex) {
    if (selectedIndex == null || editor.selectedLyricLineId == null) return;
    if (_lastScrolledLineId == editor.selectedLyricLineId) return;
    _lastScrolledLineId = editor.selectedLyricLineId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_listController.hasClients) return;
      final target = (selectedIndex * 36.0).clamp(
        0.0,
        _listController.position.maxScrollExtent,
      );
      _listController.animateTo(
        target,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _addNewLine(EditorController editor) {
    final project = editor.project;
    if (project == null) return;

    final newLine = LyricLine(
      id: newId('line'),
      text: 'Lời bài hát mới',
      actorId: project.actors.isNotEmpty ? project.actors.first.id : 'male',
      tokens: const [
        LyricToken(id: 'tok-1', text: 'Lời', index: 0),
        LyricToken(id: 'tok-2', text: 'bài', index: 1),
        LyricToken(id: 'tok-3', text: 'hát', index: 2),
        LyricToken(id: 'tok-4', text: 'mới', index: 3),
      ],
    );

    final updatedLines = List<LyricLine>.from(project.lyricLines)..add(newLine);
    editor.updateLyricLines(updatedLines, description: 'Thêm dòng lyric');
  }

  void _changeLineActor(EditorController editor, int index, String newActorId) {
    final project = editor.project;
    if (project == null || index < 0 || index >= project.lyricLines.length) {
      return;
    }

    final updated = List<LyricLine>.from(project.lyricLines);
    updated[index] = updated[index].copyWith(actorId: newActorId);
    editor.updateLyricLines(
      updated,
      description: 'Đổi actor dòng ${index + 1}',
    );
  }

  void _normalizeLyrics(EditorController editor) {
    final project = editor.project;
    if (project == null) return;

    final updated = project.lyricLines.map((line) {
      final clean = _lyricsEngine.normalizeText(line.text);
      final tokens = _lyricsEngine.tokenize(clean, mode: TokenizeMode.word);
      return line.copyWith(text: clean, tokens: tokens);
    }).toList();

    editor.updateLyricLines(updated, description: 'Chuẩn hóa lời bài hát');
  }

  Future<void> _confirmClearAllLyrics(
    BuildContext context,
    EditorController editor,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa toàn bộ lời bài hát?'),
        content: const Text(
          'Bạn có chắc chắn muốn xóa toàn bộ danh sách câu hát hiện tại không?\n(Thao tác này có thể hoàn tác bằng Ctrl+Z / Cmd+Z).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa tất cả'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      editor.updateLyricLines([], description: 'Xóa toàn bộ lời bài hát');
    }
  }

  Future<void> _editLineText(
    BuildContext context,
    EditorController editor,
    int index,
  ) async {
    final project = editor.project;
    if (project == null || index < 0 || index >= project.lyricLines.length) {
      return;
    }

    final currentLine = project.lyricLines[index];
    final controller = TextEditingController(text: currentLine.text);

    final newText = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Sửa câu ${index + 1}'),
        content: SizedBox(
          width: 400,
          child: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Lời câu hát'),
            onSubmitted: (val) => Navigator.pop(context, val),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );

    if (newText != null &&
        newText.trim().isNotEmpty &&
        newText != currentLine.text) {
      final clean = newText.trim();
      final updated = List<LyricLine>.from(project.lyricLines);
      updated[index] = _lyricsEngine
          .repairMissingTokens(currentLine.copyWith(text: clean))
          .line;
      editor.updateLyricLines(updated, description: 'Sửa lời câu ${index + 1}');
    }
  }

  void _showContextMenu(
    Offset globalPos,
    EditorController editor,
    int index,
  ) async {
    final project = editor.project;
    if (project == null) return;
    editor.selectLyricLine(index);
    final missing = _lyricsEngine.missingWords(project.lyricLines[index]);

    final value = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPos.dx,
        globalPos.dy,
        globalPos.dx,
        globalPos.dy,
      ),
      items: [
        if (missing.isNotEmpty)
          PopupMenuItem(
            value: 'repair_missing',
            child: Row(
              children: [
                const Icon(Icons.manage_search, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Tìm và thêm ${missing.length} từ còn thiếu'),
                ),
              ],
            ),
          ),
        if (missing.isNotEmpty) const PopupMenuDivider(),
        const PopupMenuItem(value: 'edit', child: Text('Sửa câu…')),
        const PopupMenuItem(value: 'duplicate', child: Text('Nhân đôi dòng')),
        const PopupMenuItem(
          value: 'shift_timing',
          child: Text('Dịch chuyển timing…'),
        ),
        const PopupMenuItem(
          value: 'clear_timing',
          child: Text('Xóa timing dòng này'),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'delete',
          child: Text('Xóa dòng', style: TextStyle(color: Colors.redAccent)),
        ),
      ],
    );

    if (!mounted) return;

    if (value == 'repair_missing') {
      final current = editor.project;
      if (current == null || index >= current.lyricLines.length) return;
      final repaired = _lyricsEngine.repairMissingTokens(
        current.lyricLines[index],
      );
      if (repaired.addedWords.isEmpty) return;
      final updated = List<LyricLine>.from(current.lyricLines);
      updated[index] = repaired.line;
      editor.updateLyricLines(
        updated,
        description: 'Thêm từ còn thiếu ở dòng ${index + 1}',
      );
      editor.selectLyricLine(index);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã thêm: ${repaired.addedWords.join(', ')}')),
      );
    } else if (value == 'edit') {
      _editLineText(context, editor, index);
    } else if (value == 'shift_timing') {
      showShiftTimingDialog(context, editor, currentLineIndex: index);
    } else if (value == 'duplicate') {
      final updated = List<LyricLine>.from(project.lyricLines);
      final line = updated[index];
      updated.insert(index + 1, line.copyWith(id: newId('line')));
      editor.updateLyricLines(
        updated,
        description: 'Nhân đôi dòng ${index + 1}',
      );
    } else if (value == 'clear_timing') {
      final updated = List<LyricLine>.from(project.lyricLines);
      updated[index] = updated[index].copyWith(clearTiming: true);
      editor.updateLyricLines(
        updated,
        description: 'Xóa timing dòng ${index + 1}',
      );
    } else if (value == 'delete') {
      final updated = List<LyricLine>.from(project.lyricLines)..removeAt(index);
      editor.updateLyricLines(updated, description: 'Xóa dòng ${index + 1}');
    }
  }

  Future<void> _showImportDialog(
    BuildContext context,
    EditorController editor,
  ) async {
    final textController = TextEditingController();
    var keepPrefix = false;

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: const Text('Import Lời Bài Hát'),
          content: SizedBox(
            width: 500,
            height: 380,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () async {
                        final result = await FilePicker.platform.pickFiles(
                          dialogTitle: 'Chọn file phụ đề / lời bài hát',
                          type: FileType.custom,
                          allowedExtensions: ['txt', 'lrc', 'srt', 'ass'],
                        );
                        final path = result?.files.single.path;
                        if (path != null) {
                          final content = await File(path).readAsString();
                          textController.text = content;
                        }
                      },
                      icon: const Icon(Icons.folder_open, size: 16),
                      label: const Text('Chọn file (TXT, LRC, SRT, ASS)'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final data = await Clipboard.getData(
                          Clipboard.kTextPlain,
                        );
                        if (data?.text != null) {
                          textController.text = data!.text!;
                        }
                      },
                      icon: const Icon(Icons.paste, size: 16),
                      label: const Text('Dán Clipboard'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: TextField(
                    controller: textController,
                    maxLines: null,
                    expands: true,
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                    decoration: const InputDecoration(
                      hintText:
                          'Dán lời bài hát ở đây...\n\nVí dụ:\nNam: Ngày mai em đi\nNữ: Em vẫn nhớ anh\nHợp: Ta còn bên nhau',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Giữ lại tiền tố Actor (Nam:, Nữ:) trong phụ đề hiển thị',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: keepPrefix,
                  onChanged: (val) =>
                      setDlgState(() => keepPrefix = val ?? false),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () {
                final content = textController.text.trim();
                if (content.isNotEmpty && editor.project != null) {
                  List<LyricLine> parsedLines;
                  final isSrt = content.contains('-->');
                  final isAss =
                      content.contains('[Events]') ||
                      content.contains('Dialogue:');
                  final isLrc = RegExp(r'\[\d{1,2}:\d{2}').hasMatch(content);

                  if (isSrt) {
                    parsedLines = _lyricsEngine.parseSrt(
                      content,
                      actors: editor.project!.actors,
                      keepActorPrefix: keepPrefix,
                    );
                  } else if (isAss) {
                    parsedLines = _lyricsEngine.parseAss(
                      content,
                      actors: editor.project!.actors,
                      keepActorPrefix: keepPrefix,
                    );
                  } else if (isLrc) {
                    parsedLines = _lyricsEngine.parseLrc(
                      content,
                      actors: editor.project!.actors,
                      keepActorPrefix: keepPrefix,
                    );
                  } else {
                    parsedLines = _lyricsEngine.parseTxt(
                      content,
                      actors: editor.project!.actors,
                      keepActorPrefix: keepPrefix,
                    );
                  }

                  editor.updateLyricLines(
                    parsedLines,
                    description: 'Import lời bài hát',
                  );
                }
                Navigator.pop(context);
              },
              child: const Text('Import'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LyricStatusBadge extends StatelessWidget {
  const _LyricStatusBadge({required this.status});
  final LyricEntryStatus status;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case LyricEntryStatus.added:
        bg = Colors.green.withValues(alpha: 0.2);
        fg = Colors.greenAccent;
        label = 'Đã thêm';
      case LyricEntryStatus.missingWords:
        bg = Colors.orange.withValues(alpha: 0.2);
        fg = Colors.orangeAccent;
        label = 'Thiếu từ';
      case LyricEntryStatus.notAdded:
        bg = Colors.grey.withValues(alpha: 0.2);
        fg = Colors.grey;
        label = 'Chưa thêm';
    }

    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 9, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({
    required this.icon,
    required this.title,
    this.actions = const [],
  });

  final IconData icon;
  final String title;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Container(
    height: 32,
    padding: const EdgeInsets.symmetric(horizontal: 8),
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
        const Spacer(),
        ...actions,
      ],
    ),
  );
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 32,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: 8),
        Text(
          text,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
      ],
    ),
  );
}
