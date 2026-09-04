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
  bool isBypassed = false;

  @override
  void initState() {
    super.initState();
    final fx = widget.editor.project!.settings.audioEffects;
    semitones = fx.semitones;
    reverb = fx.reverb;
    tuning = fx.tuningHz;
    speed = fx.speed;
    widget.editor.playback.addListener(_onPlaybackChanged);
  }

  @override
  void dispose() {
    widget.editor.playback.removeListener(_onPlaybackChanged);
    super.dispose();
  }

  void _onPlaybackChanged() {
    if (mounted) setState(() {});
  }

  Future<void> apply({
    bool startPlayback = false,
    bool closeDialog = false,
  }) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final fx = AudioEffects(
        semitones: isBypassed ? 0 : semitones,
        reverb: isBypassed ? 0 : reverb,
        tuningHz: isBypassed ? 440 : tuning,
        speed: speed,
      );
      await widget.editor.applyAudioEffects(
        fx,
        startPlayback: startPlayback,
      );
      if (closeDialog && mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
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
              tooltip: 'Đặt lại $label',
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
  Widget build(BuildContext context) {
    final playback = widget.editor.playback;
    final isPlaying = playback.isPlaying;

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.equalizer, size: 22),
          SizedBox(width: 8),
          Text('Hiệu ứng âm thanh'),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Áp dụng cho nghe thử và xuất video. File gốc được giữ nguyên.',
                style: TextStyle(fontSize: 12, color: Colors.white70),
              ),
              const SizedBox(height: 12),

              // Audition & Playback Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: isPlaying ? 'Tạm dừng' : 'Phát thử',
                      onPressed: busy
                          ? null
                          : () {
                              if (isPlaying) {
                                playback.pause();
                              } else {
                                apply(startPlayback: true);
                              }
                            },
                      icon: Icon(
                        isPlaying
                            ? Icons.pause_circle_filled
                            : Icons.play_circle_filled,
                        size: 32,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isPlaying ? 'Đang phát thử' : 'Đã tạm dừng',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${_formatDuration(playback.position)} / ${_formatDuration(playback.duration)}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontFamily: 'monospace',
                              color: Colors.white60,
                            ),
                          ),
                        ],
                      ),
                    ),
                    FilterChip(
                      label: Text(isBypassed ? 'Bypass (Gốc)' : 'Hiệu ứng: Bật'),
                      selected: !isBypassed,
                      onSelected: busy
                          ? null
                          : (val) {
                              setState(() => isBypassed = !val);
                              apply(startPlayback: isPlaying);
                            },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),
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

              if (busy) ...[
                const SizedBox(height: 8),
                const Row(
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Đang xử lý âm thanh với FFmpeg…',
                      style: TextStyle(fontSize: 12, color: Colors.orangeAccent),
                    ),
                  ],
                ),
              ],

              if (error != null) ...[
                const SizedBox(height: 8),
                Text(
                  error!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: const Text('Đóng'),
        ),
        OutlinedButton(
          onPressed: busy
              ? null
              : () => apply(startPlayback: false, closeDialog: true),
          child: const Text('Áp dụng & Đóng'),
        ),
        FilledButton(
          onPressed: busy ? null : () => apply(startPlayback: true),
          child: Text(busy ? 'Đang xử lý…' : 'Áp dụng / nghe thử'),
        ),
      ],
    );
  }
}
