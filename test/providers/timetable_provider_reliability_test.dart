import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/services/miui_live_activities_service.dart';
import 'package:university_timetable/services/storage_service.dart';

class _FailOnceStorageService extends StorageService {
  _FailOnceStorageService() : super.forTesting();

  int initCallCount = 0;

  @override
  Future<void> init() async {
    initCallCount++;
    if (initCallCount == 1) {
      throw StateError('simulated initialization failure');
    }
    await super.init();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    StorageService().resetForTesting();
    SharedPreferences.setMockInitialValues({
      'did_migrate_app_logs_default': true,
    });
  });

  test('initialize retries after the previous attempt fails', () async {
    final storage = _FailOnceStorageService();
    final provider = TimetableProvider(
      storageService: storage,
      autoInitialize: false,
      enableLiveActivitySync: false,
    );

    await expectLater(provider.initialize(), throwsStateError);
    await provider.initialize();

    expect(storage.initCallCount, 2);
    expect(provider.activeProfile, isNotNull);
    provider.dispose();
  });

  test(
    'concurrent initialize callers share one initialization attempt',
    () async {
      final storage = StorageService.forTesting();
      final provider = TimetableProvider(
        storageService: storage,
        autoInitialize: false,
        enableLiveActivitySync: false,
      );

      final firstInitialization = provider.initialize();
      final secondInitialization = provider.initialize();

      expect(identical(firstInitialization, secondInitialization), isTrue);
      await Future.wait([firstInitialization, secondInitialization]);
      provider.dispose();
    },
  );

  test('handleAppResumed immediately resynchronizes live scheduling', () async {
    final course = Course(
      id: 'resume-snapshot-course',
      name: '恢复同步测试课程',
      teacher: '张老师',
      location: 'A101',
      dayOfWeek: DateTime.now().weekday,
      startSection: 1,
      endSection: 2,
      startTime: '08:00',
      endTime: '09:40',
      startWeek: 1,
      endWeek: 30,
    );
    SharedPreferences.setMockInitialValues({
      'courses': [course.toJsonString()],
      'did_migrate_app_logs_default': true,
    });

    final liveService = TestMiuiLiveActivitiesService();
    final provider = TimetableProvider(
      storageService: StorageService.forTesting(),
      autoInitialize: false,
      enableLiveActivitySync: true,
      liveActivitiesService: liveService,
    );
    await provider.initialize();
    await pumpEventQueue();
    liveService.syncScheduleSnapshotCallCount = 0;

    await provider.handleAppResumed();

    expect(liveService.syncScheduleSnapshotCallCount, 1);
    provider.dispose();
  });
}
