import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/timetable_profile.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/services/data_transfer_service.dart';
import 'package:university_timetable/services/partner_timetable_service.dart';
import 'package:university_timetable/services/storage_service.dart';

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
}
