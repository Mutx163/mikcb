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
    expect(restored.weekDescription(l10n), '第 2、4、6 周');
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

    expect(course.weekDescription(l10n), '第 1-3、5、7-9 周');
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

    expect(course.weekDescription(l10n), '第 2～6 周');
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

  test(
    'fromJson clamps customWeeks and suspendedWeeks like the week range',
    () {
      // 回归钉：startWeek/endWeek 一直被 normalizeWeeks 夹到 1..30，而
      // customWeeks/suspendedWeeks 曾是裸列表 —— 一份外部备份可以塞进任意多个、
      // 任意大的周次值，activeWeeks 原样吐出，导入去重键 weeks.join(',')
      // 与按周展开都会被放大。
      final course = Course.fromJson({
        'id': 'course-week-list',
        'name': '周次列表课',
        'teacher': '老师',
        'location': 'A1',
        'dayOfWeek': 1,
        'startSection': 1,
        'endSection': 1,
        'startTime': '08:00',
        'endTime': '09:40',
        'customWeeks': [37, 2, 0, -5, 2, 1000000000, 3, '4', 'x', 3.9, null],
        'suspendedWeeks': [31, 4, 999],
      });

      // 越界项丢弃、去重、升序；非数字项被忽略，而不是记作「第 0 周」。
      expect(course.customWeeks, [2, 3, 4]);
      expect(course.normalizedCustomWeeks, [2, 3, 4]);
      expect(course.suspendedWeeks, [4]);
      expect(course.normalizedSuspendedWeeks, [4]);
      expect(course.isSuspendedInWeek(4), isTrue);
      // 第 4 周同时被停课，activeWeeks 正确地把它排除（语义保持不变）。
      expect(course.activeWeeks, [2, 3]);
    },
  );

  test('fromJson rejects absurdly long week lists without traversing them', () {
    final course = Course.fromJson({
      'id': 'course-week-flood',
      'name': '洪水课',
      'teacher': '老师',
      'location': 'A1',
      'dayOfWeek': 1,
      'startSection': 1,
      'endSection': 1,
      'startTime': '08:00',
      'endTime': '09:40',
      'customWeeks': List<int>.generate(
        Course.maxWeekListEntries + 1,
        (index) => index,
      ),
    });

    expect(course.customWeeks, isNull);
    expect(course.hasCustomWeeks, isFalse);
    // 回落到 startWeek..endWeek 区间，长度有界。
    expect(course.activeWeeks.length, lessThanOrEqualTo(30));
  });

  test('week lists clamp at consumption too, for code-constructed courses', () {
    // 有些调用点直接读裸字段（timetable_provider.toggleCourseSuspension、
    // course_import_screen 的周次展示），所以解析侧钳了一遍；这里守住消费侧，
    // 覆盖不经 fromJson、直接构造的 Course。
    final course = Course(
      id: 'course-direct',
      name: '直接构造',
      teacher: '老师',
      location: 'A1',
      dayOfWeek: 1,
      startSection: 1,
      endSection: 1,
      startTime: '08:00',
      endTime: '09:40',
      customWeeks: [1, 4, 999999, 4, -1],
    );

    expect(course.normalizedCustomWeeks, [1, 4]);
    expect(course.activeWeeks, [1, 4]);
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
