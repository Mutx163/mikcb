import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/time_scheme.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    StorageService().resetForTesting();
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'migrates legacy single timetable data into a default profile',
    () async {
      final legacyCourse = Course(
        id: 'legacy-course',
        name: '大学英语',
        teacher: '李老师',
        location: 'B201',
        dayOfWeek: 2,
        startSection: 3,
        endSection: 4,
        startTime: '10:00',
        endTime: '11:40',
      );
      final legacySettings = TimetableSettings.defaults().copyWith(
        semesterWeekCount: 18,
        semesterStartDate: DateTime(2026, 2, 23),
      );

      SharedPreferences.setMockInitialValues({
        'courses': [legacyCourse.toJsonString()],
        'timetable_settings': legacySettings.toJsonString(),
        'current_week': 5,
        'semester_start': DateTime(2026, 2, 23).millisecondsSinceEpoch,
      });

      final storage = StorageService();
      await storage.init();

      final profiles = await storage.getProfiles();
      final activeProfileId = await storage.getActiveProfileId();

      expect(profiles, hasLength(1));
      expect(profiles.single.name, '默认课表');
      expect(profiles.single.courses.single.name, '大学英语');
      expect(profiles.single.settings.semesterWeekCount, 18);
      expect(profiles.single.currentWeek, 5);
      expect(activeProfileId, profiles.single.id);
      expect(profiles.single.settings.activeTimeSchemeId, isNotNull);

      final schemes = await storage.getTimeSchemes();
      expect(schemes, hasLength(1));
      expect(schemes.single.name, '当前课表时间');
    },
  );

  test('persists profiles and active profile id', () async {
    final storage = StorageService();
    await storage.init();

    final profiles = await storage.getProfiles();
    final profile = profiles.single.copyWith(name: '我的课表');
    await storage.saveProfiles([profile]);
    await storage.setActiveProfileId(profile.id);

    final restoredProfiles = await storage.getProfiles();
    final restoredActiveProfileId = await storage.getActiveProfileId();

    expect(restoredProfiles.single.name, '我的课表');
    expect(restoredActiveProfileId, profile.id);
  });

  test('persists and restores global time schemes', () async {
    final storage = StorageService();
    await storage.init();

    final scheme = TimeScheme(
      id: 'winter',
      name: '冬季作息',
      sections: const [SectionTime(startTime: '08:30', endTime: '09:15')],
      createdAt: DateTime(2026, 3, 22, 8),
      updatedAt: DateTime(2026, 3, 22, 8, 30),
    );
    await storage.saveTimeSchemes([scheme]);

    final restoredSchemes = await storage.getTimeSchemes();
    final restoredScheme = restoredSchemes.firstWhere(
      (item) => item.id == 'winter',
    );

    expect(restoredScheme.id, 'winter');
    expect(restoredScheme.sections.single.displayText, '08:30-09:15');
  });

  test('migrates existing profiles to hide prefix text by default', () async {
    final legacySettings = TimetableSettings.defaults().copyWith(
      liveHidePrefixText: false,
    );
    final profileJson = [
      {
        'id': 'profile-1',
        'name': '默认课表',
        'courses': [],
        'settings': legacySettings.toJson(),
        'currentWeek': 1,
        'createdAt': DateTime(2026, 3, 22, 8).toIso8601String(),
        'lastUsedAt': DateTime(2026, 3, 22, 8).toIso8601String(),
      },
    ];

    SharedPreferences.setMockInitialValues({
      'timetable_profiles': jsonEncode(profileJson),
      'active_timetable_profile_id': 'profile-1',
      'time_schemes': jsonEncode([]),
    });

    final storage = StorageService();
    await storage.init();

    final profiles = await storage.getProfiles();

    expect(profiles.single.settings.liveHidePrefixText, isTrue);
  });

  test('backs up corrupt profiles and recreates default profile', () async {
    SharedPreferences.setMockInitialValues({
      'timetable_profiles': '{bad-json',
      'active_timetable_profile_id': 'profile-1',
    });

    final storage = StorageService();
    await storage.init();

    final profiles = await storage.getProfiles();
    final prefs = await SharedPreferences.getInstance();

    expect(profiles, hasLength(1));
    expect(profiles.single.name, '默认课表');
    expect(prefs.getString('timetable_profiles'), isNot('{bad-json'));
    expect(
      prefs.getKeys().where(
        (key) => key.startsWith('timetable_profiles_corrupt_backup_'),
      ),
      isNotEmpty,
    );
  });

  test('creates a default profile for a valid empty profile list', () async {
    SharedPreferences.setMockInitialValues({
      'timetable_profiles': '[]',
    });

    final storage = StorageService();
    await storage.init();

    final profiles = await storage.getProfiles();

    expect(profiles, hasLength(1));
    expect(profiles.single.name, '默认课表');
  });

  test(
    'backs up valid-json profiles with no recoverable entries and recreates default profile',
    () async {
      SharedPreferences.setMockInitialValues({
        'timetable_profiles': jsonEncode([
          <String, dynamic>{'id': null, 'name': '坏档案'},
          <String, dynamic>{'settings': 'not-a-map'},
        ]),
        'active_timetable_profile_id': 'missing-profile',
      });

      final storage = StorageService();
      await storage.init();

      final profiles = await storage.getProfiles();
      final prefs = await SharedPreferences.getInstance();

      expect(profiles, hasLength(1));
      expect(profiles.single.name, '默认课表');
      expect(prefs.getString('timetable_profiles'), isNotEmpty);
      expect(
        prefs.getKeys().where(
          (key) => key.startsWith('timetable_profiles_corrupt_backup_'),
        ),
        isNotEmpty,
      );
    },
  );

  test(
    'backs up corrupt legacy courses and falls back to empty list',
    () async {
      SharedPreferences.setMockInitialValues({
        'courses': ['{bad-json'],
      });

      final storage = StorageService();
      await storage.init();

      final courses = await storage.getCourses();
      final prefs = await SharedPreferences.getInstance();

      expect(courses, isEmpty);
      expect(prefs.getStringList('courses'), isNull);
      expect(
        prefs.getKeys().where(
          (key) => key.startsWith('courses_corrupt_backup_'),
        ),
        isNotEmpty,
      );
    },
  );
}
