import 'package:flutter/material.dart';
import '../editor/editor_controller.dart';

enum ShiftScope { all, fromCurrent, single }

Future<void> showShiftTimingDialog(
  BuildContext context,
  EditorController editor, {
  int? currentLineIndex,
}) async {
  final project = editor.project;
  if (project == null || project.lyricLines.isEmpty) return;

  final lineIdx = currentLineIndex?.clamp(0, project.lyricLines.length - 1) ?? 0;

  var selectedScope = ShiftScope.all;
  final customController = TextEditingController(text: '-80');

  await showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDlgState) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.tune, color: Color(0xFFFFB300)),
            SizedBox(width: 8),
            Text('Dịch chuyển Timing (Shift Timing)'),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Dịch chuyển thời gian bắt đầu và kết thúc của các từ/câu để khắc phục tình trạng bị chệch nhịp, trễ hoặc sớm hơn nhạc.',
                style: TextStyle(fontSize: 12, color: Colors.white70),
              ),
              const SizedBox(height: 16),

              // Phạm vi áp dụng
              const Text('Phạm vi áp dụng:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              SegmentedButton<ShiftScope>(
                segments: [
                  const ButtonSegment(
                    value: ShiftScope.all,
                    label: Text('Toàn bài', style: TextStyle(fontSize: 11)),
                  ),
                  ButtonSegment(
                    value: ShiftScope.fromCurrent,
                    label: Text('Từ câu ${lineIdx + 1}', style: const TextStyle(fontSize: 11)),
                  ),
                  ButtonSegment(
                    value: ShiftScope.single,
                    label: Text('Câu ${lineIdx + 1}', style: const TextStyle(fontSize: 11)),
                  ),
                ],
                selected: {selectedScope},
                onSelectionChanged: (val) => setDlgState(() => selectedScope = val.first),
              ),

              const SizedBox(height: 16),

              // Quick Preset Chips
              const Text('Mức dịch chuyển nhanh:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ActionChip(
                    label: const Text('-120 ms (Sớm)', style: TextStyle(fontSize: 11)),
                    onPressed: () => setDlgState(() => customController.text = '-120'),
                  ),
                  ActionChip(
                    backgroundColor: customController.text == '-80' ? const Color(0xFFFFB300).withValues(alpha: 0.25) : null,
                    side: customController.text == '-80' ? const BorderSide(color: Color(0xFFFFB300)) : null,
                    label: const Text('-80 ms (Chuẩn)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    onPressed: () => setDlgState(() => customController.text = '-80'),
                  ),
                  ActionChip(
                    label: const Text('-50 ms', style: TextStyle(fontSize: 11)),
                    onPressed: () => setDlgState(() => customController.text = '-50'),
                  ),
                  ActionChip(
                    label: const Text('+50 ms (Trễ)', style: TextStyle(fontSize: 11)),
                    onPressed: () => setDlgState(() => customController.text = '50'),
                  ),
                  ActionChip(
                    label: const Text('+80 ms', style: TextStyle(fontSize: 11)),
                    onPressed: () => setDlgState(() => customController.text = '80'),
                  ),
                  ActionChip(
                    label: const Text('+100 ms', style: TextStyle(fontSize: 11)),
                    onPressed: () => setDlgState(() => customController.text = '100'),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Custom Input
              TextField(
                controller: customController,
                keyboardType: const TextInputType.numberWithOptions(signed: true),
                decoration: const InputDecoration(
                  labelText: 'Thời gian dịch chuyển (mili-giây)',
                  helperText: 'Số âm (-) để chạy sớm hơn, số dương (+) để chạy chậm hơn',
                  suffixText: 'ms',
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.check, size: 16),
            label: const Text('Áp Dụng'),
            onPressed: () {
              final ms = int.tryParse(customController.text.trim());
              if (ms != null && ms != 0) {
                int? fromIdx;
                int? singleIdx;
                if (selectedScope == ShiftScope.fromCurrent) fromIdx = lineIdx;
                if (selectedScope == ShiftScope.single) singleIdx = lineIdx;

                editor.shiftTiming(
                  deltaMs: ms,
                  fromLineIndex: fromIdx,
                  singleLineIndex: singleIdx,
                );
              }
              Navigator.pop(context);
            },
          ),
        ],
      ),
    ),
  );
}
