import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/timetable_profile.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/services/storage_service.dart';

/// 一键重刷全课表颜色（applyCourseRecolors）的 provider 契约。
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

  test('按 id 覆盖颜色/文字色，其余字段保持并通知', () async {
    final provider = await seededProvider();
    await provider.addCourse(mathEntry(id: 'c1', dayOfWeek: 1));
    await provider.addCourse(mathEntry(id: 'c2', dayOfWeek: 3));
    var notified = 0;
    provider.addListener(() => notified++);

    final recolored = provider.courses
        .map((c) => c.copyWith(color: '#4CAF50', textColor: '#FFFFFF'))
        .toList();
    final updatedCount = await provider.applyCourseRecolors(recolored);

    expect(updatedCount, 2);
    expect(provider.courses.every((c) => c.color == '#4CAF50'), isTrue);
    expect(provider.courses.every((c) => c.textColor == '#FFFFFF'), isTrue);
    // 非颜色字段不动。
    expect(provider.courses.map((c) => c.dayOfWeek), [1, 3]);
    expect(provider.courses.every((c) => c.location == 'A101'), isTrue);
    expect(notified, greaterThan(0));
  });

  test('无变化（同色）返回 0 且不通知', () async {
    final provider = await seededProvider();
    await provider.addCourse(mathEntry(id: 'c1', dayOfWeek: 1));
    var notified = 0;
    provider.addListener(() => notified++);

    final unchanged = provider.courses.map((c) => c.copyWith()).toList();
    final updatedCount = await provider.applyCourseRecolors(unchanged);

    expect(updatedCount, 0);
    expect(notified, 0);
  });

  test('空课表 / 空输入返回 0', () async {
    final provider = await seededProvider();
    expect(await provider.applyCourseRecolors(const []), 0);
    await provider.addCourse(mathEntry(id: 'c1', dayOfWeek: 1));
    // id 不在课表里的副本不会误改任何课程。
    final stranger = mathEntry(id: 'ghost', dayOfWeek: 5, color: '#4CAF50');
    expect(await provider.applyCourseRecolors([stranger]), 0);
    expect(provider.courses.single.color, '#E91E63');
  });

  test('重刷结果持久化：新 provider 重读可见', () async {
    final provider = await seededProvider();
    await provider.addCourse(mathEntry(id: 'c1', dayOfWeek: 1));
    await provider.addCourse(mathEntry(id: 'c2', dayOfWeek: 3));
    await provider.applyCourseRecolors(
      provider.courses
          .map((c) => c.copyWith(color: '#4CAF50', textColor: null))
          .toList(),
    );

    final reloaded = TimetableProvider(
      autoInitialize: false,
      enableLiveActivitySync: false,
    );
    await reloaded.initialize();

    expect(reloaded.courses.length, 2);
    expect(reloaded.courses.every((c) => c.color == '#4CAF50'), isTrue);
  });
}
