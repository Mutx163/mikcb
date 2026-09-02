import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/services/storage_service.dart';

/// isAppDataEffectivelyEmpty 此前零测试覆盖——「空 copyWith() 让
/// activeTimeSchemeId 混入默认性比较、迁移引导永不弹出」的潜在回归
/// （Issue #52 审核 S1）正是靠这组测试守住。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    StorageService().resetForTesting();
    SharedPreferences.setMockInitialValues({});
  });

  Course course(String id) {
    return Course(
      id: id,
      name: '高等数学',
      teacher: 'T',
      location: 'R',
      dayOfWeek: 1,
      startSection: 1,
      endSection: 2,
      startTime: '08:00',
      endTime: '09:40',
    );
  }

  Map<String, Object?> singleProfileJson(
    TimetableSettings settings, {
    List<Course> courses = const [],
  }) {
    return {
      'id': 'profile-1',
      'name': '默认课表',
      'courses': courses.map((c) => c.toJson()).toList(),
      'settings': settings.toJson(),
      'currentWeek': 1,
      'createdAt': DateTime(2026, 3).toIso8601String(),
      'lastUsedAt': DateTime(2026, 3).toIso8601String(),
    };
  }

  test('single empty profile with auto-backfilled scheme id counts as empty',
      () async {
    // 时间方案初始化会无条件给每个 profile 回填 activeTimeSchemeId（自动
    // 生成、非用户自定义）。「空数据」判定必须排除该字段，否则老包迁移
    // 引导（PackageMigrationGuide）在这种最典型的新装用户上永不弹出。
    final settings =
        TimetableSettings.defaults().copyWith(activeTimeSchemeId: 'scheme-1');
    SharedPreferences.setMockInitialValues({
      'timetable_profiles': jsonEncode([singleProfileJson(settings)]),
      'active_timetable_profile_id': 'profile-1',
    });

    final storage = StorageService();
    await storage.init();

    expect(await storage.isAppDataEffectivelyEmpty(), isTrue);
  });

  test('profile with any course counts as non-empty', () async {
    final settings =
        TimetableSettings.defaults().copyWith(activeTimeSchemeId: 'scheme-1');
    SharedPreferences.setMockInitialValues({
      'timetable_profiles': jsonEncode([
        singleProfileJson(settings, courses: [course('c1')]),
      ]),
      'active_timetable_profile_id': 'profile-1',
    });

    final storage = StorageService();
    await storage.init();

    expect(await storage.isAppDataEffectivelyEmpty(), isFalse);
  });

  test('settings without scheme id unchanged: defaults still count as empty',
      () async {
    // 无 scheme id 的默认设置与 defaults 全等（历史行为），保持为空。
    SharedPreferences.setMockInitialValues({
      'timetable_profiles': jsonEncode([
        singleProfileJson(TimetableSettings.defaults()),
      ]),
      'active_timetable_profile_id': 'profile-1',
    });

    final storage = StorageService();
    await storage.init();

    expect(await storage.isAppDataEffectivelyEmpty(), isTrue);
  });
}
