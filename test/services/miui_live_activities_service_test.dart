import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/services/miui_live_activities_service.dart';

/// 课表快照 settings 子树的契约守卫：展开详情字段名单必须带上「写法版本号」。
///
/// 原生靠它区分「用户把字段关掉了」与「老快照不认识这个字段」，漏写会让设置页的
/// 单项隐藏重新失效（回归背景见 `.agents/notes/implemented/bug-fix/
/// 2026-09-15-expanded-detail-hidden-fields-padded-back.md`）。
void main() {
  test('快照 settings 子树带展开详情写法版本号', () {
    final settings = TimetableSettings.defaults().copyWith(
      liveExpandedDetailFields: const ['time', 'next'],
    );

    final json = buildLiveSnapshotSettingsJson(settings);

    expect(
      json['liveExpandedDetailSchemaVersion'],
      kLiveExpandedDetailSchemaVersion,
    );
    // 设置本体照旧逐字段透传，不能因为合并版本号丢字段。
    expect(json['liveExpandedDetailFields'], ['time', 'next']);
    expect(json['liveEnableBeforeClass'], settings.liveEnableBeforeClass);
    expect(json['livePromoteDuringClass'], settings.livePromoteDuringClass);
  });

  test('写法版本号与原生常量同值', () {
    final source = File(
      'android/app/src/main/kotlin/com/mutx163/qingyu/LiveUpdateScheduler.kt',
    ).readAsStringSync();
    final match = RegExp(
      r'EXPANDED_DETAIL_SCHEMA_VERSION\s*=\s*(\d+)',
    ).firstMatch(source);

    expect(match, isNotNull, reason: '原生 EXPANDED_DETAIL_SCHEMA_VERSION 未找到');
    expect(int.parse(match!.group(1)!), kLiveExpandedDetailSchemaVersion);
  });
}
