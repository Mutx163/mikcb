import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/schedule_date_rule.dart';
import 'package:university_timetable/models/timetable_profile.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/services/data_transfer_service.dart';

/// 全量备份解析里，`scheduleDateRules` / `locationTimeGroups` 也必须有
/// 「整份清零就拒收」的守卫（第 32 轮）。
///
/// 同一个文件、同一个类里已经有两份口径：
/// - 单课表路径 `:234-241` 用的是 `_parseListWithTotalLossGuard`，
///   它的注释（:93-107）立的就是这条规矩："允许逐条跳过，但不允许整列表清零"；
/// - 全量备份路径 `:326-328` 对 `profiles`/`timeSchemes` 也做了等长校验，
///   可是 :335-341 的 `scheduleDateRules` 与 `locationTimeGroups` 走的还是
///   裸的 `_parseOptionalList` —— 逐条 try/catch 静默跳过。
///
/// 后果：`.mikcb` 的 `schemaVersion` 不匹配就直接拒收，能进到这里的文件
/// 一定是本机同版本写出来的，条目读不出来只可能是截断/手改/损坏。
/// 而消费侧是**整表替换**（`import_export_service.dart:531`、
/// `unified_transfer_service.dart:327`），撤销快照走的正是同一条写入
/// （`unified_transfer_service.dart:894`）：一条坏规则 = 那条日期规则永久消失，
/// 界面却报"导入成功"。
void main() {
  String cleanBackup() {
    return DataTransferService().buildFullBackupJson(
      profiles: [
        TimetableProfile(
          id: 'profile-1',
          name: '默认课表',
          courses: const [],
          settings: TimetableSettings.defaults(),
          currentWeek: 1,
          createdAt: DateTime(2026, 3, 22),
          lastUsedAt: DateTime(2026, 3, 22),
        ),
      ],
      activeProfileId: 'profile-1',
      timeSchemes: const [],
    );
  }

  String corrupt(String key) {
    final payload = Map<String, dynamic>.from(jsonDecode(cleanBackup()) as Map)
      ..[key] = ['bad'];
    return jsonEncode(payload);
  }

  test('日期规则整表读不出来时拒收，而不是静默变空表', () {
    expect(
      () => DataTransferService().parseFullBackupJson(
        corrupt('scheduleDateRules'),
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('地点分组整表读不出来时拒收，而不是静默变空表', () {
    expect(
      () => DataTransferService().parseFullBackupJson(
        corrupt('locationTimeGroups'),
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('只坏一条时仍然救得回其余部分（守卫不误伤逐条跳过）', () {
    const realRule = ScheduleDateRule(
      id: 'rule-1',
      name: '国庆调休',
      timeSchemeId: 'scheme-1',
      startDate: '2026-10-01',
      endDate: '2026-10-07',
    );
    final service = DataTransferService();
    final json = service.buildFullBackupJson(
      profiles: [
        TimetableProfile(
          id: 'profile-1',
          name: '默认课表',
          courses: const [],
          settings: TimetableSettings.defaults(),
          currentWeek: 1,
          createdAt: DateTime(2026, 3, 22),
          lastUsedAt: DateTime(2026, 3, 22),
        ),
      ],
      activeProfileId: 'profile-1',
      timeSchemes: const [],
      scheduleDateRules: const [realRule],
    );
    final payload = Map<String, dynamic>.from(jsonDecode(json) as Map)
      ..['scheduleDateRules'] = [realRule.toJson(), 'bad'];

    final backup = service.parseFullBackupJson(jsonEncode(payload));

    expect(backup.scheduleDateRules, hasLength(1));
    expect(backup.scheduleDateRules.single.name, '国庆调休');
  });

  test('干净的备份照常解析', () {
    final backup = DataTransferService().parseFullBackupJson(cleanBackup());

    expect(backup.profiles.single.name, '默认课表');
    expect(backup.scheduleDateRules, isEmpty);
    expect(backup.locationTimeGroups, isEmpty);
  });
}
