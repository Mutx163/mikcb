import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/timetable_settings.dart';
import '../providers/timetable_provider.dart';
import 'about_screen.dart';
import 'data_transfer_screen.dart';
import 'time_scheme_management_screen.dart';
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
                semesterWeekCount: settings.semesterWeekCount,
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
                            settings: const RouteSettings(
                                name: '/settings/appearance'),
                            builder: (_) => const _AppearanceSettingsScreen(),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    _SettingsEntryTile(
                      icon: Icons.notifications_active_outlined,
                      title: '超级岛与通知',
                      subtitle: '提醒时段、岛展示、通知栏和显示内容',
                      trailing: Text(
                        _liveSettingsSummary(settings),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            settings:
                                const RouteSettings(name: '/settings/live'),
                            builder: (_) => const _LiveSettingsScreen(),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    _SettingsEntryTile(
                      icon: Icons.schedule_rounded,
                      title: '时间模板',
                      subtitle: settings.activeTimeSchemeId == null
                          ? '给当前课表快速切换一套节次时间'
                          : '当前：${provider.activeTimeScheme?.name ?? "未选择"}',
                      trailing: Text(
                        '${provider.activeTimeScheme?.sectionCount ?? settings.sectionCount} 节',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      onTap: () => _openTimeSchemeQuickSwitcher(context),
                    ),
                    const Divider(height: 1),
                    _SettingsEntryTile(
                      icon: Icons.view_week_outlined,
                      title: '布局与节次',
                      subtitle: '节次时间、行高、时间列、周末显示与卡片布局',
                      trailing: Text(
                        '${settings.sectionCount} 节',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            settings:
                                const RouteSettings(name: '/settings/layout'),
                            builder: (_) => const _LayoutSettingsScreen(),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    _SettingsEntryTile(
                      icon: Icons.swap_horiz_rounded,
                      title: '数据备份与迁移',
                      subtitle: '导出完整课表文件，给别人直接导入使用',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            settings: const RouteSettings(
                                name: '/settings/data-transfer'),
                            builder: (_) => const DataTransferScreen(),
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
                            settings: const RouteSettings(name: '/user-guide'),
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
                            settings: const RouteSettings(name: '/about'),
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
                      const SizedBox(height: 8),
                      Text(
                        '当前学期共 ${settings.semesterWeekCount} 周。',
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
                          FilledButton.tonalIcon(
                            onPressed: () => _pickSemesterWeekCount(context),
                            icon: const Icon(Icons.view_week_outlined),
                            label: Text('学期周数 ${settings.semesterWeekCount}'),
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

  Future<void> _pickSemesterWeekCount(BuildContext context) async {
    final provider = context.read<TimetableProvider>();
    final currentWeekCount = provider.settings.semesterWeekCount;
    final selected = await showModalBottomSheet<int>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const ListTile(
                title: Text(
                  '选择学期周数',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text('不同学校可按实际教学周数调整。'),
              ),
              ...List.generate(30, (index) {
                final weekCount = index + 1;
                return ListTile(
                  title: Text('$weekCount 周'),
                  trailing: weekCount == currentWeekCount
                      ? const Icon(Icons.check_rounded)
                      : null,
                  onTap: () => Navigator.pop(context, weekCount),
                );
              }),
            ],
          ),
        );
      },
    );

    if (selected == null || !context.mounted || selected == currentWeekCount) {
      return;
    }

    final message = await provider.updateTimetableSettings(
      provider.settings.copyWith(semesterWeekCount: selected),
    );
    if (message != null) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      return;
    }

    if (provider.currentWeek > selected) {
      await provider.setCurrentWeek(selected);
    }
  }

  Future<void> _openTimeSchemeQuickSwitcher(BuildContext context) async {
    final provider = context.read<TimetableProvider>();
    final activeSchemeId = provider.activeTimeScheme?.id;
    final selectedSchemeId = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final sheetProvider = sheetContext.watch<TimetableProvider>();
        final schemes = sheetProvider.timeSchemes;
        final currentSchemeId = sheetProvider.activeTimeScheme?.id;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '时间模板',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  '直接给当前课表切换作息时间；更复杂的编辑、复制和新建在管理页里。',
                  style: Theme.of(sheetContext).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 420),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: schemes.length + 1,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (listContext, index) {
                      if (index == schemes.length) {
                        return ListTile(
                          leading: const Icon(Icons.tune_rounded),
                          title: const Text('管理时间模板'),
                          subtitle: const Text('新建、复制、编辑节次与删除模板'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () =>
                              Navigator.of(sheetContext).pop('__manage__'),
                        );
                      }

                      final scheme = schemes[index];
                      final isCurrent = scheme.id == currentSchemeId;
                      return ListTile(
                        leading: Icon(
                          isCurrent
                              ? Icons.check_circle_rounded
                              : Icons.schedule_outlined,
                        ),
                        title: Text(scheme.name),
                        subtitle: Text(
                          '${scheme.sectionCount} 节 · ${scheme.sections.first.displayText}${scheme.sectionCount > 1 ? ' 起' : ''}',
                        ),
                        trailing: isCurrent
                            ? const Text('当前')
                            : const Icon(Icons.chevron_right_rounded),
                        onTap: () => Navigator.of(sheetContext).pop(scheme.id),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!context.mounted || selectedSchemeId == null) {
      return;
    }

    if (selectedSchemeId == '__manage__') {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const TimeSchemeManagementScreen(),
        ),
      );
      return;
    }

    if (selectedSchemeId == activeSchemeId) {
      return;
    }

    await provider.applyTimeScheme(selectedSchemeId);
    if (!context.mounted) {
      return;
    }
    final nextScheme = provider.activeTimeScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已应用时间模板：${nextScheme?.name ?? "未命名模板"}')),
    );
  }
}

class _SemesterOverviewCard extends StatelessWidget {
  final int currentWeek;
  final int semesterWeekCount;
  final DateTime? semesterStartDate;

  const _SemesterOverviewCard({
    required this.currentWeek,
    required this.semesterWeekCount,
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
                    '当前第 $currentWeek 周 / 共 $semesterWeekCount 周',
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
            subtitle: '不同提醒时段可以自由组合；这里的开关互不替代。',
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('上课前提醒'),
                  subtitle: Text(
                      '在课程开始前 ${_draft.liveShowBeforeClassMinutes} 分钟弹出；不受下面“课中 / 临近下课提醒”开关影响'),
                  value: _draft.liveEnableBeforeClass,
                  onChanged: (value) {
                    setState(() {
                      _draft = _draft.copyWith(liveEnableBeforeClass: value);
                    });
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('启用课中 / 临近下课提醒'),
                  subtitle: const Text('只影响上课后到下课前的提醒，不影响“上课前提醒”开关'),
                  value: _draft.liveEnableDuringClass,
                  onChanged: (value) {
                    setState(() {
                      _draft = _draft.copyWith(liveEnableDuringClass: value);
                    });
                  },
                ),
                if (_draft.liveEnableDuringClass) ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('提醒启动时机'),
                    subtitle: Text(_draft.liveClassReminderStartMinutes == 0
                        ? '从上课开始就展示，并在距下课 ${_draft.liveEndSecondsCountdownThreshold} 秒切到秒级倒数'
                        : '在距下课前 ${_draft.liveClassReminderStartMinutes} 分钟开始展示，并在最后 ${_draft.liveEndSecondsCountdownThreshold} 秒切到秒级倒数'),
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
                        if (value != null) {
                          setState(() {
                            _draft = _draft.copyWith(
                                liveClassReminderStartMinutes: value);
                          });
                        }
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SettingsSectionCard(
            title: '提醒时段内展示方式',
            subtitle: '对前面启用的提醒时段生效。',
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('支持展示超级岛/灵动岛'),
                  subtitle:
                      const Text('关闭后不会再尝试触发系统超级岛；该能力需 HyperOS 3.0.300 及以上支持'),
                  value: _draft.livePromoteDuringClass,
                  onChanged: (value) {
                    setState(() {
                      _draft = _draft.copyWith(livePromoteDuringClass: value);
                    });
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('显示通知栏常驻通知'),
                  subtitle: const Text('关闭后尽量弱化普通通知栏的状态展现（因系统限制可能无效）'),
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

  @override
  void initState() {
    super.initState();
    _draft = context.read<TimetableProvider>().settings;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TimetableProvider>();
    final activeScheme = provider.activeTimeScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('布局与时间模板'),
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
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('自动充满屏幕高度'),
                    subtitle: const Text('开启后会按当前节数自动铺满页面底部，不再保留下方空隙。'),
                    value: _draft.timetableAutoFitSectionHeight,
                    onChanged: (value) {
                      setState(() {
                        _draft = _draft.copyWith(
                          timetableAutoFitSectionHeight: value,
                        );
                      });
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('隐藏周六周日'),
                    subtitle: const Text('开启后首页只显示周一到周五，剩余列宽会自动铺满。'),
                    value: _draft.timetableHideWeekends,
                    onChanged: (value) {
                      setState(() {
                        _draft = _draft.copyWith(timetableHideWeekends: value);
                      });
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('启用应用内震动反馈'),
                    subtitle: const Text('关闭后，页码切换等交互不再触发轻微震动。'),
                    value: _draft.enableHaptics,
                    onChanged: (value) {
                      setState(() {
                        _draft = _draft.copyWith(enableHaptics: value);
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<SectionTimeDisplayMode>(
                    value: _draft.timetableSectionTimeDisplayMode,
                    decoration: const InputDecoration(
                      labelText: '首页时间列显示',
                      border: OutlineInputBorder(),
                    ),
                    items: SectionTimeDisplayMode.values
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value.label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _draft = _draft.copyWith(
                          timetableSectionTimeDisplayMode: value,
                        );
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  Text('课表行高 ${_draft.sectionHeight.toStringAsFixed(0)}'),
                  Slider(
                    value: _draft.sectionHeight,
                    min: 48,
                    max: 92,
                    divisions: 11,
                    label: _draft.sectionHeight.toStringAsFixed(0),
                    onChanged: _draft.timetableAutoFitSectionHeight
                        ? null
                        : (value) {
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
                    '课程卡片显示',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '默认显示课程名、老师和教室；其他信息可按课表自由开关组合。',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('显示课程名'),
                    value: _draft.courseCardShowName,
                    onChanged: (value) {
                      setState(() {
                        _draft = _draft.copyWith(courseCardShowName: value);
                      });
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('显示老师'),
                    value: _draft.courseCardShowTeacher,
                    onChanged: (value) {
                      setState(() {
                        _draft = _draft.copyWith(courseCardShowTeacher: value);
                      });
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('显示教室'),
                    value: _draft.courseCardShowLocation,
                    onChanged: (value) {
                      setState(() {
                        _draft = _draft.copyWith(courseCardShowLocation: value);
                      });
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('显示时间'),
                    value: _draft.courseCardShowTime,
                    onChanged: (value) {
                      setState(() {
                        _draft = _draft.copyWith(courseCardShowTime: value);
                      });
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('显示上课/下课字样'),
                    subtitle: const Text('关闭后仅显示时间点，不显示“上课”“下课”文字。'),
                    value: _draft.courseCardShowTimeLabels,
                    onChanged: _draft.courseCardShowTime
                        ? (value) {
                            setState(() {
                              _draft = _draft.copyWith(
                                courseCardShowTimeLabels: value,
                              );
                            });
                          }
                        : null,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('显示周数'),
                    subtitle: const Text('例如第 1-16 周、单双周'),
                    value: _draft.courseCardShowWeeks,
                    onChanged: (value) {
                      setState(() {
                        _draft = _draft.copyWith(courseCardShowWeeks: value);
                      });
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('显示课程简介'),
                    subtitle: const Text('默认关闭，空间不足时会最先被压缩'),
                    value: _draft.courseCardShowDescription,
                    onChanged: (value) {
                      setState(() {
                        _draft = _draft.copyWith(
                          courseCardShowDescription: value,
                        );
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<CourseCardVerticalAlign>(
                    value: _draft.courseCardVerticalAlign,
                    decoration: const InputDecoration(
                      labelText: '垂直排版',
                      border: OutlineInputBorder(),
                    ),
                    items: CourseCardVerticalAlign.values
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value.label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _draft = _draft.copyWith(
                          courseCardVerticalAlign: value,
                        );
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<CourseCardHorizontalAlign>(
                    value: _draft.courseCardHorizontalAlign,
                    decoration: const InputDecoration(
                      labelText: '水平排版',
                      border: OutlineInputBorder(),
                    ),
                    items: CourseCardHorizontalAlign.values
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value.label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _draft = _draft.copyWith(
                          courseCardHorizontalAlign: value,
                        );
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
                    '时间模板',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    activeScheme == null
                        ? '当前课表还没有绑定时间模板。'
                        : '当前课表使用的是“${activeScheme.name}”，切换模板会直接影响首页时间显示和课程创建时间。',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.schedule_rounded),
                    title: Text(activeScheme?.name ?? '未选择时间模板'),
                    subtitle: Text(
                      activeScheme == null
                          ? '进入模板管理后选择一套作息时间。'
                          : '共 ${activeScheme.sectionCount} 节 · ${activeScheme.sections.first.displayText}${activeScheme.sectionCount > 1 ? ' 起' : ''}',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: _openTimeSchemeManagement,
                  ),
                  if (activeScheme != null) ...[
                    const SizedBox(height: 8),
                    ...List.generate(activeScheme.sections.length, (index) {
                      final section = activeScheme.sections[index];
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text('第 ${index + 1} 节'),
                        trailing: Text(section.displayText),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: SwitchListTile(
              title: const Text('首页显示冲突小胶囊'),
              subtitle: const Text('关闭后，首页课表不再对冲突课程显示“冲突”小胶囊。'),
              value: _draft.showConflictBadgeOnTimetable,
              onChanged: (value) {
                setState(() {
                  _draft = _draft.copyWith(showConflictBadgeOnTimetable: value);
                });
              },
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
                    '说明',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '时间模板是全局共享的。如果你想只改当前课表的时间，先在模板管理里复制一套模板，再应用到当前课表。',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openTimeSchemeManagement() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const TimeSchemeManagementScreen(),
      ),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _draft = context.read<TimetableProvider>().settings;
    });
  }

  Future<void> _save() async {
    final provider = context.read<TimetableProvider>();
    final message = await provider.updateTimetableSettings(
      _draft.copyWith(
        activeTimeSchemeId: provider.settings.activeTimeSchemeId,
        sections: List<SectionTime>.from(provider.settings.sections),
      ),
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
  if (settings.liveEnableBeforeClass) enabledStages.add('上课前');
  if (settings.liveEnableDuringClass) {
    if (settings.liveClassReminderStartMinutes == 0) {
      enabledStages.add('上课中');
    } else {
      enabledStages.add('下课提醒');
    }
  }
  if (enabledStages.isEmpty) {
    return '已全关';
  }
  return enabledStages.join(' + ');
}

Color _colorFromHex(String hexColor) {
  final normalized = hexColor.replaceFirst('#', '');
  return Color(int.parse('FF$normalized', radix: 16));
}

String _formatDate(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
