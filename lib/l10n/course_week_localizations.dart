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
