import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/timetable_profile.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    StorageService().resetForTesting();
    final now = DateTime(2026, 4, 12);
    final profile = TimetableProfile(
      id: 'profile-1',
      name: '默认课表',
      courses: const [],
      settings: TimetableSettings.defaults(),
      currentWeek: 1,
      createdAt: now,
      lastUsedAt: now,
    );
    SharedPreferences.setMockInitialValues({
      'did_migrate_app_logs_default': true,
      'did_migrate_live_hide_prefix_default': true,
      'timetable_profiles': jsonEncode([profile.toJson()]),
      'active_timetable_profile_id': profile.id,
      'time_schemes': '[]',
    });
  });

  Future<TimetableProvider> seededProvider() async {
    final provider = TimetableProvider(
      autoInitialize: false,
      enableLiveActivitySync: false,
    );
    await provider.initialize();
    await provider.updateTimetableSettings(
      provider.settings.copyWith(
        semesterStartDate: DateTime(2026, 4, 6),
        semesterWeekCount: 20,
        timetableHideWeekends: false,
      ),
    );
    return provider;
  }

  Course mathEntry({
    required String id,
    required int dayOfWeek,
    String color = '#E91E63',
  }) {
    return Course(
      id: id,
      name: '高等数学',
      teacher: '张老师',
      location: 'A101',
      dayOfWeek: dayOfWeek,
      startSection: dayOfWeek == 1 ? 1 : 3,
      endSection: dayOfWeek == 1 ? 2 : 4,
      startTime: dayOfWeek == 1 ? '08:00' : '10:00',
      endTime: dayOfWeek == 1 ? '09:40' : '11:40',
      color: color,
    );
  }

  test('updateCourseGroup persists the new color and notifies', () async {
    final provider = await seededProvider();
    var notified = 0;
    provider.addListener(() => notified++);

    await provider.addCourse(mathEntry(id: 'c1', dayOfWeek: 1));
    expect(provider.courses.single.color, '#E91E63');

    final group = provider.courseGroupForCourse(provider.courses.first)!;
    final updated =
        group.courses.map((c) => c.copyWith(color: '#4CAF50')).toList();
    await provider.updateCourseGroup(group.name, updated);

    expect(provider.courses.single.color, '#4CAF50');
    expect(notified, greaterThan(0));
  });

  test(
    'editor single-course save (group-replace) keeps the picked color '
    'even with same-name siblings', () async {
      final provider = await seededProvider();

      // A course group with two schedule entries sharing one name.
      await provider.addCourse(mathEntry(id: 'c1', dayOfWeek: 1));
      await provider.addCourse(mathEntry(id: 'c2', dayOfWeek: 3));

      // What _saveGroup's single-course branch does now: replace the whole
      // original-name group with the edited set (only c1 rebuilt here).
      final rebuilt = mathEntry(id: 'c1', dayOfWeek: 1, color: '#4CAF50');
      await provider.updateCourseGroup('高等数学', [rebuilt]);

      expect(provider.courses.length, 1);
      expect(provider.courses.single.id, 'c1');
      expect(provider.courses.single.color, '#4CAF50');
    },
  );

  test(
    'addCourse shared-field step still unifies fresh imports (regression)',
    () async {
      final provider = await seededProvider();

      // Import flow adds a second entry of the same name WITHOUT color set
      // consistently; addCourse should propagate the sibling's shared fields.
      await provider.addCourse(mathEntry(id: 'c1', dayOfWeek: 1));
      final second = mathEntry(id: 'c2', dayOfWeek: 3, color: '#2196F3');
      await provider.addCourse(second);

      // The later entry inherits the existing group's shared color.
      expect(
        provider.courses.where((c) => c.id == 'c2').single.color,
        '#E91E63',
      );
    },
  );
}
