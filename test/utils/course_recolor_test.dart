import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/utils/course_color_palette.dart';
import 'package:university_timetable/utils/course_recolor.dart';
import 'package:university_timetable/utils/import_random_course_colors.dart';

Course _course({
  required String id,
  required String name,
  String teacher = '',
  String color = '#2196F3',
  String? textColor,
  int dayOfWeek = 1,
}) {
  return Course(
    id: id,
    name: name,
    teacher: teacher,
    location: 'A101',
    dayOfWeek: dayOfWeek,
    startSection: 1,
    endSection: 2,
    startTime: '08:00',
    endTime: '09:40',
    color: color,
    textColor: textColor,
    startWeek: 1,
    endWeek: 16,
  );
}

void main() {
  group('buildCourseRecolorGroupKey', () {
    test('同名同色口径：忽略大小写与空白，不掺教师', () {
      expect(
        buildCourseRecolorGroupKey(
          _course(id: '1', name: ' 高等数学 ', teacher: '张三'),
        ),
        buildCourseRecolorGroupKey(
          _course(id: '2', name: '高等数学', teacher: '李四'),
        ),
      );
      expect(
        buildCourseRecolorGroupKey(_course(id: '1', name: '体育')),
        isNot(buildCourseRecolorGroupKey(_course(id: '2', name: '数学'))),
      );
    });
  });

  group('applySeedCourseRecolor（种子批次）', () {
    test('同名不同教师也共享一色，维持「同名同色」不变式', () {
      final courses = [
        _course(id: '1', name: '体育', teacher: '张三', color: '#111111'),
        _course(id: '2', name: '体育', teacher: '李四', color: '#222222'),
        _course(id: '3', name: '高等数学', teacher: '王五', color: '#333333'),
      ];

      final recolored = applySeedCourseRecolor(
        courses,
        seed: 42,
        colorGroupId: kCourseColorGroupAllId,
        assignMatchingTextColor: false,
      );

      expect(recolored[0].color, recolored[1].color);
      expect(recolored[0].color, isNot(recolored[2].color));
      expect(kPresetCourseColorHexes, contains(recolored[0].color));
      // 只动颜色，其余字段原样保留。
      expect(recolored[1].teacher, '李四');
      expect(recolored[2].id, '3');
      expect(recolored[2].location, 'A101');
    });

    test('同一种子同一课程列表逐色一致（切回依赖的确定性）', () {
      final courses = [
        _course(id: '1', name: 'A', color: '#111111'),
        _course(id: '2', name: 'B', color: '#222222'),
        _course(id: '3', name: 'C', color: '#333333'),
      ];

      final first = applySeedCourseRecolor(
        courses,
        seed: 7,
        colorGroupId: kCourseColorGroupAllId,
        assignMatchingTextColor: true,
      );
      final second = applySeedCourseRecolor(
        courses,
        seed: 7,
        colorGroupId: kCourseColorGroupAllId,
        assignMatchingTextColor: true,
      );

      expect(first.map((c) => c.color).toList(), second.map((c) => c.color));
      expect(
        first[0].textColor,
        matchingCourseTextColorHex(first[0].color),
      );
    });

    test('文字色开关关闭时清掉逐课文字色（回落全局）', () {
      final recolored = applySeedCourseRecolor(
        [_course(id: '1', name: 'A', textColor: '#FFFFFF')],
        seed: 3,
        colorGroupId: kCourseColorGroupAllId,
        assignMatchingTextColor: false,
      );
      expect(recolored.single.textColor, isNull);
    });

    test('颜色组生效：深色系只取深阶色板', () {
      final recolored = applySeedCourseRecolor(
        [
          _course(id: '1', name: 'A'),
          _course(id: '2', name: 'B'),
          _course(id: '3', name: 'C'),
        ],
        seed: 11,
        colorGroupId: 'deep',
        assignMatchingTextColor: false,
      );
      for (final course in recolored) {
        expect(kDeepCourseColorGroupHexes, contains(course.color));
      }
    });
  });

  group('captureCourseRecolorSnapshot / 应用快照', () {
    test('往返：重刷后应用快照恢复导入原色（含文字色）', () {
      final courses = [
        _course(id: '1', name: '体育', color: '#E91E63', textColor: '#1F1F1F'),
        _course(
          id: '2',
          name: '体育',
          color: '#E91E63',
          textColor: '#1F1F1F',
          dayOfWeek: 2,
        ),
        _course(id: '3', name: '高等数学', color: '#4CAF50'),
      ];

      final snapshot = captureCourseRecolorSnapshot(
        courses,
        now: DateTime(2026, 8, 30, 10, 0),
      );
      final recolored = applySeedCourseRecolor(
        courses,
        seed: 99,
        colorGroupId: kCourseColorGroupAllId,
        assignMatchingTextColor: true,
      );
      expect(recolored[0].color, isNot('#E91E63'));

      final restored = applyCourseRecolorScheme(recolored, snapshot);

      expect(restored[0].color, '#E91E63');
      expect(restored[0].textColor, '#1F1F1F');
      expect(restored[1].color, '#E91E63');
      expect(restored[2].color, '#4CAF50');
      expect(restored[2].textColor, isNull);
    });

    test('快照里没有的组（新加课程）保持原色不动', () {
      final courses = [_course(id: '1', name: 'A', color: '#E91E63')];
      final snapshot = captureCourseRecolorSnapshot(courses);

      final withNewCourse = [
        ...courses,
        _course(id: '9', name: 'NEW', color: '#123456', dayOfWeek: 2),
      ];
      final restored = applyCourseRecolorScheme(withNewCourse, snapshot);

      expect(restored[0].color, '#E91E63');
      expect(restored[1].color, '#123456');
    });
  });

  group('CourseRecolorScheme JSON', () {
    test('种子记录往返保留字段', () {
      final scheme = CourseRecolorScheme.seed(
        seed: 12345,
        colorGroupId: 'pastel',
        assignMatchingTextColor: true,
        createdAt: DateTime(2026, 8, 30, 9, 30),
      );

      final restored = CourseRecolorScheme.fromJson(scheme.toJson());

      expect(restored, isNotNull);
      expect(restored!.isSnapshot, isFalse);
      expect(restored.seed, 12345);
      expect(restored.colorGroupId, 'pastel');
      expect(restored.assignMatchingTextColor, isTrue);
      expect(restored.createdAt, scheme.createdAt);
    });

    test('快照记录往返保留逐组颜色（含 null 文字色）', () {
      final snapshot = captureCourseRecolorSnapshot([
        _course(id: '1', name: 'A', color: '#E91E63', textColor: '#1F1F1F'),
        _course(id: '2', name: 'B', color: '#4CAF50'),
      ]);

      final restored = CourseRecolorScheme.fromJson(snapshot.toJson());

      expect(restored, isNotNull);
      expect(restored!.isSnapshot, isTrue);
      final entries = restored.snapshotEntries!;
      expect(entries['name\u0000a']!.color, '#E91E63');
      expect(entries['name\u0000a']!.textColor, '#1F1F1F');
      expect(entries['name\u0000b']!.color, '#4CAF50');
      expect(entries['name\u0000b']!.textColor, isNull);
    });

    test('坏数据（缺时间/缺种子）返回 null 由调用方丢弃', () {
      expect(CourseRecolorScheme.fromJson({}), isNull);
      expect(CourseRecolorScheme.fromJson({'createdAt': 'not-a-date'}), isNull);
      expect(CourseRecolorScheme.fromJson({'createdAt': '2026-08-30'}), isNull);
    });

    test('快照条目坏数据（color 缺失/为空/非字符串）丢弃该条', () {
      // 回归锚点：color 曾兜底默认蓝（损坏记录渲染成错误颜色），类型垃圾
      // 曾抛 TypeError 导致整份历史被服务层 catch 清空。
      expect(
        CourseRecolorSnapshotEntry.fromJson({'color': '#4CAF50'}),
        isNotNull,
      );
      expect(CourseRecolorSnapshotEntry.fromJson({}), isNull);
      expect(CourseRecolorSnapshotEntry.fromJson({'color': null}), isNull);
      expect(CourseRecolorSnapshotEntry.fromJson({'color': ''}), isNull);
      expect(CourseRecolorSnapshotEntry.fromJson({'color': 123}), isNull);
      // 文字色垃圾只丢文字色，颜色本体保留。
      final entry = CourseRecolorSnapshotEntry.fromJson({
        'color': '#4CAF50',
        'text': 42,
      });
      expect(entry!.color, '#4CAF50');
      expect(entry.textColor, isNull);
    });

    test('种子记录类型垃圾丢弃该条；字段缺失仍兜底默认值', () {
      // 回归锚点：seed 分支的 colorGroupId/开关曾是裸 cast，类型垃圾抛
      // TypeError 被 _loadSchemes 整体 catch，一条坏种子记录清空全部历史。
      expect(
        CourseRecolorScheme.fromJson({
          'createdAt': '2026-08-30T09:00:00',
          'seed': 7,
          'colorGroupId': 123,
        }),
        isNull,
      );
      expect(
        CourseRecolorScheme.fromJson({
          'createdAt': '2026-08-30T09:00:00',
          'seed': 7,
          'assignMatchingTextColor': 'yes',
        }),
        isNull,
      );
      final scheme = CourseRecolorScheme.fromJson({
        'createdAt': '2026-08-30T09:00:00',
        'seed': 7,
      });
      expect(scheme!.seed, 7);
      expect(scheme.colorGroupId, kCourseColorGroupAllId);
      expect(scheme.assignMatchingTextColor, false);
    });
  });
}
