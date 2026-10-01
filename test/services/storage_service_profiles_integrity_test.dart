import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/timetable_profile.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/services/storage_service.dart';

Course _course(String id, {String name = '课'}) {
  return Course(
    id: id,
    name: name,
    teacher: 'T',
    location: 'R',
    dayOfWeek: 1,
    startSection: 1,
    endSection: 2,
    startTime: '08:00',
    endTime: '09:40',
  );
}

TimetableProfile _profile(
  String id, {
  List<Course> courses = const [],
  String name = '档案',
}) {
  final now = DateTime(2026, 7, 18);
  return TimetableProfile(
    id: id,
    name: name,
    courses: courses,
    settings: TimetableSettings.defaults(),
    currentWeek: 1,
    createdAt: now,
    lastUsedAt: now,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    StorageService().resetForTesting();
    SharedPreferences.setMockInitialValues({});
  });

  group('lenient profile parse', () {
    test('skips one bad course without wiping the key', () async {
      final good = _course('good', name: '高等数学');
      final raw = [
        {
          'id': 'profile-1',
          'name': '默认课表',
          'courses': [good.toJson(), 'not-a-course-object'],
          'settings': TimetableSettings.defaults().toJson(),
          'currentWeek': 1,
          'createdAt': DateTime(2026, 3).toIso8601String(),
          'lastUsedAt': DateTime(2026, 3).toIso8601String(),
        },
      ];
      SharedPreferences.setMockInitialValues({
        'timetable_profiles': jsonEncode(raw),
        'active_timetable_profile_id': 'profile-1',
      });

      final storage = StorageService();
      await storage.init();
      final profiles = await storage.getProfiles();
      final prefs = await SharedPreferences.getInstance();

      expect(profiles, hasLength(1));
      expect(profiles.single.courses.map((c) => c.id), ['good']);
      expect(prefs.getString('timetable_profiles'), isNotNull);
      expect(
        prefs.getKeys().where(
          (key) => key.startsWith('timetable_profiles_corrupt_backup_'),
        ),
        isEmpty,
      );
    });

    test('skips one bad profile and keeps the other', () async {
      final goodProfile = _profile(
        'keep-me',
        name: '保留',
        courses: [_course('c1')],
      );
      final raw = [goodProfile.toJson(), 'broken-profile'];
      SharedPreferences.setMockInitialValues({
        'timetable_profiles': jsonEncode(raw),
        'active_timetable_profile_id': 'keep-me',
      });

      final storage = StorageService();
      await storage.init();
      final profiles = await storage.getProfiles();

      expect(profiles.map((p) => p.id), ['keep-me']);
      expect(profiles.single.courses, hasLength(1));
    });

    test('条目级损坏只留档不写回，坏记录原始字节仍在盘上', () async {
      // 回归钉（CODE_REVIEW 2026-10-01 A4）：冷启动自愈此前会在「个别条目读坏」时
      // 把清洗结果整份写回磁盘，等于把「当前解析器读不懂」变成永久删除 —— 用户只
      // 看到莫名少了一节课，原始字节既不留档也无法找回，且此后每次启动都继续踩。
      final good = _course('good', name: '高等数学');
      final badCourse = <String, dynamic>{
        'id': 'ghost',
        'name': '会被读坏的课',
        // teacher 缺失 → Course.fromJson 抛错 → 条目级丢弃
      };
      final raw = [
        {
          'id': 'profile-1',
          'name': '默认课表',
          'courses': [good.toJson(), badCourse],
          'settings': TimetableSettings.defaults().toJson(),
          'currentWeek': 1,
          'createdAt': DateTime(2026, 3).toIso8601String(),
          'lastUsedAt': DateTime(2026, 3).toIso8601String(),
        },
      ];
      SharedPreferences.setMockInitialValues({
        'timetable_profiles': jsonEncode(raw),
        'active_timetable_profile_id': 'profile-1',
      });

      final storage = StorageService();
      await storage.init();
      final profiles = await storage.getProfiles();
      final prefs = await SharedPreferences.getInstance();

      // 内存视图仍然可用：坏课被排除，好课保留。
      expect(profiles.single.courses.map((c) => c.id), ['good']);

      // 盘上原文不能被清洗结果覆盖 —— 解析器修好后这条记录还救得回来。
      final onDisk = jsonDecode(prefs.getString('timetable_profiles')!) as List;
      expect((onDisk.single as Map)['courses'], hasLength(2));

      // 坏条目本身要留档，否则「不写回」只是把问题推到下一次保存。
      final quarantine = prefs.getString('timetable_profiles_unparsed_items');
      expect(quarantine, isNotNull);
      expect(quarantine, contains('ghost'));
    });

    test('整条记录坏掉仍然写回（该记录本身不可用）', () async {
      // 与上一条对照：整条 profile 坏掉时留在盘上每次启动都会重新踩，
      // 维持既有的「移出列表并写回」行为。
      final goodProfile = _profile(
        'keep-me',
        name: '保留',
        courses: [_course('c1')],
      );
      SharedPreferences.setMockInitialValues({
        'timetable_profiles': jsonEncode([
          goodProfile.toJson(),
          'broken-profile',
        ]),
        'active_timetable_profile_id': 'keep-me',
      });

      final storage = StorageService();
      await storage.init();
      await storage.getProfiles();
      final prefs = await SharedPreferences.getInstance();

      final onDisk = jsonDecode(prefs.getString('timetable_profiles')!) as List;
      expect(onDisk, hasLength(1));
      expect((onDisk.single as Map)['id'], 'keep-me');
    });
  });

  group('profiles RMW serialization', () {
    test('concurrent updateProfiles preserve both course adds', () async {
      final storage = StorageService();
      await storage.init();
      final seed = await storage.getProfiles();
      final base = seed.single;
      await storage.saveProfiles([
        base.copyWith(courses: [_course('seed')]),
      ]);

      await Future.wait([
        storage.updateProfiles((current) async {
          final profile = current.single;
          return [
            profile.copyWith(courses: [...profile.courses, _course('a')]),
          ];
        }),
        storage.updateProfiles((current) async {
          final profile = current.single;
          return [
            profile.copyWith(courses: [...profile.courses, _course('b')]),
          ];
        }),
      ]);

      final restored = await storage.getProfiles();
      final ids = restored.single.courses.map((c) => c.id).toSet();
      expect(ids, containsAll(['seed', 'a', 'b']));
    });
  });
}
