import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/timetable_settings.dart';
import '../providers/timetable_provider.dart';

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

  @override
  void initState() {
    super.initState();
    final settings = context.read<TimetableProvider>().settings;
    _sections = settings.sections.map((item) => item.copyWith()).toList();
    _sectionHeight = settings.sectionHeight;
    _compactFontSize = settings.compactFontSize;
    _semesterStartDate = settings.semesterStartDate;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('课表设置'),
        actions: [
          TextButton(
            onPressed: _saveSettings,
            child: const Text(
              '保存',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSemesterSection(),
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
}
