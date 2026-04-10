import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../models/course.dart';
import '../providers/timetable_provider.dart';
import 'add_course_screen.dart';

class CourseOverviewScreen extends StatelessWidget {
  const CourseOverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
        title: Text(l10n.courseOverviewTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: l10n.addNewCourseTooltip,
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
          ? Center(child: Text(l10n.emptyCourseOverviewHint))
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
                            l10n.conflictDetectedMessage(conflictingCourseCount),
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onErrorContainer,
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
                                    l10n.conflictCountLabel(groupConflictCount),
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
                                ? l10n.scheduledCountWithConflictHint(group.length)
                                : l10n.scheduledCountLabel(group.length),
                          ),
                          children: group.map((course) {
                            final conflicts =
                                conflictMap[course.id] ?? const [];
                            final conflictSummary =
                                _buildConflictSummary(context, conflicts);

                            return ListTile(
                              isThreeLine: conflicts.isNotEmpty,
                              title: Text(
                                l10n.courseTimeSummary(
                                  course.dayOfWeek,
                                  course.startSection,
                                  course.endSection,
                                ),
                              ),
                              subtitle: Text(
                                conflicts.isEmpty
                                    ? l10n.courseDetailSummary(
                                        course.weekDescription,
                                        course.teacher.isNotEmpty
                                            ? course.teacher
                                            : l10n.teacherUnset,
                                        course.location.isNotEmpty
                                            ? course.location
                                            : l10n.locationUnset,
                                      )
                                    : l10n.courseDetailSummaryWithConflict(
                                        course.weekDescription,
                                        course.teacher.isNotEmpty
                                            ? course.teacher
                                            : l10n.teacherUnset,
                                        course.location.isNotEmpty
                                            ? course.location
                                            : l10n.locationUnset,
                                        conflictSummary,
                                      ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit,
                                        color: Colors.blue),
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
                                    icon: const Icon(Icons.delete,
                                        color: Colors.red),
                                    onPressed: () =>
                                        _confirmDelete(context, course),
                                  ),
                                ],
                              ),
                              onTap: () {
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

  String _buildConflictSummary(BuildContext context, List<Course> conflicts) {
    final l10n = AppLocalizations.of(context)!;
    final labels = conflicts
        .map((course) {
          return '${course.name}(${course.weekDescription} ${l10n.weekdaySectionSummary(_weekdayShortLabel(l10n, course.dayOfWeek), course.startSection, course.endSection)})';
        })
        .toSet()
        .toList();
    return labels.join('、');
  }

  String _weekdayShortLabel(AppLocalizations l10n, int dayOfWeek) {
    return switch (dayOfWeek) {
      1 => l10n.weekdayShortMonday,
      2 => l10n.weekdayShortTuesday,
      3 => l10n.weekdayShortWednesday,
      4 => l10n.weekdayShortThursday,
      5 => l10n.weekdayShortFriday,
      6 => l10n.weekdayShortSaturday,
      7 => l10n.weekdayShortSunday,
      _ => dayOfWeek.toString(),
    };
  }

  void _confirmDelete(BuildContext context, Course course) {
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              title: Text(AppLocalizations.of(ctx)!.confirmDeleteTitle),
              content: Text(
                AppLocalizations.of(ctx)!.confirmDeleteCourseMessage(course.name),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(AppLocalizations.of(ctx)!.cancelAction),
                ),
                TextButton(
                  onPressed: () {
                    context.read<TimetableProvider>().deleteCourse(course.id);
                    Navigator.pop(ctx);
                  },
                  child: Text(
                    AppLocalizations.of(ctx)!.deleteAction,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ));
  }
}
