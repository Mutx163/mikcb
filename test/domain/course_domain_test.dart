import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/domain/course_domain.dart';
import 'package:university_timetable/models/course.dart';

Course _course({
  required String id,
  String name = '高数',
  String teacher = '张老师',
  String location = 'A101',
  int dayOfWeek = 1,
  int startSection = 1,
  int endSection = 2,
  int startWeek = 1,
  int endWeek = 16,
  List<int>? customWeeks,
  List<int>? suspendedWeeks,
  String? description,
  String? note,
}) {
  return Course(
    id: id,
    name: name,
    teacher: teacher,
    location: location,
    dayOfWeek: dayOfWeek,
    startSection: startSection,
    endSection: endSection,
    startTime: '08:00',
    endTime: '09:40',
    startWeek: startWeek,
    endWeek: endWeek,
    customWeeks: customWeeks,
    suspendedWeeks: suspendedWeeks,
    description: description,
    note: note,
  );
}

void main() {
  group('CourseDomain.conflict / overlapInWeek', () {
    test('同一天同时段冲突', () {
      expect(
        CourseDomain.conflict(_course(id: 'a'), _course(id: 'b')),
        isTrue,
      );
    });

    test('同 id 不与自己冲突', () {
      expect(
        CourseDomain.conflict(_course(id: 'a'), _course(id: 'a')),
        isFalse,
      );
    });

    test('不同星期不冲突', () {
      expect(
        CourseDomain.conflict(
          _course(id: 'a'),
          _course(id: 'b', dayOfWeek: 2),
        ),
        isFalse,
      );
    });

    test('节次错开不冲突（前后相邻也算不冲突）', () {
      expect(
        CourseDomain.conflict(
          _course(id: 'a'),
          _course(id: 'b', startSection: 3, endSection: 4),
        ),
        isFalse,
      );
    });

    test('指定周：一边停课该周则不冲突', () {
      expect(
        CourseDomain.conflict(
          _course(id: 'a', suspendedWeeks: [5]),
          _course(id: 'b'),
          week: 5,
        ),
        isFalse,
      );
    });

    test('customWeeks 在外壳之外时不误报（仓库导入常见形态）', () {
      // 外壳 1–16，但实际只在第 10 周上课
      final a = _course(id: 'a', customWeeks: [10]);
      final b = _course(id: 'b', endWeek: 9);
      expect(CourseDomain.conflict(a, b), isFalse);

      // 候选周并集中存在共同激活周（第 10 周）→ 冲突
      final c = _course(id: 'c', startWeek: 10, endWeek: 12);
      expect(CourseDomain.conflict(a, c), isTrue);
    });

    test('overlapInWeek 不做同 id 排除（情侣课表口径）', () {
      expect(
        CourseDomain.overlapInWeek(_course(id: 'a'), _course(id: 'a')),
        isTrue,
      );
    });
  });

  group('CourseDomain.buildConflictMap', () {
    test('对称记录双方', () {
      final map = CourseDomain.buildConflictMap([
        _course(id: 'a'),
        _course(id: 'b'),
        _course(id: 'c', dayOfWeek: 3),
      ]);
      expect(map['a'], hasLength(1));
      expect(map['a']!.first.id, 'b');
      expect(map['b']!.first.id, 'a');
      expect(map.containsKey('c'), isFalse);
    });

    test('指定周时只按该周判定', () {
      final map = CourseDomain.buildConflictMap([
        _course(id: 'a', suspendedWeeks: [5]),
        _course(id: 'b'),
      ], week: 5);
      expect(map, isEmpty);
    });
  });

  group('CourseDomain.weekCandidates', () {
    test('customWeeks 优先', () {
      expect(
        CourseDomain.weekCandidates(_course(id: 'a', customWeeks: [2, 4, 6])),
        {2, 4, 6},
      );
    });

    test('startWeek 小于 1 时钳到 1', () {
      expect(
        CourseDomain.weekCandidates(_course(id: 'a', startWeek: 0, endWeek: 2)),
        {1, 2},
      );
    });

    test('endWeek 小于 startWeek 时退化为单周', () {
      expect(
        CourseDomain.weekCandidates(_course(id: 'a', startWeek: 5, endWeek: 3)),
        {5},
      );
    });
  });

  group('CourseDomain.applySharedFields', () {
    test('共享字段从 source 覆盖到 target，teacher/location 保留 target 自己的', () {
      final target = _course(
        id: 'a',
        name: '旧名',
        teacher: '李老师',
        location: 'B202',
      );
      final source = _course(
        id: 'b',
        name: '新名',
        description: '课程简介',
      );
      final merged = CourseDomain.applySharedFields(target, source);
      expect(merged.name, '新名');
      expect(merged.teacher, '李老师');
      expect(merged.location, 'B202');
      expect(merged.description, '课程简介');
    });

    test('source 无简介时提升 legacy note 为共享简介', () {
      final target = _course(id: 'a');
      final source = _course(id: 'b', note: '旧版备注');
      final merged = CourseDomain.applySharedFields(target, source);
      expect(merged.description, '旧版备注');
    });

    test('shortName / color / textColor / 课程性质一并共享', () {
      final target = _course(id: 'a');
      final source = _course(
        id: 'b',
      ).copyWith(
        shortName: '数',
        color: '#FF5722',
        textColor: '#FFFFFF',
      );
      final merged = CourseDomain.applySharedFields(target, source);
      expect(merged.shortName, '数');
      expect(merged.color, '#FF5722');
      expect(merged.textColor, '#FFFFFF');
    });
  });

  group('buildSharedCourseNameKey / sharedKey', () {
    test('trim + 小写归一', () {
      expect(buildSharedCourseNameKey('  高数 A  '), '高数 a');
      expect(
        CourseDomain.sharedKey(_course(id: 'a', name: ' 大学英语 ')),
        '大学英语',
      );
    });
  });
}
