import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/utils/course_color_palette.dart';
import 'package:university_timetable/utils/import_random_course_colors.dart';

Course _sampleCourse({
  required String id,
  required String name,
  String teacher = '',
  String color = '#2196F3',
}) {
  return Course(
    id: id,
    name: name,
    teacher: teacher,
    location: 'A101',
    dayOfWeek: 1,
    startSection: 1,
    endSection: 2,
    startTime: '08:00',
    endTime: '09:40',
    color: color,
    startWeek: 1,
    endWeek: 16,
  );
}

void main() {
  group('applyRandomImportCourseColors', () {
    test('returns empty list for empty input', () {
      expect(applyRandomImportCourseColors(const []), isEmpty);
    });

    test('same name and teacher share one color', () {
      final colored = applyRandomImportCourseColors([
        _sampleCourse(id: '1', name: '高等数学', teacher: '张三', color: '#111111'),
        _sampleCourse(id: '2', name: '高等数学', teacher: '张三', color: '#222222'),
        _sampleCourse(id: '3', name: '线性代数', teacher: '李四', color: '#333333'),
      ], random: Random(42));

      expect(colored[0].color, colored[1].color);
      expect(colored[0].color, isNot(colored[2].color));
      expect(kPresetCourseColorHexes, contains(colored[0].color));
      expect(kPresetCourseColorHexes, contains(colored[2].color));
    });

    test('whitespace in name or teacher is normalized for grouping', () {
      final colored = applyRandomImportCourseColors([
        _sampleCourse(id: '1', name: '  高等数学 ', teacher: '张  三'),
        _sampleCourse(id: '2', name: '高等数学', teacher: '张 三'),
      ], random: Random(7));

      expect(colored[0].color, colored[1].color);
    });

    test('overrides spreadsheet-provided colors', () {
      final colored = applyRandomImportCourseColors([
        _sampleCourse(id: '1', name: 'A', teacher: 'T', color: '#AABBCC'),
      ], random: Random(1));

      expect(colored.single.color, isNot('#AABBCC'));
      expect(kPresetCourseColorHexes, contains(colored.single.color));
    });

    test('uses fixed seed for deterministic palette order', () {
      final first = applyRandomImportCourseColors([
        _sampleCourse(id: '1', name: 'A', teacher: '1'),
        _sampleCourse(id: '2', name: 'B', teacher: '2'),
      ], random: Random(99));
      final second = applyRandomImportCourseColors([
        _sampleCourse(id: '1', name: 'A', teacher: '1'),
        _sampleCourse(id: '2', name: 'B', teacher: '2'),
      ], random: Random(99));

      expect(
        first.map((course) => course.color).toList(),
        second.map((course) => course.color).toList(),
      );
    });
  });

  group('buildImportCourseColorGroupKey', () {
    test('joins normalized name and teacher', () {
      expect(
        buildImportCourseColorGroupKey(name: ' 高数 ', teacher: ' 张三 '),
        '高数\u0000张三',
      );
    });
  });
}
