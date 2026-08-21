import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/services/storage_service.dart';

class _BlockingDeferredRecordsStorage extends StorageService {
  _BlockingDeferredRecordsStorage() : super.forTesting();

  final teacherLoadStarted = Completer<void>();
  final locationLoadStarted = Completer<void>();
  final teacherRelease = Completer<List<String>>();
  final locationRelease = Completer<List<String>>();

  final savedTeachers = <List<String>>[];
  final savedLocations = <List<String>>[];

  @override
  Future<void> saveTeacherRecords(List<String> teachers) async {
    savedTeachers.add(List<String>.from(teachers));
  }

  @override
  Future<void> saveLocationRecords(List<String> locations) async {
    savedLocations.add(List<String>.from(locations));
  }

  @override
  Future<List<String>> getTeacherRecords() async {
    if (!teacherLoadStarted.isCompleted) {
      teacherLoadStarted.complete();
    }
    return teacherRelease.future;
  }

  @override
  Future<List<String>> getLocationRecords() async {
    if (!locationLoadStarted.isCompleted) {
      locationLoadStarted.complete();
    }
    return locationRelease.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'did_migrate_app_logs_default': true,
    });
  });

  test('recording during deferred load is not overwritten', () async {
    final storage = _BlockingDeferredRecordsStorage();
    final provider = TimetableProvider(
      storageService: storage,
      autoInitialize: false,
      enableLiveActivitySync: false,
    );

    final initialization = provider.initialize();
    await Future.wait([
      initialization,
      storage.teacherLoadStarted.future.timeout(const Duration(seconds: 2)),
      storage.locationLoadStarted.future.timeout(const Duration(seconds: 2)),
    ]);

    var recordCompleted = false;
    final record = provider.recordTeacher('新教师')
      ..then((_) => recordCompleted = true);
    await pumpEventQueue();
    expect(recordCompleted, isFalse);

    storage.teacherRelease.complete(const ['旧教师']);
    storage.locationRelease.complete(const []);
    await record;

    expect(provider.uniqueTeachers, containsAll(['旧教师', '新教师']));
    expect(storage.savedTeachers.last, ['新教师', '旧教师']);
    provider.dispose();
  });

  test('deferred records notify listeners after they are loaded', () async {
    final storage = _BlockingDeferredRecordsStorage();
    final provider = TimetableProvider(
      storageService: storage,
      autoInitialize: false,
      enableLiveActivitySync: false,
    );

    final initialization = provider.initialize();
    await Future.wait([
      initialization,
      storage.teacherLoadStarted.future.timeout(const Duration(seconds: 2)),
      storage.locationLoadStarted.future.timeout(const Duration(seconds: 2)),
    ]);

    var notifications = 0;
    provider.addListener(() => notifications++);
    final baseline = notifications;
    storage.teacherRelease.complete(const ['存储教师']);
    storage.locationRelease.complete(const ['存储地点']);
    await pumpEventQueue();

    expect(provider.uniqueTeachers, contains('存储教师'));
    expect(provider.uniqueLocations, contains('存储地点'));
    expect(notifications, greaterThan(baseline));
    provider.dispose();
  });
}
