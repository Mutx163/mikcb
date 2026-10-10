import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/logging/app_debug_log.dart';

/// release 构建里 `appDebugLog` 对 `LocationTimeApply*` 两个标签仍然打印
/// （取证需要），所以这些消息必须先在出口处抹掉可识别到人的字段。
/// 下面的原文都是从生产代码里抄出来的形状：
/// `lib/domain/time_scheme_logic.dart:425-432/449-451/461`、
/// `lib/providers/timetable_provider.dart:1957/2011/2031/2060/2133`、
/// `lib/screens/location_time_match_screen.dart:208`。
void main() {
  test('抹掉 course/loc/name，保留 id 与节次等诊断量', () {
    const raw =
        '跳过改写(节次越界/无sections): course=高等数学 loc=A101 '
        'sections=1-2 scheme=作息甲 override=null currentClock=07:00-07:40';
    final redacted = redactPersonalFields(raw);

    expect(redacted, isNot(contains('高等数学')));
    expect(redacted, isNot(contains('A101')));
    expect(redacted, contains('course=**'));
    expect(redacted, contains('loc=**'));
    // 取证需要的结构量一个字都不能少。
    expect(redacted, contains('sections=1-2'));
    expect(redacted, contains('scheme=作息甲'));
    expect(redacted, contains('currentClock=07:00-07:40'));
  });

  test('竖线拼接的样本行按段命中，id 仍可用于对号', () {
    const raw =
        'name=线性代数|id=7d1c2b3e|override=null|08:00-09:40|loc=三教201';
    final redacted = redactPersonalFields(raw);

    expect(redacted, isNot(contains('线性代数')));
    expect(redacted, isNot(contains('三教201')));
    expect(redacted, contains('name=**'));
    expect(redacted, contains('id=7d1c2b3e'));
    expect(redacted, contains('08:00-09:40'));
  });

  test('命中结果与改写前后的 trace 同样脱敏', () {
    const raw =
        'DIFF course=大学英语 id=c-9 loc=主楼302 group=A楼早读组 '
        'teacher=王老师';
    final redacted = redactPersonalFields(raw);

    expect(redacted, isNot(contains('大学英语')));
    expect(redacted, isNot(contains('主楼302')));
    expect(redacted, isNot(contains('王老师')));
    expect(redacted, isNot(contains('A楼早读组')));
    expect(redacted, contains('id=c-9'));
  });

  test('计数与机构名这类同前缀字段不被误伤', () {
    const raw = '用户点击「重新匹配当前课表」 courses=12 groups=3 '
        'overridesBefore=1 schoolName=示例大学';
    expect(redactPersonalFields(raw), raw);
  });

  test('没有可脱敏字段时原样返回', () {
    const raw = '套用完成 matched=3 updated=2 overflow=0';
    expect(redactPersonalFields(raw), raw);
  });

  test('名字列表字段（overflowNames / changeSamples）也要抹掉', () {
    // 2026-10-08 补：这两个键原先一条都匹配不上，而值里就是课程名
    // （`schedule_rule_apply.dart:314-315`、`location_time_match_screen.dart:216`），
    // 于是 release 日志里课程名原样落盘。
    const raw =
        '应用结束 overflow=3 overflowNames=高等数学,大学英语 '
        'changeSamples=高等数学|id-1|clock 08:00-09:40';
    final redacted = redactPersonalFields(raw);

    expect(redacted, isNot(contains('高等数学')));
    expect(redacted, isNot(contains('大学英语')));
    expect(redacted, contains('overflow=3'), reason: '计数是取证信息，必须留着');
    expect(redacted, contains('overflowNames=**'));
    expect(redacted, contains('changeSamples=**'));
    // ⚠️ 2026-10-08 改口径：`changeSamples` 的每个元素是
    // `课程名|id|说明`（`schedule_rule_apply.dart:191-194`），元素内部没有 `key=`
    // 可供逐段匹配 —— 原先「值到空格或 | 为止」只能盖住第 1 门课名，
    // 第 2~12 门连同课程 id 原样进了用户导出的那份日志（实测 7/8 绕过）。
    // 所以这里**整值盖住**，id 不再保留：这份文件会被导出发群，
    // 宁可少几个对号用的 id，也不能把 12 门课名交出去。
    // 样本行的完整内容在应用内仍然可见（UI 摘要 / debug 构建的 logcat）。
    expect(redacted, isNot(contains('id-1')),
        reason: '样本行的 id 与课名同属一个元素，保住 id 就等于保住课名');
  });

  test('性能探针的 samples 计数不在表里，不能被误伤', () {
    // `timetable_screen.dart:4321` 的 `samples=${probe.samples}` 是计数。
    // 为了盖住审计日志里的名字列表而把 `samples` 加进表，会连它一起抹掉 ——
    // "过度脱敏答非所问"，本仓为这件事返工过（`weather_service.dart:298`）。
    const raw =
        '[DayPager] lift(p75): vx=0.0 dx=0.0 dur=0ms samples=1 gapBeforeUp=0ms';
    expect(redactPersonalFields(raw), raw);
  });

  test('2026-10-10 补的三个键：profileName / originalName / clientIp', () {
    // 10-09 隐私审查发现 2 的三个真实漏点，逐条对应生产代码：
    // - `profileName`：`time_scheme_repository.dart:174` 拼进服务消息、
    //   经 `error=` 出口落盘（courseName 同行被盖，它原样漏出）；
    // - `originalName`：`lan_edit_api_handlers.dart:485` 审计日志（同上）；
    // - `clientIp`：`lan_edit_api_handlers.dart:241/250/262/881/896` 五处
    //   鉴权失败记录，暴露内网网段。
    const raw = 'lan_edit_course_group_saved originalName=高等数学 '
        'courseName=高等数学(周二) scheduleCount=3 clientIp=192.168.1.23';
    final redacted = redactPersonalFields(raw);

    expect(redacted, isNot(contains('高等数学')));
    expect(redacted, isNot(contains('192.168.1.23')));
    expect(redacted, contains('originalName=**'));
    expect(redacted, contains('courseName=**'));
    expect(redacted, contains('clientIp=**'));
    // 计数字段是取证信息，必须留着。
    expect(redacted, contains('scheduleCount=3'));

    // `profileName` 走 extras 查表那条出口（服务消息序列化成
    // `code|profileName=…|courseName=…`，`|` 是边界，`|profileName=` 能命中）。
    const serviceMessage =
        'section_count_below_usage_detail|profileName=张三的课表|courseName=高等数学';
    final redactedMessage = redactPersonalFields(serviceMessage);
    expect(redactedMessage, isNot(contains('张三的课表')));
    expect(redactedMessage, contains('profileName=**'));
    expect(redactedMessage, contains('courseName=**'));

    // extras 结构化出口同样要盖（`redactPersonalFieldValue` 查的是同一份表）。
    expect(redactPersonalFieldValue('profileName', '张三的课表'), '**');
    expect(redactPersonalFieldValue('originalName', '高等数学'), '**');
    expect(redactPersonalFieldValue('clientIp', '192.168.1.23'), '**');
  });
}
