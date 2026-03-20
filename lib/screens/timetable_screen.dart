import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/course.dart';
import '../models/timetable_settings.dart';
import '../providers/timetable_provider.dart';
import '../services/miui_live_activities_service.dart';
import '../widgets/course_card.dart';
import 'add_course_screen.dart';
import 'timetable_settings_screen.dart';

class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  static const double _timeColumnWidth = 44;

  final List<String> _weekDays = const ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

  @override
  Widget build(BuildContext context) {
    return Consumer<TimetableProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text(
              '课程表',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            actionsIconTheme: const IconThemeData(size: 20),
            actions: [
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.chevron_left),
                onPressed: provider.currentWeek > 1
                    ? () => provider.setCurrentWeek(provider.currentWeek - 1)
                    : null,
                tooltip: '上一周',
              ),
              TextButton(
                onPressed: _showWeekSelector,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  '第${provider.currentWeek}周',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.chevron_right),
                onPressed: provider.currentWeek < 20
                    ? () => provider.setCurrentWeek(provider.currentWeek + 1)
                    : null,
                tooltip: '下一周',
              ),
              PopupMenuButton<String>(
                tooltip: '更多',
                onSelected: _handleTopMenuAction,
                itemBuilder: (context) => const [
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
              : Column(
                  children: [
                    _buildWeekDayHeader(),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return _buildTimetableGrid(
                            provider,
                            provider.settings,
                            constraints.maxWidth,
                          );
                        },
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildWeekDayHeader() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: _timeColumnWidth,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                '节次',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          ...List.generate(_weekDays.length, (index) {
            final isToday = index + 1 == DateTime.now().weekday;
            return Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isToday ? Theme.of(context).primaryColor.withValues(alpha: 0.1) : null,
                  border: Border(
                    bottom: BorderSide(
                      color: isToday ? Theme.of(context).primaryColor : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  _weekDays[index],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                    color: isToday ? Theme.of(context).primaryColor : null,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTimetableGrid(
    TimetableProvider provider,
    TimetableSettings settings,
    double availableWidth,
  ) {
    final dayWidth = (availableWidth - _timeColumnWidth) / 7;
    final sectionHeight = settings.sectionHeight;

    return SingleChildScrollView(
      child: SizedBox(
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
                            fontSize: settings.compactFontSize + 1,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          section.startTime,
                          style: TextStyle(
                            fontSize: (settings.compactFontSize - 1).clamp(7.0, 14.0),
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
                final dayCourses = provider.getCoursesForDay(dayOfWeek);
                return SizedBox(
                  width: dayWidth,
                  child: _buildDayColumn(dayOfWeek, dayCourses, settings),
                );
              }),
            ),
          ],
        ),
      ),
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
              onTap: () => _showCourseDetail(course),
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
                      context.read<TimetableProvider>().setCurrentWeek(week);
                      Navigator.pop(context);
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

  void _showCourseDetail(Course course) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                course.name,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _buildDetailRow(Icons.location_on, '教室', course.location),
              _buildDetailRow(Icons.person, '教师', course.teacher),
              _buildDetailRow(Icons.access_time, '时间', '${course.startTime} - ${course.endTime}'),
              _buildDetailRow(Icons.calendar_today, '周次', '第${course.startWeek}-${course.endWeek}周'),
              _buildDetailRow(Icons.view_agenda, '节次', '第${course.startSection}-${course.endSection}节'),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _editCourse(course);
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text('编辑'),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _deleteCourse(course);
                    },
                    icon: const Icon(Icons.delete),
                    label: const Text('删除'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value)),
        ],
      ),
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

  void _deleteCourse(Course course) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('确认删除'),
          content: Text('确定要删除课程“${course.name}”吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                context.read<TimetableProvider>().deleteCourse(course.id);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('课程已删除')),
                );
              },
              child: const Text('删除', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  void _showTestOptions() async {
    final service = MiuiLiveActivitiesService();
    final supportInfo = await service.checkPromotedSupport();

    if (!mounted) return;

    final androidVersion = supportInfo['androidVersion'] ?? 0;
    final hasPermission = supportInfo['hasNotificationPermission'] == true;
    final hasPromotedPermission = supportInfo['hasPromotedPermission'] == true;
    final canPostPromoted = supportInfo['canPostPromoted'] == true;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('实时更新检查'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Android 版本: $androidVersion'),
            Text('通知权限: ${hasPermission ? "✅" : "❌"}'),
            Text('推广权限声明: ${hasPromotedPermission ? "✅" : "❌"}'),
            Text('可发布推广: ${canPostPromoted ? "✅" : "❌"}'),
            const Divider(),
            if (!canPostPromoted && androidVersion >= 36)
              const Text(
                '需要在系统设置中为应用开启实时更新或推广通知。',
                style: TextStyle(color: Colors.orange),
              ),
          ],
        ),
        actions: [
          if (!canPostPromoted && androidVersion >= 36)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                service.openPromotedSettings();
              },
              child: const Text('打开设置'),
            ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _sendTestNotification();
            },
            child: const Text('继续测试'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  void _sendTestNotification() async {
    final service = MiuiLiveActivitiesService();
    final hasPermission = await service.checkNotificationPermission();
    if (!hasPermission) {
      final granted = await service.requestNotificationPermission();
      if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('需要通知权限')),
          );
        }
        return;
      }
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('5 秒后发送测试通知，请返回桌面观察效果'),
        duration: Duration(seconds: 2),
      ),
    );

    await Future.delayed(const Duration(seconds: 5));

    final now = DateTime.now();
    final startTime = now.add(const Duration(minutes: 10));
    final endTime = startTime.add(const Duration(minutes: 45));
    final nextStartTime = endTime.add(const Duration(minutes: 10));
    final nextEndTime = nextStartTime.add(const Duration(minutes: 45));

    final testCurrentCourse = Course(
      id: 'test-1',
      name: '高等数学',
      teacher: '张老师',
      location: '教学楼 A301',
      dayOfWeek: 1,
      startSection: 1,
      endSection: 2,
      startTime: _formatTime(startTime),
      endTime: _formatTime(endTime),
      color: '#2196F3',
    );

    final testNextCourse = Course(
      id: 'test-2',
      name: '大学英语',
      teacher: '李老师',
      location: '教学楼 B205',
      dayOfWeek: 1,
      startSection: 3,
      endSection: 4,
      startTime: _formatTime(nextStartTime),
      endTime: _formatTime(nextEndTime),
      color: '#4CAF50',
    );

    await service.startLiveUpdate(
      testCurrentCourse,
      testNextCourse,
      autoDismissAfterStartMinutes: 1,
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
