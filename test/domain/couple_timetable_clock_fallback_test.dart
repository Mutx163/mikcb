import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/domain/couple_timetable_logic.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/timetable_settings.dart';

/// 情侣课表的"忙/闲"区间不能把解析不了的钟点当成 00:00（2026-10-02 审查）。
///
/// `CoupleTimetableLogic._clockToMinutes` 对畸形串返回 **0**
/// （`couple_timetable_logic.dart:410-418`：`parts.length != 2 → 0`、
/// `int.tryParse(...) ?? 0`），而调用方的守卫是 `clockEnd > clockStart`：
/// 只要**另一端**是能解析的正常钟点，0 就会被当成"这门课从 00:00 开始"，
/// 那条 `fall back to owner section table` 的分支永远走不到。
/// 钟点串可以停在 `SectionTime`/`Course` 里（`SectionTime.fromJson` 只要求
/// 非空字符串，见 `lib/utils/clock_time.dart` 顶部说明），
/// 云同步/手改备份都能送进来。
void main() {
  const sections = <SectionTime>[
    SectionTime(startTime: '08:00', endTime: '08:45'),
    SectionTime(startTime: '08:55', endTime: '09:40'),
    SectionTime(startTime: '10:00', endTime: '10:45'),
    SectionTime(startTime: '10:55', endTime: '11:40'),
  ];

  Course course({
    required String startTime,
    required String endTime,
    int startSection = 2,
    int endSection = 3,
  }) {
    return Course(
      id: 'c-1',
      name: '线性代数',
      teacher: '李老师',
      location: 'B301',
      dayOfWeek: 2,
      startSection: startSection,
      endSection: endSection,
      startTime: startTime,
      endTime: endTime,
    );
  }

  group('情侣课表区间的钟点解析', () {
    test('开始钟点畸形时回落到节次表，而不是算成 00:00 起', () {
      final interval = CoupleTimetableLogic.courseBusyInterval(
        course(startTime: '8 点', endTime: '10:45'),
        sections,
      );

      expect(interval, isNotNull);
      // 第 2 节开始 → 08:55；第 3 节结束 → 10:45。
      expect(
        interval!.startMinutes,
        8 * 60 + 55,
        reason: '畸形串被当成 0 之后，clockEnd(645) > clockStart(0) 成立，'
            '于是返回 00:00-10:45：对方的课表里这门课从午夜就开始占用',
      );
      expect(interval.endMinutes, 10 * 60 + 45);
    });

    test('结束钟点畸形时同样回落', () {
      final interval = CoupleTimetableLogic.courseBusyInterval(
        course(startTime: '08:55', endTime: '下午'),
        sections,
      );

      expect(interval, isNotNull);
      expect(interval!.startMinutes, 8 * 60 + 55);
      expect(interval.endMinutes, 10 * 60 + 45);
    });

    test('两端都正常时仍优先用课程自己的墙钟时间', () {
      final interval = CoupleTimetableLogic.courseBusyInterval(
        course(startTime: '07:00', endTime: '07:40'),
        sections,
      );

      expect(interval, isNotNull);
      expect(interval!.startMinutes, 7 * 60);
      expect(interval.endMinutes, 7 * 60 + 40);
    });

    test('两端都解析不了且节次越界时才判为无区间', () {
      final interval = CoupleTimetableLogic.courseBusyInterval(
        course(
          startTime: 'a',
          endTime: 'b',
          startSection: 9,
          endSection: 9,
        ),
        sections,
      );

      expect(interval, isNull);
    });

    test('全天观察区间不接受畸形首节', () {
      expect(
        CoupleTimetableLogic.observationRangeForSections(const [
          SectionTime(startTime: '上午8点', endTime: '08:45'),
          SectionTime(startTime: '10:55', endTime: '11:40'),
        ]),
        isNull,
        reason: '首节畸形 → dayStart=0 → 区间变成 00:00-11:40，'
            '空闲时间凭空多出 00:00-08:00 这一段',
      );

      final normal = CoupleTimetableLogic.observationRangeForSections(sections);
      expect(normal, isNotNull);
      expect(normal!.startMinutes, 8 * 60);
      expect(normal.endMinutes, 11 * 60 + 40);
    });
  });
}
