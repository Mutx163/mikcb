import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/services/ai_course_import_service.dart';

void main() {
  final service = AiCourseImportService();
  final settings = TimetableSettings.defaults();

  test('parses valid ai import json into courses', () {
    const content = '''
{
  "schema": "mikcb_ai_import_v1",
  "courses": [
    {
      "name": "程序设计技术基础",
      "teacher": "黄群惠",
      "location": "A主101",
      "dayOfWeek": 1,
      "startSection": 9,
      "endSection": 10,
      "customWeeks": [3, 4, 5, 6, 7, 8, 9, 11],
      "courseNature": "required",
      "note": "25机械设计（专升本）[1-3]班(107)"
    }
  ],
  "warnings": []
}
''';

    final result = service.parse(content, settings: settings);

    expect(result.courses, hasLength(1));
    expect(result.courses.first.name, '程序设计技术基础');
    expect(result.courses.first.teacher, '黄群惠');
    expect(result.courses.first.location, 'A主101');
    expect(result.courses.first.dayOfWeek, 1);
    expect(result.courses.first.startSection, 9);
    expect(result.courses.first.endSection, 10);
    expect(result.courses.first.customWeeks, [3, 4, 5, 6, 7, 8, 9, 11]);
    expect(result.requiredSectionCount, 10);
  });

  test('accepts markdown code fence wrapped json', () {
    const content = '''
```json
{
  "schema": "mikcb_ai_import_v1",
  "courses": [
    {
      "name": "就业指导",
      "teacher": "周政霖",
      "location": "A主402",
      "dayOfWeek": "5",
      "startSection": "9",
      "endSection": "10",
      "customWeeks": [14, 11, 12, 13],
      "courseNature": "required",
      "note": ""
    }
  ],
  "warnings": ["图片有少量重叠，已自动去重"]
}
```
''';

    final result = service.parse(content, settings: settings);

    expect(result.courses, hasLength(1));
    expect(result.courses.first.dayOfWeek, 5);
    expect(result.courses.first.customWeeks, [11, 12, 13, 14]);
    expect(result.warnings, ['图片有少量重叠，已自动去重']);
  });

  test('rejects unsupported course fields', () {
    const content = '''
{
  "schema": "mikcb_ai_import_v1",
  "courses": [
    {
      "name": "机电传动控制",
      "teacher": "刘驰",
      "location": "A主215",
      "dayOfWeek": 1,
      "startSection": 9,
      "endSection": 10,
      "customWeeks": [1, 2, 3, 4],
      "courseNature": "required",
      "note": "",
      "startTime": "08:00"
    }
  ],
  "warnings": []
}
''';

    expect(
      () => service.parse(content, settings: settings),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('ai_unknown_fields'),
        ),
      ),
    );
  });

  test('infers course nature from name and parses week expression string', () {
    const content = '''
{
  "schema": "mikcb_ai_import_v1",
  "courses": [
    {
      "name": "数控技术及应用课程设计[32][必修]",
      "teacher": "朱小飞",
      "location": "A3202",
      "dayOfWeek": 2,
      "startSection": 1,
      "endSection": 4,
      "customWeeks": "14-15(全部)[01-02-03-04节]",
      "courseNature": "",
      "note": "25机械设计（专升本）03班(33)"
    }
  ],
  "warnings": []
}
''';

    final result = service.parse(content, settings: settings);
    final course = result.courses.first;

    expect(course.name, '数控技术及应用课程设计');
    expect(course.courseNature, CourseNature.required);
    expect(course.customWeeks, [14, 15]);
    expect(course.startSection, 1);
    expect(course.endSection, 4);
  });
}
