import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/data/timetable_repository.dart';
import 'package:university_timetable/models/timetable_profile.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/services/storage_service.dart';

TimetableProfile _profile(String id, {String name = '默认课表'}) {
  return TimetableProfile(
    id: id,
    name: name,
    courses: const [],
    settings: TimetableSettings.defaults(),
    currentWeek: 1,
    createdAt: DateTime(2026, 8, 1),
    lastUsedAt: DateTime(2026, 8, 1),
  );
}

void main() {
  late StorageService storage;
  late TimetableRepository repository;

  setUp(() {
    StorageService().resetForTesting();
    SharedPreferences.setMockInitialValues({});
    storage = StorageService();
    repository = TimetableRepository(storage);
  });

  group('TimetableRepository.saveProfiles', () {
    test('行为 1:1：保存后可读回', () async {
      await repository.saveProfiles([_profile('p1')]);
      final loaded = await repository.loadProfiles();
      expect(loaded, hasLength(1));
      expect(loaded.single.id, 'p1');
    });

    test('首次保存后写入 schemaVersion=1', () async {
      expect(await storage.getProfilesSchemaVersion(), 0);
      await repository.saveProfiles([_profile('p1')]);
      expect(await storage.getProfilesSchemaVersion(), 1);
    });

    test('多次保存后版本号保持 1（不随保存次数变化）', () async {
      await repository.saveProfiles([_profile('p1')]);
      await repository.saveProfiles([_profile('p1'), _profile('p2')]);
      await repository.saveProfiles([_profile('p2')]);
      expect(await storage.getProfilesSchemaVersion(), 1);
      expect((await repository.loadProfiles()).single.id, 'p2');
    });

    test('未保存过时版本号为 0（兼容版本号引入前的历史数据）', () async {
      // 模拟旧版本写入的 profiles：绕过仓储直接写 storage
      await storage.saveProfiles([_profile('legacy')]);
      expect(await storage.getProfilesSchemaVersion(), 0);
      // 仓储读路径不受影响
      final loaded = await repository.loadProfiles();
      expect(loaded.single.id, 'legacy');
    });
  });

  group('TimetableRepository activeProfileId', () {
    test('透传 StorageService', () async {
      expect(await repository.getActiveProfileId(), isNull);
      await repository.setActiveProfileId('p1');
      expect(await repository.getActiveProfileId(), 'p1');
    });
  });
}
