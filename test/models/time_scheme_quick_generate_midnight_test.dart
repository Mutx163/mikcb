import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/time_scheme.dart';
import 'package:university_timetable/models/timetable_settings.dart';

/// 回归钉（2026-10-02 审查第 7 轮，快速生成作息）：
///
/// `buildQuickSectionTimes` 的越界判定是 `currentEndMinutes > 24 * 60`，所以
/// **恰好 1440** 是被允许的收尾；可写出去用的是 `_minutesToClock`，它先做
/// `minutes % 1440`（time_scheme.dart:237），1440 于是回绕成 `"00:00"`。
/// 紧接着 `validateSectionTimes` 用 `_clockMinutes` 读这份 `"00:00"` 得到 0，
/// `endMinutes <= startMinutes` 成立，抛 `section_end_must_after_start`
/// 「第 N 节结束时间必须晚于开始时间」。
///
/// 但 24:00 在本仓是**合法**写法：`_clockMinutes` 专门为它开了例外
/// （`hour == 24 ? minute == 0`，注释写着"晚自习/末节课的合法写法，语义是当天结束"），
/// 手工填的 `22:00-24:00` 由 `test/models/time_scheme_test.dart:175` 钉着合法，
/// `ClockTime(allowEndOfDay:)` 与原生 `LiveClock` 也都按"次日零点"处理。
/// 唯独快速生成的出口把它写成了 00:00。
///
/// 触发路径真实存在：作息管理页 →「快速生成作息」，晚自习开始 22:00、
/// 单节时长 120（`time_scheme_quick_generate_sheet.dart:370` 只判 `int.tryParse`
/// 是否为 null，对时长没有上限），点确认 → 弹层报"结束时间必须晚于开始时间"，
/// 用户按提示把时长往小改、往大改都还是这句，直到改成 119 分钟才过。
void main() {
  List<SectionTime> build({
    required String eveningStartTime,
    required int classDurationMinutes,
    int eveningCount = 1,
    int breakDurationMinutes = 10,
  }) => buildQuickSectionTimes(
    morningCount: 0,
    afternoonCount: 0,
    eveningCount: eveningCount,
    morningStartTime: null,
    afternoonStartTime: null,
    eveningStartTime: eveningStartTime,
    classDurationMinutes: classDurationMinutes,
    breakDurationMinutes: breakDurationMinutes,
  );

  test('末节课正好上到当天 24:00 时写 24:00，不回绕成 00:00', () {
    final sections = build(
      eveningStartTime: '22:00',
      classDurationMinutes: 120,
    );

    expect(sections, hasLength(1));
    // 修复前：这里抛 FormatException('第 1 节结束时间必须晚于开始时间')。
    expect(sections.single.startTime, '22:00');
    expect(sections.single.endTime, '24:00');
    expect(validateSectionTimes(sections), isNull);
  });

  test('跨午夜的写法仍然被拒（守卫没有被放宽）', () {
    // 23:30 + 45 = 1455 > 1440
    expect(
      () => build(
        eveningStartTime: '23:30',
        classDurationMinutes: 45,
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('24:00 之后还想排下一节同样被拒', () {
    expect(
      () => build(
        eveningStartTime: '22:00',
        classDurationMinutes: 120,
        eveningCount: 2,
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('白天段以 24:00 收尾时，后续节次仍按越界处理而不是错时间', () {
    // 上午 1 节 08:00-10:00，下午从 22:00 起 120 分钟 → 末节 24:00
    final sections = buildQuickSectionTimes(
      morningCount: 1,
      afternoonCount: 0,
      eveningCount: 1,
      morningStartTime: '08:00',
      afternoonStartTime: null,
      eveningStartTime: '22:00',
      classDurationMinutes: 120,
      breakDurationMinutes: 10,
    );

    expect(sections.map((section) => section.endTime), ['10:00', '24:00']);
    expect(validateSectionTimes(sections), isNull);
  });
}
