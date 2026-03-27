import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/services/home_widget_snapshot_service.dart';

void main() {
  test(
      'widget snapshot can hide completed courses while preserving daily state',
      () {
    const service = HomeWidgetSnapshotService();
    final settings = TimetableSettings.defaults().copyWith(
      widgetHideCompletedCourses: true,
      widgetHeightAdjustment: 8,
      widgetCornerRadius: 16,
    );
    final now = DateTime(2026, 3, 27, 14, 30);
    final courses = [
      Course(
        id: 'finished',
        name: '高等数学',
        teacher: '张老师',
        location: 'A101',
        dayOfWeek: now.weekday,
        startSection: 1,
        endSection: 2,
        startTime: '08:00',
        endTime: '09:35',
      ),
      Course(
        id: 'ongoing',
        name: '大学英语',
        teacher: '李老师',
        location: 'B203',
        dayOfWeek: now.weekday,
        startSection: 5,
        endSection: 6,
        startTime: '14:00',
        endTime: '15:35',
      ),
      Course(
        id: 'upcoming',
        name: '程序设计',
        teacher: '王老师',
        location: 'C305',
        dayOfWeek: now.weekday,
        startSection: 7,
        endSection: 8,
        startTime: '16:00',
        endTime: '17:35',
      ),
    ];

    final snapshot = service.build(
      profileId: 'profile-1',
      profileName: '默认课表',
      currentWeek: 6,
      settings: settings,
      todayCourses: courses,
      now: now,
    );

    expect(snapshot.state, HomeWidgetSnapshotState.ongoing);
    expect(snapshot.totalTodayCourseCount, 3);
    expect(snapshot.heightAdjustment, 8);
    expect(snapshot.cornerRadius, 16);
    expect(snapshot.todayCourses, hasLength(3));
    expect(snapshot.visibleTodayCourses.map((course) => course.id), [
      'ongoing',
      'upcoming',
    ]);
    expect(snapshot.highlightedCourse?.id, 'ongoing');
  });
}
