import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/timetable_profile.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/services/ics_export_service.dart';

/// 「24:00 下课」的课必须照样导进系统日历（第 32 轮）。
///
/// 缺陷在 `ics_export_service.dart` 的两处叠出来的：
/// - `_parseTime`(:618-636) 的守卫是 `hour > 23 || minute > 59 || second > 59`，
///   对 `24:00` 直接返回 null；
/// - `_buildTimedEvent`(:456-459) 见 `endParts == null` 就 `return null` —— 整条事件不产出。
///
/// 而 `24:00` 是本仓认可的合法值（`lib/models/time_scheme.dart:229-240` 专开例外、
/// `ClockTime.tryParse(allowEndOfDay: true)` 的文档注释写明"换算成日期是精确的次日零点"，
/// `test/models/time_scheme_quick_generate_midnight_test.dart` 钉着快速生成作息末节就是它，
/// 统计侧第 27 轮也为此加了 `allowEndOfDay`）。
/// 后果：末节上到 24:00 的晚自习/长课导出到系统日历后**整节凭空消失**，
/// 而 `IcsCollectedEvents` 只统计 `skippedHolidayCourses`，用户看不到任何"少了 N 节"的提示。
void main() {
  final service = IcsExportService();

  TimetableProfile singleCourseProfile({
    required String startTime,
    required String endTime,
  }) {
    return TimetableProfile(
      id: 'profile-1',
      name: '主课表',
      courses: [
        Course(
          id: 'c1',
          name: '晚自习',
          teacher: '张老师',
          location: 'A101',
          dayOfWeek: DateTime.monday,
          startSection: 1,
          endSection: 9,
          startTime: startTime,
          endTime: endTime,
          startWeek: 1,
          endWeek: 1,
        ),
      ],
      settings: TimetableSettings.defaults().copyWith(
        semesterWeekCount: 8,
        semesterStartDate: DateTime(2026, 3, 2),
      ),
      currentWeek: 1,
      createdAt: DateTime(2026, 2, 1, 9),
      lastUsedAt: DateTime(2026, 2, 1, 10),
    );
  }

  IcsExportResult export({required String startTime, required String endTime}) {
    return service.build(
      profile: singleCourseProfile(startTime: startTime, endTime: endTime),
      fromDate: DateTime(2026, 3),
      toDate: DateTime(2026, 3, 31),
      eventTypes: const {IcsExportEventType.course},
      generatedAt: DateTime.utc(2026, 4, 1, 12),
    );
  }

  test('结束时间 24:00 的课照样产出事件，落在次日零点', () {
    final result = export(startTime: '22:00', endTime: '24:00');

    expect(result.eventCount, 1, reason: '24:00 下课不是畸形值，不该被丢掉');
    expect(
      result.content,
      contains('DTSTART:${_icsUtc(DateTime(2026, 3, 2, 22))}'),
    );
    expect(result.content, contains('DTEND:${_icsUtc(DateTime(2026, 3, 3))}'));
  });

  test('24:30 这类会被 DateTime 静默归一的钟点仍然拒收', () {
    // 与 ClockTime.tryParse 的文档同一条口径：只放行恰好 24:00。
    expect(export(startTime: '22:00', endTime: '24:30').eventCount, 0);
    expect(export(startTime: '22:00', endTime: '25:00').eventCount, 0);
  });

  test('24:00 当开始时间依然非法', () {
    // 开始时间没有"当天结束"的语义；放行它会让事件跑到次日还跨一整天。
    expect(export(startTime: '24:00', endTime: '24:00').eventCount, 0);
  });
}

String _icsUtc(DateTime localWallClock) {
  final value = localWallClock.toUtc();
  return '${value.year.toString().padLeft(4, '0')}'
      '${value.month.toString().padLeft(2, '0')}'
      '${value.day.toString().padLeft(2, '0')}'
      'T${value.hour.toString().padLeft(2, '0')}'
      '${value.minute.toString().padLeft(2, '0')}'
      '${value.second.toString().padLeft(2, '0')}Z';
}
