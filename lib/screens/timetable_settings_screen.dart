import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/timetable_settings.dart';
import '../providers/timetable_provider.dart';
import 'about_screen.dart';
import 'user_guide_screen.dart';

class TimetableSettingsScreen extends StatelessWidget {
  const TimetableSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TimetableProvider>(
      builder: (context, provider, child) {
        final settings = provider.settings;
        return Scaffold(
          appBar: AppBar(
            title: const Text('课表设置'),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SemesterOverviewCard(
                currentWeek: provider.currentWeek,
                semesterStartDate: settings.semesterStartDate,
              ),
              const SizedBox(height: 16),
              Card(
                child: Column(
                  children: [
                    _SettingsEntryTile(
                      icon: Icons.palette_outlined,
                      title: '外观与配色',
                      subtitle: '主题色、课表背景、课程卡片颜色',
                      trailing: _ColorDot(
                        color: _colorFromHex(settings.themeSeedColor),
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const _AppearanceSettingsScreen(),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    _SettingsEntryTile(
                      icon: Icons.notifications_active_outlined,
                      title: '超级岛与通知',
                      subtitle: '三时段、岛展示、通知栏和显示内容',
                      trailing: Text(
                        _liveSettingsSummary(settings),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const _LiveSettingsScreen(),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    _SettingsEntryTile(
                      icon: Icons.view_week_outlined,
                      title: '布局与节次',
                      subtitle: '节次时间、行高、紧凑字号',
                      trailing: Text(
                        '${settings.sectionCount} 节',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const _LayoutSettingsScreen(),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    _SettingsEntryTile(
                      icon: Icons.menu_book_outlined,
                      title: '使用引导与权限',
                      subtitle: '简称建议、通知、自启动、电池策略',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const UserGuideScreen(),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    _SettingsEntryTile(
                      icon: Icons.info_outline_rounded,
                      title: '关于软件',
                      subtitle: '开源说明、版本信息和 GitHub',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AboutScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '开学日期与当前周',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        settings.semesterStartDate == null
                            ? '未设置开学日期，回本周和日期栏会缺少精确映射。'
                            : '已设置开学日期，可用它同步当前周并驱动课表日期显示。',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.tonalIcon(
                            onPressed: () => _pickSemesterStartDate(context),
                            icon: const Icon(Icons.event_outlined),
                            label: const Text('设置开学日期'),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: settings.semesterStartDate == null
                                ? null
                                : () => _syncCurrentWeek(context),
                            icon: const Icon(Icons.sync_outlined),
                            label: const Text('同步当前周'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickSemesterStartDate(BuildContext context) async {
    final provider = context.read<TimetableProvider>();
    final selected = await showDatePicker(
      context: context,
      initialDate: provider.settings.semesterStartDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (selected == null || !context.mounted) {
      return;
    }

    final message = await provider.updateTimetableSettings(
      provider.settings.copyWith(semesterStartDate: selected),
    );
    if (!context.mounted || message == null) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _syncCurrentWeek(BuildContext context) async {
    final provider = context.read<TimetableProvider>();
    await provider.syncCurrentWeekWithSemesterStart();
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已同步到第 ${provider.currentWeek} 周')),
    );
  }
}

class _SemesterOverviewCard extends StatelessWidget {
  final int currentWeek;
  final DateTime? semesterStartDate;

  const _SemesterOverviewCard({
    required this.currentWeek,
    required this.semesterStartDate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.calendar_view_week_outlined,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '当前第 $currentWeek 周',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    semesterStartDate == null
                        ? '开学日期未设置'
                        : '开学日期：${_formatDate(semesterStartDate!)}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppearanceSettingsScreen extends StatefulWidget {
  const _AppearanceSettingsScreen();

  @override
  State<_AppearanceSettingsScreen> createState() =>
      _AppearanceSettingsScreenState();
}

class _AppearanceSettingsScreenState extends State<_AppearanceSettingsScreen> {
  static const List<String> _themeColors = [
    '#2563EB',
    '#0891B2',
    '#0F766E',
    '#4F46E5',
    '#DC2626',
    '#EA580C',
    '#CA8A04',
    '#111827',
  ];

  static const List<String> _backgroundColors = [
    '#F8FAFC',
    '#F7F7F5',
    '#FDF6EC',
    '#F2F7FF',
    '#F5F3FF',
    '#ECFDF5',
  ];

  static const List<String> _cardColors = [
    '#2563EB',
    '#4CAF50',
    '#FF9800',
    '#E91E63',
    '#9C27B0',
    '#00BCD4',
    '#FF5722',
    '#795548',
    '#607D8B',
  ];

  late TimetableSettings _draft;

  @override
  void initState() {
    super.initState();
    _draft = context.read<TimetableProvider>().settings;
  }

  @override
  Widget build(BuildContext context) {
    final previewCardColor = _draft.timetableUseUnifiedCardColor
        ? _draft.timetableUnifiedCardColor
        : _draft.themeSeedColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('外观与配色'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('保存'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: _colorFromHex(_draft.timetablePageBackgroundColor),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '预览',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.78),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 72,
                            decoration: BoxDecoration(
                              color: _colorFromHex(previewCardColor),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.all(10),
                            child: const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '数控',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  'A301',
                                  style: TextStyle(color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            height: 72,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.72),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '课表背景',
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _SettingsSectionCard(
            title: '应用主题色',
            subtitle: '影响顶部栏、强调色和全局主色调。',
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _themeColors
                  .map(
                    (color) => _SelectableColorChip(
                      colorHex: color,
                      selected: _draft.themeSeedColor == color,
                      onTap: () {
                        setState(() {
                          _draft = _draft.copyWith(themeSeedColor: color);
                        });
                      },
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 16),
          _SettingsSectionCard(
            title: '课表背景色',
            subtitle: '只作用于课表页面的大背景。',
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _backgroundColors
                  .map(
                    (color) => _SelectableColorChip(
                      colorHex: color,
                      selected: _draft.timetablePageBackgroundColor == color,
                      onTap: () {
                        setState(() {
                          _draft = _draft.copyWith(
                            timetablePageBackgroundColor: color,
                          );
                        });
                      },
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('统一课程卡片颜色'),
                  subtitle: const Text('关闭后继续使用每门课程自己的颜色'),
                  value: _draft.timetableUseUnifiedCardColor,
                  onChanged: (value) {
                    setState(() {
                      _draft = _draft.copyWith(
                        timetableUseUnifiedCardColor: value,
                      );
                    });
                  },
                ),
                if (_draft.timetableUseUnifiedCardColor) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: _cardColors
                          .map(
                            (color) => _SelectableColorChip(
                              colorHex: color,
                              selected:
                                  _draft.timetableUnifiedCardColor == color,
                              onTap: () {
                                setState(() {
                                  _draft = _draft.copyWith(
                                    timetableUnifiedCardColor: color,
                                  );
                                });
                              },
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final provider = context.read<TimetableProvider>();
    final message = await provider.updateTimetableSettings(_draft);
    if (!mounted) {
      return;
    }
    if (message != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      return;
    }
    Navigator.pop(context);
  }
}

class _LiveSettingsScreen extends StatefulWidget {
  const _LiveSettingsScreen();

  @override
  State<_LiveSettingsScreen> createState() => _LiveSettingsScreenState();
}

class _LiveSettingsScreenState extends State<_LiveSettingsScreen> {
  static const List<int> _beforeClassMinutesOptions = [1, 5, 10, 15, 20, 30];
  static const List<int> _endSecondsOptions = [15, 30, 45, 60, 90];

  late TimetableSettings _draft;

  @override
  void initState() {
    super.initState();
    _draft = context.read<TimetableProvider>().settings;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('超级岛与通知'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('保存'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SettingsSectionCard(
            title: '提醒时段',
            subtitle: '三段可以自由组合，测试通知也会按这里的开关执行。',
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('上课前提醒'),
                  subtitle:
                      Text('在课程开始前 ${_draft.liveShowBeforeClassMinutes} 分钟弹出'),
                  value: _draft.liveEnableBeforeClass,
                  onChanged: (value) {
                    setState(() {
                      _draft = _draft.copyWith(liveEnableBeforeClass: value);
                    });
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('上课中提醒'),
                  subtitle: const Text('课程进行中持续展示'),
                  value: _draft.liveEnableDuringClass,
                  onChanged: (value) {
                    setState(() {
                      _draft = _draft.copyWith(liveEnableDuringClass: value);
                    });
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('下课提醒'),
                  subtitle: Text(
                      '距下课 ${_draft.liveEndSecondsCountdownThreshold} 秒切换秒级提醒'),
                  value: _draft.liveEnableBeforeEnd,
                  onChanged: (value) {
                    setState(() {
                      _draft = _draft.copyWith(liveEnableBeforeEnd: value);
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SettingsSectionCard(
            title: '上课中展示方式',
            subtitle: '只对上课中阶段生效。',
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('上课中显示超级岛'),
                  subtitle: const Text('关闭后上课中阶段不请求岛展示'),
                  value: _draft.livePromoteDuringClass,
                  onChanged: (value) {
                    setState(() {
                      _draft = _draft.copyWith(livePromoteDuringClass: value);
                    });
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('上课中显示通知栏通知'),
                  subtitle: const Text('关闭后尽量弱化普通通知内容'),
                  value: _draft.liveShowDuringClassNotification,
                  onChanged: (value) {
                    setState(() {
                      _draft = _draft.copyWith(
                        liveShowDuringClassNotification: value,
                      );
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '时间阈值',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: _draft.liveShowBeforeClassMinutes,
                    decoration: const InputDecoration(
                      labelText: '上课前弹出时间',
                      border: OutlineInputBorder(),
                    ),
                    items: _beforeClassMinutesOptions
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text('$value 分钟'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _draft = _draft.copyWith(
                          liveShowBeforeClassMinutes: value,
                        );
                      });
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
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text('$value 秒'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _draft = _draft.copyWith(
                          liveEndSecondsCountdownThreshold: value,
                        );
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _SettingsSectionCard(
            title: '显示内容',
            subtitle: '这些项会影响岛区和通知展开视图的信息密度。',
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('显示课程名'),
                  value: _draft.liveShowCourseName,
                  onChanged: (value) {
                    setState(() {
                      _draft = _draft.copyWith(liveShowCourseName: value);
                    });
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('优先显示课程简称'),
                  subtitle: const Text('建议简称控制在 3 个字以内'),
                  value: _draft.liveUseShortName,
                  onChanged: (value) {
                    setState(() {
                      _draft = _draft.copyWith(liveUseShortName: value);
                    });
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('显示地点'),
                  value: _draft.liveShowLocation,
                  onChanged: (value) {
                    setState(() {
                      _draft = _draft.copyWith(liveShowLocation: value);
                    });
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('显示倒计时'),
                  value: _draft.liveShowCountdown,
                  onChanged: (value) {
                    setState(() {
                      _draft = _draft.copyWith(liveShowCountdown: value);
                    });
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('隐藏前缀文案'),
                  subtitle: const Text('例如隐藏“即将上课”这类前缀'),
                  value: _draft.liveHidePrefixText,
                  onChanged: (value) {
                    setState(() {
                      _draft = _draft.copyWith(liveHidePrefixText: value);
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final provider = context.read<TimetableProvider>();
    final message = await provider.updateTimetableSettings(_draft);
    if (!mounted) {
      return;
    }
    if (message != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      return;
    }
    Navigator.pop(context);
  }
}

class _LayoutSettingsScreen extends StatefulWidget {
  const _LayoutSettingsScreen();

  @override
  State<_LayoutSettingsScreen> createState() => _LayoutSettingsScreenState();
}

class _LayoutSettingsScreenState extends State<_LayoutSettingsScreen> {
  late TimetableSettings _draft;
  late List<SectionTime> _sections;

  @override
  void initState() {
    super.initState();
    _draft = context.read<TimetableProvider>().settings;
    _sections = List<SectionTime>.from(_draft.sections);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TimetableProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('布局与节次'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('保存'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '课表密度',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  Text('课表行高 ${_draft.sectionHeight.toStringAsFixed(0)}'),
                  Slider(
                    value: _draft.sectionHeight,
                    min: 48,
                    max: 92,
                    divisions: 11,
                    label: _draft.sectionHeight.toStringAsFixed(0),
                    onChanged: (value) {
                      setState(() {
                        _draft = _draft.copyWith(sectionHeight: value);
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  Text('紧凑字号 ${_draft.compactFontSize.toStringAsFixed(1)}'),
                  Slider(
                    value: _draft.compactFontSize,
                    min: 7,
                    max: 12,
                    divisions: 10,
                    label: _draft.compactFontSize.toStringAsFixed(1),
                    onChanged: (value) {
                      setState(() {
                        _draft = _draft.copyWith(compactFontSize: value);
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '节次时间',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '当前课表最多已使用到第 ${provider.maxUsedSection} 节，保存时不能少于这个数量。',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: _sections.length >= 20 ? null : _addSection,
                        icon: const Icon(Icons.add),
                        label: const Text('新增一节'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed:
                            _sections.length <= 1 ? null : _removeSection,
                        icon: const Icon(Icons.remove),
                        label: const Text('删除末节'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: _resetSections,
                        icon: const Icon(Icons.restart_alt),
                        label: const Text('恢复默认'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...List.generate(_sections.length, (index) {
                    final section = _sections[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('第 ${index + 1} 节'),
                      subtitle:
                          Text('${section.startTime} - ${section.endTime}'),
                      trailing: IconButton(
                        tooltip: '编辑时间',
                        onPressed: () => _editSectionTime(index),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editSectionTime(int index) async {
    final start = await showTimePicker(
      context: context,
      initialTime: _parseTimeOfDay(_sections[index].startTime),
    );
    if (start == null || !mounted) {
      return;
    }

    final end = await showTimePicker(
      context: context,
      initialTime: _parseTimeOfDay(_sections[index].endTime),
    );
    if (end == null || !mounted) {
      return;
    }

    setState(() {
      _sections[index] = SectionTime(
        startTime: _formatTimeOfDay(start),
        endTime: _formatTimeOfDay(end),
      );
    });
  }

  void _addSection() {
    setState(() {
      _sections.add(_buildNextSection(_sections.last));
    });
  }

  void _removeSection() {
    setState(() {
      _sections.removeLast();
    });
  }

  void _resetSections() {
    setState(() {
      _sections = List<SectionTime>.from(TimetableSettings.defaults().sections);
    });
  }

  Future<void> _save() async {
    final provider = context.read<TimetableProvider>();
    final message = await provider.updateTimetableSettings(
      _draft.copyWith(sections: List<SectionTime>.from(_sections)),
    );
    if (!mounted) {
      return;
    }
    if (message != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      return;
    }
    Navigator.pop(context);
  }
}

class _SettingsEntryTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback onTap;

  const _SettingsEntryTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: trailing ?? const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}

class _SettingsSectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _SettingsSectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _SelectableColorChip extends StatelessWidget {
  final String colorHex;
  final bool selected;
  final VoidCallback onTap;

  const _SelectableColorChip({
    required this.colorHex,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = _colorFromHex(colorHex);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.onSurface
                : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.22),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: selected
            ? const Icon(Icons.check_rounded, color: Colors.white)
            : null,
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  final Color color;

  const _ColorDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}

String _liveSettingsSummary(TimetableSettings settings) {
  final enabledStages = <String>[];
  if (settings.liveEnableBeforeClass) enabledStages.add('前');
  if (settings.liveEnableDuringClass) enabledStages.add('中');
  if (settings.liveEnableBeforeEnd) enabledStages.add('下');
  if (enabledStages.isEmpty) {
    return '已全关';
  }
  return enabledStages.join('/');
}

Color _colorFromHex(String hexColor) {
  final normalized = hexColor.replaceFirst('#', '');
  return Color(int.parse('FF$normalized', radix: 16));
}

String _formatDate(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

TimeOfDay _parseTimeOfDay(String value) {
  final parts = value.split(':');
  return TimeOfDay(
    hour: int.parse(parts[0]),
    minute: int.parse(parts[1]),
  );
}

String _formatTimeOfDay(TimeOfDay time) {
  return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
}

SectionTime _buildNextSection(SectionTime last) {
  final end = _parseTimeOfDay(last.endTime);
  final startMinutes = end.hour * 60 + end.minute + 10;
  final endMinutes = startMinutes + 45;
  return SectionTime(
    startTime: _minutesToTime(startMinutes),
    endTime: _minutesToTime(endMinutes),
  );
}

String _minutesToTime(int minutes) {
  final normalized = minutes % (24 * 60);
  final hour = normalized ~/ 60;
  final minute = normalized % 60;
  return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}
