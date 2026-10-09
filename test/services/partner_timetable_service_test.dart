import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/timetable_profile.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/services/data_transfer_service.dart';
import 'package:university_timetable/services/partner_timetable_service.dart';
import 'package:university_timetable/services/storage_service.dart';
import 'package:university_timetable/services/transfer_package.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StorageService storageService;
  late DataTransferService dataTransferService;
  late PartnerTimetableService partnerService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storageService = StorageService();
    storageService.resetForTesting();
    await storageService.init();
    dataTransferService = DataTransferService();
    partnerService = PartnerTimetableService(
      storageService: storageService,
      dataTransferService: dataTransferService,
    );

    final defaultProfile = TimetableProfile(
      id: 'default',
      name: '默认课表',
      courses: const [],
      settings: TimetableSettings.defaults(),
      currentWeek: 1,
      createdAt: DateTime(2026, 7, 8),
      lastUsedAt: DateTime(2026, 7, 8),
    );
    await storageService.saveProfiles([defaultProfile]);
    await storageService.setActiveProfileId('default');
  });

  test('imports partner timetable from single profile backup', () async {
    final content = dataTransferService.buildBackupJson(
      profileName: '小明的课表',
      courses: [
        Course(
          id: 'c1',
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
      settings: TimetableSettings.defaults(),
      currentWeek: 3,
    );

    final result = await partnerService.importFromContent(content);

    expect(result.kind, PartnerImportResultKind.created);
    expect(result.profile.isPartnerImported, isTrue);
    expect(result.profile.courses.single.name, '高数');
    expect(result.binding.partnerName, '小明的课表');

    final profiles = await storageService.getProfiles();
    expect(
      profiles.any((profile) => profile.id == PartnerTimetableService.partnerProfileId),
      isTrue,
    );
    expect(await storageService.getPartnerTimetableBinding(), isNotNull);
  });

  test('updates existing partner profile on re-import', () async {
    final first = dataTransferService.buildBackupJson(
      profileName: 'TA',
      courses: [
        Course(
          id: 'c1',
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
      settings: TimetableSettings.defaults(),
      currentWeek: 1,
    );
    await partnerService.importFromContent(first);

    final second = dataTransferService.buildBackupJson(
      profileName: 'TA',
      courses: [
        Course(
          id: 'c2',
          name: '英语',
          teacher: '李老师',
          location: 'B202',
          dayOfWeek: 2,
          startSection: 3,
          endSection: 4,
          startTime: '10:00',
          endTime: '11:40',
        ),
      ],
      settings: TimetableSettings.defaults(),
      currentWeek: 2,
    );
    final result = await partnerService.importFromContent(second);

    expect(result.kind, PartnerImportResultKind.updated);
    expect(result.profile.courses.single.name, '英语');
    expect(result.profile.currentWeek, 2);
  });

  test('re-import preserves partner week offset', () async {
    final content = dataTransferService.buildBackupJson(
      profileName: 'TA',
      courses: const [],
      settings: TimetableSettings.defaults(),
      currentWeek: 1,
    );
    await partnerService.importFromContent(content);
    final binding = await storageService.getPartnerTimetableBinding();
    expect(binding, isNotNull);
    await storageService.savePartnerTimetableBinding(
      binding!.copyWith(weekOffset: 2),
    );

    await partnerService.importFromContent(content);
    final updated = await storageService.getPartnerTimetableBinding();
    expect(updated?.weekOffset, 2);
  });

  test('re-import preserves partner couple colors', () async {
    final content = dataTransferService.buildBackupJson(
      profileName: 'TA',
      courses: const [],
      settings: TimetableSettings.defaults(),
      currentWeek: 1,
    );
    await partnerService.importFromContent(content);
    final binding = await storageService.getPartnerTimetableBinding();
    await storageService.savePartnerTimetableBinding(
      binding!.copyWith(
        mineColorHex: '#FF5722',
        partnerColorHex: '#4CAF50',
        togetherColorHex: '#00BCD4',
      ),
    );

    await partnerService.importFromContent(content);
    final updated = await storageService.getPartnerTimetableBinding();
    expect(updated?.mineColorHex, '#FF5722');
    expect(updated?.partnerColorHex, '#4CAF50');
    expect(updated?.togetherColorHex, '#00BCD4');
  });

  test('unlink removes partner profile and binding', () async {
    final content = dataTransferService.buildBackupJson(
      profileName: 'TA',
      courses: const [],
      settings: TimetableSettings.defaults(),
      currentWeek: 1,
    );
    await partnerService.importFromContent(content);
    await partnerService.unlink();

    final profiles = await storageService.getProfiles();
    expect(
      profiles.any((profile) => profile.id == PartnerTimetableService.partnerProfileId),
      isFalse,
    );
    expect(await storageService.getPartnerTimetableBinding(), isNull);
  });

  // 2026-10-08 审核修复：情侣课表导入原先也静默吞掉部分损坏 —— 100 门里坏
  // 40 门会安静导入 60 门、报「已导入」，用户下次打开才发现少了几十节。
  // 现在 `parseBackupJson` 带回的跳过条数必须透传到 `PartnerImportResult`，
  // 让调用方如实提示。
  test('部分损坏：救回能读的部分，并把跳过条数透传出来', () async {
    Map<String, dynamic> goodCourse(String id, String name) => <String, dynamic>{
          'id': id,
          'name': name,
          'teacher': '王老师',
          'location': 'A101',
          'dayOfWeek': 1,
          'startSection': 1,
          'endSection': 2,
          'startTime': '08:00',
          'endTime': '09:40',
        };
    final content = jsonEncode(<String, dynamic>{
      'app': 'mikcb',
      'schemaVersion': DataTransferService.schemaVersion,
      'profileName': 'TA的课表',
      'courses': <Object?>[
        goodCourse('c-1', '高等数学'),
        'garbage', // 非 Map 条目 → 解析时跳过
        goodCourse('c-2', '线性代数'),
        42,
      ],
      'exams': const <Object?>[],
      'settings': <String, dynamic>{},
      'currentWeek': 1,
      'exportedAt': '2026-10-08T00:00:00.000',
      'packageType': TransferPackage.packageType,
      'scope': 'all_data',
      'channel': 'file',
    });

    final result = await partnerService.importFromContent(content);

    // 救回 2 门能读的，坏掉的 2 条如实记进 droppedTotal。
    expect(result.profile.courses.length, 2);
    expect(result.droppedTotal, 2);
  });
}
