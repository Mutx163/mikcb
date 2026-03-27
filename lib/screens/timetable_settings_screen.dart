import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/course.dart';
import '../models/timetable_settings.dart';
import '../providers/timetable_provider.dart';
import '../services/miui_live_activities_service.dart';
import '../services/umeng_analytics_service.dart';
import 'about_screen.dart';
import 'data_transfer_screen.dart';
import 'live_settings_subpages.dart';
import 'time_scheme_bottom_sheet.dart';
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
                onPickSemesterStartDate: () => _pickSemesterStartDate(context),
                onSyncCurrentWeek: settings.semesterStartDate == null
                    ? null
                    : () => _syncCurrentWeek(context),
                onPickSemesterWeekCount: () => _pickSemesterWeekCount(context),
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
                      icon: Icons.widgets_outlined,
                      title: '桌面小组件',
                      subtitle: '今日课程卡片、小组件背景与显示信息',
                      trailing: Text(
                        settings.widgetBackgroundStyle.label,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            settings: const RouteSettings(
                                name: '/settings/home-widget'),
                            builder: (_) => const _HomeWidgetSettingsScreen(),
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
    await showTimeSchemeBottomSheet(context);
  }
}

class _SemesterOverviewCard extends StatelessWidget {
  final int currentWeek;
  final int semesterWeekCount;
  final DateTime? semesterStartDate;
  final VoidCallback onPickSemesterStartDate;
  final VoidCallback? onSyncCurrentWeek;
  final VoidCallback onPickSemesterWeekCount;

  const _SemesterOverviewCard({
    required this.currentWeek,
    required this.semesterWeekCount,
    required this.semesterStartDate,
    required this.onPickSemesterStartDate,
    required this.onSyncCurrentWeek,
    required this.onPickSemesterWeekCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'assets/branding/launcher_icon.png',
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
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
                            ? '设置开学日期后，可更准确地同步当前周和课表日期。'
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
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: onPickSemesterStartDate,
                  icon: const Icon(Icons.event_outlined),
                  label: Text(
                    semesterStartDate == null ? '设置开学日期' : '修改开学日期',
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: onSyncCurrentWeek,
                  icon: const Icon(Icons.sync_outlined),
                  label: const Text('同步当前周'),
                ),
                FilledButton.tonalIcon(
                  onPressed: onPickSemesterWeekCount,
                  icon: const Icon(Icons.view_week_outlined),
                  label: Text('学期周数 $semesterWeekCount'),
                ),
              ],
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
    final previewCardColor = _draft.timetableUseUnifiedCardColor
        ? _draft.timetableUnifiedCardColor
        : _draft.themeSeedColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('外观与配色'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Theme.of(context).brightness == Brightness.dark
                ? Theme.of(context).colorScheme.surfaceContainerHighest
                : _colorFromHex(_draft.timetablePageBackgroundColor),
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
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainer
                          .withValues(alpha: 0.82),
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
                              color: Theme.of(context)
                                  .colorScheme
                                  .surface
                                  .withValues(alpha: 0.72),
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
            title: '显示模式',
            subtitle: '支持跟随系统、浅色模式和深色模式。',
            child: DropdownButtonFormField<AppThemeMode>(
              value: _draft.appThemeMode,
              decoration: const InputDecoration(
                labelText: '主题模式',
                border: OutlineInputBorder(),
              ),
              items: AppThemeMode.values
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(value.label),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                _updateDraft(_draft.copyWith(appThemeMode: value));
              },
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
                        _updateDraft(_draft.copyWith(themeSeedColor: color));
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
                        _updateDraft(
                          _draft.copyWith(
                            timetablePageBackgroundColor: color,
                          ),
                        );
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
                    _updateDraft(
                      _draft.copyWith(
                        timetableUseUnifiedCardColor: value,
                      ),
                    );
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
                                _updateDraft(
                                  _draft.copyWith(
                                    timetableUnifiedCardColor: color,
                                  ),
                                );
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

  void _updateDraft(TimetableSettings next, {bool debounce = false}) {
    setState(() {
      _draft = next;
    });
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
    if (next.liveMiuiIslandExpandedIconMode ==
            MiuiIslandExpandedIconMode.customImage &&
        (next.liveMiuiIslandExpandedIconPath == null ||
            next.liveMiuiIslandExpandedIconPath!.isEmpty)) {
      return;
    }
    final provider = context.read<TimetableProvider>();
    final message = await provider.updateTimetableSettings(next);
    if (!mounted) {
      return;
    }
    if (message != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      setState(() {
        _draft = provider.settings;
      });
    }
  }
}

class _LiveSettingsScreen extends StatefulWidget {
  const _LiveSettingsScreen();

  @override
  State<_LiveSettingsScreen> createState() => _LiveSettingsScreenState();
}

class _LiveSettingsScreenState extends State<_LiveSettingsScreen> {
  late TimetableSettings _draft;

  @override
  void initState() {
    super.initState();
    _draft = context.read<TimetableProvider>().settings;
  }

  @override
  Widget build(BuildContext context) {
    final beforeClassSummary =
        _liveDisplaySummary(_draft.beforeClassDisplaySettings);
    final duringEndSummary = _draft.liveDuringEndFollowBeforeClass
        ? '跟随上课前提醒'
        : _liveDisplaySummary(_draft.duringEndDisplaySettings);
    return Scaffold(
      appBar: AppBar(
        title: const Text('超级岛与通知'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Column(
              children: [
                _SettingsEntryTile(
                  icon: Icons.alarm_outlined,
                  title: '提醒时段',
                  subtitle: '上课前、课中/下课提醒开关，展示时机和通知方式',
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LiveReminderTimingScreen(),
                      ),
                    );
                    if (!mounted) return;
                    setState(() {
                      _draft = context.read<TimetableProvider>().settings;
                    });
                  },
                ),
                const Divider(height: 1),
                _SettingsEntryTile(
                  icon: Icons.upcoming_outlined,
                  title: '上课前提醒显示',
                  subtitle: beforeClassSummary,
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LiveDisplaySettingsScreen(
                          title: '上课前提醒显示',
                          forDuringEnd: false,
                        ),
                      ),
                    );
                    if (!mounted) return;
                    setState(() {
                      _draft = context.read<TimetableProvider>().settings;
                    });
                  },
                ),
                const Divider(height: 1),
                _SettingsEntryTile(
                  icon: Icons.timelapse_rounded,
                  title: '课中/下课提醒显示',
                  subtitle: duringEndSummary,
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LiveDisplaySettingsScreen(
                          title: '课中/下课提醒显示',
                          forDuringEnd: true,
                        ),
                      ),
                    );
                    if (!mounted) return;
                    setState(() {
                      _draft = context.read<TimetableProvider>().settings;
                    });
                  },
                ),
                const Divider(height: 1),
                _SettingsEntryTile(
                  icon: Icons.shield_outlined,
                  title: '后台保活',
                  subtitle: '隐藏后台、后台保活辅助服务和权限入口',
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LiveKeepAliveSettingsScreen(),
                      ),
                    );
                    if (!mounted) return;
                    setState(() {
                      _draft = context.read<TimetableProvider>().settings;
                    });
                  },
                ),
                const Divider(height: 1),
                _SettingsEntryTile(
                  icon: Icons.science_outlined,
                  title: '测试与诊断',
                  subtitle: '发送测试通知，检查超级岛和本地诊断日志',
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const _LiveTestingSettingsScreen(),
                      ),
                    );
                    if (!mounted) return;
                    setState(() {
                      _draft = context.read<TimetableProvider>().settings;
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
}

class _LiveTestingSettingsScreen extends StatelessWidget {
  const _LiveTestingSettingsScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('测试与诊断')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SettingsSectionCard(
            title: '测试通知',
            subtitle: '用于验证超级岛、通知栏和课程简称等显示效果。',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () => _showTestOptions(context),
                  icon: const Icon(Icons.science_outlined),
                  label: const Text('发送测试通知'),
                ),
                if (!kReleaseMode) ...[
                  const SizedBox(height: 12),
                  Text(
                    '下面两个按钮仅测试版显示，用于验证友盟 U-APM 崩溃和卡顿上报。',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: () => _triggerUmengTestCrash(context),
                        icon: const Icon(Icons.warning_amber_rounded),
                        label: const Text('崩溃测试'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () => _triggerUmengTestAnr(context),
                        icon: const Icon(Icons.hourglass_bottom_rounded),
                        label: const Text('异常卡顿测试'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SettingsSectionCard(
            title: '本地诊断日志',
            subtitle: '导出和清空重收集入口放在关于软件页底部的测试者选项中。',
            child: Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonalIcon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AboutScreen()),
                  );
                },
                icon: const Icon(Icons.info_outline_rounded),
                label: const Text('前往关于软件'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _triggerUmengTestCrash(BuildContext context) async {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('即将触发友盟 U-APM 测试崩溃，请重新打开应用查看后台是否收到上报')),
  );
  await Future<void>.delayed(const Duration(milliseconds: 300));
  await UmengAnalyticsService.triggerTestCrash();
}

Future<void> _triggerUmengTestAnr(BuildContext context) async {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('即将触发约 30 秒主线程卡死，请脱离 flutter run 测试，并在卡死后重新打开应用查看友盟后台'),
      duration: Duration(seconds: 4),
    ),
  );
  await Future<void>.delayed(const Duration(milliseconds: 300));
  await UmengAnalyticsService.triggerTestAnr();
}

Future<void> _showTestOptions(BuildContext context) async {
  final now = DateTime.now();
  const beforeClassLead = Duration(seconds: 8);
  const totalCourseDuration = Duration(minutes: 3);

  String formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  final provider = context.read<TimetableProvider>();
  await provider.initialize();
  final liveService = MiuiLiveActivitiesService();
  await liveService.initialize();
  await liveService.recordDiagnosticEvent(
    'live_update_test_requested',
    'User requested manual live island test notification',
    extras: {
      'from': 'settings_screen',
      'currentWeek': provider.currentWeek,
    },
  );

  final selection = provider.getTestLiveActivityCourseSelection(now: now);
  if (selection == null) {
    await liveService.recordDiagnosticEvent(
      'live_update_test_no_selection',
      'Manual live island test found no eligible course',
      extras: {
        'weekday': now.weekday,
      },
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('当前没有可测试的课程')),
    );
    return;
  }
  final settings = provider.settings;
  final displaySettings = settings.beforeClassDisplaySettings;
  final start = now.add(beforeClassLead);
  final end = start.add(totalCourseDuration);

  final baseCourse = selection.currentCourse;
  final previewNextCourse = selection.nextCourse;
  final resolvedShortName = provider.resolveCourseShortName(baseCourse);
  await liveService.recordDiagnosticEvent(
    'live_update_test_selection_ready',
    'Manual live island test resolved target course',
    extras: {
      'courseName': baseCourse.name,
      'stage': selection.stage.name,
      'hasNextCourse': previewNextCourse != null,
    },
  );

  final testCourse = Course(
    id: 'test_auto_id',
    name: baseCourse.name,
    shortName: resolvedShortName,
    teacher: baseCourse.teacher,
    location: baseCourse.location,
    dayOfWeek: now.weekday,
    startSection: baseCourse.startSection,
    endSection: baseCourse.endSection,
    startWeek: baseCourse.startWeek,
    endWeek: baseCourse.endWeek,
    startTime: formatTime(start),
    endTime: formatTime(end),
    color: baseCourse.color,
    note: '此处显示备注。可以在课程编辑页进行设置。',
  );

  if (!context.mounted) return;

  try {
    provider.suspendLiveActivitySyncFor(
      end.difference(now) + const Duration(seconds: 20),
    );
    await liveService.recordDiagnosticEvent(
      'live_update_test_suspend_sync',
      'Temporarily suspended scheduled live update sync for manual test',
      extras: {
        'untilMillis':
            end.add(const Duration(seconds: 20)).millisecondsSinceEpoch,
      },
    );
    await liveService.stopLiveUpdate();
    await Future<void>.delayed(const Duration(milliseconds: 150));
    final progressMilestones = provider.buildLiveProgressMilestones(
      baseCourse,
      startAtMillis: start.millisecondsSinceEpoch,
      endAtMillis: end.millisecondsSinceEpoch,
    );
    final progressBreakOffsetsMillis =
        provider.buildLiveProgressBreakOffsetsMillis(
      baseCourse,
      startAtMillis: start.millisecondsSinceEpoch,
      endAtMillis: end.millisecondsSinceEpoch,
    );
    await liveService.recordDiagnosticEvent(
      'live_update_test_starting',
      'Manual live island test is starting native live update',
      extras: {
        'courseName': testCourse.name,
        'startAtMillis': start.millisecondsSinceEpoch,
        'endAtMillis': end.millisecondsSinceEpoch,
        'milestoneCount': progressMilestones.length,
      },
    );
    await liveService.startLiveUpdate(
      testCourse,
      previewNextCourse,
      stage: LiveActivityStage.beforeClass.name,
      beforeClassLeadMillis: beforeClassLead.inMilliseconds,
      startAtMillis: start.millisecondsSinceEpoch,
      endAtMillis: end.millisecondsSinceEpoch,
      endReminderLeadMillis: 0,
      endSecondsCountdownThreshold: settings.liveEndSecondsCountdownThreshold,
      promoteDuringClass: settings.livePromoteDuringClass,
      showNotificationDuringClass: settings.liveShowDuringClassNotification,
      enableBeforeClass: true,
      enableDuringClass: false,
      enableBeforeEnd: false,
      showCountdown: displaySettings.showCountdown,
      countdownTextStyle: displaySettings.countdownTextStyle,
      showStageText: displaySettings.showStageText,
      showCourseNameInIsland: displaySettings.showCourseName,
      showLocationInIsland: displaySettings.showLocation,
      useShortNameInIsland: displaySettings.useShortName,
      hidePrefixText: displaySettings.hidePrefixText,
      duringClassTimeDisplayMode: displaySettings.duringClassTimeDisplayMode,
      enableMiuiIslandLabelImage: displaySettings.enableMiuiIslandLabelImage,
      miuiIslandLabelStyle: displaySettings.miuiIslandLabelStyle,
      miuiIslandLabelContent: displaySettings.miuiIslandLabelContent,
      miuiIslandLabelFontColor: displaySettings.miuiIslandLabelFontColor,
      miuiIslandLabelFontWeight: displaySettings.miuiIslandLabelFontWeight,
      miuiIslandLabelRenderQuality:
          displaySettings.miuiIslandLabelRenderQuality,
      miuiIslandLabelFontSize: displaySettings.miuiIslandLabelFontSize,
      miuiIslandLabelOffsetX: displaySettings.miuiIslandLabelOffsetX,
      miuiIslandLabelOffsetY: displaySettings.miuiIslandLabelOffsetY,
      miuiIslandExpandedIconMode: displaySettings.miuiIslandExpandedIconMode,
      miuiIslandExpandedIconPath: displaySettings.miuiIslandExpandedIconPath,
      beforeClassQuickAction: settings.liveBeforeClassQuickAction,
      progressBreakOffsetsMillis: progressBreakOffsetsMillis,
      progressMilestoneLabels: progressMilestones
          .map((milestone) => milestone['label'] as String)
          .toList(),
      progressMilestoneTimeTexts: progressMilestones
          .map((milestone) => milestone['timeText'] as String)
          .toList(),
    );
    await liveService.recordDiagnosticEvent(
      'live_update_test_started',
      'Manual live island test successfully requested native live update',
      extras: {
        'courseName': testCourse.name,
        'stage': LiveActivityStage.beforeClass.name,
      },
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已发送上课提醒测试通知，约 8 秒内会进入上课前提醒阶段')),
    );
  } catch (e, stackTrace) {
    await UmengAnalyticsService.reportDiagnostic(
      'live_update_test_failed',
      'Manual live island test failed before native island appeared',
      error: e,
      stackTrace: stackTrace,
      dedupeKey: 'live_update_test_failed',
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('发送失败: $e')),
    );
  }
}

class _LayoutSettingsScreen extends StatefulWidget {
  const _LayoutSettingsScreen();

  @override
  State<_LayoutSettingsScreen> createState() => _LayoutSettingsScreenState();
}

class _HomeWidgetSettingsScreen extends StatefulWidget {
  const _HomeWidgetSettingsScreen();

  @override
  State<_HomeWidgetSettingsScreen> createState() =>
      _HomeWidgetSettingsScreenState();
}

class _HomeWidgetSettingsScreenState extends State<_HomeWidgetSettingsScreen> {
  static const double _defaultWidgetHeightAdjustment = -11;
  static const double _defaultWidgetCornerRadius = 22;

  late TimetableSettings _draft;
  Timer? _autoSaveTimer;
  bool _isPersisting = false;
  TimetableSettings? _pendingPersist;

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
      appBar: AppBar(
        title: const Text('桌面小组件'),
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
                    '今日课程组件',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '首批支持 2×2、2×4、4×4 三种尺寸。点击小组件会直接打开首页，课程开始和结束时会主动刷新。',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<WidgetBackgroundStyle>(
                    value: _draft.widgetBackgroundStyle,
                    decoration: const InputDecoration(
                      labelText: '背景样式',
                      border: OutlineInputBorder(),
                    ),
                    items: WidgetBackgroundStyle.values
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
                        _draft.copyWith(widgetBackgroundStyle: value),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('显示地点'),
                    subtitle: const Text('关闭后，小组件次级信息会优先显示周次和课程数量。'),
                    value: _draft.widgetShowLocation,
                    onChanged: (value) {
                      _updateDraft(
                        _draft.copyWith(widgetShowLocation: value),
                      );
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('显示倒计时'),
                    subtitle: const Text('先保留刷新开关，后续会用于下一节课和上课中的剩余时间展示。'),
                    value: _draft.widgetShowCountdown,
                    onChanged: (value) {
                      _updateDraft(
                        _draft.copyWith(widgetShowCountdown: value),
                      );
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('隐藏已上完课程'),
                    subtitle: const Text('开启后，2×2 和 4×4 课程列表只显示还没结束的课程。'),
                    value: _draft.widgetHideCompletedCourses,
                    onChanged: (value) {
                      _updateDraft(
                        _draft.copyWith(widgetHideCompletedCourses: value),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '卡片高度微调',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _draft.widgetHeightAdjustment ==
                            _defaultWidgetHeightAdjustment
                        ? '默认'
                        : (_draft.widgetHeightAdjustment >
                                _defaultWidgetHeightAdjustment
                            ? '更高 ${(_draft.widgetHeightAdjustment - _defaultWidgetHeightAdjustment).toStringAsFixed(0)}'
                            : '更矮 ${(_defaultWidgetHeightAdjustment - _draft.widgetHeightAdjustment).toStringAsFixed(0)}'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Slider(
                    value: (_draft.widgetHeightAdjustment -
                            _defaultWidgetHeightAdjustment)
                        .clamp(-16, 16)
                        .toDouble(),
                    min: -16,
                    max: 16,
                    divisions: 32,
                    label: _draft.widgetHeightAdjustment.toStringAsFixed(0),
                    onChanged: (value) {
                      _updateDraft(
                        _draft.copyWith(
                          widgetHeightAdjustment:
                              _defaultWidgetHeightAdjustment + value,
                        ),
                        debounce: true,
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '卡片圆角',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_draft.widgetCornerRadius.toStringAsFixed(0)}dp',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Slider(
                    value:
                        (_draft.widgetCornerRadius - _defaultWidgetCornerRadius)
                            .clamp(-14, 14)
                            .toDouble(),
                    min: -14,
                    max: 14,
                    divisions: 28,
                    label: _draft.widgetCornerRadius.toStringAsFixed(0),
                    onChanged: (value) {
                      _updateDraft(
                        _draft.copyWith(
                          widgetCornerRadius:
                              _defaultWidgetCornerRadius + value,
                        ),
                        debounce: true,
                      );
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
                    '说明',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '小组件目前优先展示今日课程。无课状态会保持完整卡片，不会出现空白；如果你切换课表或修改样式，桌面组件也会跟着刷新。',
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

  void _updateDraft(TimetableSettings next, {bool debounce = false}) {
    setState(() {
      _draft = next;
    });
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
    _pendingPersist = next;
    if (_isPersisting) {
      return;
    }
    _drainPersistQueue();
  }

  Future<void> _drainPersistQueue() async {
    _isPersisting = true;
    try {
      while (_pendingPersist != null) {
        final next = _pendingPersist!;
        _pendingPersist = null;
        await _persistDraft(next);
      }
    } finally {
      _isPersisting = false;
    }
  }

  Future<void> _persistDraft(TimetableSettings next) async {
    final provider = context.read<TimetableProvider>();
    final message = await provider.updateTimetableSettings(next);
    if (!mounted) {
      return;
    }
    if (message != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      setState(() {
        _draft = provider.settings;
      });
      return;
    }
  }
}

class _LayoutSettingsScreenState extends State<_LayoutSettingsScreen> {
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
      appBar: AppBar(
        title: const Text('布局与节次'),
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
                      _updateDraft(
                        _draft.copyWith(
                          timetableAutoFitSectionHeight: value,
                        ),
                      );
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('隐藏周六周日'),
                    subtitle: const Text('开启后首页只显示周一到周五，剩余列宽会自动铺满。'),
                    value: _draft.timetableHideWeekends,
                    onChanged: (value) {
                      _updateDraft(
                        _draft.copyWith(timetableHideWeekends: value),
                      );
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('启用应用内震动反馈'),
                    subtitle: const Text('关闭后，页码切换等交互不再触发轻微震动。'),
                    value: _draft.enableHaptics,
                    onChanged: (value) {
                      _updateDraft(_draft.copyWith(enableHaptics: value));
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
                      _updateDraft(
                        _draft.copyWith(
                          timetableSectionTimeDisplayMode: value,
                        ),
                      );
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
                            _updateDraft(
                              _draft.copyWith(sectionHeight: value),
                              debounce: true,
                            );
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
                      _updateDraft(
                        _draft.copyWith(compactFontSize: value),
                        debounce: true,
                      );
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
                      _updateDraft(
                        _draft.copyWith(courseCardShowName: value),
                      );
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('显示老师'),
                    value: _draft.courseCardShowTeacher,
                    onChanged: (value) {
                      _updateDraft(
                        _draft.copyWith(courseCardShowTeacher: value),
                      );
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('显示教室'),
                    value: _draft.courseCardShowLocation,
                    onChanged: (value) {
                      _updateDraft(
                        _draft.copyWith(courseCardShowLocation: value),
                      );
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('显示时间'),
                    value: _draft.courseCardShowTime,
                    onChanged: (value) {
                      _updateDraft(
                        _draft.copyWith(courseCardShowTime: value),
                      );
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('显示上课/下课字样'),
                    subtitle: const Text('关闭后仅显示时间点，不显示“上课”“下课”文字。'),
                    value: _draft.courseCardShowTimeLabels,
                    onChanged: _draft.courseCardShowTime
                        ? (value) {
                            _updateDraft(
                              _draft.copyWith(
                                courseCardShowTimeLabels: value,
                              ),
                            );
                          }
                        : null,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('显示周数'),
                    subtitle: const Text('例如第 1-16 周、单双周'),
                    value: _draft.courseCardShowWeeks,
                    onChanged: (value) {
                      _updateDraft(
                        _draft.copyWith(courseCardShowWeeks: value),
                      );
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('显示课程简介'),
                    subtitle: const Text('默认关闭，空间不足时会最先被压缩'),
                    value: _draft.courseCardShowDescription,
                    onChanged: (value) {
                      _updateDraft(
                        _draft.copyWith(
                          courseCardShowDescription: value,
                        ),
                      );
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('显示非本周课程'),
                    subtitle: const Text('默认关闭，开启后会用灰色半透明显示不在当前周的课程'),
                    value: _draft.timetableShowNonCurrentWeekCourses,
                    onChanged: (value) {
                      _updateDraft(
                        _draft.copyWith(
                          timetableShowNonCurrentWeekCourses: value,
                        ),
                      );
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
                      _updateDraft(
                        _draft.copyWith(
                          courseCardVerticalAlign: value,
                        ),
                      );
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
                      _updateDraft(
                        _draft.copyWith(
                          courseCardHorizontalAlign: value,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          Card(
            child: SwitchListTile(
              title: const Text('首页显示冲突小胶囊'),
              subtitle: const Text('关闭后，首页课表不再对冲突课程显示“冲突”小胶囊。'),
              value: _draft.showConflictBadgeOnTimetable,
              onChanged: (value) {
                _updateDraft(
                  _draft.copyWith(showConflictBadgeOnTimetable: value),
                );
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
                  Text(
                    '冲突课程透明度 ${(_draft.timetableConflictCourseOpacity * 100).round()}%',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '冲突课程会自动层叠显示，调低透明度后能同时看到多节课。',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  Slider(
                    value: _draft.timetableConflictCourseOpacity,
                    min: 0.2,
                    max: 1.0,
                    divisions: 16,
                    label:
                        '${(_draft.timetableConflictCourseOpacity * 100).round()}%',
                    onChanged: (value) {
                      _updateDraft(
                        _draft.copyWith(
                          timetableConflictCourseOpacity: value,
                        ),
                        debounce: true,
                      );
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
                    '说明',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '时间模板已移到设置首页。这里主要调课表行高、时间列、周末显示和课程卡片布局；如果你想只改当前课表的时间，先在时间模板里复制一套再应用。',
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

  void _updateDraft(TimetableSettings next, {bool debounce = false}) {
    setState(() {
      _draft = next;
    });
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
    final message = await provider.updateTimetableSettings(
      next.copyWith(
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
      setState(() {
        _draft = provider.settings;
      });
      return;
    }
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
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashFactory: NoSplash.splashFactory,
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) {
            return colorScheme.primary.withValues(alpha: 0.08);
          }
          if (states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.focused)) {
            return colorScheme.primary.withValues(alpha: 0.04);
          }
          return Colors.transparent;
        }),
        child: ListTile(
          leading: Icon(icon),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: trailing ?? const Icon(Icons.chevron_right_rounded),
        ),
      ),
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
    final outlineColor = selected
        ? Theme.of(context).colorScheme.onSurface
        : Theme.of(context).dividerColor.withValues(alpha: 0.72);
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
            color: outlineColor,
            width: selected ? 2 : 1,
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

String _liveDisplaySummary(LiveDisplaySettings settings) {
  final parts = <String>[];
  if (settings.showCourseName) {
    parts.add(settings.useShortName ? '简称' : '课程名');
  }
  if (settings.showLocation) {
    parts.add('地点');
  }
  if (settings.showCountdown) {
    parts.add('倒计时·${settings.countdownTextStyle.label}');
  } else if (settings.showStageText) {
    parts.add('阶段文案');
  }
  if (settings.enableMiuiIslandLabelImage) {
    parts.add('左侧文字图');
  }
  if (parts.isEmpty) {
    return '显示项较少';
  }
  return parts.join(' / ');
}

Color _colorFromHex(String hexColor) {
  final normalized = hexColor.replaceFirst('#', '');
  return Color(int.parse('FF$normalized', radix: 16));
}

String _formatDate(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
