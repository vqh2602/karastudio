import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<int?> showKaraColorPicker(
  BuildContext context, {
  required int initialColor,
  required List<int> suggestions,
}) {
  return showDialog<int>(
    context: context,
    builder: (context) => _KaraColorPickerDialog(
      initialColor: initialColor,
      suggestions: suggestions,
    ),
  );
}

class _KaraColorPickerDialog extends StatefulWidget {
  const _KaraColorPickerDialog({
    required this.initialColor,
    required this.suggestions,
  });

  final int initialColor;
  final List<int> suggestions;

  @override
  State<_KaraColorPickerDialog> createState() => _KaraColorPickerDialogState();
}

class _KaraColorPickerDialogState extends State<_KaraColorPickerDialog> {
  late HSVColor _color;
  late final TextEditingController _hexController;
  String? _hexError;

  Color get _selectedColor => _color.toColor();

  @override
  void initState() {
    super.initState();
    _color = HSVColor.fromColor(Color(widget.initialColor));
    _hexController = TextEditingController(text: _hex(_selectedColor));
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  void _setColor(HSVColor value) {
    setState(() {
      _color = value;
      _hexError = null;
      _hexController.value = TextEditingValue(
        text: _hex(_selectedColor),
        selection: const TextSelection.collapsed(offset: 9),
      );
    });
  }

  void _applyHex(String input) {
    var value = input.trim().replaceFirst('#', '');
    if (value.length == 6) value = 'FF$value';
    final parsed = value.length == 8 ? int.tryParse(value, radix: 16) : null;
    if (parsed == null) {
      setState(() => _hexError = 'Nhập #RRGGBB hoặc #AARRGGBB');
      return;
    }
    _setColor(HSVColor.fromColor(Color(parsed)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Chọn màu'),
      content: SizedBox(
        width: 370,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SaturationValuePicker(
                color: _color,
                onChanged: (saturation, value) => _setColor(
                  _color.withSaturation(saturation).withValue(value),
                ),
              ),
              const SizedBox(height: 14),
              const Text('Hue', style: TextStyle(fontSize: 11)),
              _HueSlider(
                hue: _color.hue,
                onChanged: (hue) => _setColor(_color.withHue(hue)),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const SizedBox(
                    width: 58,
                    child: Text('Opacity', style: TextStyle(fontSize: 11)),
                  ),
                  Expanded(
                    child: Slider(
                      value: _color.alpha,
                      onChanged: (alpha) => _setColor(_color.withAlpha(alpha)),
                    ),
                  ),
                  SizedBox(
                    width: 38,
                    child: Text(
                      '${(_color.alpha * 100).round()}%',
                      textAlign: TextAlign.end,
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _selectedColor,
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: theme.colorScheme.outline),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _hexController,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[#0-9a-fA-F]'),
                        ),
                        LengthLimitingTextInputFormatter(9),
                      ],
                      decoration: InputDecoration(
                        labelText: 'HEX',
                        hintText: '#FFFFFFFF',
                        errorText: _hexError,
                        isDense: true,
                      ),
                      onSubmitted: _applyHex,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Áp dụng mã HEX',
                    onPressed: () => _applyHex(_hexController.text),
                    icon: const Icon(Icons.check, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('MÀU GỢI Ý', style: TextStyle(fontSize: 11)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final value in widget.suggestions)
                    Tooltip(
                      message: _hex(Color(value)),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () =>
                            _setColor(HSVColor.fromColor(Color(value))),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: Color(value),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: value == _selectedColor.toARGB32()
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.outline,
                              width: value == _selectedColor.toARGB32() ? 3 : 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _selectedColor.toARGB32()),
          child: const Text('Chọn màu'),
        ),
      ],
    );
  }
}

class _SaturationValuePicker extends StatelessWidget {
  const _SaturationValuePicker({required this.color, required this.onChanged});

  final HSVColor color;
  final void Function(double saturation, double value) onChanged;

  void _handle(Offset position, Size size) {
    final saturation = (position.dx / size.width).clamp(0.0, 1.0);
    final value = (1 - (position.dy / size.height)).clamp(0.0, 1.0);
    onChanged(saturation, value);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, 180);
        return GestureDetector(
          onTapDown: (details) => _handle(details.localPosition, size),
          onPanUpdate: (details) => _handle(details.localPosition, size),
          child: CustomPaint(
            size: size,
            painter: _SaturationValuePainter(color),
          ),
        );
      },
    );
  }
}

class _SaturationValuePainter extends CustomPainter {
  const _SaturationValuePainter(this.color);

  final HSVColor color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final radius = Radius.circular(8);
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(rect, radius));
    canvas.drawRect(
      rect,
      Paint()..color = HSVColor.fromAHSV(1, color.hue, 1, 1).toColor(),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          colors: [Colors.white, Colors.transparent],
        ).createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black],
        ).createShader(rect),
    );
    canvas.restore();

    final center = Offset(
      color.saturation * size.width,
      (1 - color.value) * size.height,
    );
    canvas.drawCircle(center, 7, Paint()..color = Colors.white);
    canvas.drawCircle(
      center,
      6,
      Paint()
        ..color = color.toColor()
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      center,
      7,
      Paint()
        ..color = Colors.black54
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _SaturationValuePainter oldDelegate) =>
      oldDelegate.color != color;
}

class _HueSlider extends StatelessWidget {
  const _HueSlider({required this.hue, required this.onChanged});

  final double hue;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            height: 12,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFFF0000),
                  Color(0xFFFFFF00),
                  Color(0xFF00FF00),
                  Color(0xFF00FFFF),
                  Color(0xFF0000FF),
                  Color(0xFFFF00FF),
                  Color(0xFFFF0000),
                ],
              ),
            ),
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: Colors.transparent,
              inactiveTrackColor: Colors.transparent,
              trackHeight: 12,
              thumbColor: HSVColor.fromAHSV(1, hue, 1, 1).toColor(),
              thumbShape: const RoundSliderThumbShape(
                enabledThumbRadius: 7,
                elevation: 2,
              ),
            ),
            child: Slider(value: hue, min: 0, max: 360, onChanged: onChanged),
          ),
        ],
      ),
    );
  }
}

String _hex(Color color) =>
    '#${color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';
