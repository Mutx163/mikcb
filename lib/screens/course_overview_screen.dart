import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/course.dart';
import '../providers/timetable_provider.dart';
import 'add_course_screen.dart';

class CourseOverviewScreen extends StatelessWidget {
  const CourseOverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TimetableProvider>();
    final courses = provider.courses;
    final conflictMap = provider.courseConflictMap;
    final conflictingCourseCount = conflictMap.length;

    // Group courses by name
    final Map<String, List<Course>> groupedCourses = {};
    for (var course in courses) {
      groupedCourses.putIfAbsent(course.name, () => []).add(course);
    }
    final courseNames = groupedCourses.keys.toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('课程总览与编辑'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '添加新课程',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  settings: const RouteSettings(name: '/course/create'),
                  builder: (_) => const AddCourseScreen(),
                ),
              );
            },
          )
        ],
      ),
      body: courseNames.isEmpty
          ? const Center(child: Text('长按课表或点击右上角添加课程'))
          : Column(
              children: [
                if (conflictingCourseCount > 0)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '检测到 $conflictingCourseCount 门排课存在实际冲突，课程列表已标记冲突项。',
                            style: TextStyle(
                              color:
                                  Theme.of(context).colorScheme.onErrorContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: ListView.builder(
                    itemCount: courseNames.length,
                    itemBuilder: (context, index) {
                      final name = courseNames[index];
                      final group = groupedCourses[name]!;

                      final representativeCourse = group.first;
                      final shortNameDisplay =
                          (representativeCourse.shortName != null &&
                                  representativeCourse.shortName!.isNotEmpty)
                              ? ' (${representativeCourse.shortName})'
                              : '';
                      final groupConflictCount = group
                          .where((course) => conflictMap.containsKey(course.id))
                          .length;

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: ExpansionTile(
                          leading: CircleAvatar(
                            backgroundColor: Color(int.parse(
                                'FF${representativeCourse.color.replaceAll('#', '')}',
                                radix: 16)),
                            child: Text(
                              representativeCourse.name.substring(0, 1),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '$name$shortNameDisplay',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (groupConflictCount > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .errorContainer,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    '冲突 $groupConflictCount 节',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onErrorContainer,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Text(
                            groupConflictCount > 0
                                ? '共排课 ${group.length} 节 · 展开查看冲突详情'
                                : '共排课 ${group.length} 节',
                          ),
                          children: group.map((course) {
                            final conflicts = conflictMap[course.id] ?? const [];
                            final conflictSummary =
                                _buildConflictSummary(conflicts);

                            return ListTile(
                              isThreeLine: conflicts.isNotEmpty,
                              title: Text(
                                '时间: 星期${course.dayOfWeek} 第${course.startSection}-${course.endSection}节',
                              ),
                              subtitle: Text(
                                conflicts.isEmpty
                                    ? '第${course.startWeek}-${course.endWeek}周  教师: ${course.teacher.isNotEmpty ? course.teacher : "未置"}  教室: ${course.location.isNotEmpty ? course.location : "未置"}'
                                    : '第${course.startWeek}-${course.endWeek}周  教师: ${course.teacher.isNotEmpty ? course.teacher : "未置"}  教室: ${course.location.isNotEmpty ? course.location : "未置"}\n冲突课程: $conflictSummary',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon:
                                        const Icon(Icons.edit, color: Colors.blue),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          settings: const RouteSettings(
                                              name: '/course/edit'),
                                          builder: (_) =>
                                              AddCourseScreen(course: course),
                                        ),
                                      );
                                    },
                                  ),
                                  IconButton(
                                    icon:
                                        const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () =>
                                        _confirmDelete(context, course),
                                  ),
                                ],
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    settings:
                                        const RouteSettings(name: '/course/edit'),
                                    builder: (_) =>
                                        AddCourseScreen(course: course),
                                  ),
                                );
                              },
                            );
                          }).toList(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  String _buildConflictSummary(List<Course> conflicts) {
    final labels = conflicts
        .map((course) {
          final weekMode = course.isOddWeek
              ? ' 单周'
              : course.isEvenWeek
                  ? ' 双周'
                  : '';
          return '${course.name}(第${course.startWeek}-${course.endWeek}周$weekMode 星期${course.dayOfWeek} ${course.startSection}-${course.endSection}节)';
        })
        .toSet()
        .toList();
    return labels.join('、');
  }

  void _confirmDelete(BuildContext context, Course course) {
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('确认删除'),
              content: Text('确定要删除课程“${course.name}”吗？'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () {
                    context.read<TimetableProvider>().deleteCourse(course.id);
                    Navigator.pop(ctx);
                  },
                  child: const Text('删除', style: TextStyle(color: Colors.red)),
                ),
              ],
            ));
  }
}
