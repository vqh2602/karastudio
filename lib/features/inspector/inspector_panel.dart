import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/presets/style_preset_manager.dart';
import '../../models/project_model.dart';
import '../editor/editor_controller.dart';
import 'color_picker_dialog.dart';

class InspectorPanel extends ConsumerStatefulWidget {
  const InspectorPanel({super.key});

  @override
  ConsumerState<InspectorPanel> createState() => _InspectorPanelState();
}

class _InspectorPanelState extends ConsumerState<InspectorPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final StylePresetManager _presetManager = const StylePresetManager();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editor = ref.watch(editorControllerProvider);
    final project = editor.project;

    if (project == null) {
      return ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        child: const Column(
          children: [
            _PanelHeader(icon: Icons.tune, title: 'INSPECTOR'),
            Expanded(
              child: Center(
                child: Text(
                  'Chưa có project',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final activeStyle = project.styles.firstWhere(
      (s) => s.id == 'classic',
      orElse: () => project.styles.isNotEmpty
          ? project.styles.first
          : const SubtitleStyle(id: 'classic', name: 'Classic'),
    );

    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Column(
        children: [
          const _PanelHeader(icon: Icons.tune, title: 'INSPECTOR'),
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelPadding: const EdgeInsets.symmetric(horizontal: 10),
            labelStyle: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
            tabs: const [
              Tab(text: 'STYLE'),
              Tab(text: 'TYPOGRAPHY'),
              Tab(text: 'LAYOUT/FX'),
              Tab(text: 'ACTORS'),
              Tab(text: 'PROJECT'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _StyleTab(
                  editor: editor,
                  project: project,
                  style: activeStyle,
                  presetManager: _presetManager,
                ),
                _TypographyTab(
                  editor: editor,
                  project: project,
                  style: activeStyle,
                ),
                _LayoutEffectsTab(
                  editor: editor,
                  project: project,
                  style: activeStyle,
                ),
                _ActorsTab(editor: editor, project: project),
                _ProjectSettingsTab(editor: editor, project: project),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StyleTab extends StatelessWidget {
  const _StyleTab({
    required this.editor,
    required this.project,
    required this.style,
    required this.presetManager,
  });

  final EditorController editor;
  final ProjectModel project;
  final SubtitleStyle style;
  final StylePresetManager presetManager;

  void _updateStyle(SubtitleStyle newStyle) {
    final updated = project.styles
        .map((s) => s.id == style.id ? newStyle : s)
        .toList();
    editor.updateProjectStyles(updated, description: 'Đổi style phụ đề');
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const _SectionTitle('PRESETS'),
        DropdownButton<String>(
          isExpanded: true,
          value:
              presetManager.getBuiltInPresets().any((p) => p.name == style.name)
              ? style.name
              : null,
          hint: const Text(
            'Chọn mẫu style có sẵn…',
            style: TextStyle(fontSize: 12),
          ),
          items: presetManager.getBuiltInPresets().map((p) {
            return DropdownMenuItem(
              value: p.name,
              child: Text(p.name, style: const TextStyle(fontSize: 12)),
            );
          }).toList(),
          onChanged: (name) {
            if (name != null) {
              final chosen = presetManager.getBuiltInPresets().firstWhere(
                (p) => p.name == name,
              );
              // A preset supplies visual properties, but the target style must
              // keep its identity so lyric/actor references and saved projects
              // continue to point at it.
              _updateStyle(chosen.copyWith(id: style.id));
            }
          },
        ),

        const SizedBox(height: 12),
        const _SectionTitle('MÀU SẮC CHỮ (INACTIVE & ACTIVE)'),
        _ColorRow(
          label: 'Inactive Fill',
          colorValue: style.inactiveColorValue,
          onColorChanged: (c) =>
              _updateStyle(style.copyWith(inactiveColorValue: c)),
        ),
        _ColorRow(
          label: 'Active Karaoke Fill',
          colorValue: style.activeColorValue,
          onColorChanged: (c) =>
              _updateStyle(style.copyWith(activeColorValue: c)),
        ),
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: const Text('Active Gradient', style: TextStyle(fontSize: 11)),
          value: style.activeUseGradient,
          onChanged: (val) =>
              _updateStyle(style.copyWith(activeUseGradient: val)),
        ),
        if (style.activeUseGradient)
          _ColorRow(
            label: 'Active Gradient Color 2',
            colorValue: style.activeSecondaryColorValue,
            onColorChanged: (c) =>
                _updateStyle(style.copyWith(activeSecondaryColorValue: c)),
          ),

        const SizedBox(height: 12),
        const _SectionTitle('VIỀN CHỮ (OUTLINE)'),
        _SliderRow(
          label: 'Outline Width',
          value: style.outlineWidth,
          min: 0,
          max: 12,
          onChanged: (v) => _updateStyle(style.copyWith(outlineWidth: v)),
        ),
        _ColorRow(
          label: 'Outline Color',
          colorValue: style.outlineColorValue,
          onColorChanged: (c) =>
              _updateStyle(style.copyWith(outlineColorValue: c)),
        ),

        const SizedBox(height: 12),
        const _SectionTitle('BÓNG ĐỔ (SHADOW) & GLOW'),
        _SliderRow(
          label: 'Shadow Blur',
          value: style.shadowBlur,
          min: 0,
          max: 20,
          onChanged: (v) => _updateStyle(style.copyWith(shadowBlur: v)),
        ),
        _ColorRow(
          label: 'Shadow Color',
          colorValue: style.shadowColorValue,
          onColorChanged: (c) =>
              _updateStyle(style.copyWith(shadowColorValue: c)),
        ),
        _SliderRow(
          label: 'Neon Glow Radius',
          value: style.glowRadius,
          min: 0,
          max: 24,
          onChanged: (v) => _updateStyle(style.copyWith(glowRadius: v)),
        ),
        if (style.glowRadius > 0)
          _ColorRow(
            label: 'Glow Color',
            colorValue: style.glowColorValue == 0
                ? style.activeColorValue
                : style.glowColorValue,
            onColorChanged: (c) =>
                _updateStyle(style.copyWith(glowColorValue: c)),
          ),
      ],
    );
  }
}

class _TypographyTab extends StatelessWidget {
  const _TypographyTab({
    required this.editor,
    required this.project,
    required this.style,
  });

  final EditorController editor;
  final ProjectModel project;
  final SubtitleStyle style;

  void _updateStyle(SubtitleStyle newStyle) {
    final updated = project.styles
        .map((s) => s.id == style.id ? newStyle : s)
        .toList();
    editor.updateProjectStyles(updated, description: 'Đổi typography');
  }

  @override
  Widget build(BuildContext context) {
    final fontFamilies = <String>{
      style.fontFamily,
      'Arial',
      'Helvetica',
      'Avenir Next',
      'Times New Roman',
      'Georgia',
      'Courier New',
    }.toList();
    const weightNames = <int, String>{
      100: 'Thin',
      200: 'ExtraLight',
      300: 'Light',
      400: 'Regular',
      500: 'Medium',
      600: 'SemiBold',
      700: 'Bold',
      800: 'ExtraBold',
      900: 'Black',
    };

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const _SectionTitle('FONT & KÍCH THƯỚC'),
        DropdownButton<String>(
          isExpanded: true,
          value: style.fontFamily,
          items: fontFamilies
              .map(
                (f) => DropdownMenuItem(
                  value: f,
                  child: Text(f, style: TextStyle(fontFamily: f, fontSize: 12)),
                ),
              )
              .toList(),
          onChanged: (f) {
            if (f != null) _updateStyle(style.copyWith(fontFamily: f));
          },
        ),
        _SliderRow(
          label: 'Font Size',
          value: style.fontSize,
          min: 24,
          max: 120,
          onChanged: (v) => _updateStyle(style.copyWith(fontSize: v)),
        ),

        const SizedBox(height: 12),
        const _SectionTitle('ĐỘ DÀY & KIỂU CHỮ'),
        Row(
          children: [
            Expanded(
              child: DropdownButton<int>(
                isExpanded: true,
                value: style.fontWeight,
                items: weightNames.entries
                    .map(
                      (entry) => DropdownMenuItem(
                        value: entry.key,
                        child: Text(
                          '${entry.value} (${entry.key})',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (w) {
                  if (w != null) _updateStyle(style.copyWith(fontWeight: w));
                },
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(
                Icons.format_italic,
                color: style.isItalic ? const Color(0xFFFFB300) : null,
              ),
              onPressed: () =>
                  _updateStyle(style.copyWith(isItalic: !style.isItalic)),
              tooltip: 'Italic',
            ),
            IconButton(
              icon: Icon(
                Icons.format_underlined,
                color: style.isUnderline ? const Color(0xFFFFB300) : null,
              ),
              onPressed: () =>
                  _updateStyle(style.copyWith(isUnderline: !style.isUnderline)),
              tooltip: 'Underline',
            ),
          ],
        ),

        const SizedBox(height: 12),
        const _SectionTitle('CĂN LỀ (ALIGNMENT) & KHOẢNG CÁCH'),
        SegmentedButton<SubtitleAlignment>(
          segments: const [
            ButtonSegment(
              value: SubtitleAlignment.left,
              icon: Icon(Icons.format_align_left, size: 14),
            ),
            ButtonSegment(
              value: SubtitleAlignment.center,
              icon: Icon(Icons.format_align_center, size: 14),
            ),
            ButtonSegment(
              value: SubtitleAlignment.right,
              icon: Icon(Icons.format_align_right, size: 14),
            ),
          ],
          selected: {style.alignment},
          onSelectionChanged: (set) =>
              _updateStyle(style.copyWith(alignment: set.first)),
        ),
        const SizedBox(height: 8),
        _SliderRow(
          label: 'Letter Spacing',
          value: style.letterSpacing,
          min: -2,
          max: 10,
          onChanged: (v) => _updateStyle(style.copyWith(letterSpacing: v)),
        ),
        _SliderRow(
          label: 'Line Height',
          value: style.lineHeight,
          min: 0.8,
          max: 2.5,
          onChanged: (v) => _updateStyle(style.copyWith(lineHeight: v)),
        ),
      ],
    );
  }
}

class _LayoutEffectsTab extends StatelessWidget {
  const _LayoutEffectsTab({
    required this.editor,
    required this.project,
    required this.style,
  });

  final EditorController editor;
  final ProjectModel project;
  final SubtitleStyle style;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const _SectionTitle('CHẾ ĐỘ HIỂN THỊ HÀNG KARAOKE'),
        DropdownButton<LayoutMode>(
          isExpanded: true,
          value: project.settings.layoutMode,
          items: const [
            DropdownMenuItem(
              value: LayoutMode.alternatingTwoRows,
              child: Text(
                '2 Hàng So Le (Alternating Rows)',
                style: TextStyle(fontSize: 11),
              ),
            ),
            DropdownMenuItem(
              value: LayoutMode.singleRow,
              child: Text(
                '1 Hàng Đơn (Single Row)',
                style: TextStyle(fontSize: 11),
              ),
            ),
            DropdownMenuItem(
              value: LayoutMode.multiRow,
              child: Text(
                'Nhiều Hàng (Multi-Row)',
                style: TextStyle(fontSize: 11),
              ),
            ),
          ],
          onChanged: (m) {
            if (m != null) {
              editor.updateProjectSettings(
                project.settings.copyWith(layoutMode: m),
              );
            }
          },
        ),
        if (project.settings.layoutMode == LayoutMode.alternatingTwoRows) ...[
          _SliderRow(
            label: 'Hàng A — Ngang (X: Trái ↔ Phải)',
            value: project.settings.rowAPositionX * 100,
            min: 0,
            max: 100,
            onChanged: (v) => editor.updateProjectSettings(
              project.settings.copyWith(rowAPositionX: v / 100),
            ),
          ),
          _SliderRow(
            label: 'Hàng A — Dọc (Y: Trên ↔ Dưới)',
            value: project.settings.rowAPositionY * 100,
            min: 5,
            max: 95,
            onChanged: (v) => editor.updateProjectSettings(
              project.settings.copyWith(rowAPositionY: v / 100),
            ),
          ),
          const SizedBox(height: 6),
          _SliderRow(
            label: 'Hàng B — Ngang (X: Trái ↔ Phải)',
            value: project.settings.rowBPositionX * 100,
            min: 0,
            max: 100,
            onChanged: (v) => editor.updateProjectSettings(
              project.settings.copyWith(rowBPositionX: v / 100),
            ),
          ),
          _SliderRow(
            label: 'Hàng B — Dọc (Y: Trên ↔ Dưới)',
            value: project.settings.rowBPositionY * 100,
            min: 5,
            max: 95,
            onChanged: (v) => editor.updateProjectSettings(
              project.settings.copyWith(rowBPositionY: v / 100),
            ),
          ),
        ] else if (project.settings.layoutMode == LayoutMode.singleRow) ...[
          _SliderRow(
            label: 'Hàng Đơn — Ngang (X)',
            value: project.settings.singleRowPositionX * 100,
            min: 0,
            max: 100,
            onChanged: (v) => editor.updateProjectSettings(
              project.settings.copyWith(singleRowPositionX: v / 100),
            ),
          ),
          _SliderRow(
            label: 'Hàng Đơn — Dọc (Y)',
            value: project.settings.singleRowPositionY * 100,
            min: 5,
            max: 95,
            onChanged: (v) => editor.updateProjectSettings(
              project.settings.copyWith(singleRowPositionY: v / 100),
            ),
          ),
        ],

        const SizedBox(height: 12),
        const _SectionTitle('BIẾN ĐỔI (TRANSFORM & ROTATION)'),
        _SliderRow(
          label: 'Góc Xoay Z (Độ)',
          value: style.rotationZ,
          min: -45,
          max: 45,
          onChanged: (v) {
            final updated = project.styles
                .map((s) => s.id == style.id ? s.copyWith(rotationZ: v) : s)
                .toList();
            editor.updateProjectStyles(updated);
          },
        ),
        _SliderRow(
          label: 'Nghiêng Skew X',
          value: style.skewX,
          min: -30,
          max: 30,
          onChanged: (v) {
            final updated = project.styles
                .map((s) => s.id == style.id ? s.copyWith(skewX: v) : s)
                .toList();
            editor.updateProjectStyles(updated);
          },
        ),

        const SizedBox(height: 12),
        const _SectionTitle('HƯỚNG CHẠY MÀU (SWEEP DIRECTION)'),
        DropdownButton<SweepDirection>(
          isExpanded: true,
          value: style.sweepDirection,
          items: const [
            DropdownMenuItem(
              value: SweepDirection.leftToRight,
              child: Text(
                'Trái qua Phải (Left → Right)',
                style: TextStyle(fontSize: 11),
              ),
            ),
            DropdownMenuItem(
              value: SweepDirection.rightToLeft,
              child: Text(
                'Phải qua Trái (Right → Left)',
                style: TextStyle(fontSize: 11),
              ),
            ),
            DropdownMenuItem(
              value: SweepDirection.centerOut,
              child: Text(
                'Từ Giữa ra Ngoài (Center → Out)',
                style: TextStyle(fontSize: 11),
              ),
            ),
            DropdownMenuItem(
              value: SweepDirection.bottomToTop,
              child: Text(
                'Dưới lên Trên (Bottom → Top)',
                style: TextStyle(fontSize: 11),
              ),
            ),
          ],
          onChanged: (dir) {
            if (dir != null) {
              final updated = project.styles
                  .map(
                    (s) =>
                        s.id == style.id ? s.copyWith(sweepDirection: dir) : s,
                  )
                  .toList();
              editor.updateProjectStyles(updated);
            }
          },
        ),
      ],
    );
  }
}

class _ActorsTab extends StatelessWidget {
  const _ActorsTab({required this.editor, required this.project});

  final EditorController editor;
  final ProjectModel project;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const _SectionTitle('DANH SÁCH ACTORS / CA SĨ'),
        ...project.actors.map((actor) {
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 6,
                        backgroundColor: Color(actor.colorValue),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        actor.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'ID: ${actor.id}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _ColorRow(
                    label: 'Màu Actor',
                    colorValue: actor.colorValue,
                    onColorChanged: (c) {
                      final updated = project.actors
                          .map(
                            (a) => a.id == actor.id
                                ? a.copyWith(colorValue: c)
                                : a,
                          )
                          .toList();
                      editor.updateProjectActors(updated);
                    },
                  ),
                  Row(
                    children: [
                      const Text(
                        'Tín hiệu Lead:',
                        style: TextStyle(fontSize: 11),
                      ),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: actor.indicatorId,
                        items: const [
                          DropdownMenuItem(
                            value: 'dots',
                            child: Text(
                              'Dots Countdown',
                              style: TextStyle(fontSize: 11),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'circles',
                            child: Text(
                              'Pulse Circles',
                              style: TextStyle(fontSize: 11),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'lamp',
                            child: Text('Lamp', style: TextStyle(fontSize: 11)),
                          ),
                          DropdownMenuItem(
                            value: 'countdown',
                            child: Text(
                              '3..2..1 Numbers',
                              style: TextStyle(fontSize: 11),
                            ),
                          ),
                        ],
                        onChanged: (ind) {
                          if (ind != null) {
                            final updated = project.actors
                                .map(
                                  (a) => a.id == actor.id
                                      ? a.copyWith(indicatorId: ind)
                                      : a,
                                )
                                .toList();
                            editor.updateProjectActors(updated);
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _ProjectSettingsTab extends StatelessWidget {
  const _ProjectSettingsTab({required this.editor, required this.project});

  final EditorController editor;
  final ProjectModel project;

  @override
  Widget build(BuildContext context) {
    final hasVideo = project.video != null;
    final hasImage = project.backgroundImage != null;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const _SectionTitle('LỚP NỀN (BACKGROUND VIDEO / IMAGE)'),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    hasVideo
                        ? Icons.video_file
                        : (hasImage ? Icons.image : Icons.layers_clear),
                    size: 18,
                    color: (hasVideo || hasImage)
                        ? const Color(0xFFFFB300)
                        : Colors.white38,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      hasVideo
                          ? 'Video: ${project.video!.path.split(RegExp(r'[\\/]')).last}'
                          : (hasImage
                                ? 'Ảnh: ${project.backgroundImage!.path.split(RegExp(r'[\\/]')).last}'
                                : 'Chưa đặt video hoặc ảnh nền'),
                      style: const TextStyle(fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.video_library_outlined, size: 14),
                    label: const Text(
                      'Load Video Nền (Mute)',
                      style: TextStyle(fontSize: 10),
                    ),
                    onPressed: editor.importBackgroundVideo,
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.image_outlined, size: 14),
                    label: const Text(
                      'Load Ảnh Nền',
                      style: TextStyle(fontSize: 10),
                    ),
                    onPressed: editor.importBackgroundImage,
                  ),
                  if (hasVideo || hasImage)
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.delete_outline, size: 14),
                      label: const Text(
                        'Xóa Nền',
                        style: TextStyle(fontSize: 10),
                      ),
                      onPressed: editor.removeBackground,
                    ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),
        const _SectionTitle('THIẾT LẬP DỰ ÁN'),
        Text(
          'Canvas: ${project.canvasWidth} × ${project.canvasHeight}  •  ${project.fps} fps',
          style: const TextStyle(fontSize: 12),
        ),
        const SizedBox(height: 12),
        _SliderRow(
          label: 'Tự động lưu (Giây)',
          value: project.settings.autosaveSeconds.toDouble(),
          min: 0,
          max: 120,
          onChanged: (v) => editor.updateProjectSettings(
            project.settings.copyWith(autosaveSeconds: v.round()),
          ),
        ),
        _SliderRow(
          label: 'Lead Time Báo Câu (ms)',
          value: project.settings.leadTimeUs / 1000,
          min: 500,
          max: 5000,
          onChanged: (v) => editor.updateProjectSettings(
            project.settings.copyWith(leadTimeUs: (v * 1000).round()),
          ),
        ),
        _SliderRow(
          label: 'Bù độ trễ Timing (ms)',
          value: project.settings.inputTimingOffsetMs.toDouble(),
          min: -200,
          max: 200,
          onChanged: (v) => editor.updateProjectSettings(
            project.settings.copyWith(inputTimingOffsetMs: v.round()),
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6, top: 4),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        color: Color(0xFFFFB300),
        letterSpacing: 0.5,
      ),
    ),
  );
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 11)),
              Text(
                value.toStringAsFixed(1),
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _ColorRow extends StatelessWidget {
  const _ColorRow({
    required this.label,
    required this.colorValue,
    required this.onColorChanged,
  });

  final String label;
  final int colorValue;
  final ValueChanged<int> onColorChanged;

  @override
  Widget build(BuildContext context) {
    const colors = [
      0xFFFFFFFF,
      0xFFFFC107,
      0xFFFF5722,
      0xFFE040FB,
      0xFF00E5FF,
      0xFF42A5F5,
      0xFF00E676,
      0xFF000000,
      0x99000000,
    ];

    Future<void> openPicker() async {
      final selected = await showKaraColorPicker(
        context,
        initialColor: colorValue,
        suggestions: colors,
      );
      if (selected != null) onColorChanged(selected);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label, style: const TextStyle(fontSize: 11)),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: openPicker,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: Color(colorValue),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white38),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '#${colorValue.toRadixString(16).padLeft(8, '0').toUpperCase()}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.colorize, size: 15),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final color in colors)
                Tooltip(
                  message:
                      '#${color.toRadixString(16).padLeft(8, '0').toUpperCase()}',
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => onColorChanged(color),
                    child: Container(
                      width: 19,
                      height: 19,
                      decoration: BoxDecoration(
                        color: Color(color),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: color == colorValue
                              ? Theme.of(context).colorScheme.primary
                              : Colors.white30,
                          width: color == colorValue ? 2 : 1,
                        ),
                      ),
                    ),
                  ),
                ),
              Tooltip(
                message: 'Mở bảng chọn màu',
                child: InkWell(
                  borderRadius: BorderRadius.circular(5),
                  onTap: openPicker,
                  child: Container(
                    width: 23,
                    height: 19,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: Colors.white30),
                    ),
                    child: const Icon(Icons.add, size: 14),
                  ),
                ),
              ),
            ],
          ),
        ],
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
