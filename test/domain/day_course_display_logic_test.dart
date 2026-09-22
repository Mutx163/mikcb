import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/domain/couple_timetable_logic.dart';
import 'package:university_timetable/domain/day_course_display_logic.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/timetable_settings.dart';

Course _course({
  required String id,
  String name = '高数',
  int dayOfWeek = 1,
  int startSection = 1,
  int endSection = 2,
  int startWeek = 1,
  int endWeek = 16,
}) {
  return Course(
    id: id,
    name: name,
    teacher: '张老师',
    location: 'A101',
    dayOfWeek: dayOfWeek,
    startSection: startSection,
    endSection: endSection,
    startTime: '08:00',
    endTime: '09:40',
    startWeek: startWeek,
    endWeek: endWeek,
  );
}

DayCourseDisplayLabels _labels() => const DayCourseDisplayLabels(
      nonCurrentWeek: '非本周',
      conflict: '冲突',
      coupleTogether: '一起上课',
      couplePartner: 'TA的课',
      ongoingCourse: '正在上课',
    );

void main() {
  final settings = TimetableSettings.defaults();

  group('透明度与灰色钉子', () {
    test('非本周固定 0.62 与 #94A3B8 —— 主屏/预览不得各写各的', () {
      expect(kNonCurrentWeekCourseOpacity, 0.62);
      expect(kNonCurrentWeekCourseColorHex, '#94A3B8');
      expect(
        courseDisplayOpacity(
          isCurrentWeekCourse: false,
          isConflicting: true,
          conflictOpacity: 0.3,
        ),
        0.62,
      );
    });

    test('本周冲突课跟用户透明度，其余不透明', () {
      expect(
        courseDisplayOpacity(
          isCurrentWeekCourse: true,
          isConflicting: true,
          conflictOpacity: 0.35,
        ),
        0.35,
      );
      expect(
        courseDisplayOpacity(
          isCurrentWeekCourse: true,
          isConflicting: false,
          conflictOpacity: 0.35,
        ),
        1,
      );
    });
  });

  group('resolveDisplayCourseColor', () {
    final nonCurrent = DayCourseDisplayItem(
      course: _course(id: 'a'),
      opacity: kNonCurrentWeekCourseOpacity,
    );

    test('非本周一律 #94A3B8，即使开了统一卡片色', () {
      final unified = settings.copyWith(
        timetableUseUnifiedCardColor: true,
        timetableUnifiedCardColor: '#FF0000',
      );
      expect(
        resolveDisplayCourseColor(nonCurrent, settings: unified),
        '#94A3B8',
      );
    });

    test('本周课跟统一卡片色开关', () {
      final current = DayCourseDisplayItem(
        course: nonCurrent.course,
        isCurrentWeekCourse: true,
      );
      final unified = settings.copyWith(
        timetableUseUnifiedCardColor: true,
        timetableUnifiedCardColor: '#112233',
      );
      expect(resolveDisplayCourseColor(current, settings: unified), '#112233');
      expect(resolveDisplayCourseColor(current, settings: settings), isNull);
    });

    test('合堂课优先走合堂色板；没有注入回调时不崩', () {
      final together = DayCourseDisplayItem(
        course: nonCurrent.course,
        isCurrentWeekCourse: true,
        coupleKind: CoupleCourseKind.together,
      );
      expect(
        resolveDisplayCourseColor(
          together,
          settings: settings,
          coupleColorForKind: (_) => '#9C27B0',
        ),
        '#9C27B0',
      );
      expect(resolveDisplayCourseColor(together, settings: settings), isNull);
    });
  });

  group('顶栏与角标文案', () {
    final base = DayCourseDisplayItem(
      course: _course(id: 'a'),
      isCurrentWeekCourse: true,
      isConflicting: true,
    );

    test('预览口径：只标冲突，不带合堂/进行中', () {
      expect(
        resolveCompactOverlineText(
          base,
          labels: _labels(),
          showConflictBadge: true,
        ),
        '冲突',
      );
      expect(
        resolveCompactBadgeText(
          base,
          labels: _labels(),
          showConflictBadge: true,
        ),
        '冲突',
      );
    });

    test('主屏口径：合堂盖过冲突，角标可拼多项', () {
      final togetherOngoing = DayCourseDisplayItem(
        course: base.course,
        isCurrentWeekCourse: true,
        isConflicting: true,
        isCurrentCourse: true,
        coupleKind: CoupleCourseKind.together,
      );
      expect(
        resolveCompactOverlineText(
          togetherOngoing,
          labels: _labels(),
          showConflictBadge: true,
        ),
        '一起上课',
      );
      expect(
        resolveCompactBadgeText(
          togetherOngoing,
          labels: _labels(),
          showConflictBadge: true,
        ),
        '一起上课 · 正在上课 · 冲突',
      );
    });

    test('非本周顶栏文案优先于冲突', () {
      final nonCurrent = DayCourseDisplayItem(
        course: base.course,
        isConflicting: true,
        opacity: kNonCurrentWeekCourseOpacity,
      );
      expect(
        resolveCompactOverlineText(
          nonCurrent,
          labels: _labels(),
          showConflictBadge: true,
        ),
        '非本周',
      );
      expect(
        resolveCompactBadgeText(
          nonCurrent,
          labels: _labels(),
          showConflictBadge: true,
        ),
        '冲突',
      );
    });
  });

  group('筛选与排序', () {
    test('与本周课重叠的非本周课直接滤掉', () {
      final current = _course(id: 'cur', startWeek: 3, endWeek: 3);
      final overlappingNonCurrent = _course(id: 'near', startWeek: 5, endWeek: 5);
      final items = buildDayCourseDisplayItems(
        courses: [overlappingNonCurrent, current],
        week: 3,
        settings: settings,
        conflictMap: const {},
      );
      expect(items.map((e) => e.course.id).toList(), ['cur']);
    });

    test('没有本周课时，重叠的非本周只保留离上课周最近的那张', () {
      final near = _course(id: 'near', startWeek: 5, endWeek: 5);
      final far = _course(id: 'far', startWeek: 12, endWeek: 12);
      final items = buildDayCourseDisplayItems(
        courses: [far, near],
        week: 3,
        settings: settings,
        conflictMap: const {},
      );
      expect(items.map((e) => e.course.id).toList(), ['near']);
    });

    test('排序：开始节次 → 本周课靠后 → 结束节次 → id', () {
      // 比较器直接钉排序口径（筛选层可能把重叠的非本周课滤掉，
      // 用比较器才能稳定覆盖「同 start 时本周靠后」这一条）。
      final earlyNon = DayCourseDisplayItem(
        course: _course(id: 'a', endSection: 1, startWeek: 8, endWeek: 8),
        opacity: kNonCurrentWeekCourseOpacity,
      );
      final earlyCurrent = DayCourseDisplayItem(
        course: _course(id: 'b', startWeek: 3, endWeek: 3),
        isCurrentWeekCourse: true,
      );
      final late = DayCourseDisplayItem(
        course: _course(id: 'c', startSection: 4, endSection: 5, startWeek: 3, endWeek: 3),
        isCurrentWeekCourse: true,
      );
      final sorted = [late, earlyCurrent, earlyNon]
        ..sort(compareDayCourseDisplayItems);
      expect(sorted.map((e) => e.course.id).toList(), ['a', 'b', 'c']);
    });

    test('getCoursesForDay：已结课的课不再以非本周出现', () {
      final active = _course(id: 'live', startWeek: 5, endWeek: 8);
      final finished = _course(
        id: 'dead',
        startSection: 2,
        endWeek: 2,
      );
      final showNonCurrent = settings.copyWith(
        timetableShowNonCurrentWeekCourses: true,
      );
      final dayCourses = getCoursesForDay(
        [finished, active],
        3,
        1,
        showNonCurrent,
      );
      expect(dayCourses.map((c) => c.id).toList(), ['live']);
    });
  });
}
