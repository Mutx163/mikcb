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
}
