import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/timetable_profile.dart';
import 'package:university_timetable/models/location_time_group.dart';
import 'package:university_timetable/models/schedule_date_rule.dart';
import 'package:university_timetable/models/time_scheme.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StorageService storage;

  setUp(() async {
    storage = StorageService.forTesting();
    SharedPreferences.setMockInitialValues({
      'did_migrate_app_logs_default': true,
      'timetable_profiles': jsonEncode([_profilePayload()]),
      'active_timetable_profile_id': 'profile-test',
      'time_schemes': jsonEncode([_scheme('initial-scheme', '初始作息').toJson()]),
    });
    await storage.init();
  });

  test(
    'concurrent collection writes preserve each completed payload',
    () async {
      final schemeA = _scheme('scheme-a', '早班');
      final schemeB = _scheme('scheme-b', '晚班');
      final groupA = _group('group-a', 'A楼');
      final groupB = _group('group-b', 'B楼');
      final ruleA = _rule('rule-a', '2026-09-01', '2026-09-30');
      final ruleB = _rule('rule-b', '2026-10-01', '2026-10-31');

      final firstWrites = <Future<void>>[
        storage.saveTimeSchemes([schemeA]),
        storage.saveLocationTimeGroups([groupA]),
        storage.saveScheduleDateRules([ruleA]),
        storage.saveTeacherRecords(const ['张老师']),
        storage.saveLocationRecords(const ['A101']),
      ];
      await Future.wait(firstWrites);
      final secondWrites = <Future<void>>[
        storage.saveTimeSchemes([schemeB]),
        storage.saveLocationTimeGroups([groupB]),
        storage.saveScheduleDateRules([ruleB]),
        storage.saveTeacherRecords(const ['李老师']),
        storage.saveLocationRecords(const ['B202']),
      ];
      await Future.wait(secondWrites);

      final schemes = await storage.getTimeSchemes();
      final groups = await storage.getLocationTimeGroups();
      final rules = await storage.getScheduleDateRules();
      final teachers = await storage.getTeacherRecords();
      final locations = await storage.getLocationRecords();

      // Later writes are complete payloads and never partially interleave with
      // earlier writes for the same preference key.
      expect(schemes.map((item) => item.id), contains('scheme-b'));
      expect(groups.map((item) => item.id), contains('group-b'));
      expect(rules.map((item) => item.id), contains('rule-b'));
      expect(teachers, ['李老师']);
      expect(locations, ['B202']);
    },
  );

  test(
    'mutating a source list after save cannot alter the queued payload',
    () async {
      final schemes = <TimeScheme>[_scheme('scheme-a', '早班')];
      final groups = <LocationTimeGroup>[_group('group-a', 'A楼')];
      final rules = <ScheduleDateRule>[
        _rule('rule-a', '2026-09-01', '2026-09-30'),
      ];

      final writes = <Future<void>>[
        storage.saveTimeSchemes(schemes),
        storage.saveLocationTimeGroups(groups),
        storage.saveScheduleDateRules(rules),
      ];
      schemes.clear();
      groups.clear();
      rules.clear();
      await Future.wait(writes);

      expect(
        (await storage.getTimeSchemes()).map((item) => item.id),
        contains('scheme-a'),
      );
      expect(
        (await storage.getLocationTimeGroups()).map((item) => item.id),
        contains('group-a'),
      );
      expect(
        (await storage.getScheduleDateRules()).map((item) => item.id),
        contains('rule-a'),
      );
    },
  );

  test('getters observe queued group and rule writes before reading cache', () async {
    final group = _group('group-queued', '排队楼');
    final rule = _rule('rule-queued', '2026-11-01', '2026-11-30');

    final groupWrite = storage.saveLocationTimeGroups([group]);
    final ruleWrite = storage.saveScheduleDateRules([rule]);
    final groupsFuture = storage.getLocationTimeGroups();
    final rulesFuture = storage.getScheduleDateRules();

    final groups = await groupsFuture;
    final rules = await rulesFuture;
    await Future.wait([groupWrite, ruleWrite]);

    expect(groups.single.id, 'group-queued');
    expect(rules.single.id, 'rule-queued');
    },
  );

  test('getProfiles waits for in-flight profile writes before reading', () async {
    final gate = Completer<void>();
    const updatedName = '排队课表';

    final write = storage.updateProfiles((current) async {
      await gate.future;
      return [
        TimetableProfile(
          id: 'profile-test',
          name: updatedName,
          courses: const [],
          settings: TimetableSettings.defaults(),
          currentWeek: 2,
          createdAt: DateTime.utc(2026, 8, 1),
          lastUsedAt: DateTime.utc(2026, 8, 1),
        ),
      ];
    });
    // 写仍挂在 gate 上时发起读：读必须等写链排空后取到新缓存，
    // 而不是用旧缓存/旧磁盘快照立即返回。
    final readFuture = storage.getProfiles();
    gate.complete();

    final profiles = await readFuture;
    await write;

    expect(profiles.single.name, updatedName);
  });
}

TimeScheme _scheme(String id, String name) {
  final now = DateTime.utc(2026, 8, 1);
  return TimeScheme(
    id: id,
    name: name,
    sections: const [SectionTime(startTime: '08:00', endTime: '09:40')],
    createdAt: now,
    updatedAt: now,
  );
}

LocationTimeGroup _group(String id, String name) {
  return LocationTimeGroup(
    id: id,
    name: name,
    timeSchemeId: 'scheme-a',
    keywords: const [LocationKeyword(pattern: '楼')],
  );
}

Map<String, dynamic> _profilePayload() {
  final now = DateTime.utc(2026, 8, 1);
  return {
    'id': 'profile-test',
    'name': '测试课表',
    'courses': const <dynamic>[],
    'tasks': const <dynamic>[],
    'scheduleItems': const <dynamic>[],
    'exams': const <dynamic>[],
    'settings': TimetableSettings.defaults().toJson(),
    'currentWeek': 1,
    'createdAt': now.toIso8601String(),
    'lastUsedAt': now.toIso8601String(),
  };
}

ScheduleDateRule _rule(String id, String startDate, String endDate) {
  return ScheduleDateRule(
    id: id,
    name: '学期规则',
    startDate: startDate,
    endDate: endDate,
    timeSchemeId: 'scheme-a',
  );
}
