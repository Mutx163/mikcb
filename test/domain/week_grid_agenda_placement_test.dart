// 测试目标：周网格「考试/日程卡」落格映射（lib/domain/week_grid_agenda_placement.dart）。
//
// 期望值全部**人推**（不是从实现里抄的）：节次表按 8:00–9:50 / 10:05–11:45 /
// 14:00–15:45 三节手算，每条用例先写期望区间再断言。覆盖：任一重叠即算、
// 前后钳位、午休空档取最近节、脏时间拒收、考试过期过滤、跨天日程整列。
//
// TEST-POLICY：纯逻辑测试放 test/domain/，期望值来自独立推导。
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/domain/week_grid_agenda_placement.dart';
import 'package:university_timetable/models/exam.dart';
import 'package:university_timetable/models/schedule_item.dart';
import 'package:university_timetable/models/settings/timetable_settings_live.dart';

/// 手算的三节节次表（真实模板的简化版：上午两节 + 下午一节，中间留午休空档）。
const List<SectionTime> _sections = [
  SectionTime(startTime: '08:00', endTime: '09:50'),
  SectionTime(startTime: '10:05', endTime: '11:45'),
  SectionTime(startTime: '14:00', endTime: '15:45'),
];

Exam _exam(
  String name,
  DateTime date,
  String startTime,
  String endTime, {
  String id = 'exam-1',
}) {
  return Exam(
    id: id,
    courseId: 'course-1',
    name: name,
    dateTime: date,
    startTime: startTime,
    endTime: endTime,
    createdAt: DateTime(2026, 4, 12),
    updatedAt: DateTime(2026, 4, 12),
  );
}

/// 固定的目标日期，取**安全的未来日期**：`Exam.isExpired` 判
/// `now > examEnd`，考试落在本条测试里就必须永不真过期——目标日期若用
/// 「今天」，下午跑测试时上午的考试已被过滤（与日视图议程同口径，行为
/// 本身没错，是期望值没算时间）。2030 年对 CI 的任何时钟都安全。
final DateTime _targetDate = DateTime(2030, 1, 15);

void main() {
  group('sectionSpanForClockRange（钟点 → 重叠节次区间）', () {
    test('考试 8:30–10:30 与第 1、2 节都重叠 → 跨 1–2 节，高度取并集', () {
      // 手算：8:30<=9:50 且 8:00<=10:30 → 第 1 节命中；
      // 8:30<=11:45 且 10:05<=10:30 → 第 2 节命中。
      expect(
        WeekGridAgendaPlacement.sectionSpanForClockRange(
          startTime: '08:30',
          endTime: '10:30',
          sections: _sections,
        ),
        (1, 2),
      );
    });

    test('考试完全落在单节内 → 单节区间', () {
      expect(
        WeekGridAgendaPlacement.sectionSpanForClockRange(
          startTime: '14:20',
          endTime: '15:30',
          sections: _sections,
        ),
        (3, 3),
      );
    });

    test('晚间考试（22:00–23:00）落在末节之后 → 钳到最近的第 3 节', () {
      // 手算距离：第 3 节末 15:45 → 22:00 间隔 375 分钟；前两节更远。
      expect(
        WeekGridAgendaPlacement.sectionSpanForClockRange(
          startTime: '22:00',
          endTime: '23:00',
          sections: _sections,
        ),
        (3, 3),
      );
    });

    test('早读（07:00–07:30）落在第 1 节之前 → 钳到第 1 节', () {
      expect(
        WeekGridAgendaPlacement.sectionSpanForClockRange(
          startTime: '07:00',
          endTime: '07:30',
          sections: _sections,
        ),
        (1, 1),
      );
    });

    test('午休（12:00–12:30）不与任何节重叠 → 取最近（第 2 节差 15 分钟，第 3 节差 90 分钟）', () {
      expect(
        WeekGridAgendaPlacement.sectionSpanForClockRange(
          startTime: '12:00',
          endTime: '12:30',
          sections: _sections,
        ),
        (2, 2),
      );
    });

    test('结束早于开始的脏数据（10:00–09:00）不抛异常，按单点钳到最近节', () {
      // 手算：effectiveEnd=10:00；第 1 节差 10 分钟（600-590）、
      // 第 2 节差 5 分钟（605-600）→ 第 2 节。
      expect(
        WeekGridAgendaPlacement.sectionSpanForClockRange(
          startTime: '10:00',
          endTime: '09:00',
          sections: _sections,
        ),
        (2, 2),
      );
    });

    test('脏时间串（"8.30"）拒收 → 返回 null，调用方不画卡', () {
      expect(
        WeekGridAgendaPlacement.sectionSpanForClockRange(
          startTime: '8.30',
          endTime: '10:30',
          sections: _sections,
        ),
        isNull,
      );
    });

    test('空节次表 → 返回 null', () {
      expect(
        WeekGridAgendaPlacement.sectionSpanForClockRange(
          startTime: '08:30',
          endTime: '10:30',
          sections: const [],
        ),
        isNull,
      );
    });

    test('全天区间（00:00–23:59，跨天日程口径）覆盖全部节次', () {
      expect(
        WeekGridAgendaPlacement.sectionSpanForClockRange(
          startTime: '00:00',
          endTime: '23:59',
          sections: _sections,
        ),
        (1, 3),
      );
    });
  });

  group('resolve（某一天的落格条目）', () {
    test('别的日期与已过期的考试不落格', () {
      final entries = WeekGridAgendaPlacement.resolve(
        exams: [
          _exam('别天考试', DateTime(2030, 1, 16), '08:30', '10:30', id: 'e1'),
          // 已过期：日期在过去（2026-01-01 09:00 < 任何测试时钟）。
          // 月/日不显式传 1：DateTime 的月日参数默认都是 1，显式传被判冗余。
          _exam('过期考试', DateTime(2026), '08:30', '09:00'),
        ],
        scheduleInstances: const [],
        date: _targetDate,
        sections: _sections,
      );
      expect(entries, isEmpty);
    });

    test('当天未过期考试落格到重叠节次', () {
      final exam = _exam('期末考试', _targetDate, '08:30', '10:30');
      final entries = WeekGridAgendaPlacement.resolve(
        exams: [exam],
        scheduleInstances: const [],
        date: _targetDate,
        sections: _sections,
      );
      expect(entries, hasLength(1));
      expect(entries.first.isExam, isTrue);
      expect(entries.first.startSection, 1);
      expect(entries.first.endSection, 2);
      expect(entries.first.title, '期末考试');
    });

    test('跨天日程（前后各一天）在当天落整列（00:00–23:59 → 全部节次）', () {
      final item = ScheduleItem(
        id: 'schedule-1',
        title: '运动会',
        // 前后各一天，围着 [ _targetDate ]：中段那天前后都在续。
        startDate: DateTime(2030, 1, 14),
        endDate: DateTime(2030, 1, 16),
        startTime: '09:00',
        endTime: '10:00',
        createdAt: DateTime(2026, 4, 12),
        updatedAt: DateTime(2026, 4, 12),
      );
      final instance = ScheduleItemInstance(item: item, date: _targetDate);
      final entries = WeekGridAgendaPlacement.resolve(
        exams: const [],
        scheduleInstances: [instance],
        date: _targetDate,
        sections: _sections,
      );
      expect(entries, hasLength(1));
      expect(entries.first.isExam, isFalse);
      // 跨天口径：前日续来 00:00 / 续到次日 23:59 → 整列。
      expect(entries.first.continuesFromPreviousDay, isTrue);
      expect(entries.first.continuesToNextDay, isTrue);
      expect(entries.first.startTime, '00:00');
      expect(entries.first.endTime, '23:59');
      expect(entries.first.startSection, 1);
      expect(entries.first.endSection, 3);
    });

    test('单次日程落在自己的钟点区间', () {
      final item = ScheduleItem(
        id: 'schedule-2',
        title: '班会',
        startDate: _targetDate,
        endDate: _targetDate,
        startTime: '14:00',
        endTime: '15:00',
        createdAt: DateTime(2026, 4, 12),
        updatedAt: DateTime(2026, 4, 12),
      );
      final instance = ScheduleItemInstance(item: item, date: _targetDate);
      final entries = WeekGridAgendaPlacement.resolve(
        exams: const [],
        scheduleInstances: [instance],
        date: _targetDate,
        sections: _sections,
      );
      expect(entries, hasLength(1));
      expect(entries.first.startSection, 3);
      expect(entries.first.endSection, 3);
      expect(entries.first.title, '班会');
    });

    test('同跨度的日程与考试：日程排前、考试叠在上层（类型次序与日视图议程一致）', () {
      final item = ScheduleItem(
        id: 'schedule-3',
        title: '自习',
        startDate: _targetDate,
        endDate: _targetDate,
        startTime: '08:30',
        endTime: '09:30',
        createdAt: DateTime(2026, 4, 12),
        updatedAt: DateTime(2026, 4, 12),
      );
      final instance = ScheduleItemInstance(item: item, date: _targetDate);
      final exam = _exam('突击测验', _targetDate, '08:30', '09:30');
      final entries = WeekGridAgendaPlacement.resolve(
        exams: [exam],
        scheduleInstances: [instance],
        date: _targetDate,
        sections: _sections,
      );
      expect(entries, hasLength(2));
      expect(entries.first.isExam, isFalse);
      expect(entries.last.isExam, isTrue);
    });
  });
}
