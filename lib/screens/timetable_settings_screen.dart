import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/timetable_settings.dart';
import '../providers/timetable_provider.dart';

const List<_ThemePreset> _themePresets = [
  _ThemePreset('晴空蓝', '#2563EB'),
  _ThemePreset('青柠绿', '#16A34A'),
  _ThemePreset('琥珀橙', '#EA580C'),
  _ThemePreset('玫瑰粉', '#E11D48'),
  _ThemePreset('深海青', '#0F766E'),
  _ThemePreset('暮光紫', '#7C3AED'),
];

Color _colorFromHex(String hexColor) {
  final normalized = hexColor.replaceFirst('#', '');
  return Color(int.parse('FF$normalized', radix: 16));
}

class _ThemePreset {
  final String label;
  final String hex;

  const _ThemePreset(this.label, this.hex);
}

class TimetableSettingsScreen extends StatefulWidget {
  const TimetableSettingsScreen({super.key});

  @override
  State<TimetableSettingsScreen> createState() => _TimetableSettingsScreenState();
}

class _TimetableSettingsScreenState extends State<TimetableSettingsScreen> {
  late List<SectionTime> _sections;
  late double _sectionHeight;
  late double _compactFontSize;
  DateTime? _semesterStartDate;
  
  late bool _liveShowCourseName;
  late bool _liveShowLocation;
  late bool _liveShowCountdown;
  late bool _liveUseShortName;
  late bool _liveHidePrefixText;
  late String _themeSeedColor;

  @override
  void initState() {
    super.initState();
    final settings = context.read<TimetableProvider>().settings;
    _sections = settings.sections.map((item) => item.copyWith()).toList();
    _sectionHeight = settings.sectionHeight;
    _compactFontSize = settings.compactFontSize;
    _semesterStartDate = settings.semesterStartDate;
    _liveShowCourseName = settings.liveShowCourseName;
    _liveShowLocation = settings.liveShowLocation;
    _liveShowCountdown = settings.liveShowCountdown;
    _liveUseShortName = settings.liveUseShortName;
    _liveHidePrefixText = settings.liveHidePrefixText;
    _themeSeedColor = settings.themeSeedColor;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('课表设置'),
        actions: [
          TextButton(
            onPressed: _saveSettings,
            child: Text(
              '保存',
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSemesterSection(),
          const SizedBox(height: 16),
          _buildThemeSection(),
          const SizedBox(height: 16),
          _buildDisplaySection(),
          const SizedBox(height: 16),
          _buildSectionEditor(),
          const SizedBox(height: 16),
          ...List.generate(_sections.length, (index) {
            final section = _sections[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                title: Text('第 ${index + 1} 节'),
                subtitle: Text('${section.startTime} - ${section.endTime}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _editSectionTime(index),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSemesterSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '学期设置',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: const Text('开学日期'),
              subtitle: Text(
                _semesterStartDate == null ? '未设置' : _formatDate(_semesterStartDate!),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _pickSemesterStartDate,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _semesterStartDate == null
                        ? null
                        : () async {
                            await context
                                .read<TimetableProvider>()
                                .syncCurrentWeekWithSemesterStart();
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('已按开学日期同步当前周')),
                            );
                          },
                    child: const Text('同步当前周'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _semesterStartDate == null
                        ? null
                        : () {
                            setState(() {
                              _semesterStartDate = null;
                            });
                          },
                    child: const Text('清除日期'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '主题配色',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '切换应用主色，顶部栏、按钮和高亮态会一起更新。',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _themePresets.map((preset) {
                final isSelected = preset.hex == _themeSeedColor;
                final color = _colorFromHex(preset.hex);
                return InkWell(
                  onTap: () => setState(() => _themeSeedColor = preset.hex),
                  borderRadius: BorderRadius.circular(18),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? color.withValues(alpha: 0.14)
                          : Theme.of(context).colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isSelected
                            ? color
                            : Theme.of(context).colorScheme.outlineVariant,
                        width: isSelected ? 1.6 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          preset.label,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisplaySection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '显示设置',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text('行高: ${_sectionHeight.toStringAsFixed(0)}'),
            Slider(
              value: _sectionHeight,
              min: 52,
              max: 96,
              divisions: 11,
              label: _sectionHeight.toStringAsFixed(0),
              onChanged: (value) {
                setState(() {
                  _sectionHeight = value;
                });
              },
            ),
            const SizedBox(height: 8),
            Text('课表字体: ${_compactFontSize.toStringAsFixed(1)}'),
            Slider(
              value: _compactFontSize,
              min: 7,
              max: 12,
              divisions: 10,
              label: _compactFontSize.toStringAsFixed(1),
              onChanged: (value) {
                setState(() {
                  _compactFontSize = value;
                });
              },
            ),
            const Divider(),
            const Text(
              '超级岛显示自定义',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('显示课程名字'),
              value: _liveShowCourseName,
              onChanged: (val) => setState(() => _liveShowCourseName = val),
              contentPadding: EdgeInsets.zero,
            ),
            SwitchListTile(
              title: const Text('使用课程简称'),
              subtitle: const Text('关闭则显示全称'),
              value: _liveUseShortName,
              onChanged: _liveShowCourseName ? (val) => setState(() => _liveUseShortName = val) : null,
              contentPadding: EdgeInsets.zero,
            ),
            SwitchListTile(
              title: const Text('显示教室地点'),
              value: _liveShowLocation,
              onChanged: (val) => setState(() => _liveShowLocation = val),
              contentPadding: EdgeInsets.zero,
            ),
            SwitchListTile(
              title: const Text('显示上课/下课倒计时'),
              value: _liveShowCountdown,
              onChanged: (val) => setState(() => _liveShowCountdown = val),
              contentPadding: EdgeInsets.zero,
            ),
            SwitchListTile(
              title: const Text('隐藏"距上/下课"字眼'),
              subtitle: const Text('只显示纯粹的时间倒计'),
              value: _liveHidePrefixText,
              onChanged: (val) => setState(() => _liveHidePrefixText = val),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionEditor() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '节次设置',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '当前共 ${_sections.length} 节。你可以调整节次数量，并为每一节设置开始和结束时间。',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _showQuickGenerateDialog,
                icon: const Icon(Icons.flash_on),
                label: const Text('⚡ 快速生成时间表'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _sections.length > 1 ? _removeSection : null,
                    icon: const Icon(Icons.remove),
                    label: const Text('减少一节'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _addSection,
                    icon: const Icon(Icons.add),
                    label: const Text('增加一节'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _addSection() {
    final last = _sections.isNotEmpty
        ? _sections.last
        : const SectionTime(startTime: '08:00', endTime: '08:45');
    setState(() {
      _sections = [
        ..._sections,
        last.copyWith(),
      ];
    });
  }

  void _removeSection() {
    setState(() {
      _sections = _sections.sublist(0, _sections.length - 1);
    });
  }

  Future<void> _editSectionTime(int index) async {
    final section = _sections[index];
    final start = await _pickTime(section.startTime);
    if (start == null || !mounted) return;

    final end = await _pickTime(section.endTime);
    if (end == null || !mounted) return;

    setState(() {
      _sections[index] = section.copyWith(
        startTime: start,
        endTime: end,
      );
    });
  }

  Future<String?> _pickTime(String initialValue) async {
    final parts = initialValue.split(':');
    final initialTime = TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );

    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    if (picked == null) return null;

    final hour = picked.hour.toString().padLeft(2, '0');
    final minute = picked.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<void> _pickSemesterStartDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _semesterStartDate ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 2),
    );
    if (picked == null) return;

    setState(() {
      _semesterStartDate = DateTime(picked.year, picked.month, picked.day);
    });
  }

  Future<void> _saveSettings() async {
    for (var i = 0; i < _sections.length; i++) {
      final section = _sections[i];
      if (section.startTime.compareTo(section.endTime) >= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('第 ${i + 1} 节的结束时间必须晚于开始时间')),
        );
        return;
      }
    }

    final provider = context.read<TimetableProvider>();
    final error = await provider.updateTimetableSettings(
      TimetableSettings(
        sections: _sections,
        sectionHeight: _sectionHeight,
        compactFontSize: _compactFontSize,
        semesterStartDate: _semesterStartDate,
        liveShowCourseName: _liveShowCourseName,
        liveShowLocation: _liveShowLocation,
        liveShowCountdown: _liveShowCountdown,
        liveUseShortName: _liveUseShortName,
        liveHidePrefixText: _liveHidePrefixText,
        themeSeedColor: _themeSeedColor,
      ),
    );

    if (!mounted) return;

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
      return;
    }

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('课表设置已保存')),
    );
  }

  String _formatDate(DateTime date) {
    final year = date.year.toString();
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  void _showQuickGenerateDialog() {
    int classDuration = 45;
    int shortBreak = 10;
    TimeOfDay morningStart = const TimeOfDay(hour: 8, minute: 0);
    int morningCount = 4;
    TimeOfDay afternoonStart = const TimeOfDay(hour: 14, minute: 0);
    int afternoonCount = 4;
    TimeOfDay eveningStart = const TimeOfDay(hour: 19, minute: 0);
    int eveningCount = 2;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Widget buildTimePickerRow(String label, TimeOfDay time, ValueChanged<TimeOfDay> onChanged) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(label),
                    TextButton(
                      onPressed: () async {
                        final picked = await showTimePicker(context: context, initialTime: time);
                        if (picked != null) {
                          setDialogState(() => onChanged(picked));
                        }
                      },
                      child: Text(time.format(context), style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              );
            }

            Widget buildNumberRow(String label, int value, ValueChanged<int> onChanged, {int min = 0, int max = 12, int step = 1}) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(label),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: value > min ? () => setDialogState(() => onChanged(value - step)) : null,
                        ),
                        SizedBox(
                          width: 32,
                          child: Text('$value', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: value < max ? () => setDialogState(() => onChanged(value + step)) : null,
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }

            return AlertDialog(
              title: const Text('快捷生成时间表'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    buildNumberRow('每节课时长 (分钟)', classDuration, (v) => classDuration = v, min: 10, max: 120, step: 5),
                    buildNumberRow('课间休息 (分钟)', shortBreak, (v) => shortBreak = v, min: 0, max: 60, step: 5),
                    const Divider(),
                    buildTimePickerRow('上午首节时间', morningStart, (v) => morningStart = v),
                    buildNumberRow('上午节数', morningCount, (v) => morningCount = v, max: 6),
                    const Divider(),
                    buildTimePickerRow('下午首节时间', afternoonStart, (v) => afternoonStart = v),
                    buildNumberRow('下午节数', afternoonCount, (v) => afternoonCount = v, max: 6),
                    const Divider(),
                    buildTimePickerRow('晚上首节时间', eveningStart, (v) => eveningStart = v),
                    buildNumberRow('晚上节数', eveningCount, (v) => eveningCount = v, max: 4),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                ElevatedButton(
                  onPressed: () {
                    _generateSections(
                      classDuration,
                      shortBreak,
                      morningStart,
                      morningCount,
                      afternoonStart,
                      afternoonCount,
                      eveningStart,
                      eveningCount,
                    );
                    Navigator.pop(context);
                  },
                  child: const Text('生成应用'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _generateSections(
    int classDuration,
    int shortBreak,
    TimeOfDay morningStart,
    int morningCount,
    TimeOfDay afternoonStart,
    int afternoonCount,
    TimeOfDay eveningStart,
    int eveningCount,
  ) {
    List<SectionTime> newSections = [];

    void generateForPeriod(TimeOfDay start, int count) {
      TimeOfDay current = start;
      for (int i = 0; i < count; i++) {
        final startTimeStr = '${current.hour.toString().padLeft(2, '0')}:${current.minute.toString().padLeft(2, '0')}';
        
        int endMinutes = current.hour * 60 + current.minute + classDuration;
        int endH = (endMinutes ~/ 60) % 24;
        int endM = endMinutes % 60;
        final endTimeStr = '${endH.toString().padLeft(2, '0')}:${endM.toString().padLeft(2, '0')}';
        
        newSections.add(SectionTime(
          startTime: startTimeStr,
          endTime: endTimeStr,
        ));

        int nextMinutes = endMinutes + shortBreak;
        current = TimeOfDay(hour: (nextMinutes ~/ 60) % 24, minute: nextMinutes % 60);
      }
    }

    if (morningCount > 0) generateForPeriod(morningStart, morningCount);
    if (afternoonCount > 0) generateForPeriod(afternoonStart, afternoonCount);
    if (eveningCount > 0) generateForPeriod(eveningStart, eveningCount);

    setState(() {
      _sections = newSections;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已生成课表，若有特大课间可单独调整，无误后点击保存。')),
    );
  }
}
