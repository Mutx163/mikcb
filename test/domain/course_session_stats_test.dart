import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/domain/course_session_stats.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/course_task.dart';
import 'package:university_timetable/models/exam.dart';
import 'package:university_timetable/models/timetable_settings.dart';

/// 学期开始日：2026-09-07 是周一。
///
/// 手工推的日期（不抄实现）：
/// - 第 1 周周三 = 09-09
/// - 第 2 周周三 = 09-16
/// - 第 3 周周三 = 09-23
DateTime get _semesterStart => DateTime(2026, 9, 7);

/// 造一门课。默认值就是「第 1~3 周、每周三 1~2 节」这门标准课，
/// 大多数用例从这个基准上只改一个维度（分析器把「显式写默认值」判为冗余，
/// 所以调用点常常看不见 startWeek/startSection 这些默认值——看这里的签名）。
Course _course({
  String id = 'c1',
  String name = '线性代数',
  int dayOfWeek = 3,
  int startSection = 1,
  int endSection = 2,
  int startWeek = 1,
  int endWeek = 3,
  bool isOddWeek = false,
  bool isEvenWeek = false,
  List<int>? customWeeks,
  List<int>? suspendedWeeks,
  Map<int, CourseSessionNote>? sessionNotes,
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
    isOddWeek: isOddWeek,
    isEvenWeek: isEvenWeek,
    customWeeks: customWeeks,
    suspendedWeeks: suspendedWeeks,
    sessionNotes: sessionNotes,
  );
}

TimetableSettings _settings({DateTime? semesterStart}) {
  return TimetableSettings.defaults().copyWith(semesterStartDate: semesterStart);
}

CourseSessionStats _build({
  required List<Course> courses,
  TimetableSettings? settings,
  List<CourseTask> tasks = const [],
  List<Exam> exams = const [],
  DateTime? now,
  bool Function(DateTime date)? isHoliday,
  String? Function(String courseId, String date)? reminderLookup,
}) {
  return CourseSessionStatsCalculator.build(
    courseName: courses.isEmpty ? '' : courses.first.name,
    courses: courses,
    settings: settings ?? _settings(semesterStart: _semesterStart),
    tasks: tasks,
    exams: exams,
    now: now ?? DateTime(2026, 9, 20),
    isHoliday: isHoliday,
    reminderDateLookup: reminderLookup,
  );
}

void main() {
  group('课次展开', () {
    test('每周一次课：3 周 → 3 次课，日期按周一算出的真实日期', () {
      final stats = _build(courses: [_course()]);

      expect(stats.sessions.length, 3);
      expect(
        stats.sessions.map((s) => s.date).toList(),
        [DateTime(2026, 9, 9), DateTime(2026, 9, 16), DateTime(2026, 9, 23)],
        reason: '第 1/2/3 周周三分别是 09-09、09-16、09-23',
      );
      expect(stats.sessions.map((s) => s.week).toList(), [1, 2, 3]);
    });

    test('单周课只展开奇数周，双周课只展开偶数周', () {
      final odd = _build(
        courses: [_course(endWeek: 6, isOddWeek: true)],
      );
      final even = _build(
        courses: [_course(endWeek: 6, isEvenWeek: true)],
      );

      expect(odd.sessions.map((s) => s.week).toList(), [1, 3, 5]);
      expect(even.sessions.map((s) => s.week).toList(), [2, 4, 6]);
    });

    test('自定义周次以它为准，不被 startWeek/endWeek 覆盖', () {
      final stats = _build(
        courses: [
          _course(endWeek: 16, customWeeks: [2, 7, 11]),
        ],
      );

      expect(stats.sessions.map((s) => s.week).toList(), [2, 7, 11]);
    });

    test('停课周仍然列出来，但标 suspended 且不计入计划课次', () {
      final stats = _build(
        courses: [
          _course(suspendedWeeks: [2]),
        ],
      );

      expect(stats.sessions.length, 3, reason: '停课周也要让用户看见');
      expect(stats.suspendedSessions, 1);
      expect(stats.plannedSessions, 2, reason: '计划口径不含停课');
      expect(
        stats.sessions.firstWhere((s) => s.week == 2).phase,
        CourseSessionPhase.suspended,
      );
    });

    test('同名课多次排课：课次合并、每节数累加', () {
      final stats = _build(
        courses: [
          _course(dayOfWeek: 1),
          _course(id: 'c2', startSection: 5, endSection: 6),
        ],
      );

      // 每条各 3 周 → 共 6 次课
      expect(stats.sessions.length, 6);
      expect(
        stats.sectionsPerSession,
        4,
        reason: '一次课（周一那节）2 节 + 另一次课（周三那节）2 节 = 4 节',
      );
      expect(stats.sessions.map((s) => s.courseId).toSet(), {'c1', 'c2'});
    });
  });

  group('阶段判定', () {
    test('今天之前 done、当天 today、之后 upcoming', () {
      final stats = _build(
        courses: [_course()],
        now: DateTime(2026, 9, 16, 14, 30),
      );

      expect(stats.sessions[0].phase, CourseSessionPhase.done); // 09-09
      expect(stats.sessions[1].phase, CourseSessionPhase.today); // 09-16
      expect(stats.sessions[2].phase, CourseSessionPhase.upcoming); // 09-23
      expect(stats.doneSessions, 1);
      expect(stats.todaySessions, 1);
      expect(stats.upcomingSessions, 1);
    });

    test('传入的日期带时分秒也算「当天」，不因时刻先后翻成已过', () {
      final stats = _build(
        courses: [_course()],
        now: DateTime(2026, 9, 16, 23, 59),
      );

      expect(
        stats.sessions.firstWhere((s) => s.week == 2).phase,
        CourseSessionPhase.today,
        reason: '判定按日历日，不按 00:00 时刻比较',
      );
    });

    test('假期优先于已过/未到，且不计入计划', () {
      final stats = _build(
        courses: [_course()],
        now: DateTime(2026, 9, 20),
        isHoliday: (date) => date == DateTime(2026, 9, 16),
      );

      expect(
        stats.sessions.firstWhere((s) => s.week == 2).phase,
        CourseSessionPhase.holiday,
      );
      expect(stats.holidaySessions, 1);
      expect(stats.plannedSessions, 2);
    });

    test('停课优先于假期：既停课又放假时判为停课', () {
      final stats = _build(
        courses: [_course(suspendedWeeks: [2])],
        isHoliday: (date) => date == DateTime(2026, 9, 16),
      );

      expect(
        stats.sessions.firstWhere((s) => s.week == 2).phase,
        CourseSessionPhase.suspended,
      );
    });

    test('没设开学日期：全部 undated、日期为空、hasCalendar=false', () {
      final stats = _build(
        courses: [_course()],
        settings: _settings(),
      );

      expect(stats.hasCalendar, isFalse);
      expect(stats.undatedSessions, 3);
      expect(stats.sessions.every((s) => s.date == null), isTrue);
      expect(
        stats.doneSessions,
        0,
        reason: '没有日期轴就不能假装「上过了」',
      );
      expect(stats.plannedSessions, 3, reason: '仍算 3 次排课');
    });
  });

  group('已有记录的对齐', () {
    test('备注文本按周次挂到对应课次上', () {
      final stats = _build(
        courses: [
          _course(
            sessionNotes: {
              1: const CourseSessionNote(text: '第一章'),
              3: const CourseSessionNote(text: '第三章'),
            },
          ),
        ],
      );

      expect(stats.sessions[0].noteText, '第一章');
      expect(stats.sessions[1].noteText, isNull);
      expect(stats.sessions[2].noteText, '第三章');
      expect(stats.notedSessions, 2);
    });

    test('只有 hasHomework 标记、没有文字，也算有作业但不调成有备注', () {
      final stats = _build(
        courses: [
          _course(
            sessionNotes: {
              2: const CourseSessionNote(hasHomework: true),
            },
          ),
        ],
      );

      final week2 = stats.sessions.firstWhere((s) => s.week == 2);
      expect(week2.hasHomework, isTrue);
      expect(week2.hasNote, isFalse);
      expect(stats.homeworkSessions, 1);
      expect(stats.notedSessions, 0);
    });

    test('挂了本课本周的作业条目也算有作业（未设 hasHomework 标记时）', () {
      final stats = _build(
        courses: [_course()],
        tasks: [
          CourseTask(
            id: 't1',
            title: '第三章习题',
            courseId: 'c1',
            sourceWeek: 3,
            createdAt: DateTime(2026, 9),
            updatedAt: DateTime(2026, 9),
          ),
        ],
      );

      final week3 = stats.sessions.firstWhere((s) => s.week == 3);
      expect(week3.taskCount, 1);
      expect(week3.hasHomework, isTrue);
      expect(stats.homeworkSessions, 1);
    });

    test('别的课的作业不算进来', () {
      final stats = _build(
        courses: [_course()],
        tasks: [
          CourseTask(
            id: 't1',
            title: '别的课作业',
            courseId: 'other',
            sourceWeek: 1,
            createdAt: DateTime(2026, 9),
            updatedAt: DateTime(2026, 9),
          ),
        ],
      );

      expect(stats.homeworkSessions, 0);
    });

    test('考试按「本课 + 同一日历日」挂到课次上', () {
      final stats = _build(
        courses: [_course()],
        exams: [
          Exam(
            id: 'e1',
            courseId: 'c1',
            name: '期中',
            dateTime: DateTime(2026, 9, 16, 10),
            startTime: '10:00',
            endTime: '11:40',
            createdAt: DateTime(2026, 9),
            updatedAt: DateTime(2026, 9),
          ),
        ],
      );

      expect(stats.sessions.firstWhere((s) => s.week == 2).examCount, 1);
      expect(stats.sessions.firstWhere((s) => s.week == 1).examCount, 0);
    });

    test('提醒按「课程 + 真实日期」匹配，日期不对不亮', () {
      final stats = _build(
        courses: [_course()],
        reminderLookup: (courseId, date) =>
            courseId == 'c1' && date == '2026-09-16' ? 'classreminder:x' : null,
      );

      expect(stats.sessions.firstWhere((s) => s.week == 2).hasReminder, isTrue);
      expect(stats.sessions.firstWhere((s) => s.week == 1).hasReminder, isFalse);
      expect(stats.reminderSessions, 1);
    });

    test('没设开学日期时，即使有提醒条目也不亮（没有日期可匹配）', () {
      final stats = _build(
        courses: [_course()],
        settings: _settings(),
        reminderLookup: (courseId, date) => 'classreminder:x',
      );

      expect(stats.reminderSessions, 0);
    });
  });

  group('排序与汇总', () {
    test('课次按日期升序，跨周日排序也正确', () {
      final stats = _build(
        courses: [
          _course(id: 'c2', dayOfWeek: 5, startSection: 3, endSection: 4),
          _course(dayOfWeek: 1),
        ],
      );

      final dates = stats.sessions.map((s) => s.date).toList();
      final sorted = List<DateTime?>.from(dates)
        ..sort((a, b) => a!.compareTo(b!));
      expect(dates, sorted);
    });

    test('已上课时只算已过的那几次', () {
      final stats = _build(
        courses: [
          _course(endSection: 3), // 每次 3 节
        ],
        now: DateTime(2026, 9, 17),
      );

      // 09-09、09-16 已过（2 次 × 3 节 = 6 节），09-23 未到
      expect(stats.doneSessions, 2);
      expect(stats.doneSections, 6);
    });

    test('计划课时 = 每次节数 × 计划课次', () {
      final stats = _build(
        courses: [_course()],
      );

      expect(stats.plannedSections, 2 * 3);
    });
  });

  group('课次日期规则与课表同源', () {
    test('第 1 周周一就是学期首周的周一', () {
      final date = courseOccurrenceDate(
        _semesterStart,
        _course(dayOfWeek: 1),
        1,
      );
      expect(date, DateTime(2026, 9, 7));
    });

    test('开学日不是周一时，第 1 周仍从那个周一算起', () {
      // 2026-09-09 是周三，它所在周的周一是 09-07
      final date = courseOccurrenceDate(
        DateTime(2026, 9, 9),
        _course(dayOfWeek: 1),
        1,
      );
      expect(date, DateTime(2026, 9, 7));
    });

    test('开学日期为空或周次非法时返回 null', () {
      expect(courseOccurrenceDate(null, _course(), 1), isNull);
      expect(courseOccurrenceDate(_semesterStart, _course(), 0), isNull);
    });

    test('周日课：第 1 周周日 = 开学周一 + 6 天', () {
      final date = courseOccurrenceDate(
        _semesterStart,
        _course(dayOfWeek: 7),
        1,
      );
      expect(date, DateTime(2026, 9, 13));
    });
  });
}
