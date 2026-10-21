import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/domain/course_timetable_signature.dart';
import 'package:university_timetable/models/course.dart';

/// 课表内容指纹：**只**该对「用户看得见的课表变化」敏感。
///
/// 判据两面都要测：教务改了课名必须变（否则抓到新课表也不提示），本机改颜色 /
/// 备注**不能**变（否则每次重新导入都提示「已更新课表」，而用户看到的课表一模一样）。
Course _course({
  String name = '高等数学',
  String teacher = '张老师',
  String location = '教一 101',
  int dayOfWeek = 1,
  int startSection = 1,
  int endSection = 2,
  int startWeek = 1,
  int endWeek = 16,
  bool isOddWeek = false,
  bool isEvenWeek = false,
  List<int>? customWeeks,
  List<int>? suspendedWeeks,
  String color = '#2196F3',
  String? note,
  bool hasCustomTime = false,
  String startTime = '08:00',
  String endTime = '09:40',
}) {
  return Course(
    id: 'c-$name-$dayOfWeek-$startSection',
    name: name,
    teacher: teacher,
    location: location,
    dayOfWeek: dayOfWeek,
    startSection: startSection,
    endSection: endSection,
    startTime: startTime,
    endTime: endTime,
    color: color,
    startWeek: startWeek,
    endWeek: endWeek,
    isOddWeek: isOddWeek,
    isEvenWeek: isEvenWeek,
    customWeeks: customWeeks,
    suspendedWeeks: suspendedWeeks,
    note: note,
    hasCustomTime: hasCustomTime,
  );
}

void main() {
  test('空课表有固定指纹', () {
    expect(timetableContentSignature(const []), 'empty');
  });

  group('教务真的改了 → 指纹必须变', () {
    final base = [_course()];

    void expectChanged(List<Course> other, String what) {
      expect(
        timetableContentSignature(other),
        isNot(timetableContentSignature(base)),
        reason: '$what 变了，指纹却没变 → 抓到新课表也不会提示用户',
      );
    }

    test('课名', () => expectChanged([_course(name: '线性代数')], '课名'));
    test('老师', () => expectChanged([_course(teacher: '李老师')], '老师'));
    test('地点', () => expectChanged([_course(location: '教二 203')], '地点'));
    test('星期', () => expectChanged([_course(dayOfWeek: 3)], '星期'));
    test('节次', () => expectChanged([_course(startSection: 3)], '节次'));
    test('周次范围', () => expectChanged([_course(endWeek: 18)], '周次'));
    test('单周', () => expectChanged([_course(isOddWeek: true)], '单周'));
    test('双周', () => expectChanged([_course(isEvenWeek: true)], '双周'));
    test(
      '自定义周',
      () => expectChanged([
        _course(customWeeks: [1, 3, 5]),
      ], '自定义周'),
    );
    test(
      '停课周',
      () => expectChanged([
        _course(suspendedWeeks: [4]),
      ], '停课周'),
    );
    test(
      '自定义钟点',
      () => expectChanged([
        _course(hasCustomTime: true, startTime: '07:30', endTime: '09:10'),
      ], '自定义钟点'),
    );
    test('多一门课', () => expectChanged([_course(), _course(name: '大学物理')], '课程数量'));
    test('少一门课', () => expectChanged(const [], '课程数量'));
  });

  group('本机编辑物 → 指纹不能变', () {
    final base = [_course()];
    final baseSig = timetableContentSignature(base);

    test('颜色（随机分配 / 用户改色）不影响', () {
      expect(
        timetableContentSignature([_course(color: '#FF0000')]),
        baseSig,
        reason: '重新导入时会重算随机色，若颜色进指纹就是「每次都说更新了」',
      );
    });

    test('备注 / 作业不影响', () {
      expect(
        timetableContentSignature([_course(note: '带计算器')]),
        baseSig,
      );
    });

    test('顺序不影响', () {
      final a = [_course(), _course(name: '大学物理', dayOfWeek: 2)];
      final b = [_course(name: '大学物理', dayOfWeek: 2), _course()];
      expect(timetableContentSignature(a), timetableContentSignature(b));
    });

    test('两边空白不影响', () {
      expect(timetableContentSignature([_course(name: ' 高等数学 ')]), baseSig);
    });
  });

  test('指纹跨调用稳定（同一份内容两次计算相等）', () {
    final courses = [_course(), _course(name: '大学物理', dayOfWeek: 2)];
    expect(
      timetableContentSignature(courses),
      timetableContentSignature(List<Course>.from(courses)),
    );
  });

  test('指纹是固定长度十六进制后缀，不含 Dart 的 hashCode（跨进程不稳定）', () {
    final sig = timetableContentSignature([_course()]);
    expect(sig, startsWith('1#'));
    expect(
      RegExp(r'^1#[0-9a-f]{8}$').hasMatch(sig),
      isTrue,
      reason: '实际是 $sig；换成 String.hashCode 会让「隔一次启动一比全都不一样」',
    );
  });
}
