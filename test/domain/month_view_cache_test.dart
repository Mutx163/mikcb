import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/domain/month_view_cache.dart';
import 'package:university_timetable/domain/month_view_logic.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/exam.dart';
import 'package:university_timetable/models/holiday_entry.dart';
import 'package:university_timetable/models/schedule_item.dart';
import 'package:university_timetable/models/timetable_settings.dart';

/// 月视图网格缓存测试。
///
/// 期望值全部**人推**，不从 `month_view_cache.dart` 里抄判据：
/// - 「命中」= 两次调用拿到**同一个对象**（`identical`），不是「内容相等」；
/// - 「未命中」= 拿到另一个对象。判据变严（多一条进键）只会让命中变少，
///   所以我用「该命中的地方必须 identical」+「该未命中的地方必须不同」
///   两头都钉，任何一条判据被删或改成常量，至少一头会红；
/// - 三份 list 的判据是**元素签名**（同一批元素、同一个顺序），不是列表实例
///   身份 —— 这条由「provider 式新包装表必须命中」那一组钉住；
/// - 容量 3 的淘汰顺序按「最近使用」推：先后取 A、B、C，再取 A（A 变成
///   最近使用），此时最久未用的是 B —— 第 4 个月进来必须淘汰 B，A 留下。
void main() {
  DateTime d(int year, int month, int day) => DateTime(year, month, day);

  TimetableSettings settingsWith({DateTime? semesterStart}) {
    return const TimetableSettings(
      sections: [],
      semesterWeekCount: 16,
    ).copyWith(semesterStartDate: semesterStart);
  }

  /// 一门「整个学期都上」的课：周次走 [Course] 默认的 1–16，作息走默认节次。
  Course course({required int dayOfWeek}) {
    return Course(
      id: 'c-$dayOfWeek',
      name: '课程',
      teacher: '老师',
      location: '教室',
      dayOfWeek: dayOfWeek,
      startSection: 1,
      endSection: 2,
      startTime: '08:00',
      endTime: '09:50',
    );
  }

  Exam exam({
    required DateTime dateTime,
    String startTime = '08:30',
    String endTime = '10:30',
  }) {
    final stamp = DateTime(2026, 10, 20, 12);
    return Exam(
      id: 'exam-${dateTime.toIso8601String()}-$endTime',
      courseId: 'course-1',
      name: '考试',
      dateTime: dateTime,
      startTime: startTime,
      endTime: endTime,
      createdAt: stamp,
      updatedAt: stamp,
    );
  }

  ScheduleItem schedule({
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final stamp = DateTime(2026, 10, 20, 12);
    return ScheduleItem(
      id: 's-${startDate.day}',
      title: '日程',
      startDate: startDate,
      endDate: endDate,
      startTime: '19:00',
      endTime: '20:00',
      createdAt: stamp,
      updatedAt: stamp,
    );
  }

  group('命中与未命中：年份 + 月份', () {
    test('同一份输入取两次：第二次是同一个对象（命中）', () {
      final cache = MonthViewDataCache();
      final courses = [course(dayOfWeek: 1)];
      final scheduleItems = <ScheduleItem>[
        schedule(startDate: d(2026, 10, 19), endDate: d(2026, 10, 21)),
      ];
      final exams = <Exam>[exam(dateTime: d(2026, 10, 20))];
      final settings = settingsWith(semesterStart: d(2026, 9, 7));
      final now = DateTime(2026, 10, 20, 9, 30);

      final first = cache.grid(
        year: 2026,
        month: 10,
        now: now,
        courses: courses,
        scheduleItems: scheduleItems,
        exams: exams,
        settings: settings,
        holidayData: null,
      );
      final second = cache.grid(
        year: 2026,
        month: 10,
        now: now,
        courses: courses,
        scheduleItems: scheduleItems,
        exams: exams,
        settings: settings,
        holidayData: null,
      );

      expect(identical(first, second), isTrue);
      // 顺带钉住「缓存没把数据换掉」：2026-10 的 42 格里，10/20 是周二，
      // 课程挂周一，所以 10/19 那格 1 门课、10/20 那格 0 门课、1 场考试。
      expect(first.days, hasLength(42));
      expect(first.entryFor(d(2026, 10, 19))!.courseCount, 1);
      expect(first.entryFor(d(2026, 10, 20))!.courseCount, 0);
      expect(first.entryFor(d(2026, 10, 20))!.examCount, 1);
    });

    test('换月不命中（同一年内）', () {
      final cache = MonthViewDataCache();
      final courses = [course(dayOfWeek: 1)];
      final settings = settingsWith(semesterStart: d(2026, 9, 7));
      final now = DateTime(2026, 10, 20, 9);

      final october = cache.grid(
        year: 2026,
        month: 10,
        now: now,
        courses: courses,
        scheduleItems: const [],
        exams: const [],
        settings: settings,
        holidayData: null,
      );
      final november = cache.grid(
        year: 2026,
        month: 11,
        now: now,
        courses: courses,
        scheduleItems: const [],
        exams: const [],
        settings: settings,
        holidayData: null,
      );

      expect(identical(october, november), isFalse);
      expect(october.month, 10);
      expect(november.month, 11);
    });

    test('同月不同年不命中（2026-10 与 2027-10）', () {
      final cache = MonthViewDataCache();
      final settings = settingsWith(semesterStart: d(2026, 9, 7));
      final now = DateTime(2026, 10, 20, 9);

      final first = cache.grid(
        year: 2026,
        month: 10,
        now: now,
        courses: const [],
        scheduleItems: const [],
        exams: const [],
        settings: settings,
        holidayData: null,
      );
      final second = cache.grid(
        year: 2027,
        month: 10,
        now: now,
        courses: const [],
        scheduleItems: const [],
        exams: const [],
        settings: settings,
        holidayData: null,
      );

      expect(identical(first, second), isFalse);
      expect(first.year, 2026);
      expect(second.year, 2027);
    });
  });

  group('命中与未命中：五份输入的身份', () {
    test('provider 式新包装表（同一份 backing list 取两次）→ 命中', () {
      final cache = MonthViewDataCache();
      // provider 的真实形状：backing list 不变，每次访问现造一个 unmodifiable
      // 包装表（timetable_provider.dart:211「List.unmodifiable(_courses)」）。
      // 两个包装表是不同对象，但元素是同一批 —— 必须命中，否则真机上缓存
      // 永远失效，这个改动等于没加。
      final backing = [course(dayOfWeek: 1)];
      final settings = settingsWith(semesterStart: d(2026, 9, 7));
      final now = DateTime(2026, 10, 20, 9);

      final firstWrapper = List<Course>.unmodifiable(backing);
      final secondWrapper = List<Course>.unmodifiable(backing);
      // 先钉住前提：这两个包装表确实不是同一个对象。
      expect(identical(firstWrapper, secondWrapper), isFalse);

      MonthGridData take(List<Course> courses) => cache.grid(
        year: 2026,
        month: 10,
        now: now,
        courses: courses,
        scheduleItems: const [],
        exams: const [],
        settings: settings,
        holidayData: null,
      );

      final first = take(firstWrapper);
      final second = take(secondWrapper);

      expect(identical(first, second), isTrue);
      // 2026-10-19 是周一，课程挂周一 → 那格 1 门；10-20 周二 → 0 门。
      expect(second.entryFor(d(2026, 10, 19))!.courseCount, 1);
      expect(second.entryFor(d(2026, 10, 20))!.courseCount, 0);
    });

    test('backing list 里替换掉一个元素（长度不变）→ 不命中', () {
      final cache = MonthViewDataCache();
      final keeping = course(dayOfWeek: 1);
      final replacedAway = course(dayOfWeek: 3);
      final backing = [keeping, replacedAway];
      final settings = settingsWith(semesterStart: d(2026, 9, 7));
      final now = DateTime(2026, 10, 20, 9);

      MonthGridData take() => cache.grid(
        year: 2026,
        month: 10,
        now: now,
        courses: List<Course>.unmodifiable(backing),
        scheduleItems: const [],
        exams: const [],
        settings: settings,
        holidayData: null,
      );

      final before = take();
      // 原地换掉第 2 个元素：长度没变，但元素实例变了 = 内容变了。
      backing[1] = course(dayOfWeek: 5);
      final after = take();

      expect(identical(before, after), isFalse);
      // 换进来的周五课在 2026-10-23（周五）那格应出现。
      expect(before.entryFor(d(2026, 10, 23))!.courseCount, 0);
      expect(after.entryFor(d(2026, 10, 23))!.courseCount, 1);
    });

    test('backing list 追加一个元素（长度变）→ 不命中', () {
      final cache = MonthViewDataCache();
      final backing = [course(dayOfWeek: 1)];
      final settings = settingsWith(semesterStart: d(2026, 9, 7));
      final now = DateTime(2026, 10, 20, 9);

      MonthGridData take() => cache.grid(
        year: 2026,
        month: 10,
        now: now,
        courses: List<Course>.unmodifiable(backing),
        scheduleItems: const [],
        exams: const [],
        settings: settings,
        holidayData: null,
      );

      final before = take();
      expect(before.entryFor(d(2026, 10, 21))!.courseCount, 0);
      // 追加一门周三课：2026-10-21 是周三。
      backing.add(course(dayOfWeek: 3));
      final after = take();

      expect(identical(before, after), isFalse);
      expect(after.entryFor(d(2026, 10, 21))!.courseCount, 1);
    });

    test('元素相同但顺序对调 → 不命中（顺序参与签名）', () {
      final cache = MonthViewDataCache();
      final monday = course(dayOfWeek: 1);
      final wednesday = course(dayOfWeek: 3);
      final backing = [monday, wednesday];
      final settings = settingsWith(semesterStart: d(2026, 9, 7));
      final now = DateTime(2026, 10, 20, 9);

      MonthGridData take() => cache.grid(
        year: 2026,
        month: 10,
        now: now,
        courses: List<Course>.unmodifiable(backing),
        scheduleItems: const [],
        exams: const [],
        settings: settings,
        holidayData: null,
      );

      final before = take();
      backing[0] = wednesday;
      backing[1] = monday;
      final after = take();

      // 同一批元素、同一长度，只有顺序变了 —— 必须重算：格子配色的取色顺序
      // 与议程行序都由 list 顺序决定。
      expect(identical(before, after), isFalse);
      // 内容口径没变：两个日子的课程数仍然各 1。
      expect(after.entryFor(d(2026, 10, 19))!.courseCount, 1);
      expect(after.entryFor(d(2026, 10, 21))!.courseCount, 1);
    });

    test('scheduleItems / exams / settings / holidayData 换实例同样不命中', () {
      final cache = MonthViewDataCache();
      final now = DateTime(2026, 10, 20, 9);
      final settings = settingsWith(semesterStart: d(2026, 9, 7));

      MonthGridData take({
        required List<ScheduleItem> scheduleItems,
        required List<Exam> exams,
        required TimetableSettings settings,
        required HolidayData? holidayData,
      }) {
        return cache.grid(
          year: 2026,
          month: 10,
          now: now,
          courses: const [],
          scheduleItems: scheduleItems,
          exams: exams,
          settings: settings,
          holidayData: holidayData,
        );
      }

      final baseline = take(
        scheduleItems: const [],
        exams: const [],
        settings: settings,
        holidayData: null,
      );

      // 每次只动一份输入：命中说明该份没进键。scheduleItems / exams 这两例
      // 动的是**元素**（空表 → 一条），settings / holidayData 动的是单对象实例。
      expect(
        identical(
          baseline,
          take(
            scheduleItems: [
              schedule(startDate: d(2026, 10, 19), endDate: d(2026, 10, 19)),
            ],
            exams: const [],
            settings: settings,
            holidayData: null,
          ),
        ),
        isFalse,
        reason: 'scheduleItems 多了一条日程却没重算',
      );
      expect(
        identical(
          baseline,
          take(
            scheduleItems: const [],
            exams: [exam(dateTime: d(2026, 10, 21))],
            settings: settings,
            holidayData: null,
          ),
        ),
        isFalse,
        reason: 'exams 多了一场考试却没重算',
      );
      expect(
        identical(
          baseline,
          take(
            scheduleItems: const [],
            exams: const [],
            settings: settingsWith(semesterStart: d(2026, 9, 14)),
            holidayData: null,
          ),
        ),
        isFalse,
        reason: 'settings 换了实例却没重算',
      );
      expect(
        identical(
          baseline,
          take(
            scheduleItems: const [],
            exams: const [],
            settings: settings,
            holidayData: const HolidayData(year: 2026, version: 1, entries: []),
          ),
        ),
        isFalse,
        reason: 'holidayData 换了实例却没重算',
      );
    });

    test('scheduleItems / exams 也走元素签名：新包装表命中、元素变了不命中', () {
      final cache = MonthViewDataCache();
      final settings = settingsWith(semesterStart: d(2026, 9, 7));
      final now = DateTime(2026, 10, 20, 9);
      final scheduleBacking = <ScheduleItem>[
        schedule(startDate: d(2026, 10, 19), endDate: d(2026, 10, 19)),
      ];
      final examBacking = <Exam>[exam(dateTime: d(2026, 10, 21))];

      MonthGridData take() => cache.grid(
        year: 2026,
        month: 10,
        now: now,
        courses: const [],
        scheduleItems: List<ScheduleItem>.unmodifiable(scheduleBacking),
        exams: List<Exam>.unmodifiable(examBacking),
        settings: settings,
        holidayData: null,
      );

      final first = take();
      // 两份都换包装表、元素不变 → 命中（与 courses 同一条口径）。
      expect(identical(first, take()), isTrue);
      expect(first.entryFor(d(2026, 10, 19))!.scheduleCount, 1);
      expect(first.entryFor(d(2026, 10, 21))!.examCount, 1);

      // 换掉日程元素 → 不命中。
      scheduleBacking[0] = schedule(
        startDate: d(2026, 10, 22),
        endDate: d(2026, 10, 22),
      );
      final afterScheduleChange = take();
      expect(identical(first, afterScheduleChange), isFalse);
      expect(afterScheduleChange.entryFor(d(2026, 10, 19))!.scheduleCount, 0);
      expect(afterScheduleChange.entryFor(d(2026, 10, 22))!.scheduleCount, 1);

      // 换掉考试元素 → 不命中。
      examBacking[0] = exam(dateTime: d(2026, 10, 23));
      final afterExamChange = take();
      expect(identical(afterScheduleChange, afterExamChange), isFalse);
      expect(afterExamChange.entryFor(d(2026, 10, 21))!.examCount, 0);
      expect(afterExamChange.entryFor(d(2026, 10, 23))!.examCount, 1);
    });

    test('holidayData 为 null 与「空数据」是两个不同的键（null 也要进键）', () {
      final cache = MonthViewDataCache();
      final now = DateTime(2026, 10, 20, 9);
      final settings = settingsWith(semesterStart: d(2026, 9, 7));

      final noData = cache.grid(
        year: 2026,
        month: 10,
        now: now,
        courses: const [],
        scheduleItems: const [],
        exams: const [],
        settings: settings,
        holidayData: null,
      );
      final emptyData = cache.grid(
        year: 2026,
        month: 10,
        now: now,
        courses: const [],
        scheduleItems: const [],
        exams: const [],
        settings: settings,
        holidayData: const HolidayData(year: 2026, version: 1, entries: []),
      );

      expect(identical(noData, emptyData), isFalse);
    });
  });

  group('命中与未命中：now 只按日历日', () {
    test('同一天不同时刻 → 命中（早上 8 点算的，晚上 23 点复用）', () {
      final cache = MonthViewDataCache();
      final settings = settingsWith(semesterStart: d(2026, 9, 7));

      MonthGridData take(DateTime now) => cache.grid(
        year: 2026,
        month: 10,
        now: now,
        courses: const [],
        scheduleItems: const [],
        exams: const [],
        settings: settings,
        holidayData: null,
      );

      final morning = take(DateTime(2026, 10, 20, 8));
      final evening = take(DateTime(2026, 10, 20, 23, 59, 59, 999));

      expect(identical(morning, evening), isTrue);
      // today 也只取日期成分。
      expect(morning.today, d(2026, 10, 20));
    });

    test('跨天 → 不命中（10-20 与 10-21）', () {
      final cache = MonthViewDataCache();
      final settings = settingsWith(semesterStart: d(2026, 9, 7));

      MonthGridData take(DateTime now) => cache.grid(
        year: 2026,
        month: 10,
        now: now,
        courses: const [],
        scheduleItems: const [],
        exams: const [],
        settings: settings,
        holidayData: null,
      );

      final day20 = take(DateTime(2026, 10, 20, 23, 59));
      final day21 = take(DateTime(2026, 10, 21, 0, 1));

      expect(identical(day20, day21), isFalse);
      expect(day20.today, d(2026, 10, 20));
      expect(day21.today, d(2026, 10, 21));
    });

    test('跨月但同一时刻：日期不同即不命中（09-30 与 10-01）', () {
      final cache = MonthViewDataCache();
      final settings = settingsWith(semesterStart: d(2026, 9, 7));

      final september = cache.grid(
        year: 2026,
        month: 9,
        now: DateTime(2026, 9, 30, 12),
        courses: const [],
        scheduleItems: const [],
        exams: const [],
        settings: settings,
        holidayData: null,
      );
      final october = cache.grid(
        year: 2026,
        month: 10,
        now: DateTime(2026, 10, 1, 12),
        courses: const [],
        scheduleItems: const [],
        exams: const [],
        settings: settings,
        holidayData: null,
      );

      expect(identical(september, october), isFalse);
    });

    test('刻意放宽：当天已结束的考试，同一天内仍复用旧网格（圆点留到次日）', () {
      final cache = MonthViewDataCache();
      final settings = settingsWith(semesterStart: d(2026, 9, 7));
      final exams = [
        // 2026-10-20 08:30–10:30。
        exam(dateTime: d(2026, 10, 20)),
      ];

      MonthGridData take(DateTime now) => cache.grid(
        year: 2026,
        month: 10,
        now: now,
        courses: const [],
        scheduleItems: const [],
        exams: exams,
        settings: settings,
        holidayData: null,
      );

      // 10:00 还没结束 → 计入 1。
      final duringExam = take(DateTime(2026, 10, 20, 10));
      expect(duringExam.entryFor(d(2026, 10, 20))!.examCount, 1);

      // 21:00 已结束 → 缓存仍给同一实例，圆点还在（类注释写明的放宽口径）。
      final afterExam = take(DateTime(2026, 10, 20, 21));
      expect(identical(duringExam, afterExam), isTrue);
      expect(afterExam.entryFor(d(2026, 10, 20))!.examCount, 1);

      // 对照：绕过缓存直接算，21:00 已经过了 10:30，当天应算 0 场。
      final fresh = MonthViewLogic.buildMonthGrid(
        year: 2026,
        month: 10,
        now: DateTime(2026, 10, 20, 21),
        courses: const [],
        scheduleItems: const [],
        exams: exams,
        settings: settings,
        holidayData: null,
      );
      expect(fresh.entryFor(d(2026, 10, 20))!.examCount, 0);

      // 跨天自然恢复：次日第一次取数就重算，圆点消失。
      final nextDay = take(DateTime(2026, 10, 21, 8));
      expect(nextDay.entryFor(d(2026, 10, 20))!.examCount, 0);
    });
  });

  group('容量：只留最近 3 个月', () {
    final settings = settingsWith(semesterStart: d(2026, 9, 7));
    final now = DateTime(2026, 10, 20, 9);

    test('连续进 4 个月：最早那个被丢，后 3 个还命中', () {
      final cache = MonthViewDataCache();
      MonthGridData take(int month) => cache.grid(
        year: 2026,
        month: month,
        now: now,
        courses: const [],
        scheduleItems: const [],
        exams: const [],
        settings: settings,
        holidayData: null,
      );

      final september = take(9);
      final october = take(10);
      final november = take(11);
      // 3 个都在容量内，全部命中。
      expect(identical(take(9), september), isTrue);
      expect(identical(take(10), october), isTrue);
      expect(identical(take(11), november), isTrue);

      // 第 4 个月进来：9 月是最久未用的那条，被挤掉。
      final december = take(12);
      expect(identical(take(12), december), isTrue);
      expect(identical(take(11), november), isTrue);
      expect(identical(take(10), october), isTrue);
      // 9 月重新算过，不再是同一对象。
      expect(identical(take(9), september), isFalse);
    });

    test('翻回来算一次「最近使用」：被丢的是中间停顿最久的那页', () {
      final cache = MonthViewDataCache();
      MonthGridData take(int month) => cache.grid(
        year: 2026,
        month: month,
        now: now,
        courses: const [],
        scheduleItems: const [],
        exams: const [],
        settings: settings,
        holidayData: null,
      );

      final september = take(9);
      final october = take(10);
      final november = take(11);
      // 用户从 11 月翻回 9 月：此刻最久未用的变成 10 月。
      expect(identical(take(9), september), isTrue);
      expect(identical(take(11), november), isTrue);

      final december = take(12);
      // 10 月是最久未用的那条，已被挤掉。
      expect(identical(take(9), september), isTrue);
      expect(identical(take(11), november), isTrue);
      expect(identical(take(12), december), isTrue);
      expect(identical(take(10), october), isFalse);
    });
  });

  group('clear()', () {
    test('清空之后再取同一份输入：不命中', () {
      final cache = MonthViewDataCache();
      final settings = settingsWith(semesterStart: d(2026, 9, 7));
      final now = DateTime(2026, 10, 20, 9);
      final courses = [course(dayOfWeek: 2)];

      MonthGridData take() => cache.grid(
        year: 2026,
        month: 10,
        now: now,
        courses: courses,
        scheduleItems: const [],
        exams: const [],
        settings: settings,
        holidayData: null,
      );

      final before = take();
      expect(identical(take(), before), isTrue);

      cache.clear();

      final after = take();
      expect(identical(after, before), isFalse);
      // 清空只丢缓存，不丢数据：内容与清空前一致。
      expect(after.days, hasLength(42));
      expect(after.entryFor(d(2026, 10, 20))!.courseCount, 1);
      expect(after.entryFor(d(2026, 10, 19))!.courseCount, 0);

      // 清空之后缓存照常工作：再取一次又命中。
      expect(identical(take(), after), isTrue);
    });
  });
}
