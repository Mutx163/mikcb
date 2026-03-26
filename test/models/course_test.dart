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
}
