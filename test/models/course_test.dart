import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/course.dart';

void main() {
  test('copyWith can clear nullable fields', () {
    final course = Course(
      id: 'course-1',
      name: '高等数学',
      shortName: '高数',
      teacher: '张老师',
      location: 'A101',
      dayOfWeek: 1,
      startSection: 1,
      endSection: 2,
      startTime: '08:00',
      endTime: '09:40',
      description: '课程简介',
      note: '备注',
      timeSchemeIdOverride: 'scheme-1',
    );

    final cleared = course.copyWith(
      shortName: null,
      description: null,
      note: null,
      timeSchemeIdOverride: null,
    );

    expect(cleared.name, '高等数学');
    expect(cleared.shortName, isNull);
    expect(cleared.description, isNull);
    expect(cleared.note, isNull);
    expect(cleared.timeSchemeIdOverride, isNull);
  });

  test('custom weeks are preserved and used for week filtering', () {
    final course = Course(
      id: 'course-2',
      name: '大学物理',
      teacher: '李老师',
      location: 'B201',
      dayOfWeek: 2,
      startSection: 3,
      endSection: 4,
      startTime: '10:00',
      endTime: '11:40',
      startWeek: 1,
      endWeek: 16,
      customWeeks: [6, 2, 4, 4],
    );

    final restored = Course.fromJson(course.toJson());

    expect(restored.normalizedCustomWeeks, [2, 4, 6]);
    expect(restored.isInWeek(2), isTrue);
    expect(restored.isInWeek(3), isFalse);
    expect(restored.weekDescription, '第2、4、6周');
  });

  test('custom week description compresses continuous ranges', () {
    final course = Course(
      id: 'course-3',
      name: '线性代数',
      teacher: '王老师',
      location: 'C301',
      dayOfWeek: 3,
      startSection: 1,
      endSection: 2,
      startTime: '08:00',
      endTime: '09:40',
      customWeeks: [1, 2, 3, 5, 7, 8, 9],
    );

    expect(course.weekDescription, '第1-3、5、7-9周');
  });
}
