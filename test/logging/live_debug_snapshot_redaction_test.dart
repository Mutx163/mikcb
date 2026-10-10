import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/logging/app_debug_log.dart';

/// 超级岛自检「导出」回退路径的脱敏（2026-10-10 修，10-09 隐私审查发现 1）。
///
/// 背景：`settings_live.dart` 的 `_exportCurrentDebugSnapshot()` 在原生日志导出
/// 拿不到时**静默回退**成「当前调试快照 JSON」，跟同一个分享面板出去。而
/// `debugStatus` 来自原生 `LiveUpdateService.buildDebugStatus()`，其中
/// `snapshot["course"]` 带着明文的课程名 / 教师 / 教室 / 备注 / 下一门课，
/// `snapshot["notification"]` 的正文本身就是拼好的「课程名 · 教室」
/// （`LiveUpdateService.kt:2382-2391` 与 `:2443-2450`）。应用内导出日志早已
/// 全部脱敏，唯独这条出口原先一个都没盖。
///
/// 修法两层（`redactedLiveDebugSnapshot`）：
/// 1. `redactPersonalFieldMap()` 递归查表 —— 结构化个人字段与 JSON 文本全覆盖；
/// 2. `notification` / `summary` 子树**整棵拿掉** —— 它们的值是自由文本
///    （拼好的句子，没有 `key=` 形态），查表与正则都定位不到，而内容全部
///    派生自课程数据，保留等于把课名教室原样交出去。
void main() {
  // 与 LiveUpdateService.kt:2358-2448 的 updateDebugSnapshot 同形状的最小快照。
  Map<String, dynamic> buildSnapshot() => {
    'generatedAtMillis': 1760073600000,
    'summary': {
      'serviceRunning': true,
      'statusText': '高等数学 · 一教 201',
      'notIslandReason': '',
    },
    'environment': {'androidVersion': 36, 'isDarkMode': false},
    'service': {'startedAtMillis': 1760070000000, 'restartCount': 0},
    'course': {
      'courseName': '高等数学',
      'shortCourseNameRaw': '高数',
      'nextCourseName': '大学英语',
      'location': '一教 201',
      'teacher': '王老师',
      'note': '带上次作业',
      'startTimeText': '10:00',
      'endTimeText': '11:40',
    },
    'timing': {'nowMillis': 1760073600000, 'remainingToEndMillis': 1920000},
    'switches': {'enableBeforeClass': true, 'showCountdown': true},
    'notification': {
      'shouldPromote': true,
      'notificationsAllowed': true,
      'notificationTitle': '高等数学 · 一教 201',
      'notificationContentText': '正在上课 · 还有 32 分钟',
    },
  };

  test('course 子树整棵被盖（键在表里），课名/教师/教室/备注不落盘', () {
    final out = redactedLiveDebugSnapshot(buildSnapshot());
    final text = const JsonEncoder.withIndent('  ').convert(out);

    expect(out['course'], '**');
    expect(text, isNot(contains('高等数学')));
    expect(text, isNot(contains('大学英语')));
    expect(text, isNot(contains('一教 201')));
    expect(text, isNot(contains('王老师')));
    expect(text, isNot(contains('带上次作业')));
  });

  test('notification / summary 子树整棵拿掉（自由文本派生自课程数据）', () {
    final out = redactedLiveDebugSnapshot(buildSnapshot());
    final text = const JsonEncoder.withIndent('  ').convert(out);

    // 通知正文没有 `key=` 形态、查表定位不到，只能按子树拿。
    expect(out['notification'], '**');
    expect(out['summary'], '**');
    expect(text, isNot(contains('notificationTitle')));
    expect(text, isNot(contains('notificationContentText')));
    expect(text, isNot(contains('正在上课')));
    expect(text, isNot(contains('32 分钟')));
  });

  test('取证量原样保留：时间戳 / 计数 / 布尔 / 开关子树', () {
    final out = redactedLiveDebugSnapshot(buildSnapshot());
    final text = const JsonEncoder.withIndent('  ').convert(out);

    // 嵌套子树经递归脱敏后序列化成 Dart map 文本（`{…}`），值本身原样。
    expect(text, contains('1760073600000'));
    expect(text, contains('1920000'));
    expect(text, contains('restartCount: 0'));
    expect(text, contains('androidVersion: 36'));
    // 开关 / 显示子树是纯布尔与枚举，诊断价值高、无个人信息，必须保留。
    expect(text, contains('enableBeforeClass: true'));
    expect(text, contains('showCountdown: true'));
  });

  test('未知的新子树不会被误伤（只拿名单里那两棵）', () {
    final out = redactedLiveDebugSnapshot({
      'someFutureSection': {'a': 1, 'b': 'x'},
      'course': {'courseName': '高等数学'},
    });
    expect(out['someFutureSection'].toString(), contains('a: 1'));
    expect(out['course'], '**');
  });

  test('嵌套 JSON 文本值也被解析并递归脱敏（redactPersonalFieldMap 层）', () {
    // 有的字段把状态 JsonEncoder.convert 成字符串塞进来（`statusJson` 形态），
    // `redactPersonalFieldValue` 对它先解析再按 map 递归 —— JSON 里全是
    // `"name": "…"` 形状、正则一条都匹配不上，不解析就整段漏。
    final snapshot = <String, dynamic>{
      'service': {
        'statusJson': '{"courseName":"高等数学","loc":"一教 201","tick":7}',
      },
    };
    final out = redactPersonalFieldMap(snapshot);
    // 嵌套 map 值经递归脱敏后序列化成文本；`statusJson` 键不在表里，
    // 但它的值被当作 JSON 容器解析后逐字段查表。
    final text = out['service'].toString();

    expect(text, isNot(contains('高等数学')));
    expect(text, isNot(contains('一教 201')));
    expect(text, contains('tick'));
  });

  test('message 自由文本出口对三个新键同样生效', () {
    // `redactPersonalFields`（message 出口）与 `redactPersonalFieldMap`
    // （extras / map 出口）查同一份表 —— 新键加表后两边必须同时生效，
    // 否则又是「改了这份、漏了那份」。
    final out = redactPersonalFieldMap({
      'error': 'section_count_below_usage_detail|'
          'profileName=张三的课表|courseName=高等数学',
      'audit': 'lan_edit_course_group_saved originalName=高等数学 '
          'clientIp=192.168.1.23 scheduleCount=3',
    });

    final errorText = out['error']! as String;
    expect(errorText, isNot(contains('张三的课表')));
    expect(errorText, contains('profileName=**'));
    expect(errorText, contains('courseName=**'));

    final auditText = out['audit']! as String;
    expect(auditText, isNot(contains('高等数学')));
    expect(auditText, isNot(contains('192.168.1.23')));
    expect(auditText, contains('originalName=**'));
    expect(auditText, contains('clientIp=**'));
    // 计数保留。
    expect(auditText, contains('scheduleCount=3'));
  });
}
