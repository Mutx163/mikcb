import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/location_time_group.dart';
import 'package:university_timetable/models/time_scheme.dart';
import 'package:university_timetable/models/timetable_profile.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/services/data_transfer_service.dart';
import 'package:university_timetable/services/storage_service.dart';

/// 落盘失败之后，内存必须回到失败前的样子（2026-10-02 审查）。
///
/// 本仓已经确立了这个形状：`_applySavedThemes`（主题族）与
/// `runSettingsMirrorTransaction`（设置镜像）都是「先抓旧值 → await 落库 → catch
/// 里回滚并 rethrow」。原因写在 `_applySavedThemes` 的注释里：这些类有大量
/// "先改内存、后写盘" 的入口，落盘抛错（磁盘满、`commit()` 返回 false）时内存已变、
/// 盘上没变，而下一次任意成功写入会经 `_mergeActiveProfileIntoProfilesList`
/// 把这份从未落库的改动当成既有状态落盘 —— 用户视角是「我删掉的东西过两天又没了 /
/// 我按 TA 的课表新建的档案凭空出现」。
///
/// 下面这些入口当时漏了这个形状。用可注入的 StorageService 精确地让**那一次**写盘
/// 失败来钉住它们。
class _FailingStorage extends StorageService {
  _FailingStorage() : super.forTesting();

  int schemeFailures = 0;
  int groupFailures = 0;
  int profileFailures = 0;

  /// 前 N 次 `saveProfiles` 照常成功。导入为新课表会写两次档案（add 之前一次、
  /// add 之后一次），要钉的是**第二次**失败：第一次只是把当前档案的状态镜像落盘，
  /// 它失败时还没有任何幻影状态。
  int profileCallsToSkip = 0;

  @override
  Future<void> saveTimeSchemes(List<TimeScheme> schemes) {
    if (schemeFailures > 0) {
      schemeFailures--;
      return Future<void>.error(StateError('test_scheme_write_failed'));
    }
    return super.saveTimeSchemes(schemes);
  }

  @override
  Future<void> saveLocationTimeGroups(List<LocationTimeGroup> groups) {
    if (groupFailures > 0) {
      groupFailures--;
      return Future<void>.error(StateError('test_group_write_failed'));
    }
    return super.saveLocationTimeGroups(groups);
  }

  @override
  Future<void> saveProfiles(List<TimetableProfile> profiles) {
    if (profileCallsToSkip > 0) {
      profileCallsToSkip--;
      return super.saveProfiles(profiles);
    }
    if (profileFailures > 0) {
      profileFailures--;
      return Future<void>.error(StateError('test_profile_write_failed'));
    }
    return super.saveProfiles(profiles);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FailingStorage storage;
  late TimetableProvider provider;

  Future<TimetableProvider> boot() async {
    SharedPreferences.setMockInitialValues({});
    storage = _FailingStorage();
    final created = TimetableProvider(
      storageService: storage,
      autoInitialize: false,
      enableLiveActivitySync: false,
    );
    await created.initialize();
    return created;
  }

  setUp(() async {
    provider = await boot();
  });

  tearDown(() {
    provider.dispose();
  });

  group('作息 CRUD 的落盘失败回滚', () {
    test('createTimeScheme 写盘失败后不该留下幻影作息', () async {
      final before = provider.timeSchemes.length;
      storage.schemeFailures = 1;

      await expectLater(
        provider.createTimeScheme(
          name: '新作息',
          sections: const [SectionTime(startTime: '08:00', endTime: '08:45')],
        ),
        throwsA(isA<StateError>()),
      );

      expect(provider.timeSchemes, hasLength(before));
      expect(
        provider.timeSchemes.any((scheme) => scheme.name == '新作息'),
        isFalse,
      );
    });

    test('deleteTimeScheme 写盘失败后作息必须还在', () async {
      final scheme = await provider.createTimeScheme(
        name: '会被删的作息',
        sections: const [SectionTime(startTime: '09:00', endTime: '09:45')],
      );
      final before = provider.timeSchemes.length;
      storage.schemeFailures = 1;

      await expectLater(
        provider.deleteTimeScheme(scheme.id),
        throwsA(isA<StateError>()),
      );

      expect(provider.timeSchemes, hasLength(before));
      expect(
        provider.timeSchemes.any((item) => item.id == scheme.id),
        isTrue,
        reason: '删除没落成功却在内存里生效，会被下一次成功写入永久坐实',
      );
    });

    test('renameTimeScheme 写盘失败后名字必须回滚', () async {
      final scheme = await provider.createTimeScheme(
        name: '原名',
        sections: const [SectionTime(startTime: '10:00', endTime: '10:45')],
      );

      storage.schemeFailures = 1;
      await expectLater(
        provider.renameTimeScheme(scheme.id, '改坏的名字'),
        throwsA(isA<StateError>()),
      );

      expect(
        provider.timeSchemes.firstWhere((item) => item.id == scheme.id).name,
        '原名',
      );
    });

    test('updateTimeScheme 写盘失败后节次表必须回到旧值', () async {
      final scheme = await provider.createTimeScheme(
        name: '待更新',
        sections: const [SectionTime(startTime: '11:00', endTime: '11:45')],
      );

      storage.schemeFailures = 1;
      await expectLater(
        provider.updateTimeScheme(
          schemeId: scheme.id,
          name: '待更新',
          sections: const [SectionTime(startTime: '20:00', endTime: '20:45')],
        ),
        throwsA(isA<StateError>()),
      );

      expect(
        provider.timeSchemes
            .firstWhere((item) => item.id == scheme.id)
            .sections
            .single
            .startTime,
        '11:00',
      );
    });
  });

  group('地点时间分组的落盘失败回滚', () {
    test('createLocationTimeGroup 写盘失败后不该留下幻影分组', () async {
      final scheme = await provider.createTimeScheme(
        name: '分组用的作息',
        sections: const [SectionTime(startTime: '08:00', endTime: '08:45')],
      );
      final before = provider.locationTimeGroups.length;

      storage.groupFailures = 1;
      await expectLater(
        provider.createLocationTimeGroup(
          name: '三教',
          timeSchemeId: scheme.id,
          keywords: const [LocationKeyword(pattern: '三教')],
        ),
        throwsA(isA<StateError>()),
      );

      expect(provider.locationTimeGroups, hasLength(before));
    });

    test('deleteLocationTimeGroup 写盘失败后分组必须还在', () async {
      final scheme = await provider.createTimeScheme(
        name: '分组用的作息2',
        sections: const [SectionTime(startTime: '08:00', endTime: '08:45')],
      );
      final group = await provider.createLocationTimeGroup(
        name: '四教',
        timeSchemeId: scheme.id,
        keywords: const [LocationKeyword(pattern: '四教')],
      );
      expect(provider.locationTimeGroups, hasLength(1));

      storage.groupFailures = 1;
      await expectLater(
        provider.deleteLocationTimeGroup(group.id),
        throwsA(isA<StateError>()),
      );

      expect(provider.locationTimeGroups, hasLength(1));
      expect(provider.locationTimeGroups.single.id, group.id);
    });
  });

  group('导入为新课表的落盘失败回滚', () {
    String backupContent() {
      return DataTransferService().buildBackupJson(
        profileName: 'TA 的课表',
        courses: [
          Course(
            id: 'c1',
            name: '体育',
            teacher: '教练',
            location: '场馆',
            dayOfWeek: 2,
            startSection: 1,
            endSection: 1,
            startTime: '14:00',
            endTime: '14:45',
          ),
        ],
        settings: TimetableSettings.defaults(),
        currentWeek: 1,
      );
    }

    test('写盘失败后档案列表与激活档案都必须回到导入前', () async {
      final profilesBefore = provider.profiles.length;
      final activeBefore = provider.activeProfile?.id;
      final courseNamesBefore = provider.courses
          .map((course) => course.name)
          .toList();

      storage.profileCallsToSkip = 1;
      storage.profileFailures = 1;
      final error = await provider.importAppDataBackupAsNewProfile(
        backupContent(),
      );

      expect(
        error,
        isNotNull,
        reason: '导入失败必须给错误码，而不是静默"成功"',
      );
      expect(
        provider.profiles,
        hasLength(profilesBefore),
        reason: '新档案没落成功就不该留在内存里',
      );
      expect(provider.activeProfile?.id, activeBefore);
      expect(
        provider.courses.map((course) => course.name).toList(),
        courseNamesBefore,
      );
      // 幻影档案一旦留下，下一次任意成功写入会把它永久坐实到盘上。
      final json = jsonDecode(backupContent()) as Map<String, dynamic>;
      expect(json['app'], 'mikcb');
    });
  });

  group('删除课表档的落盘失败回滚', () {
    test('删除激活档案时写盘失败，档案与显示内容都要回到删除前', () async {
      final activeId = provider.activeProfile?.id;
      expect(activeId, isNotNull);
      await provider.addCourse(
        Course(
          id: 'keep-1',
          name: '线性代数',
          teacher: '李老师',
          location: 'B301',
          dayOfWeek: 3,
          startSection: 1,
          endSection: 2,
          startTime: '08:00',
          endTime: '09:40',
        ),
      );
      await provider.createProfile(name: '另一份课表');
      await provider.switchProfile(activeId!);

      storage.profileFailures = 1;
      await expectLater(
        provider.deleteProfile(activeId),
        throwsA(isA<StateError>()),
      );

      expect(
        provider.profiles.map((profile) => profile.id),
        contains(activeId),
        reason: '写盘失败后内存里那份档案不该已被摘掉：'
            '下一次任意成功写入会把"它不存在"当成既有状态落盘，'
            '用户视角是"删除失败的课表过一会儿自己消失了"',
      );
      expect(provider.activeProfile?.id, activeId);
      expect(
        provider.courses.map((course) => course.id),
        contains('keep-1'),
        reason: '删除激活档案时会先切到备用课表并把它的内容灌进内存，'
            '回滚必须连显示内容一起还原',
      );
    });

    test('删除非激活档案写盘失败时档案仍在', () async {
      final activeId = provider.activeProfile!.id;
      final other = await provider.createProfile(name: '另一份课表');
      await provider.switchProfile(activeId);

      storage.profileFailures = 1;
      await expectLater(
        provider.deleteProfile(other.id),
        throwsA(isA<StateError>()),
      );

      expect(provider.profiles.map((profile) => profile.id), contains(other.id));
      expect(provider.activeProfile?.id, activeId);
    });
  });
}
