import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../screens/add_course_screen.dart';
import '../../screens/add_exam_screen.dart';
import '../../screens/add_schedule_item_screen.dart';
import '../../ui/hyperos/hyperos.dart';
import 'timetable_home_action_page_button.dart';

/// 首页「+」新增弹层（课程 / 日程 / 考试三宫格，2026-10-20 从课表页搬出）。
Future<void> showTimetableAddCourseSheet({
  required BuildContext context,
  required int initialWeek,
  required int initialDayOfWeek,
  required DateTime initialScheduleDate,
}) {
  final l10n = AppLocalizations.of(context)!;
  return showHomeHyperosSheet<void>(
    context: context,
    builder: (sheetContext) {
      final itemWidth =
          ((MediaQuery.sizeOf(sheetContext).width - 32 - 24) / 3).clamp(
            96.0,
            120.0,
          );

      return HyperosSheet(
        title: l10n.addCourseSheetTitle,
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: itemWidth,
              child: TimetableHomeActionPageButton(
                sheetRoute: ModalRoute.of(sheetContext),
                icon: Icons.view_week_rounded,
                title: l10n.addCourseTitle,
                pageBuilder: (_) => AddCourseScreen(
                  initialWeek: initialWeek,
                  initialDayOfWeek: initialDayOfWeek,
                ),
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: TimetableHomeActionPageButton(
                sheetRoute: ModalRoute.of(sheetContext),
                icon: Icons.event_note_rounded,
                title: l10n.addScheduleAction,
                pageBuilder: (_) => AddScheduleItemScreen(
                  initialDate: initialScheduleDate,
                ),
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: TimetableHomeActionPageButton(
                sheetRoute: ModalRoute.of(sheetContext),
                icon: Icons.school_outlined,
                title: l10n.addExam,
                pageBuilder: (_) => const AddExamScreen(),
              ),
            ),
          ],
        ),
      );
    },
  );
}
