import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

import '../models/course.dart';
import '../providers/timetable_provider.dart';
import 'add_course_screen.dart';

/// Lists undirected conflict pairs with schedule detail and jump-to-edit.
class CourseConflictScreen extends StatelessWidget {
  const CourseConflictScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<TimetableProvider>();
    final pairs = _buildConflictPairs(provider);

    return HyperosSubpage(
      onBack: () => Navigator.pop(context),
      title: Text(l10n.courseConflictDetailTitle),
      child: pairs.isEmpty
          ? Center(
              child: Text(
                l10n.courseConflictEmpty,
                style: HyperosTypography.listDetail(context),
              ),
            )
          : HyperosListView(
              children: [
                for (var index = 0; index < pairs.length; index++) ...[
                  if (index > 0) const HyperosSectionGap(),
                  HyperosSectionLabel(
                    text: '${l10n.courseConflictPairTitle} ${index + 1}',
                  ),
                  HyperosListGroup(
                    children: [
                      _ConflictCourseRow(
                        course: pairs[index].left,
                        partner: pairs[index].right,
                        onOpen: () => _openCourseEditor(
                          context,
                          provider,
                          pairs[index].left,
                        ),
                      ),
                      _ConflictCourseRow(
                        course: pairs[index].right,
                        partner: pairs[index].left,
                        onOpen: () => _openCourseEditor(
                          context,
                          provider,
                          pairs[index].right,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
    );
  }

  static List<({Course left, Course right})> _buildConflictPairs(
    TimetableProvider provider,
  ) {
    final conflictMap = provider.courseConflictMap;
    final coursesById = {
      for (final course in provider.courses) course.id: course,
    };
    final pairs = <String, ({Course left, Course right})>{};

    for (final entry in conflictMap.entries) {
      final left = coursesById[entry.key];
      if (left == null) {
        continue;
      }
      for (final right in entry.value) {
        final pairKey = left.id.compareTo(right.id) < 0
            ? '${left.id}|${right.id}'
            : '${right.id}|${left.id}';
        if (pairs.containsKey(pairKey)) {
          continue;
        }
        final ordered = left.id.compareTo(right.id) < 0
            ? (left: left, right: right)
            : (left: right, right: left);
        pairs[pairKey] = ordered;
      }
    }

    final result = pairs.values.toList()
      ..sort((a, b) {
        final day = a.left.dayOfWeek.compareTo(b.left.dayOfWeek);
        if (day != 0) {
          return day;
        }
        return a.left.startSection.compareTo(b.left.startSection);
      });
    return result;
  }

  static void _openCourseEditor(
    BuildContext context,
    TimetableProvider provider,
    Course course,
  ) {
    CourseGroup? group;
    for (final candidate in provider.courseGroups) {
      if (candidate.courses.any((item) => item.id == course.id)) {
        group = candidate;
        break;
      }
    }
    if (group == null) {
      return;
    }
    Navigator.of(context).push(
      HyperosPageRoute(
        settings: const RouteSettings(name: '/course/edit-conflict'),
        builder: (_) =>
            AddCourseScreen(courseGroup: group, initialCourse: course),
      ),
    );
  }
}

class _ConflictCourseRow extends StatelessWidget {
  const _ConflictCourseRow({
    required this.course,
    required this.partner,
    required this.onOpen,
  });

  final Course course;
  final Course partner;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dayLabel = _weekdayShort(l10n, course.dayOfWeek);
    final schedule = l10n.weekdaySectionSummary(
      dayLabel,
      course.startSection,
      course.endSection,
    );
    final weeks =
        l10n.weekLabel(course.startWeek) == l10n.weekLabel(course.endWeek)
        ? l10n.weekLabel(course.startWeek)
        : '${l10n.weekLabel(course.startWeek)}-${course.endWeek}';

    return HyperosPressableRow(
      onTap: onOpen,
      backgroundColor: HyperosColors.card(context),
      highlightColor: HyperosColors.rowHighlight(context),
      child: Padding(
        padding: hyperosChevronRowPadding(context),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    course.name,
                    style: HyperosTypography.listTitle(context),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$schedule · $weeks',
                    style: HyperosTypography.listDetail(context),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.courseConflictWithCourse(partner.name),
                    style: HyperosTypography.listDetail(
                      context,
                    ).copyWith(color: HyperosColors.error(context)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            SizedBox(width: HyperosTokens.titleChevronGap),
            const HyperosChevron(),
          ],
        ),
      ),
    );
  }

  static String _weekdayShort(AppLocalizations l10n, int dayOfWeek) {
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
}
