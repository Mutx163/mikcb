import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/time_scheme.dart';
import 'package:university_timetable/models/timetable_profile.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/services/data_transfer_service.dart';

/// 完整备份里的**容器级**条目不许被静默丢弃（2026-10-05 审查）。
///
/// 同一个文件里对 `.mikcb` 单课表导入早已立下规矩（`data_transfer_service.dart:92-110`
/// 的 `_parseListWithTotalLossGuard`，注释写得很清楚）："允许逐条跳过（部分损坏仍能救回
/// 能读的部分），但不允许整列表清零" —— 因为 `backup.courses` 是**整份替换**进课表的。
///
/// 完整备份路径（:304 `profiles`、:308 `timeSchemes`）却只用裸的 `_parseOptionalList`，
/// 它 `catch (_) { continue; }` 逐条丢，然后 :312 只在**全丢光**时才抛。而
/// `TimetableProfile.fromJson`（`timetable_profile.dart:92`）是硬转 `json['id'] as String`，
/// 一档里 id 缺失/类型不对、或 `settings` 里的节次串畸形 → **整档解析失败被丢**，
/// 剩下的照常返回，守卫进不去。接着 `import_export_service.dart:515-520`
/// `host._profiles = backup.profiles` 整表替换并落盘，`importFullAppDataBackup`
/// 返回 null（成功）。后果：导入一份 `.mikcb`/云快照后某一整份课表（连同它的课、考试、
/// 作业）静默消失，界面报"导入成功"，下一次云同步再把这份残缺刷给另一台设备；
/// 撤销（`unified_transfer_service.dart:894` 的 `_restore` 同源）也会吃掉一档。
///
/// 课程/任务/考试这些**条目级**数据留在 salvage 语义里不动（本仓
/// `data_transfer_service_test.dart:104-126` 把"逐条畸形继续跳过"钉成了设计）；
/// 课表与作息是容器，丢一个就是丢一整份用户数据，只能整份拒收。
void main() {
  TimetableProfile profile(String id, String name) => TimetableProfile(
    id: id,
    name: name,
    courses: const [],
    settings: TimetableSettings.defaults(),
    currentWeek: 1,
    createdAt: DateTime(2026, 3, 22),
    lastUsedAt: DateTime(2026, 3, 22),
  );

  String threeProfileBackup() {
    return DataTransferService().buildFullBackupJson(
      profiles: [
        profile('p1', '第一份课表'),
        profile('p2', '第二份课表'),
        profile('p3', '第三份课表'),
      ],
      activeProfileId: 'p2',
      timeSchemes: [
        TimeScheme(
          id: 'scheme-1',
          name: '标准作息',
          sections: const [],
          createdAt: DateTime(2026, 3, 22),
          updatedAt: DateTime(2026, 3, 22),
        ),
        // 第二条是故意的：只有一条作息时，"全丢光"会被 :312 的既有守卫兜住，
        // 证明不了容器级条目不许静默变少这条新规则。
        TimeScheme(
          id: 'scheme-2',
          name: '冬季作息',
          sections: const [],
          createdAt: DateTime(2026, 3, 22),
          updatedAt: DateTime(2026, 3, 22),
        ),
      ],
    );
  }

  Map<String, dynamic> payloadOf(String json) =>
      Map<String, dynamic>.from(jsonDecode(json) as Map);

  group('完整备份的容器级条目不可静默丢弃', () {
    test('中间一档的 id 畸形时整份备份必须拒收，而不是丢掉那一档报成功', () {
      final payload = payloadOf(threeProfileBackup());
      final profiles = (payload['profiles'] as List).cast<Map<String, dynamic>>();
      profiles[1]['id'] = null;

      expect(
        () => DataTransferService().parseFullBackupJson(jsonEncode(payload)),
        throwsA(isA<FormatException>()),
        reason: '一份课表 = 课 + 考试 + 作业，静默丢掉它比拒收整份危险得多',
      );
    });

    test('对照：合法三份备份照常被解析，不引入多余的限制', () {
      final backup = DataTransferService().parseFullBackupJson(
        threeProfileBackup(),
      );

      expect(backup.profiles, hasLength(3));
      expect(backup.activeProfileId, 'p2');
    });

    test('对照：空课表列表不属于"丢档"，维持既有可导入语义', () {
      final payload = payloadOf(threeProfileBackup());
      payload['profiles'] = <Object>[];

      final backup = DataTransferService().parseFullBackupJson(
        jsonEncode(payload),
      );

      expect(backup.profiles, isEmpty);
    });

    test('作息同理：一条畸形不能让剩下的作息静默变少', () {
      final payload = payloadOf(threeProfileBackup());
      final schemes = (payload['timeSchemes'] as List).cast<Map<String, dynamic>>();
      schemes.first['id'] = null;

      expect(
        () => DataTransferService().parseFullBackupJson(jsonEncode(payload)),
        throwsA(isA<FormatException>()),
      );
    });

    test('课程/作业这类条目级数据仍按"逐条跳过"处理（不回归成整份拒收）', () {
      final payload = payloadOf(threeProfileBackup());
      final profiles = (payload['profiles'] as List).cast<Map<String, dynamic>>();
      final courses = (profiles.first['courses'] as List).cast<Object>();
      // 合法备份里这一档本来就是空课表，补两条再塞一条畸形：能读的留下，
      // 丢一条课程不该让整份备份被拒。
      courses.addAll([
        <String, dynamic>{
          'id': 'c1',
          'name': '高等数学',
          'teacher': '王老师',
          'location': 'A101',
          'dayOfWeek': 1,
          'startSection': 1,
          'endSection': 2,
          'startTime': '08:00',
          'endTime': '09:40',
        },
        '这一条根本不是对象',
      ]);

      final backup = DataTransferService().parseFullBackupJson(
        jsonEncode(payload),
      );

      expect(backup.profiles, hasLength(3));
      expect(
        backup.profiles.first.courses.map((course) => course.id),
        contains('c1'),
      );
    });
  });
}
