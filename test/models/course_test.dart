import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/models/course.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('zh'));

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
      customWeeks: [6, 2, 4, 4],
    );

    final restored = Course.fromJson(course.toJson());

    expect(restored.normalizedCustomWeeks, [2, 4, 6]);
    expect(restored.isInWeek(2), isTrue);
    expect(restored.isInWeek(3), isFalse);
    expect(restored.weekDescription(l10n), '第2、4、6周');
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

    expect(course.weekDescription(l10n), '第1-3、5、7-9周');
  });

  test('empty custom weeks fall back to range week description', () {
    final course = Course(
      id: 'course-4',
      name: '概率论',
      teacher: '赵老师',
      location: 'D101',
      dayOfWeek: 4,
      startSection: 1,
      endSection: 2,
      startTime: '08:00',
      endTime: '09:40',
      startWeek: 2,
      endWeek: 6,
      customWeeks: const [],
    );

    expect(course.weekDescription(l10n), '第2-6周');
  });

  test('fromJson clamps out-of-range day, sections, and weeks', () {
    final course = Course.fromJson({
      'id': 'course-bounds',
      'name': '边界课',
      'teacher': '老师',
      'location': 'A1',
      'dayOfWeek': 9,
      'startSection': 0,
      'endSection': -3,
      'startTime': '08:00',
      'endTime': '09:40',
      'startWeek': 0,
      'endWeek': 99,
    });

    expect(course.dayOfWeek, 7);
    expect(course.startSection, 1);
    expect(course.endSection, 1);
    expect(course.startWeek, 1);
    expect(course.endWeek, 30);
  });

  test('session notes serialize and support homework helpers', () {
    final course = Course(
      id: 'course-notes',
      name: '高等数学',
      teacher: '张老师',
      location: 'A101',
      dayOfWeek: 1,
      startSection: 1,
      endSection: 2,
      startTime: '08:00',
      endTime: '09:40',
      note: '这个老师容易逃课',
      sessionNotes: {
        7: const CourseSessionNote(text: '交第三章习题', hasHomework: true),
        8: const CourseSessionNote(text: '带电脑'),
      },
    );

    final restored = Course.fromJson(course.toJson());
    expect(restored.note, '这个老师容易逃课');
    expect(restored.hasHomeworkInWeek(7), isTrue);
    expect(restored.hasHomeworkInWeek(8), isFalse);
    expect(restored.sessionNoteForWeek(7)?.text, '交第三章习题');
    expect(restored.sessionNoteForWeek(8)?.text, '带电脑');

    final withoutWeek7 = restored.copyWith(
      sessionNotes: restored.withoutSessionNote(7),
    );
    expect(withoutWeek7.hasHomeworkInWeek(7), isFalse);
    expect(withoutWeek7.sessionNoteForWeek(8)?.text, '带电脑');

    final moved = restored.sessionNotesForSingleWeek(
      sourceWeek: 7,
      targetWeek: 10,
    );
    expect(moved?[10]?.hasHomework, isTrue);
    expect(moved?[7], isNull);
  });

  test(
    'relocatingSessionNote moves week key and excluding strips source week',
    () {
      final course = Course(
        id: 'course-relocate',
        name: '高等数学',
        teacher: '张老师',
        location: 'A101',
        dayOfWeek: 1,
        startSection: 1,
        endSection: 2,
        startTime: '08:00',
        endTime: '09:40',
        sessionNotes: {
          5: const CourseSessionNote(text: '测验', hasHomework: true),
          6: const CourseSessionNote(text: '复习'),
        },
      );

      final relocated = course.relocatingSessionNote(fromWeek: 5, toWeek: 12);
      expect(relocated?[12]?.text, '测验');
      expect(relocated?[12]?.hasHomework, isTrue);
      expect(relocated?[5], isNull);
      expect(relocated?[6]?.text, '复习');

      final remaining = course.sessionNotesExcludingWeek(5);
      expect(remaining?[5], isNull);
      expect(remaining?[6]?.text, '复习');

      final single = course.sessionNotesForSingleWeek(
        sourceWeek: 5,
        targetWeek: 12,
      );
      expect(single?.keys, [12]);
      expect(single?[12]?.hasHomework, isTrue);
    },
  );
}
