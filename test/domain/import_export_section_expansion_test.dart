import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/domain/import_export_logic.dart';
import 'package:university_timetable/models/timetable_settings.dart';

/// 导入需要补节时，锚点不能被畸形末节课钟点带跑（2026-10-02 审查）。
///
/// `ImportExportLogic.buildExpandedSections`（`import_export_logic.dart:54-77`）
/// 用 `_parseClockToMinutes(expanded.last.endTime)` 取锚点，而那个解析器对
/// 畸形串返回 **-1**（`:107-118`）。于是末节的 endTime 是
/// `"08.30"`/`"上午8点"` 这类字符串时（`SectionTime.fromJson` 只要求非空串，
/// 见 `lib/utils/clock_time.dart` 顶部说明；云同步与手改备份是入口），
/// 补出来的节次变成 `-1 + 课间10 = 00:09` 起 —— 导入的第 3、4 节课
/// 直接被排到凌晨，而导入侧只会照单收下（它按新节次表烤钟点）。
void main() {
  List<SectionTime> table(List<String> pairs) {
    return [
      for (final pair in pairs)
        SectionTime(
          startTime: pair.split('-').first,
          endTime: pair.split('-').last,
        ),
    ];
  }

  test('末节钟点畸形时从最近一条能解析的结束时间接着排', () {
    final expanded = ImportExportLogic.buildExpandedSections(
      table(['08:00-08:45', '08:55-上午8点半']),
      4,
    );

    expect(expanded.length, 4);
    // 锚点应为 08:45（唯一能解析的结束时间），课间与节长按可解析条目推断。
    expect(
      expanded[2].startTime,
      '08:55',
      reason: '畸形末节让锚点变成 -1，补出来的节次从 00:09 开始',
    );
    expect(expanded[3].startTime.compareTo('01:00'), greaterThan(0));
  });

  test('一条结束时间都解析不出来时不编造凌晨节次', () {
    final expanded = ImportExportLogic.buildExpandedSections(
      table(['上午8点-上午8点半', '上午9点-上午9点半']),
      4,
    );

    expect(
      expanded.length,
      2,
      reason: '没有可靠锚点就停止补节，交由导入侧的节数校验提示，'
          '而不是凭空生成 00:09-00:54 这种节次',
    );
  });

  test('正常作息的补节行为不变', () {
    final expanded = ImportExportLogic.buildExpandedSections(
      table(['08:00-08:45', '08:55-09:40']),
      4,
    );

    // 节长 45、课间 10（都从可解析条目推断）。
    expect(expanded.map((section) => section.startTime), [
      '08:00',
      '08:55',
      '09:50',
      '10:45',
    ]);
    expect(expanded[2].endTime, '10:35');
    expect(expanded[3].endTime, '11:30');
  });

  test('空作息仍按默认模板起步', () {
    final expanded = ImportExportLogic.buildExpandedSections(const [], 2);

    expect(expanded.length, greaterThanOrEqualTo(2));
    expect(expanded.first.startTime, '08:00');
  });
}
