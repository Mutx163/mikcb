import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/exam.dart';
import 'package:university_timetable/models/location_time_group.dart';
import 'package:university_timetable/models/schedule_date_rule.dart';
import 'package:university_timetable/models/time_scheme.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/services/transfer_diff_service.dart';
import 'package:university_timetable/services/transfer_package.dart';

Course _course({String id = 'course-1', String name = '线性代数'}) {
  return Course(
    id: id,
    name: name,
    teacher: 'Teacher',
    location: 'A-101',
    dayOfWeek: 1,
    startSection: 1,
    endSection: 2,
    startTime: '08:00',
    endTime: '09:40',
  );
}

Exam _exam({String id = 'exam-1', String courseId = 'course-1'}) {
  final now = DateTime(2026, 4, 1);
  return Exam(
    id: id,
    courseId: courseId,
    name: '期中考试',
    dateTime: now,
    startTime: '09:00',
    endTime: '11:00',
    createdAt: now,
    updatedAt: now,
  );
}

TimeScheme _scheme({String id = 'scheme-1', String name = '工作日作息'}) {
  return TimeScheme(
    id: id,
    name: name,
    sections: const [SectionTime(startTime: '08:00', endTime: '08:45')],
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
}

void main() {
  test('round trips a versioned package with scope and channel', () {
    final package = TransferPackage(
      packageId: 'transfer-test-1',
      scope: TransferScope.selectedCourses,
      channel: TransferChannel.qr,
      profileName: '大二下',
      courses: [_course()],
      exams: [_exam()],
      timeSchemes: [_scheme()],
      scheduleDateRules: const [
        ScheduleDateRule(
          id: 'rule-1',
          name: '考试周',
          timeSchemeId: 'scheme-1',
          startDate: '2026-06-01',
          endDate: '2026-06-07',
        ),
      ],
      locationTimeGroups: const [
        LocationTimeGroup(
          id: 'location-1',
          name: '主教学楼',
          timeSchemeId: 'scheme-1',
          keywords: [LocationKeyword(pattern: 'A')],
        ),
      ],
      settings: TimetableSettings.defaults(),
      currentWeek: 5,
    );

    final restored = TransferPackage.decode(package.encode());

    expect(restored.packageId, package.packageId);
    expect(restored.scope, TransferScope.selectedCourses);
    expect(restored.channel, TransferChannel.qr);
    expect(restored.courses.single.name, '线性代数');
    expect(restored.exams.single.courseId, 'course-1');
    expect(restored.scheduleDateRules.single.timeSchemeId, 'scheme-1');
    expect(restored.locationTimeGroups.single.keywords.single.pattern, 'A');
  });

  test('rejects unsupported schema before any model is applied', () {
    final raw = <String, dynamic>{
      'app': TransferPackage.appId,
      'packageType': TransferPackage.packageType,
      'schemaVersion': TransferPackage.schemaVersion + 1,
      'packageId': 'future-package',
      'scope': TransferScope.currentTimetable.value,
    };

    expect(
      () => TransferPackage.decode(jsonEncode(raw)),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          'transfer_package_schema_unsupported',
        ),
      ),
    );
  });

  test(
    'reports added, updated and removed entities for merge and overwrite',
    () {
      final current = TransferPackage(
        packageId: 'current',
        scope: TransferScope.currentTimetable,
        courses: [
          _course(id: 'course-1', name: '旧名称'),
          _course(id: 'course-2'),
        ],
        exams: [_exam()],
        scheduleDateRules: const [
          ScheduleDateRule(
            id: 'rule-1',
            name: '旧规则',
            timeSchemeId: 'scheme-1',
            startDate: '2026-06-01',
            endDate: '2026-06-07',
          ),
        ],
        locationTimeGroups: const [
          LocationTimeGroup(
            id: 'location-1',
            name: '旧地点',
            timeSchemeId: 'scheme-1',
          ),
        ],
      );
      final incoming = TransferPackage(
        packageId: 'incoming',
        scope: TransferScope.currentTimetable,
        courses: [
          _course(id: 'course-1', name: '新名称'),
          _course(id: 'course-3'),
        ],
        exams: [_exam(id: 'exam-2')],
        scheduleDateRules: const [
          ScheduleDateRule(
            id: 'rule-1',
            name: '新规则',
            timeSchemeId: 'scheme-1',
            startDate: '2026-06-01',
            endDate: '2026-06-07',
          ),
        ],
        locationTimeGroups: const [
          LocationTimeGroup(
            id: 'location-2',
            name: '新地点',
            timeSchemeId: 'scheme-1',
          ),
        ],
      );

      const service = TransferDiffService();
      final merge = service.compare(current: current, incoming: incoming);
      final overwrite = service.compare(
        current: current,
        incoming: incoming,
        mode: TransferApplyMode.overwrite,
      );

      expect(merge.forKind(TransferEntityKind.courses).addedCount, 1);
      expect(merge.forKind(TransferEntityKind.courses).updatedCount, 1);
      expect(merge.forKind(TransferEntityKind.courses).removedCount, 0);
      expect(overwrite.forKind(TransferEntityKind.courses).removedCount, 1);
      expect(merge.forKind(TransferEntityKind.timeRules).updatedCount, 1);
      expect(merge.forKind(TransferEntityKind.locations).addedCount, 1);
      expect(overwrite.forKind(TransferEntityKind.locations).removedCount, 1);
    },
  );

  test(
    'returns link warnings without rejecting a shareable partial package',
    () {
      final package = TransferPackage(
        packageId: 'partial',
        scope: TransferScope.selectedCourse,
        courses: [_course()],
        exams: [_exam(courseId: 'course-not-in-share')],
      );

      final validation = const TransferDiffService().validate(package);

      expect(validation.isValid, isTrue);
      expect(validation.warnings, contains('exam_course_missing:exam-1'));
    },
  );
}
