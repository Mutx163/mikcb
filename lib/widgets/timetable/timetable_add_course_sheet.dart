import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../ui/hyperos/hyperos.dart';
import 'timetable_form_pages.dart';
import 'timetable_home_action_page_button.dart';

/// 首页「+」新增弹层（课程 / 日程 / 考试三宫格，2026-10-20 从课表页搬出）。
///
/// 三个格子的目标页面由 screens 层构造（[timetableFormPages]），本文件只负责
/// 弹层外观与把上下文原样递过去：课程格带 `initialWeek` / `initialDayOfWeek`，
/// 日程格带 `initialDate`，考试格不带上下文（新建）。
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
                pageBuilder: (_) => timetableFormPages.courseForm(
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
                pageBuilder: (_) => timetableFormPages.scheduleItemForm(
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
                pageBuilder: (_) => timetableFormPages.examForm(),
              ),
            ),
          ],
        ),
      );
    },
  );
}
