import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/course.dart';
import '../providers/timetable_provider.dart';
import 'add_course_screen.dart';

class CourseOverviewScreen extends StatelessWidget {
  const CourseOverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final courses = context.watch<TimetableProvider>().courses;
    
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
                MaterialPageRoute(builder: (_) => const AddCourseScreen()),
              );
            },
          )
        ],
      ),
      body: courseNames.isEmpty
          ? const Center(child: Text('长按课表或点击右上角添加课程'))
          : ListView.builder(
              itemCount: courseNames.length,
              itemBuilder: (context, index) {
                final name = courseNames[index];
                final group = groupedCourses[name]!;
                
                // Assume all instances of the same course likely share the same color and shortName layout
                final representativeCourse = group.first;
                final shortNameDisplay = (representativeCourse.shortName != null && representativeCourse.shortName!.isNotEmpty)
                    ? ' (${representativeCourse.shortName})'
                    : '';

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ExpansionTile(
                    leading: CircleAvatar(
                      backgroundColor: Color(int.parse('FF${representativeCourse.color.replaceAll('#', '')}', radix: 16)),
                      child: Text(
                        representativeCourse.name.substring(0, 1),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text('$name$shortNameDisplay', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('共排课 ${group.length} 节'),
                    children: group.map((course) {
                      return ListTile(
                        title: Text('时间: 星期${course.dayOfWeek} 第${course.startSection}-${course.endSection}节'),
                        subtitle: Text('第${course.startWeek}-${course.endWeek}周  教师: ${course.teacher.isNotEmpty ? course.teacher : "未置"}  教室: ${course.location.isNotEmpty ? course.location : "未置"}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => AddCourseScreen(course: course)),
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _confirmDelete(context, course),
                            ),
                          ],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => AddCourseScreen(course: course)),
                          );
                        },
                      );
                    }).toList(),
                  ),
                );
              },
            ),
    );
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
      )
    );
  }
}
