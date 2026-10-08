import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/logging/app_debug_log.dart';

/// 2026-10-08 复核实测出来的四个绕过，全部钉住。
///
/// 上一版正则 `(^|[ &|])(keys)=([^\s|]*)`：
/// - 没开 `multiLine` ⇒ 续行开头的 `course=` 一条都匹配不上；
/// - 大小写敏感 ⇒ `COURSE=` 原样漏出；
/// - `=` 前有空格就匹配不上 ⇒ `course =` 原样漏出；
/// - 值到**空格**为止，而 `changeSamples` 用 `" || "`（前后各一个空格）拼接
///   ⇒ 只盖住第 1 门课名，第 2~12 门连同课程 id 原样进了导出日志。
/// 这正是 2c8f33ce 要修的漏洞，只是补到了 extras 那一路。
void main() {
  group('key 形态的绕过', () {
    test('大写 key 也会被脱敏', () {
      expect(redactPersonalFields('COURSE=高等数学'), 'COURSE=**');
    });

    test('等号前有空格也会被脱敏', () {
      // 归一化成 `course=**`：key 本身要脱敏，`=` 前后的空白只是分隔符，
      // 保留它没有取证价值，留着反而会让同一字段出现两种写法。
      expect(redactPersonalFields('course =高等数学'), 'course=**');
    });

    test('续行开头的 key 也会被脱敏（multiLine）', () {
      final out = redactPersonalFields('step 2 of 4\ncourse=高等数学');
      expect(out, isNot(contains('高等数学')));
      expect(out, contains('course=**'));
      // 前一行不能被误伤。
      expect(out, contains('step 2 of 4'));
    });
  });

  group('名字列表：一条样本行里有 12 门课', () {
    const line =
        'changeSamples=高等数学|c-9f2a1|clock 08:00-09:40->10:00-11:40 || '
        '线性代数|c-77bd3|clock 10:00-11:40->10:00-11:40 || '
        '大学物理|c-55ea0|clock 14:00-15:40->10:00-11:40';

    test('整值盖住：id 与课名同属一个元素，保住 id 就等于保住课名', () {
      // 同一行的其它非个人字段（计数、钟点）保留。
      final out = redactPersonalFields(
        'matched=3 changeSamples=$line',
      );
      expect(out, contains('matched=3'));
      expect(out, isNot(contains('线性代数')));
    });
  });

  group('samples= 键复用导致的漏出', () {
    test('sampleOverrides 整值被盖住', () {
      const line =
          'overridesAfter=3 sampleOverrides=name=高等数学|id=c-9f2a1|loc=A101 || '
          'name=线性代数|id=c-77bd3|loc=B202';
      final out = redactPersonalFields(line);
      expect(out, isNot(contains('高等数学')));
      expect(out, isNot(contains('线性代数')));
      expect(out, isNot(contains('A101')));
      expect(out, isNot(contains('B202')));
      expect(out, contains('overridesAfter=3'));
    });
  });

  group('误伤防护：计数 / 机构名 / 性能采样不能被抹', () {
    test('samples= 性能计数原样保留', () {
      const raw = 'perf samples=12 total=780';
      expect(redactPersonalFields(raw), raw);
    });

    test('courses= / groups= / schoolName= 原样保留', () {
      const raw = '用户点击「重新匹配当前课表」 courses=12 groups=3 '
          'overridesBefore=1 schoolName=示例大学';
      expect(redactPersonalFields(raw), raw);
    });

    test('没有可脱敏字段时原样返回', () {
      const raw = '套用完成 matched=3 updated=2 overflow=0';
      expect(redactPersonalFields(raw), raw);
    });

    test('overflowNames= 仍整值盖住', () {
      expect(
        redactPersonalFields('overflowNames=高等数学,线性代数'),
        'overflowNames=**',
      );
    });

    test('keywords=（复数）地点组关键词整值盖住', () {
      final out = redactPersonalFields('keywords=[一教(exact)|六教(regex)]');
      expect(out, isNot(contains('一教')));
      expect(out, isNot(contains('六教')));
    });
  });

  group('既有口径不回退', () {
    test('course/loc/name 按段命中，id 与节次保留', () {
      const raw =
          '跳过改写(节次越界/无sections): course=高等数学 loc=A101 '
          'sections=1-2 scheme=作息甲 override=null currentClock=07:00-07:40';
      final out = redactPersonalFields(raw);
      expect(out, isNot(contains('高等数学')));
      expect(out, isNot(contains('A101')));
      expect(out, contains('sections=1-2'));
      expect(out, contains('currentClock=07:00-07:40'));
    });

    test('竖线拼接的样本行按段命中', () {
      const raw = 'name=线性代数|id=7d1c2b3e|override=null|08:00-09:40|loc=三教201';
      final out = redactPersonalFields(raw);
      expect(out, isNot(contains('线性代数')));
      expect(out, isNot(contains('三教201')));
      expect(out, contains('id=7d1c2b3e'));
    });
  });
}