import 'package:flutter/material.dart';
import '../../models/audio_effects.dart';
import 'editor_controller.dart';

Future<void> showAudioEffectsDialog(
  BuildContext context,
  EditorController editor,
) => showDialog<void>(
  context: context,
  builder: (_) => _AudioEffectsDialog(editor: editor),
);

class _AudioEffectsDialog extends StatefulWidget {
  const _AudioEffectsDialog({required this.editor});
  final EditorController editor;
  @override
  State<_AudioEffectsDialog> createState() => _AudioEffectsDialogState();
}

class _AudioEffectsDialogState extends State<_AudioEffectsDialog> {
  late int semitones;
  late double reverb;
  late double tuning;
  late double speed;
  bool busy = false;
  String? error;

  @override
  void initState() {
    super.initState();
    final fx = widget.editor.project!.settings.audioEffects;
    semitones = fx.semitones;
    reverb = fx.reverb;
    tuning = fx.tuningHz;
    speed = widget.editor.playback.speed;
  }

  Future<void> apply() async {
    setState(() {
      busy = true;
      error = null;
    });
    final previous = widget.editor.project!.settings.audioEffects;
    try {
      final fx = AudioEffects(
        semitones: semitones,
        reverb: reverb,
        tuningHz: tuning,
        speed: speed,
      );
      await widget.editor.playback.applyAudioEffects(fx);
      await widget.editor.playback.setSpeed(speed);
      widget.editor.updateProjectSettings(
        widget.editor.project!.settings.copyWith(audioEffects: fx),
        description: 'Hiệu ứng nghe thử',
      );
    } catch (e) {
      try {
        await widget.editor.playback.applyAudioEffects(previous);
      } catch (_) {
        // Keep the original error visible even if restoring also fails.
      }
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget control(
    String label,
    double value,
    double min,
    double max,
    int divisions,
    String display,
    ValueChanged<double> change,
    double reset,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label)),
            Text(display, style: const TextStyle(fontWeight: FontWeight.bold)),
            IconButton(
              tooltip: 'Reset $label',
              onPressed: busy ? null : () => setState(() => change(reset)),
              icon: const Icon(Icons.restart_alt, size: 18),
            ),
          ],
        ),
        Row(
          children: [
            IconButton(
              onPressed: busy
                  ? null
                  : () => setState(
                      () => change(
                        (value - (max - min) / divisions).clamp(min, max),
                      ),
                    ),
              icon: const Icon(Icons.remove),
            ),
            Expanded(
              child: Slider(
                value: value.clamp(min, max),
                min: min,
                max: max,
                divisions: divisions,
                onChanged: busy ? null : (v) => setState(() => change(v)),
              ),
            ),
            IconButton(
              onPressed: busy
                  ? null
                  : () => setState(
                      () => change(
                        (value + (max - min) / divisions).clamp(min, max),
                      ),
                    ),
              icon: const Icon(Icons.add),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Hiệu ứng âm thanh'),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Áp dụng cho nghe thử và xuất video. File gốc được giữ nguyên.',
              style: TextStyle(fontSize: 12),
            ),
            control(
              'Đổi tông',
              semitones.toDouble(),
              -12,
              12,
              24,
              '$semitones nửa cung',
              (v) => semitones = v.round(),
              0,
            ),
            control(
              'Vang (echo nhiều lớp)',
              reverb,
              0,
              100,
              100,
              '${reverb.round()}%',
              (v) => reverb = v,
              0,
            ),
            control(
              'Chuẩn cao độ A4',
              tuning,
              415.3,
              466.2,
              509,
              '${tuning.toStringAsFixed(1)} Hz',
              (v) => tuning = v,
              440,
            ),
            control(
              'Tốc độ',
              speed,
              0.25,
              4,
              75,
              '${speed.toStringAsFixed(2)}×',
              (v) => speed = v,
              1,
            ),
            if (error != null)
              Text(error!, style: const TextStyle(color: Colors.redAccent)),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        child: const Text('Đóng'),
      ),
      FilledButton(
        onPressed: busy ? null : apply,
        child: Text(busy ? 'Đang áp dụng…' : 'Áp dụng / nghe thử'),
      ),
    ],
  );
}
