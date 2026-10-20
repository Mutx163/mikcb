// 测试目标：周网格「考试/日程卡」两个开关（lib/models/timetable_settings.dart
// 的 weekGridShowExams / weekGridShowSchedules）的持久化往返与脏数据回落。
//
// 期望值是人推的：开关默认开（这是用户要的显示功能，默认可见）；翻成「关」
// 往返、缺键回落开、字符串脏值回落开。测试放 test/models/（TEST-POLICY：
// 新增测试只进 test/services、test/domain、test/models、test/utils、
// integration_test；存量 test/widgets、test/screens 一律不增不改）。
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/timetable_settings.dart';

void main() {
  group('weekGridShowExams / weekGridShowSchedules 持久化', () {
    test('翻成「关」后 toJson / fromJson 往返保住显式关闭', () {
      // 全部翻成非默认值：只测「默认值往返」会漏掉 toJson/fromJson 漏写
      // 字段——漏写时读回来正好等于默认值，测试仍然绿（同天气往返测试的口径）。
      final settings = TimetableSettings.defaults().copyWith(
        weekGridShowExams: false,
        weekGridShowSchedules: false,
      );
      final json = settings.toJson();
      expect(json['weekGridShowExams'], isFalse);
      expect(json['weekGridShowSchedules'], isFalse);

      final restored = TimetableSettings.fromJson(json);
      expect(restored.weekGridShowExams, isFalse);
      expect(restored.weekGridShowSchedules, isFalse);
    });

    test('缺键回落「开」（老档案与新存档都默认可见）', () {
      final restored = TimetableSettings.fromJson(<String, dynamic>{});
      expect(restored.weekGridShowExams, isTrue);
      expect(restored.weekGridShowSchedules, isTrue);
    });

    test('字符串 "false"/"true" 是合法值（lenientBool 认），垃圾值回落「开」', () {
      // lenientBool 的既定口径：真 bool 与 'true'/'false'（任意大小写）算数；
      // '1' / 1 / 0 不是 bool，按缺键交给默认值（lenient_json_readers.dart）。
      final parsed = TimetableSettings.fromJson(<String, dynamic>{
        'weekGridShowExams': 'false',
        'weekGridShowSchedules': 'true',
      });
      expect(parsed.weekGridShowExams, isFalse);
      expect(parsed.weekGridShowSchedules, isTrue);

      final junk = TimetableSettings.fromJson(<String, dynamic>{
        'weekGridShowExams': 1,
        'weekGridShowSchedules': 'yes',
      });
      expect(junk.weekGridShowExams, isTrue);
      expect(junk.weekGridShowSchedules, isTrue);
    });

    test('copyWith 只动自己的字段', () {
      final base = TimetableSettings.defaults().copyWith(
        weekGridShowExams: false,
      );
      final next = base.copyWith(weekGridShowSchedules: false);
      expect(next.weekGridShowExams, isFalse, reason: '另一个开关保持原值');
      expect(next.weekGridShowSchedules, isFalse);
      expect(base.weekGridShowSchedules, isTrue, reason: 'base 不被改动');
    });

    test('出厂默认两个开关都是「开」', () {
      final d = TimetableSettings.defaults();
      expect(d.weekGridShowExams, isTrue);
      expect(d.weekGridShowSchedules, isTrue);
    });
  });
}
