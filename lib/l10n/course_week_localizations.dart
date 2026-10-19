import 'app_localizations.dart';
import '../models/course.dart';

String formatCourseWeekList(AppLocalizations l10n, List<int> weeks) {
  if (weeks.isEmpty) {
    return '';
  }
  final ranges = <String>[];
  var rangeStart = weeks.first;
  var previous = weeks.first;

  for (var index = 1; index < weeks.length; index++) {
    final current = weeks[index];
    if (current == previous + 1) {
      previous = current;
      continue;
    }
    ranges.add(
      rangeStart == previous ? '$rangeStart' : '$rangeStart-$previous',
    );
    rangeStart = current;
    previous = current;
  }

  ranges.add(
    rangeStart == previous ? '$rangeStart' : '$rangeStart-$previous',
  );
  return ranges.join(l10n.weekListSeparator);
}

String courseWeekDescription(AppLocalizations l10n, Course course) {
  final custom = course.normalizedCustomWeeks;
  if (custom != null) {
    return l10n.courseWeekListLabel(formatCourseWeekList(l10n, custom));
  }

  final mode = course.isOddWeek
      ? ' ${l10n.oddWeeksFilter}'
      : course.isEvenWeek
      ? ' ${l10n.evenWeeksFilter}'
      : '';
  return l10n.courseWeekRangeLabel(course.startWeek, course.endWeek, mode);
}

String? courseSuspensionDescription(AppLocalizations l10n, Course course) {
  final suspended = course.normalizedSuspendedWeeks;
  if (suspended == null || suspended.isEmpty) {
    return null;
  }
  return l10n.courseWeekSuspendedLabel(
    formatCourseWeekList(l10n, suspended),
  );
}

/// 周次文案的调用点门面。
///
/// 2026-10-19 从 `Course` 搬到这里：此前 `models/course.dart` 反向 import 本文件、
/// 本文件又 import `models/course.dart`，形成全仓唯一一组真循环（架构审计 C3）。
/// 模型不该依赖本地化基类，所以「怎么把周次说成人话」留在 l10n 层，
/// 模型只提供 `normalizedCustomWeeks` / `startWeek` 这类纯数据。
///
/// 调用点写法不变：`course.weekDescription(l10n)`（需要 import 本文件）。
extension CourseWeekDescriptions on Course {
  String weekDescription(AppLocalizations l10n) =>
      courseWeekDescription(l10n, this);

  String? suspensionDescription(AppLocalizations l10n) =>
      courseSuspensionDescription(l10n, this);
}
