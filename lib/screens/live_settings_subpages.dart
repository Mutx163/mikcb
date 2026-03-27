import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../models/timetable_settings.dart';
import '../providers/timetable_provider.dart';
import '../services/miui_live_activities_service.dart';

const String _expandedIconDir = 'miui_expanded_icons';
const List<String> _labelColors = [
  '#FFFFFF',
  '#E2E8F0',
  '#BFDBFE',
  '#A7F3D0',
  '#FDE68A',
  '#F9A8D4',
];

String _formatLiveTimeCorrection(int seconds) {
  if (seconds == 0) {
    return '不矫正';
  }
  if (seconds > 0) {
    return '整体延后 $seconds 秒';
  }
  return '整体提前 ${seconds.abs()} 秒';
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.child,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
            ],
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class LiveReminderTimingScreen extends StatefulWidget {
  const LiveReminderTimingScreen({super.key});

  @override
  State<LiveReminderTimingScreen> createState() =>
      _LiveReminderTimingScreenState();
}

class _LiveReminderTimingScreenState extends State<LiveReminderTimingScreen> {
  static const List<int> _beforeClassMinutesOptions = [1, 5, 10, 15, 20, 30];
  static const List<int> _endSecondsOptions = [15, 30, 45, 60, 90];
  static const double _timeCorrectionMin = -30;
  static const double _timeCorrectionMax = 30;

  late TimetableSettings _draft;
  Timer? _autoSaveTimer;
  Future<void> _saveQueue = Future<void>.value();

  @override
  void initState() {
    super.initState();
    _draft = context.read<TimetableProvider>().settings;
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('提醒时段')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionCard(
            title: '提醒开关',
            subtitle: '不同提醒时段可以自由组合；这些开关互不替代。',
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('上课前提醒'),
                  subtitle:
                      Text('在课程开始前 ${_draft.liveShowBeforeClassMinutes} 分钟弹出'),
                  value: _draft.liveEnableBeforeClass,
                  onChanged: (value) => _updateDraft(
                    _draft.copyWith(liveEnableBeforeClass: value),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('课中 / 下课提醒'),
                  subtitle: const Text('只影响上课后到下课前的展示'),
                  value: _draft.liveEnableDuringClass ||
                      _draft.liveEnableBeforeEnd,
                  onChanged: (value) => _updateDraft(
                    _draft.copyWith(
                      liveEnableDuringClass: value,
                      liveEnableBeforeEnd: value,
                    ),
                  ),
                ),
                if (_draft.liveEnableDuringClass || _draft.liveEnableBeforeEnd)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('提醒启动时机'),
                    subtitle: Text(
                      _draft.liveClassReminderStartMinutes == 0
                          ? '从上课开始就展示，并在距下课 ${_draft.liveEndSecondsCountdownThreshold} 秒切到秒级倒数'
                          : _draft.liveEnableDuringClass &&
                                  _draft.liveShowDuringClassNotification &&
                                  !_draft.livePromoteDuringClass
                              ? '上课后先保留普通课中通知，在距下课前 ${_draft.liveClassReminderStartMinutes} 分钟切到下课提醒，并在最后 ${_draft.liveEndSecondsCountdownThreshold} 秒切到秒级倒数'
                              : _draft.liveEnableDuringClass &&
                                      _draft.liveShowDuringClassNotification
                                  ? '在距下课前 ${_draft.liveClassReminderStartMinutes} 分钟切到重点提醒，并在最后 ${_draft.liveEndSecondsCountdownThreshold} 秒切到秒级倒数'
                              : '在距下课前 ${_draft.liveClassReminderStartMinutes} 分钟开始展示，并在最后 ${_draft.liveEndSecondsCountdownThreshold} 秒切到秒级倒数',
                    ),
                    trailing: DropdownButton<int>(
                      value: _draft.liveClassReminderStartMinutes,
                      items: const [
                        DropdownMenuItem(value: 0, child: Text('一上课就展示')),
                        DropdownMenuItem(value: 5, child: Text('提前 5 分钟展示')),
                        DropdownMenuItem(value: 10, child: Text('提前 10 分钟展示')),
                        DropdownMenuItem(value: 15, child: Text('提前 15 分钟展示')),
                        DropdownMenuItem(value: 20, child: Text('提前 20 分钟展示')),
                        DropdownMenuItem(value: 30, child: Text('提前 30 分钟展示')),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        _updateDraft(
                          _draft.copyWith(
                            liveClassReminderStartMinutes: value,
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: '展示方式',
            subtitle: '对已启用的提醒时段生效。',
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('课中状态栏通知'),
                  subtitle: Text(
                    _draft.liveClassReminderStartMinutes == 0
                        ? '上课后保留状态栏通知'
                        : _draft.livePromoteDuringClass
                            ? '在下课提醒开始前保留普通通知文案'
                            : '上课后持续显示普通课中通知，到下课提醒前再切换',
                  ),
                  value: _draft.liveShowDuringClassNotification,
                  onChanged: (value) => _updateDraft(
                    _draft.copyWith(liveShowDuringClassNotification: value),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('支持展示超级岛/灵动岛'),
                  subtitle: const Text('关闭后不会再尝试触发系统超级岛'),
                  value: _draft.livePromoteDuringClass,
                  onChanged: (value) => _updateDraft(
                    _draft.copyWith(livePromoteDuringClass: value),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: '时间阈值',
            subtitle: '控制提醒开始时机和最后秒级倒计时。',
            child: Column(
              children: [
                DropdownButtonFormField<int>(
                  value: _draft.liveShowBeforeClassMinutes,
                  decoration: const InputDecoration(
                    labelText: '上课前弹出时间',
                    border: OutlineInputBorder(),
                  ),
                  items: _beforeClassMinutesOptions
                      .map((value) => DropdownMenuItem(
                          value: value, child: Text('$value 分钟')))
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    _updateDraft(
                      _draft.copyWith(liveShowBeforeClassMinutes: value),
                    );
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: _draft.liveEndSecondsCountdownThreshold,
                  decoration: const InputDecoration(
                    labelText: '下课前秒级提醒阈值',
                    border: OutlineInputBorder(),
                  ),
                  items: _endSecondsOptions
                      .map((value) => DropdownMenuItem(
                          value: value, child: Text('$value 秒')))
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    _updateDraft(
                      _draft.copyWith(
                        liveEndSecondsCountdownThreshold: value,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  '铃声时间矫正：${_formatLiveTimeCorrection(_draft.liveTimeCorrectionSeconds)}',
                ),
                Slider(
                  value: _draft.liveTimeCorrectionSeconds
                      .toDouble()
                      .clamp(_timeCorrectionMin, _timeCorrectionMax),
                  min: _timeCorrectionMin,
                  max: _timeCorrectionMax,
                  divisions: (_timeCorrectionMax - _timeCorrectionMin).toInt(),
                  label: _formatLiveTimeCorrection(
                    _draft.liveTimeCorrectionSeconds,
                  ),
                  onChanged: (value) => _updateDraft(
                    _draft.copyWith(
                      liveTimeCorrectionSeconds: value.round(),
                    ),
                    debounce: true,
                  ),
                ),
                Text(
                  '如果学校铃声比课表快几秒，就调成提前；如果铃声慢几秒，就调成延后。',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<LiveDuringClassTimeDisplayMode>(
                  value: _draft.liveDuringEndTimeDisplayMode,
                  decoration: const InputDecoration(
                    labelText: '课中 / 下课提醒时间样式',
                    helperText: '控制紧凑提醒里显示最近时间还是整段总时间',
                    border: OutlineInputBorder(),
                  ),
                  items: LiveDuringClassTimeDisplayMode.values
                      .map((value) => DropdownMenuItem(
                            value: value,
                            child: Text(value.label),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    _updateDraft(
                      _draft.copyWith(liveDuringEndTimeDisplayMode: value),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _updateDraft(TimetableSettings next, {bool debounce = false}) {
    setState(() => _draft = next);
    _autoSaveTimer?.cancel();
    if (debounce) {
      _autoSaveTimer = Timer(
        const Duration(milliseconds: 250),
        () => _enqueuePersist(next),
      );
      return;
    }
    _enqueuePersist(next);
  }

  void _enqueuePersist(TimetableSettings next) {
    _saveQueue = _saveQueue.catchError((_) {}).then((_) => _persistDraft(next));
  }

  Future<void> _persistDraft(TimetableSettings next) async {
    final provider = context.read<TimetableProvider>();
    final message = await provider.updateTimetableSettings(next);
    if (!mounted) return;
    if (message != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
      setState(() => _draft = provider.settings);
    }
  }
}

class LiveDisplaySettingsScreen extends StatefulWidget {
  final String title;
  final bool forDuringEnd;

  const LiveDisplaySettingsScreen({
    super.key,
    required this.title,
    required this.forDuringEnd,
  });

  @override
  State<LiveDisplaySettingsScreen> createState() =>
      _LiveDisplaySettingsScreenState();
}

class _LiveDisplaySettingsScreenState extends State<LiveDisplaySettingsScreen> {
  late TimetableSettings _draft;
  Timer? _autoSaveTimer;
  Future<void> _saveQueue = Future<void>.value();

  @override
  void initState() {
    super.initState();
    _draft = context.read<TimetableProvider>().settings;
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    super.dispose();
  }

  LiveDisplaySettings get _display => widget.forDuringEnd
      ? _draft.duringEndDisplaySettings
      : _draft.beforeClassDisplaySettings;

  bool get _followBeforeClass =>
      widget.forDuringEnd && _draft.liveDuringEndFollowBeforeClass;

  @override
  Widget build(BuildContext context) {
    final display = _display;
    final sectionCards = [
      _SectionCard(
        title: '显示内容',
        subtitle: '这组设置只影响当前阶段，不会改动另一组提醒显示。',
        child: Column(
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('显示课程名'),
              value: display.showCourseName,
              onChanged: (value) =>
                  _updateDisplay(display.copyWith(showCourseName: value)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('优先显示课程简称'),
              subtitle: const Text('建议简称控制在 3 个字以内'),
              value: display.useShortName,
              onChanged: (value) =>
                  _updateDisplay(display.copyWith(useShortName: value)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('显示地点'),
              value: display.showLocation,
              onChanged: (value) =>
                  _updateDisplay(display.copyWith(showLocation: value)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('显示倒计时'),
              value: display.showCountdown,
              onChanged: (value) =>
                  _updateDisplay(display.copyWith(showCountdown: value)),
            ),
            if (display.showCountdown) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<LiveCountdownTextStyle>(
                value: display.countdownTextStyle,
                decoration: const InputDecoration(
                  labelText: '倒计时格式',
                  helperText: '纯分钟样式按分钟刷新，带秒样式按秒刷新',
                  border: OutlineInputBorder(),
                ),
                items: LiveCountdownTextStyle.values
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(value.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  _updateDisplay(
                    display.copyWith(countdownTextStyle: value),
                  );
                },
              ),
            ],
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('显示阶段状态文案'),
              subtitle: const Text('关闭倒计时后，可继续显示“即将上课 / 上课中 / 下课提醒”'),
              value: display.showStageText,
              onChanged: (value) =>
                  _updateDisplay(display.copyWith(showStageText: value)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('隐藏前缀文案'),
              subtitle: const Text('例如隐藏“即将上课”这类前缀'),
              value: display.hidePrefixText,
              onChanged: (value) =>
                  _updateDisplay(display.copyWith(hidePrefixText: value)),
            ),
          ],
        ),
      ),
      if (!widget.forDuringEnd) ...[
        const SizedBox(height: 16),
        _SectionCard(
          title: '上课前快捷操作',
          subtitle: '只在上课前提醒的展开通知里显示。免打扰首次可能会跳到系统授权页。',
          child: DropdownButtonFormField<LiveBeforeClassQuickAction>(
            value: _draft.liveBeforeClassQuickAction,
            decoration: const InputDecoration(
              labelText: '快捷按钮',
              border: OutlineInputBorder(),
            ),
            items: LiveBeforeClassQuickAction.values
                .map(
                  (value) => DropdownMenuItem(
                    value: value,
                    child: Text(value.label),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              _updateDraft(
                _draft.copyWith(liveBeforeClassQuickAction: value),
              );
            },
          ),
        ),
      ],
      const SizedBox(height: 16),
      _SectionCard(
        title: '左侧图标与展开态',
        subtitle: '左侧文字图、展开态大图标和自定义图片都按当前阶段单独保存。',
        child: Column(
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('小米岛左侧文字图标'),
              subtitle: const Text('仅小米手机样式生效，会把课程名或地点生成到左侧图标位。'),
              value: display.enableMiuiIslandLabelImage,
              onChanged: (value) => _updateDisplay(
                display.copyWith(enableMiuiIslandLabelImage: value),
              ),
            ),
            if (display.enableMiuiIslandLabelImage) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<MiuiIslandLabelContent>(
                value: display.miuiIslandLabelContent,
                decoration: const InputDecoration(
                  labelText: '左侧文字内容',
                  border: OutlineInputBorder(),
                ),
                items: MiuiIslandLabelContent.values
                    .map((value) => DropdownMenuItem(
                          value: value,
                          child: Text(value.label),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  _updateDisplay(
                    display.copyWith(miuiIslandLabelContent: value),
                  );
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<MiuiIslandLabelStyle>(
                value: display.miuiIslandLabelStyle,
                decoration: const InputDecoration(
                  labelText: '左侧图标样式',
                  border: OutlineInputBorder(),
                ),
                items: MiuiIslandLabelStyle.values
                    .map((value) => DropdownMenuItem(
                          value: value,
                          child: Text(value.label),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  _updateDisplay(
                    display.copyWith(miuiIslandLabelStyle: value),
                  );
                },
              ),
              const SizedBox(height: 12),
              Text(
                  '左侧文字大小 ${display.miuiIslandLabelFontSize.toStringAsFixed(0)}'),
              Slider(
                value: display.miuiIslandLabelFontSize,
                min: 1,
                max: 32,
                divisions: 31,
                label: display.miuiIslandLabelFontSize.toStringAsFixed(0),
                onChanged: (value) => _updateDisplay(
                  display.copyWith(miuiIslandLabelFontSize: value),
                  debounce: true,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '左侧文字水平偏移 ${display.miuiIslandLabelOffsetX.toStringAsFixed(1)}',
              ),
              Slider(
                value: display.miuiIslandLabelOffsetX.clamp(-2.0, 2.0),
                min: -2,
                max: 2,
                divisions: 40,
                label: display.miuiIslandLabelOffsetX.toStringAsFixed(1),
                onChanged: (value) => _updateDisplay(
                  display.copyWith(miuiIslandLabelOffsetX: value),
                  debounce: true,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '左侧文字垂直偏移 ${display.miuiIslandLabelOffsetY.toStringAsFixed(1)}',
              ),
              Slider(
                value: display.miuiIslandLabelOffsetY.clamp(-2.0, 2.0),
                min: -2,
                max: 2,
                divisions: 40,
                label: display.miuiIslandLabelOffsetY.toStringAsFixed(1),
                onChanged: (value) => _updateDisplay(
                  display.copyWith(miuiIslandLabelOffsetY: value),
                  debounce: true,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<MiuiIslandLabelFontWeight>(
                value: display.miuiIslandLabelFontWeight,
                decoration: const InputDecoration(
                  labelText: '左侧文字粗细',
                  border: OutlineInputBorder(),
                ),
                items: MiuiIslandLabelFontWeight.values
                    .map((value) => DropdownMenuItem(
                          value: value,
                          child: Text(value.label),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  _updateDisplay(
                    display.copyWith(miuiIslandLabelFontWeight: value),
                  );
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<MiuiIslandLabelRenderQuality>(
                value: display.miuiIslandLabelRenderQuality,
                decoration: const InputDecoration(
                  labelText: '左侧文字清晰度',
                  border: OutlineInputBorder(),
                ),
                items: MiuiIslandLabelRenderQuality.values
                    .map((value) => DropdownMenuItem(
                          value: value,
                          child: Text(value.label),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  _updateDisplay(
                    display.copyWith(
                      miuiIslandLabelRenderQuality: value,
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _labelColors
                    .map(
                      (color) => _ColorDot(
                        colorHex: color,
                        selected: display.miuiIslandLabelFontColor == color,
                        onTap: () => _updateDisplay(
                          display.copyWith(
                            miuiIslandLabelFontColor: color,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 12),
            ],
            DropdownButtonFormField<MiuiIslandExpandedIconMode>(
              value: display.miuiIslandExpandedIconMode,
              decoration: const InputDecoration(
                labelText: '展开态大图标',
                border: OutlineInputBorder(),
              ),
              items: MiuiIslandExpandedIconMode.values
                  .map((value) => DropdownMenuItem(
                        value: value,
                        child: Text(value.label),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                _updateDisplay(
                  display.copyWith(
                    miuiIslandExpandedIconMode: value,
                    clearMiuiIslandExpandedIconPath:
                        value != MiuiIslandExpandedIconMode.customImage,
                  ),
                  clearExpandedIconPath:
                      value != MiuiIslandExpandedIconMode.customImage,
                );
              },
            ),
            if (display.miuiIslandExpandedIconMode ==
                MiuiIslandExpandedIconMode.customImage) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: () => _pickImage(display),
                      icon: const Icon(Icons.image_outlined),
                      label: Text(
                        display.miuiIslandExpandedIconPath == null
                            ? '选择图片'
                            : '更换图片',
                      ),
                    ),
                  ),
                  if (display.miuiIslandExpandedIconPath != null) ...[
                    const SizedBox(width: 12),
                    IconButton.outlined(
                      onPressed: () => _updateDisplay(
                        display.copyWith(
                          clearMiuiIslandExpandedIconPath: true,
                        ),
                        clearExpandedIconPath: true,
                      ),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ],
              ),
              if (display.miuiIslandExpandedIconPath != null) ...[
                const SizedBox(height: 12),
                _ImagePreview(path: display.miuiIslandExpandedIconPath!),
              ],
            ],
          ],
        ),
      ),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.forDuringEnd) ...[
            _SectionCard(
              title: '配置方式',
              subtitle: '打开后，课中和下课提醒会完全跟随上课前提醒显示，下面的独立设置暂时不可编辑。',
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('跟随上课前提醒设置'),
                value: _draft.liveDuringEndFollowBeforeClass,
                onChanged: (value) => _updateDraft(
                  _draft.copyWith(liveDuringEndFollowBeforeClass: value),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          IgnorePointer(
            ignoring: _followBeforeClass,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              opacity: _followBeforeClass ? 0.5 : 1,
              child: Column(children: sectionCards),
            ),
          ),
        ],
      ),
    );
  }

  void _updateDisplay(
    LiveDisplaySettings next, {
    bool debounce = false,
    bool clearExpandedIconPath = false,
  }) {
    final nextSettings = widget.forDuringEnd
        ? _draft.copyWithDuringEndDisplaySettings(
            next,
            clearExpandedIconPath: clearExpandedIconPath,
          )
        : _draft.copyWithBeforeClassDisplaySettings(
            next,
            clearExpandedIconPath: clearExpandedIconPath,
          );
    _updateDraft(nextSettings, debounce: debounce);
  }

  void _updateDraft(TimetableSettings next, {bool debounce = false}) {
    setState(() => _draft = next);
    _autoSaveTimer?.cancel();
    if (debounce) {
      _autoSaveTimer = Timer(
        const Duration(milliseconds: 250),
        () => _enqueuePersist(next),
      );
      return;
    }
    _enqueuePersist(next);
  }

  void _enqueuePersist(TimetableSettings next) {
    _saveQueue = _saveQueue.catchError((_) {}).then((_) => _persistDraft(next));
  }

  Future<void> _persistDraft(TimetableSettings next) async {
    final display = widget.forDuringEnd
        ? next.duringEndDisplaySettings
        : next.beforeClassDisplaySettings;
    if (display.miuiIslandExpandedIconMode ==
            MiuiIslandExpandedIconMode.customImage &&
        (display.miuiIslandExpandedIconPath == null ||
            display.miuiIslandExpandedIconPath!.isEmpty)) {
      return;
    }
    final provider = context.read<TimetableProvider>();
    final message = await provider.updateTimetableSettings(next);
    if (!mounted) return;
    if (message != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
      setState(() => _draft = provider.settings);
    }
  }

  Future<void> _pickImage(LiveDisplaySettings display) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (!mounted || result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final bytes = file.bytes ??
        (file.path == null ? null : await File(file.path!).readAsBytes());
    if (bytes == null || bytes.isEmpty) return;
    final ext = (file.extension?.isNotEmpty ?? false)
        ? file.extension!.toLowerCase()
        : 'png';
    final dir = await getApplicationDocumentsDirectory();
    final targetDir = Directory(
      '${dir.path}${Platform.pathSeparator}$_expandedIconDir',
    );
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }
    final modeSuffix = widget.forDuringEnd ? 'during_end' : 'before_class';
    final targetPath =
        '${targetDir.path}${Platform.pathSeparator}${modeSuffix}_expanded_icon.$ext';
    await File(targetPath).writeAsBytes(bytes, flush: true);
    if (!mounted) return;
    _updateDisplay(
      display.copyWith(
        miuiIslandExpandedIconMode: MiuiIslandExpandedIconMode.customImage,
        miuiIslandExpandedIconPath: targetPath,
      ),
    );
  }
}

class LiveKeepAliveSettingsScreen extends StatefulWidget {
  const LiveKeepAliveSettingsScreen({super.key});

  @override
  State<LiveKeepAliveSettingsScreen> createState() =>
      _LiveKeepAliveSettingsScreenState();
}

class _LiveKeepAliveSettingsScreenState
    extends State<LiveKeepAliveSettingsScreen> {
  final MiuiLiveActivitiesService _liveService = MiuiLiveActivitiesService();
  late TimetableSettings _draft;
  bool _enabled = false;

  @override
  void initState() {
    super.initState();
    _draft = context.read<TimetableProvider>().settings;
    unawaited(_refresh());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('后台保活')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionCard(
            title: '保活选项',
            subtitle: '用于提升超级岛和提醒在后台场景下的稳定性。',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('从最近任务中隐藏应用'),
                  subtitle: const Text('开启后应用会尽量不显示在最近任务列表中。'),
                  value: _draft.liveHideFromRecents,
                  onChanged: (value) async {
                    final messenger = ScaffoldMessenger.of(context);
                    final provider = context.read<TimetableProvider>();
                    final message = await provider.updateTimetableSettings(
                      _draft.copyWith(liveHideFromRecents: value),
                    );
                    if (!mounted) return;
                    if (message != null) {
                      messenger.showSnackBar(SnackBar(content: Text(message)));
                    }
                    setState(() => _draft = provider.settings);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    _enabled
                        ? Icons.check_circle_rounded
                        : Icons.accessibility_new_rounded,
                    color: _enabled
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  title: const Text('轻屿课表后台保活服务'),
                  subtitle: Text(
                    _enabled
                        ? '当前已开启。系统会保持后台保活辅助服务处于可用状态。'
                        : '当前未开启。可进入系统无障碍设置手动打开轻屿课表后台保活服务。',
                  ),
                  trailing: FilledButton.tonal(
                    onPressed: () => _openSettings(),
                    child: const Text('去开启'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openSettings() async {
    await _liveService.openAccessibilitySettings();
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    await _refresh();
  }

  Future<void> _refresh() async {
    final enabled = await _liveService.isKeepAliveAccessibilityEnabled();
    if (!mounted) return;
    setState(() {
      _enabled = enabled;
    });
  }
}

class _ColorDot extends StatelessWidget {
  final String colorHex;
  final bool selected;
  final VoidCallback onTap;

  const _ColorDot({
    required this.colorHex,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _parseColor(colorHex),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).dividerColor,
            width: selected ? 2.5 : 1,
          ),
        ),
      ),
    );
  }
}

class _ImagePreview extends StatelessWidget {
  final String path;

  const _ImagePreview({required this.path});

  @override
  Widget build(BuildContext context) {
    final file = File(path);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: file.existsSync()
                ? Image.file(file, width: 56, height: 56, fit: BoxFit.cover)
                : Container(
                    width: 56,
                    height: 56,
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    alignment: Alignment.center,
                    child: const Icon(Icons.broken_image_outlined),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              path,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

Color _parseColor(String hexColor) {
  final normalized = hexColor.replaceFirst('#', '');
  return Color(int.parse('FF$normalized', radix: 16));
}
