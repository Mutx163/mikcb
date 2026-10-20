import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/domain/month_view_logic.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/exam.dart';
import 'package:university_timetable/models/holiday_entry.dart';
import 'package:university_timetable/models/schedule_item.dart';
import 'package:university_timetable/models/timetable_settings.dart';

/// 月视图域逻辑测试。
///
/// 期望值全部**人推**（对照 2026 年真实日历），不从实现里抄：
/// - 2026-10-01 是周四 → 10 月网格从 09-28（周一）起；
/// - 2027-02-01 是周一 → 2 月网格无前导补位，末格 03-14；
/// - 学期 2026-09-07（周一）开学：09-07 是第 1 周，09-21 是第 3 周，
///   08-31 开学前，12-28 是第 17 周（超出 16 周学期）。
void main() {
  DateTime d(int year, int month, int day) => DateTime(year, month, day);

  TimetableSettings settingsWith({
    DateTime? semesterStart,
    int weekCount = 16,
    bool enableHolidayMarking = true,
  }) {
    return TimetableSettings(
      sections: const [],
      semesterWeekCount: weekCount,
      enableHolidayMarking: enableHolidayMarking,
    ).copyWith(semesterStartDate: semesterStart);
  }

  Course course({
    required int dayOfWeek,
    int startWeek = 1,
    int endWeek = 16,
    bool isOddWeek = false,
    bool isEvenWeek = false,
    List<int>? customWeeks,
    List<int>? suspendedWeeks,
    String color = '#2196F3',
  }) {
    return Course(
      id: 'c-$dayOfWeek-$startWeek-$customWeeks-$suspendedWeeks',
      name: '课程',
      teacher: '老师',
      location: '教室',
      dayOfWeek: dayOfWeek,
      startSection: 1,
      endSection: 2,
      startTime: '08:00',
      endTime: '09:50',
      color: color,
      startWeek: startWeek,
      endWeek: endWeek,
      isOddWeek: isOddWeek,
      isEvenWeek: isEvenWeek,
      customWeeks: customWeeks,
      suspendedWeeks: suspendedWeeks,
    );
  }

  Exam exam({
    required DateTime dateTime,
    String startTime = '08:30',
    String endTime = '10:30',
  }) {
    final base = DateTime.now();
    return Exam(
      id: 'exam-${dateTime.toIso8601String()}-$startTime',
      courseId: 'course-1',
      name: '考试',
      dateTime: dateTime,
      startTime: startTime,
      endTime: endTime,
      createdAt: base,
      updatedAt: base,
    );
  }

  ScheduleItem schedule({
    required DateTime startDate,
    required DateTime endDate,
    ScheduleRecurrence recurrence = ScheduleRecurrence.none,
  }) {
    final now = DateTime(2026, 10, 20, 12);
    return ScheduleItem(
      id: 's-${startDate.day}-${recurrence.name}',
      title: '日程',
      startDate: startDate,
      endDate: endDate,
      startTime: '19:00',
      endTime: '20:00',
      createdAt: now,
      updatedAt: now,
      recurrence: recurrence,
    );
  }

  group('monthGridDates：42 格网格', () {
    test('2026-10：10/1 是周四，网格从 09-28（周一）到 11-08', () {
      final dates = MonthViewLogic.monthGridDates(2026, 10);
      expect(dates, hasLength(42));
      expect(dates.first, d(2026, 9, 28));
      expect(dates.last, d(2026, 11, 8));
      // 每行首格都是周一。
      for (var row = 0; row < 6; row++) {
        expect(dates[row * 7].weekday, 1);
      }
      // 10/1 落在第 1 行第 4 格（周四）。
      expect(dates[3], d(2026, 10, 1));
    });

    test('2027-02：2/1 是周一，无前导补位，末格 03-14（平年 2 月）', () {
      final dates = MonthViewLogic.monthGridDates(2027, 2);
      expect(dates, hasLength(42));
      expect(dates.first, d(2027, 2, 1));
      expect(dates.last, d(2027, 3, 14));
    });

    test('跨年：2026-12 网格尾部补到 2027-01-10', () {
      // 2026-12-01 是周二 → 网格从 11-30 起；11-30 + 41 天 = 2027-01-10。
      final dates = MonthViewLogic.monthGridDates(2026, 12);
      expect(dates.first, d(2026, 11, 30));
      expect(dates.last, d(2027, 1, 10));
    });
  });

  group('buildMonthGrid：逐日聚合', () {
    test('学期周次映射：开学前 null、学期内真周次、超出学期保留真值', () {
      final grid = MonthViewLogic.buildMonthGrid(
        year: 2026,
        month: 9,
        now: d(2026, 9, 15),
        courses: const [],
        scheduleItems: const [],
        exams: const [],
        settings: settingsWith(semesterStart: d(2026, 9, 7)),
        holidayData: null,
      );
      // 08-31 是开学前补位格 → 周次 null。
      final leading = grid.entryFor(d(2026, 8, 31))!;
      expect(leading.weekIndex, isNull);
      expect(leading.weekInSemester, isFalse);
      expect(leading.isOutsideMonth, isTrue);
      // 09-07 第 1 周，09-21 第 3 周。
      expect(grid.entryFor(d(2026, 9, 7))!.weekIndex, 1);
      expect(grid.entryFor(d(2026, 9, 21))!.weekIndex, 3);
    });

    test('学期未配置：全部周次 null，课程数恒 0', () {
      final grid = MonthViewLogic.buildMonthGrid(
        year: 2026,
        month: 10,
        now: d(2026, 10, 15),
        courses: [course(dayOfWeek: 1)],
        scheduleItems: const [],
        exams: const [],
        settings: settingsWith(),
        holidayData: null,
      );
      for (final day in grid.days) {
        expect(day.weekIndex, isNull);
        expect(day.weekInSemester, isFalse);
        expect(day.courseCount, 0);
      }
    });

    test('课程点只承认当天真实发生的课（周次过滤）', () {
      final mondayCourse = course(dayOfWeek: 1, endWeek: 2);
      final oddWeekCourse = course(dayOfWeek: 3, isOddWeek: true);
      final grid = MonthViewLogic.buildMonthGrid(
        year: 2026,
        month: 9,
        now: d(2026, 9, 15),
        courses: [mondayCourse, oddWeekCourse],
        scheduleItems: const [],
        exams: const [],
        settings: settingsWith(semesterStart: d(2026, 9, 7)),
        holidayData: null,
      );
      // 周一课 1-2 周：09-07（第 1 周）、09-14（第 2 周）有，09-21（第 3 周）无。
      expect(grid.entryFor(d(2026, 9, 7))!.courseCount, 1);
      expect(grid.entryFor(d(2026, 9, 14))!.courseCount, 1);
      expect(grid.entryFor(d(2026, 9, 21))!.courseCount, 0);
      // 单周课（周三）：09-09（第 1 周，单周）有，09-16（第 2 周，双周）无。
      expect(grid.entryFor(d(2026, 9, 9))!.courseCount, 1);
      expect(grid.entryFor(d(2026, 9, 16))!.courseCount, 0);
    });

    test('停课周课程仍计数（与首页周网格 isInWeek 口径一致）', () {
      final grid = MonthViewLogic.buildMonthGrid(
        year: 2026,
        month: 9,
        now: d(2026, 9, 15),
        courses: [course(dayOfWeek: 1, suspendedWeeks: [1])],
        scheduleItems: const [],
        exams: const [],
        settings: settingsWith(semesterStart: d(2026, 9, 7)),
        holidayData: null,
      );
      // 周网格按 isInWeek 展示停课卡（带停课标记），月视图同口径计数。
      expect(grid.entryFor(d(2026, 9, 7))!.courseCount, 1);
    });

    test('课程颜色去重封顶 3 个，保持出现顺序', () {
      final grid = MonthViewLogic.buildMonthGrid(
        year: 2026,
        month: 9,
        now: d(2026, 9, 15),
        courses: [
          course(dayOfWeek: 1, color: '#FF0000'),
          course(dayOfWeek: 1, endWeek: 1, color: '#00FF00'),
          course(
            dayOfWeek: 1,
            endWeek: 1,
            color: '#00FF00', // 重复色，不重复计
          ),
          course(dayOfWeek: 1, endWeek: 1, color: ' #0000FF '),
          course(dayOfWeek: 1, endWeek: 1, color: '#FFFF00'),
        ],
        scheduleItems: const [],
        exams: const [],
        settings: settingsWith(semesterStart: d(2026, 9, 7)),
        holidayData: null,
      );
      final entry = grid.entryFor(d(2026, 9, 7))!;
      expect(entry.courseCount, 5);
      expect(entry.courseColorHexes, ['#FF0000', '#00FF00', '#0000FF']);
    });

    test('考试：当日命中、结束时间后过期、跨时长边界', () {
      final target = d(2026, 10, 20);
      final grid = MonthViewLogic.buildMonthGrid(
        year: 2026,
        month: 10,
        now: DateTime(2026, 10, 20, 10), // 上午 10 点聚合
        courses: const [],
        scheduleItems: const [],
        exams: [
          exam(dateTime: target), // 进行中（默认 08:30-10:30）→ 计入
          exam(dateTime: DateTime(2026, 10, 20, 8), endTime: '09:30'), // 已结束 → 排除
          exam(dateTime: d(2026, 10, 21)), // 别的日子 → 不入这格
        ],
        settings: settingsWith(semesterStart: d(2026, 9, 7)),
        holidayData: null,
      );
      expect(grid.entryFor(target)!.examCount, 1);
      expect(grid.entryFor(d(2026, 10, 21))!.examCount, 1);
    });

    test('日程：单次三天日程逐日计数；周重复按星期命中', () {
      final grid = MonthViewLogic.buildMonthGrid(
        year: 2026,
        month: 10,
        now: d(2026, 10, 15),
        courses: const [],
        scheduleItems: [
          schedule(startDate: d(2026, 10, 19), endDate: d(2026, 10, 21)),
          schedule(
            startDate: d(2026, 10, 5),
            endDate: d(2026, 10, 30),
            recurrence: ScheduleRecurrence.weekly,
          ),
        ],
        exams: const [],
        settings: settingsWith(semesterStart: d(2026, 9, 7)),
        holidayData: null,
      );
      // 单次日程 10/19～10/21 逐日一条；周重复日程起点是 10/05（周一），
      // 命中 10/05、10/12、10/19、10/26 —— 与单次日程只在 10/19 重叠。
      expect(grid.entryFor(d(2026, 10, 19))!.scheduleCount, 2);
      expect(grid.entryFor(d(2026, 10, 20))!.scheduleCount, 1);
      expect(grid.entryFor(d(2026, 10, 21))!.scheduleCount, 1);
      expect(grid.entryFor(d(2026, 10, 12))!.scheduleCount, 1);
      expect(grid.entryFor(d(2026, 10, 22))!.scheduleCount, 0);
    });

    test('假期标记：假期日休、调休上班日班、开关与优先级', () {
      final holidayData = HolidayData(
        year: 2026,
        version: 1,
        entries: [
          HolidayEntry(
            date: d(2026, 10, 1),
            name: '国庆节',
            type: HolidayType.vacation,
          ),
          HolidayEntry(
            date: d(2026, 10, 10),
            name: '调休上班',
            type: HolidayType.adjustedWorkday,
          ),
        ],
      );
      final grid = MonthViewLogic.buildMonthGrid(
        year: 2026,
        month: 10,
        now: d(2026, 10, 15),
        courses: const [],
        scheduleItems: const [],
        exams: const [],
        settings: settingsWith(semesterStart: d(2026, 9, 7)),
        holidayData: holidayData,
      );
      expect(grid.entryFor(d(2026, 10, 1))!.isHoliday, isTrue);
      expect(grid.entryFor(d(2026, 10, 1))!.isAdjustedWorkday, isFalse);
      // 调休上班日：班标为真、假期为假（resolver 优先级）。
      expect(grid.entryFor(d(2026, 10, 10))!.isAdjustedWorkday, isTrue);
      expect(grid.entryFor(d(2026, 10, 10))!.isHoliday, isFalse);
    });

    test('假期标记开关关闭：假期不标（resolver markingEnabled 语义）', () {
      final holidayData = HolidayData(
        year: 2026,
        version: 1,
        entries: [
          HolidayEntry(
            date: d(2026, 10, 1),
            name: '国庆节',
            type: HolidayType.vacation,
          ),
        ],
      );
      final grid = MonthViewLogic.buildMonthGrid(
        year: 2026,
        month: 10,
        now: d(2026, 10, 15),
        courses: const [],
        scheduleItems: const [],
        exams: const [],
        settings: settingsWith(
          semesterStart: d(2026, 9, 7),
          enableHolidayMarking: false,
        ),
        holidayData: holidayData,
      );
      expect(grid.entryFor(d(2026, 10, 1))!.isHoliday, isFalse);
    });

    test('today 归一：带时分秒的 now 只取日期成分', () {
      final grid = MonthViewLogic.buildMonthGrid(
        year: 2026,
        month: 10,
        now: DateTime(2026, 10, 20, 23, 59, 59),
        courses: const [],
        scheduleItems: const [],
        exams: const [],
        settings: settingsWith(semesterStart: d(2026, 9, 7)),
        holidayData: null,
      );
      expect(grid.today, d(2026, 10, 20));
    });
  });

  group('buildDayAgenda：当日混排议程', () {
    final sections = [
      const SectionTime(startTime: '08:00', endTime: '08:50'),
      const SectionTime(startTime: '09:00', endTime: '09:50'),
    ];

    Course courseAtSection(int section) {
      return Course(
        id: 'c-2-sec$section',
        name: '课程$section',
        teacher: '老师',
        location: '教室',
        dayOfWeek: 2, // 周二
        startSection: section,
        endSection: section,
        startTime: '08:00',
        endTime: '09:50',
      );
    }

    test('课程/考试/日程按钟点混排（与日视图同一混排语义）', () {
      final date = d(2026, 10, 20); // 周二
      final rows = MonthViewLogic.buildDayAgenda(
        date: date,
        courses: [courseAtSection(1)], // 第 1 节 → 作息 08:00
        scheduleItems: [schedule(startDate: date, endDate: date)], // 19:00
        exams: [exam(dateTime: date)], // 08:30
        settings: settingsWith(semesterStart: d(2026, 9, 7)),
        sections: sections,
        now: DateTime(2026, 10, 20, 0, 30),
      );
      expect(rows, hasLength(3));
      expect(rows[0].kind, MonthAgendaRowKind.course);
      expect(rows[0].clockText, '08:00');
      expect(rows[1].kind, MonthAgendaRowKind.exam);
      expect(rows[1].clockText, '08:30');
      expect(rows[2].kind, MonthAgendaRowKind.schedule);
      expect(rows[2].clockText, '19:00');
    });

    test('节次映射不到作息的行钟点为 null 并垫底', () {
      final date = d(2026, 10, 20);
      final rows = MonthViewLogic.buildDayAgenda(
        date: date,
        courses: [courseAtSection(5)], // 超出 2 节作息表 → null
        scheduleItems: [schedule(startDate: date, endDate: date)], // 19:00
        exams: const [],
        settings: settingsWith(semesterStart: d(2026, 9, 7)),
        sections: sections,
        now: DateTime(2026, 10, 20, 0, 30),
      );
      expect(rows, hasLength(2));
      expect(rows[0].kind, MonthAgendaRowKind.schedule);
      expect(rows[0].clockText, '19:00');
      expect(rows[1].kind, MonthAgendaRowKind.course);
      expect(rows[1].clockText, isNull);
    });

    test('同日多场考试按开始时间排序（人推：compareByStart 口径）', () {
      final date = d(2026, 10, 20);
      final rows = MonthViewLogic.buildDayAgenda(
        date: date,
        courses: const [],
        scheduleItems: const [],
        exams: [
          // 先写下午场、后写上午场：排序必须按开始时刻，不按注入序。
          exam(dateTime: date, startTime: '14:00', endTime: '16:30'),
          exam(dateTime: date, endTime: '12:00'),
        ],
        settings: settingsWith(semesterStart: d(2026, 9, 7)),
        sections: sections,
        now: DateTime(2026, 10, 20, 0, 30),
      );
      expect(rows, hasLength(2));
      expect(rows[0].clockText, '08:30');
      expect(rows[1].clockText, '14:00');
    });
  });
}
