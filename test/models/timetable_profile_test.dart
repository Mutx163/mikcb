import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/timetable_profile.dart';
import 'package:university_timetable/models/timetable_settings.dart';

void main() {
  test('timetable profile serializes and restores complete state', () {
    final profile = TimetableProfile(
      id: 'profile-1',
      name: '大一上',
      courses: [
        Course(
          id: 'course-1',
          name: '高数',
          teacher: '张老师',
          location: 'A101',
          dayOfWeek: 1,
          startSection: 1,
          endSection: 2,
          startTime: '08:00',
          endTime: '09:40',
        ),
      ],
      settings: TimetableSettings.defaults().copyWith(semesterWeekCount: 24),
      currentWeek: 6,
      createdAt: DateTime(2026, 3, 22, 9),
      lastUsedAt: DateTime(2026, 3, 22, 10),
    );

    final restored = TimetableProfile.fromJson(profile.toJson());

    expect(restored.id, 'profile-1');
    expect(restored.name, '大一上');
    expect(restored.courses.single.name, '高数');
    expect(restored.settings.semesterWeekCount, 24);
    expect(restored.currentWeek, 6);
    expect(restored.createdAt, DateTime(2026, 3, 22, 9));
    expect(restored.lastUsedAt, DateTime(2026, 3, 22, 10));
  });
}
