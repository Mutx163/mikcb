import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/course.dart';
import '../models/timetable_settings.dart';
import '../providers/timetable_provider.dart';
import '../services/miui_live_activities_service.dart';
import '../widgets/course_card.dart';
import 'add_course_screen.dart';
import 'course_overview_screen.dart';
import 'timetable_settings_screen.dart';

class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  static const double _headerControlWidth = 58;
  static const double _timeColumnWidth = 40;
  static const int _minWeek = 1;
  static const int _maxWeek = 20;
  static const int _centerWeekPage = 1;
  static const Duration _weekSlideDuration = Duration(milliseconds: 280);

  final List<String> _weekDays = const ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

  late final PageController _weekPageController;
  bool _isSyncingWeekPage = false;

  @override
  void initState() {
    super.initState();
    _weekPageController = PageController(initialPage: _centerWeekPage);
  }

  @override
  void dispose() {
    _weekPageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TimetableProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('课程表'),
            actions: [
              PopupMenuButton<String>(
                tooltip: '更多',
                onSelected: _handleTopMenuAction,
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'overview',
                    child: Text('课程总览'),
                  ),
                  PopupMenuItem(
                    value: 'test',
                    child: Text('测试通知'),
                  ),
                  PopupMenuItem(
                    value: 'import',
                    child: Text('导入课程'),
                  ),
                  PopupMenuItem(
                    value: 'settings',
                    child: Text('课表设置'),
                  ),
                  PopupMenuItem(
                    value: 'add',
                    child: Text('添加课程'),
                  ),
                ],
              ),
            ],
          ),
          body: provider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return _buildWeekPager(
                        provider,
                        provider.settings,
                        constraints.maxWidth,
                      );
                    },
                  ),
                ),
        );
      },
    );
  }

  Widget _buildWeekDayHeader(
    TimetableProvider provider,
    int week,
    TimetableSettings settings,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: 50,
      padding: const EdgeInsets.fromLTRB(0, 1, 0, 4),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: _headerControlWidth,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildHeaderArrow(
                      icon: Icons.chevron_left_rounded,
                      tooltip: '上一周',
                      onPressed: week > _minWeek
                          ? () => _jumpToWeek(provider, week - 1)
                          : null,
                    ),
                    InkWell(
                      onTap: _showWeekSelector,
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                        child: Text(
                          '$week周',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                    _buildHeaderArrow(
                      icon: Icons.chevron_right_rounded,
                      tooltip: '下一周',
                      onPressed: week < _maxWeek
                          ? () => _jumpToWeek(provider, week + 1)
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                InkWell(
                  onTap: () => _jumpToCurrentWeek(provider),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    child: Text(
                      '回本周',
                      style: TextStyle(
                        fontSize: 8,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          ...List.generate(_weekDays.length, (index) {
            final dayOfWeek = index + 1;
            final date = _dateForWeekDay(settings, week, dayOfWeek);
            final isToday = date != null && _isSameDate(date, DateTime.now());

            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.symmetric(horizontal: 1),
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isToday ? colorScheme.primary : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _weekDays[index],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                        color: isToday
                            ? colorScheme.primary
                            : colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      date == null
                          ? ''
                          : '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        fontSize: 8.5,
                        color: isToday
                            ? colorScheme.primary.withValues(alpha: 0.78)
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildHeaderArrow({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 14,
          height: 14,
          child: Icon(
            icon,
            size: 14,
            color: onPressed == null
                ? colorScheme.outline
                : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _buildTimetableGrid(
    TimetableProvider provider,
    TimetableSettings settings,
    double availableWidth,
    int week,
  ) {
    final dayWidth = (availableWidth - _timeColumnWidth) / 7;
    final sectionHeight = settings.sectionHeight;

    return SizedBox(
      key: ValueKey<int>(week),
      width: availableWidth,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: _timeColumnWidth,
            child: Column(
              children: List.generate(settings.sectionCount, (index) {
                final section = settings.sections[index];
                return Container(
                  height: sectionHeight,
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontSize: (settings.compactFontSize).clamp(8.0, 11.0),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        section.startTime,
                        style: TextStyle(
                          fontSize: (settings.compactFontSize - 2).clamp(6.0, 10.0),
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
          Row(
            children: List.generate(7, (dayIndex) {
              final dayOfWeek = dayIndex + 1;
              final dayCourses = _getCoursesForDay(
                provider.courses,
                week,
                dayOfWeek,
              );
              return SizedBox(
                width: dayWidth,
                child: _buildDayColumn(dayOfWeek, dayCourses, settings),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekPager(
    TimetableProvider provider,
    TimetableSettings settings,
    double availableWidth,
  ) {
    return PageView.builder(
      controller: _weekPageController,
      itemCount: 3,
      allowImplicitScrolling: true,
      physics: const PageScrollPhysics(parent: ClampingScrollPhysics()),
      onPageChanged: (page) => _handleWeekPageChanged(page, provider),
      itemBuilder: (context, index) {
        final week = _clampWeek(
          provider.currentWeek + (index - _centerWeekPage),
        );
        return _buildWeekPage(provider, settings, availableWidth, week);
      },
    );
  }

  Widget _buildWeekPage(
    TimetableProvider provider,
    TimetableSettings settings,
    double availableWidth,
    int week,
  ) {
    return Column(
      children: [
        _buildWeekDayHeader(provider, week, settings),
        Expanded(
          child: SingleChildScrollView(
            key: PageStorageKey<String>('week-scroll-$week'),
            child: _buildTimetableGrid(provider, settings, availableWidth, week),
          ),
        ),
      ],
    );
  }

  Widget _buildDayColumn(
    int dayOfWeek,
    List<Course> courses,
    TimetableSettings settings,
  ) {
    final sectionHeight = settings.sectionHeight;
    final courseCards = <Widget>[];
    final gridLines = <Widget>[];

    for (var sectionIndex = 0; sectionIndex < settings.sectionCount; sectionIndex++) {
      final section = sectionIndex + 1;
      final course = _findCourseForSection(courses, section);

      gridLines.add(
        Positioned(
          top: sectionIndex * sectionHeight,
          left: 0,
          right: 0,
          height: sectionHeight,
          child: GestureDetector(
            onTap: () => _addCourseAt(dayOfWeek, section),
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade200),
                ),
              ),
            ),
          ),
        ),
      );

      if (course != null && section == course.startSection) {
        courseCards.add(
          Positioned(
            top: sectionIndex * sectionHeight,
            left: 2,
            right: 2,
            height: course.sectionCount * sectionHeight - 4,
            child: CourseCard(
              course: course,
              isCompact: true,
              onTap: () => _editCourse(course),
              compactTitleFontSize: settings.compactFontSize,
              compactSubtitleFontSize:
                  (settings.compactFontSize - 1).clamp(7.0, 14.0),
              compactVerticalPadding: settings.sectionHeight < 64 ? 4 : 6,
            ),
          ),
        );
      }
    }

    return Container(
      height: settings.sectionCount * sectionHeight,
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Stack(
        children: [
          ...gridLines,
          ...courseCards,
        ],
      ),
    );
  }

  void _showWeekSelector() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        final provider = context.read<TimetableProvider>();
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '选择周次',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(20, (index) {
                  final week = index + 1;
                  return ActionChip(
                    label: Text('第 $week 周'),
                    onPressed: () {
                      Navigator.pop(context);
                      _jumpToWeek(provider, week);
                    },
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }



  Course? _findCourseForSection(List<Course> courses, int section) {
    for (final course in courses) {
      if (section >= course.startSection && section <= course.endSection) {
        return course;
      }
    }
    return null;
  }

  List<Course> _getCoursesForDay(List<Course> allCourses, int week, int dayOfWeek) {
    return allCourses
        .where((course) => course.dayOfWeek == dayOfWeek && course.isInWeek(week))
        .toList()
      ..sort((a, b) => a.startSection.compareTo(b.startSection));
  }

  int _clampWeek(int week) {
    if (week < _minWeek) return _minWeek;
    if (week > _maxWeek) return _maxWeek;
    return week;
  }

  DateTime? _dateForWeekDay(
    TimetableSettings settings,
    int week,
    int dayOfWeek,
  ) {
    final semesterStart = settings.semesterStartDate;
    if (semesterStart == null) {
      return null;
    }

    final normalizedStart = DateTime(
      semesterStart.year,
      semesterStart.month,
      semesterStart.day,
    ).subtract(Duration(days: semesterStart.weekday - 1));

    return normalizedStart.add(Duration(days: (week - 1) * 7 + dayOfWeek - 1));
  }

  bool _isSameDate(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }

  Future<void> _jumpToCurrentWeek(TimetableProvider provider) async {
    if (provider.settings.semesterStartDate == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先在课表设置里填写开学日期')),
      );
      return;
    }

    await provider.syncCurrentWeekWithSemesterStart();
    await _resetWeekPager();
    HapticFeedback.selectionClick();
  }

  Future<void> _animateToAdjacentWeek(
    TimetableProvider provider,
    int delta,
  ) async {
    if (_isSyncingWeekPage || !_weekPageController.hasClients) {
      return;
    }

    final targetWeek = _clampWeek(provider.currentWeek + delta);
    if (targetWeek == provider.currentWeek) {
      return;
    }

    await _weekPageController.animateToPage(
      delta < 0 ? _centerWeekPage - 1 : _centerWeekPage + 1,
      duration: _weekSlideDuration,
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _jumpToWeek(TimetableProvider provider, int week) async {
    if (_isSyncingWeekPage) {
      return;
    }

    final targetWeek = _clampWeek(week);
    if (targetWeek == provider.currentWeek) {
      return;
    }

    final delta = targetWeek - provider.currentWeek;
    if (delta.abs() == 1) {
      await _animateToAdjacentWeek(provider, delta.sign);
      return;
    }

    await provider.setCurrentWeek(targetWeek);
    await _resetWeekPager();
  }

  Future<void> _handleWeekPageChanged(
    int page,
    TimetableProvider provider,
  ) async {
    if (_isSyncingWeekPage || page == _centerWeekPage) {
      return;
    }

    final targetWeek = _clampWeek(
      provider.currentWeek + (page - _centerWeekPage),
    );
    if (targetWeek == provider.currentWeek) {
      await _resetWeekPager(animated: true);
      return;
    }

    _isSyncingWeekPage = true;
    try {
      HapticFeedback.selectionClick();
      await provider.setCurrentWeek(targetWeek);
      await _resetWeekPager();
    } finally {
      _isSyncingWeekPage = false;
    }
  }

  Future<void> _resetWeekPager({bool animated = false}) async {
    if (!_weekPageController.hasClients) {
      return;
    }

    if (animated) {
      await _weekPageController.animateToPage(
        _centerWeekPage,
        duration: _weekSlideDuration,
        curve: Curves.easeOutCubic,
      );
      return;
    }

    _weekPageController.jumpToPage(_centerWeekPage);
  }

  void _navigateToAddCourse(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddCourseScreen(),
      ),
    );
  }

  void _addCourseAt(int dayOfWeek, int section) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddCourseScreen(
          initialDayOfWeek: dayOfWeek,
          initialStartSection: section,
        ),
      ),
    );
  }

  void _editCourse(Course course) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddCourseScreen(course: course),
      ),
    );
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const TimetableSettingsScreen(),
      ),
    );
  }

  void _handleTopMenuAction(String value) {
    switch (value) {
      case 'overview':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const CourseOverviewScreen()),
        );
        break;
      case 'test':
        _showTestOptions();
        break;
      case 'import':
        _importCalendarFile();
        break;
      case 'settings':
        _openSettings();
        break;
      case 'add':
        _navigateToAddCourse(context);
        break;
    }
  }

  Future<void> _importCalendarFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['ics'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      return;
    }

    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法读取所选文件')),
      );
      return;
    }

    if (!mounted) return;
    final replaceExisting = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('导入课程'),
          content: Text('导入 ${file.name} 时，是否替换现有课程？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('追加导入'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('替换现有'),
            ),
          ],
        );
      },
    );

    if (replaceExisting == null || !mounted) {
      return;
    }

    final content = utf8.decode(bytes, allowMalformed: true);
    final importedCount = await context.read<TimetableProvider>().importWakeUpCalendar(
          content,
          replaceExisting: replaceExisting,
        );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(importedCount > 0 ? '已导入 $importedCount 条课程' : '未识别到可导入课程'),
      ),
    );
  }

  void _showTestOptions() async {
    final now = DateTime.now();
    final start = now.add(const Duration(minutes: 2));
    final end = now.add(const Duration(minutes: 3));

    String formatTime(DateTime dt) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }

    final provider = context.read<TimetableProvider>();
    final settings = provider.settings;
    final selection = provider.getTestLiveActivityCourseSelection(now: now);
    final baseCourse = selection?.currentCourse;
    final previewNextCourse = selection?.nextCourse;

    final resolvedShortName = baseCourse == null
        ? null
        : provider.resolveCourseShortName(baseCourse);

    final testCourse = Course(
      id: 'test_auto_id',
      name: baseCourse?.name ?? '智能测试模拟课',
      shortName: resolvedShortName,
      teacher: baseCourse?.teacher ?? '模拟教员',
      location: baseCourse?.location ?? '虚拟教室',
      dayOfWeek: now.weekday,
      startSection: baseCourse?.startSection ?? 1,
      endSection: baseCourse?.endSection ?? 2,
      startWeek: baseCourse?.startWeek ?? 1,
      endWeek: baseCourse?.endWeek ?? 20,
      startTime: formatTime(start),
      endTime: formatTime(end),
      color: baseCourse?.color ?? '#4285F4',
      note: '此处展示备注。可以在课程编辑页进行设置。',
    );

    final shortName = (testCourse.shortName ?? '').trim();
    final islandName =
        settings.liveUseShortName && shortName.isNotEmpty
            ? shortName
            : testCourse.name;

    if (!mounted) return;
    final shouldSend = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('测试通知预览'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('课程全名：${testCourse.name}'),
              Text('课程简称：${shortName.isEmpty ? "未设置" : shortName}'),
              Text('简称开关：${settings.liveUseShortName ? "已开启" : "已关闭"}'),
              Text('岛区预期：$islandName'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('发送'),
            ),
          ],
        );
      },
    );

    if (shouldSend != true || !mounted) {
      return;
    }

    try {
      await MiuiLiveActivitiesService().startLiveUpdate(
        testCourse, 
        previewNextCourse,
        showCountdown: settings.liveShowCountdown,
        showCourseNameInIsland: settings.liveShowCourseName,
        showLocationInIsland: settings.liveShowLocation,
        useShortNameInIsland: settings.liveUseShortName,
        hidePrefixText: settings.liveHidePrefixText,
        autoDismissAfterStartMinutes: 1,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已发射测试通知（距上课2分钟，持续1分），马上体验实机效果。')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('发送失败: $e')),
      );
    }
  }
}
