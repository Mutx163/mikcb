import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/providers/timetable_provider.dart';

Course _course({
  required String id,
  required String name,
  required int day,
  required int start,
  required int end,
  required List<int> weeks,
  String teacher = '老师',
  String location = '教室',
  String? shortName,
  String color = '#2196F3',
  String? note,
  String? description,
  String? timeSchemeIdOverride,
}) {
  return Course(
    id: id,
    name: name,
    shortName: shortName,
    teacher: teacher,
    location: location,
    dayOfWeek: day,
    startSection: start,
    endSection: end,
    startTime: '',
    endTime: '',
    color: color,
    customWeeks: weeks,
    note: note,
    description: description,
    timeSchemeIdOverride: timeSchemeIdOverride,
  );
}

void main() {
  test(
    'dedupeImportedCourses removes duplicates already in existing courses',
    () {
      final existing = [
        _course(
          id: 'a',
          name: '高等数学',
          day: 1,
          start: 1,
          end: 2,
          weeks: [1, 2, 3, 4],
        ),
      ];
      final imported = [
        _course(
          id: 'b',
          name: '高等数学',
          day: 1,
          start: 1,
          end: 2,
          weeks: [1, 2, 3, 4],
        ),
        _course(
          id: 'c',
          name: '大学英语',
          day: 2,
          start: 3,
          end: 4,
          weeks: [1, 2, 3, 4],
        ),
      ];

      final deduped = dedupeImportedCourses(
        imported,
        existingCourses: existing,
      );

      expect(deduped, hasLength(1));
      expect(deduped.first.name, '大学英语');
    },
  );

  test('dedupeImportedCourses removes duplicates within imported batch', () {
    final imported = [
      _course(
        id: 'a',
        name: '高等数学',
        day: 1,
        start: 1,
        end: 2,
        weeks: [1, 2, 3, 4],
      ),
      _course(
        id: 'b',
        name: '高等数学',
        day: 1,
        start: 1,
        end: 2,
        weeks: [1, 2, 3, 4],
      ),
    ];

    final deduped = dedupeImportedCourses(imported);

    expect(deduped, hasLength(1));
  });

  test('syncImportedCourses does not soft-match across different weekdays', () {
    final existing = [
      _course(
        id: 'a',
        name: '高等数学',
        day: 1,
        start: 1,
        end: 2,
        weeks: [1, 2, 3, 4, 5, 6],
        teacher: '张老师',
        location: 'A101',
        shortName: '高数',
        color: '#FF0000',
        note: '验收备注',
        description: '课程简介',
        timeSchemeIdOverride: 'scheme_a',
      ),
    ];
    final imported = [
      _course(
        id: 'b',
        name: '高等数学',
        day: 3,
        start: 3,
        end: 4,
        weeks: [1, 2, 3, 4, 5, 6],
        teacher: '张老师',
        location: 'B202',
      ),
    ];

    final result = syncImportedCourses(
      existingCourses: existing,
      importedCourses: imported,
    );

    expect(result.addedCount, 1);
    expect(result.updatedCount, 0);
    expect(result.mergedCourses, hasLength(2));
    expect(result.mergedCourses.map((c) => c.dayOfWeek).toSet(), {1, 3});
  });

  test(
    'syncImportedCourses soft-matches same weekday and keeps local fields',
    () {
      final existing = [
        _course(
          id: 'a',
          name: '高等数学',
          day: 1,
          start: 1,
          end: 2,
          weeks: [1, 2, 3, 4, 5, 6],
          teacher: '张老师',
          location: 'A101',
          shortName: '高数',
          color: '#FF0000',
          note: '验收备注',
          description: '课程简介',
          timeSchemeIdOverride: 'scheme_a',
        ),
      ];
      final imported = [
        _course(
          id: 'b',
          name: '高等数学',
          day: 1,
          start: 3,
          end: 4,
          weeks: [1, 2, 3, 4, 5, 6],
          teacher: '张老师',
          location: 'B202',
        ),
      ];

      final result = syncImportedCourses(
        existingCourses: existing,
        importedCourses: imported,
      );

      expect(result.addedCount, 0);
      expect(result.updatedCount, 1);
      expect(result.mergedCourses, hasLength(1));
      final merged = result.mergedCourses.first;
      expect(merged.id, 'a');
      expect(merged.dayOfWeek, 1);
      expect(merged.startSection, 3);
      expect(merged.endSection, 4);
      expect(merged.location, 'B202');
      expect(merged.shortName, '高数');
      expect(merged.color, '#FF0000');
      expect(merged.note, '验收备注');
      expect(merged.description, '课程简介');
      expect(merged.timeSchemeIdOverride, 'scheme_a');
    },
  );

  test(
    'mergeImportedCourseWithExisting keeps teacher and location when imported data is blank',
    () {
      final existing = _course(
        id: 'a',
        name: '大学英语',
        day: 2,
        start: 3,
        end: 4,
        weeks: [1, 2, 3],
        teacher: '李老师',
        location: 'C303',
        shortName: '英语',
        color: '#00FF00',
      );
      final imported = _course(
        id: 'b',
        name: '大学英语',
        day: 2,
        start: 3,
        end: 4,
        weeks: [1, 2, 3],
        teacher: '',
        location: '',
      );

      final merged = mergeImportedCourseWithExisting(existing, imported);

      expect(merged.id, 'a');
      expect(merged.teacher, '李老师');
      expect(merged.location, 'C303');
      expect(merged.shortName, '英语');
      expect(merged.color, '#00FF00');
    },
  );

  test(
    'syncImportedCourses treats split local records and one imported custom-week record as same schedule group',
    () {
      final existing = [
        _course(
          id: 'a',
          name: '高等数学',
          day: 1,
          start: 1,
          end: 2,
          weeks: [1, 2, 3, 4, 5],
          shortName: '高数',
          color: '#FF0000',
        ),
        _course(
          id: 'b',
          name: '高等数学',
          day: 1,
          start: 1,
          end: 2,
          weeks: [7, 8],
          shortName: '高数',
          color: '#FF0000',
        ),
        _course(
          id: 'c',
          name: '高等数学',
          day: 1,
          start: 1,
          end: 2,
          weeks: [11, 12, 13],
          shortName: '高数',
          color: '#FF0000',
        ),
      ];
      final imported = [
        _course(
          id: 'new',
          name: '高等数学',
          day: 1,
          start: 1,
          end: 2,
          weeks: [1, 2, 3, 4, 5, 7, 8, 11, 12, 13],
          teacher: '张老师',
          location: 'A101',
        ),
      ];

      final result = syncImportedCourses(
        existingCourses: existing,
        importedCourses: imported,
      );

      expect(result.addedCount, 0);
      expect(result.updatedCount, 3);
      expect(result.mergedCourses, hasLength(3));
      expect(
        result.mergedCourses
            .map((course) => course.activeWeeks.join(','))
            .toSet(),
        {'1,2,3,4,5', '7,8', '11,12,13'},
      );
      expect(
        result.mergedCourses.every((course) => course.shortName == '高数'),
        isTrue,
      );
      expect(
        result.mergedCourses.every((course) => course.teacher == '张老师'),
        isTrue,
      );
    },
  );

  test(
    'syncImportedCourses keeps local-only courses and merges same-day imported updates',
    () {
      final existing = [
        _course(
          id: 'a',
          name: '高等数学',
          day: 1,
          start: 1,
          end: 2,
          weeks: [1, 2, 3, 4, 5, 6],
          teacher: '张老师',
          location: 'A101',
          shortName: '高数',
        ),
        _course(
          id: 'stale',
          name: '线性代数',
          day: 5,
          start: 3,
          end: 4,
          weeks: [1, 2, 3, 4],
        ),
      ];
      final imported = [
        _course(
          id: 'new-a',
          name: '高等数学',
          day: 1,
          start: 3,
          end: 4,
          weeks: [1, 2, 3, 4, 5, 6],
          teacher: '张老师',
          location: 'B202',
        ),
      ];

      final result = syncImportedCourses(
        existingCourses: existing,
        importedCourses: imported,
      );

      expect(result.mergedCourses, hasLength(2));
      expect(result.addedCount, 0);
      expect(result.updatedCount, 1);
      expect(
        result.mergedCourses.any((course) => course.name == '线性代数'),
        isTrue,
      );
    },
  );

  test(
    'replaceImportedCoursesPreservingLocalFields removes stale courses and keeps local metadata',
    () {
      final existing = [
        _course(
          id: 'a',
          name: '高等数学',
          day: 1,
          start: 1,
          end: 2,
          weeks: [1, 2, 3, 4, 5, 6],
          teacher: '张老师',
          location: 'A101',
          shortName: '高数',
          color: '#FF0000',
          note: '本地备注',
          description: '本地简介',
          timeSchemeIdOverride: 'scheme_a',
        ),
        _course(
          id: 'stale',
          name: '线性代数',
          day: 5,
          start: 3,
          end: 4,
          weeks: [1, 2, 3, 4],
        ),
      ];
      final imported = [
        _course(
          id: 'new-a',
          name: '高等数学',
          day: 1,
          start: 3,
          end: 4,
          weeks: [1, 2, 3, 4, 5, 6],
          teacher: '张老师',
          location: 'B202',
        ),
      ];

      final replaced = replaceImportedCoursesPreservingLocalFields(
        existingCourses: existing,
        importedCourses: imported,
      );

      expect(replaced, hasLength(1));
      expect(replaced.single.id, 'a');
      expect(replaced.single.name, '高等数学');
      expect(replaced.single.dayOfWeek, 1);
      expect(replaced.single.startSection, 3);
      expect(replaced.single.endSection, 4);
      expect(replaced.single.location, 'B202');
      expect(replaced.single.shortName, '高数');
      expect(replaced.single.color, '#FF0000');
      expect(replaced.single.note, '本地备注');
      expect(replaced.single.description, '本地简介');
      expect(replaced.single.timeSchemeIdOverride, 'scheme_a');
    },
  );

  test(
    'replaceImportedCoursesPreservingLocalFields fans shared local fields into split imported schedules',
    () {
      final existing = [
        _course(
          id: 'a',
          name: '大学英语',
          day: 2,
          start: 3,
          end: 4,
          weeks: [1, 2, 3, 4, 5, 6, 7, 8],
          shortName: '英语',
          color: '#00FF00',
          description: '共享简介',
        ),
      ];
      final imported = [
        _course(
          id: 'b',
          name: '大学英语',
          day: 2,
          start: 3,
          end: 4,
          weeks: [1, 2, 3, 4],
        ),
        _course(
          id: 'c',
          name: '大学英语',
          day: 2,
          start: 3,
          end: 4,
          weeks: [5, 6, 7, 8],
        ),
      ];

      final replaced = replaceImportedCoursesPreservingLocalFields(
        existingCourses: existing,
        importedCourses: imported,
      );

      expect(replaced, hasLength(2));
      expect(replaced.map((course) => course.shortName).toSet(), {'英语'});
      expect(replaced.map((course) => course.color).toSet(), {'#00FF00'});
      expect(replaced.map((course) => course.description).toSet(), {'共享简介'});
    },
  );
}
