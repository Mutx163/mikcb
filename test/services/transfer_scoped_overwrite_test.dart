import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/time_scheme.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/services/transfer_diff_service.dart';
import 'package:university_timetable/services/transfer_package.dart';

Course _course(String id) {
  return Course(
    id: id,
    name: 'Course $id',
    teacher: 'Teacher',
    location: 'Room',
    dayOfWeek: 1,
    startSection: 1,
    endSection: 2,
    startTime: '08:00',
    endTime: '09:40',
  );
}

TimeScheme _timeScheme(String id) {
  return TimeScheme(
    id: id,
    name: 'Scheme $id',
    sections: const [SectionTime(startTime: '08:00', endTime: '08:45')],
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}

void main() {
  test('scoped overwrite preview does not report merge-only removals', () {
    final current = TransferPackage(
      packageId: 'current',
      scope: TransferScope.currentTimetable,
      courses: [_course('course-1'), _course('course-2')],
      timeSchemes: [_timeScheme('scheme-1'), _timeScheme('scheme-2')],
    );

    for (final scope in const [
      TransferScope.selectedCourse,
      TransferScope.selectedCourses,
      TransferScope.weekTimetable,
      TransferScope.timeTemplate,
    ]) {
      final incoming = TransferPackage(
        packageId: 'incoming-${scope.name}',
        scope: scope,
        courses: [_course('course-1')],
        timeSchemes: [_timeScheme('scheme-1')],
      );
      final preview = const TransferDiffService().compare(
        current: current,
        incoming: incoming,
        mode: TransferApplyMode.overwrite,
      );

      expect(
        preview.forKind(TransferEntityKind.courses).removedCount,
        0,
        reason: scope.name,
      );
      expect(
        preview.forKind(TransferEntityKind.timeSchemes).removedCount,
        0,
        reason: scope.name,
      );
    }
  });

  test('full timetable overwrite preview still reports removals', () {
    final current = TransferPackage(
      packageId: 'current',
      scope: TransferScope.currentTimetable,
      courses: [_course('course-1'), _course('course-2')],
      timeSchemes: [_timeScheme('scheme-1'), _timeScheme('scheme-2')],
    );
    final incoming = TransferPackage(
      packageId: 'incoming',
      scope: TransferScope.currentTimetable,
      courses: [_course('course-1')],
      timeSchemes: [_timeScheme('scheme-1')],
    );

    final preview = const TransferDiffService().compare(
      current: current,
      incoming: incoming,
      mode: TransferApplyMode.overwrite,
    );

    expect(preview.forKind(TransferEntityKind.courses).removedCount, 1);
    expect(preview.forKind(TransferEntityKind.timeSchemes).removedCount, 1);
  });
}
