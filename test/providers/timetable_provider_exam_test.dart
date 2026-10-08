import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/exam.dart';
import 'package:university_timetable/models/timetable_profile.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    StorageService().resetForTesting();
    SharedPreferences.setMockInitialValues({});
  });

  Future<TimetableProvider> createProvider() async {
    final provider = TimetableProvider(
      autoInitialize: false,
      enableLiveActivitySync: false,
    );
    await provider.initialize();
    await provider.updateTimetableSettings(
      provider.settings.copyWith(
        semesterStartDate: DateTime(2026, 4, 13),
        semesterWeekCount: 20,
      ),
    );
    return provider;
  }

  Future<Course> addTestCourse(TimetableProvider provider) async {
    final course = Course(
      id: 'course-1',
      name: '高等数学',
      teacher: '张老师',
      location: 'A101',
      dayOfWeek: 1,
      startSection: 1,
      endSection: 2,
      startTime: '08:00',
      endTime: '09:40',
    );
    await provider.addCourse(course);
    return course;
  }

  Exam buildExam({
    String id = 'exam-1',
    String courseId = 'course-1',
    String name = '高等数学期末考试',
    DateTime? dateTime,
  }) {
    return Exam(
      id: id,
      courseId: courseId,
      name: name,
      dateTime: dateTime ?? DateTime.now().add(const Duration(days: 10)),
      startTime: '08:30',
      endTime: '10:30',
      location: 'A-301',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  group('TimetableProvider exam CRUD', () {
    test('addExam adds exam to list', () async {
      final provider = await createProvider();
      await addTestCourse(provider);
      final exam = buildExam();

      await provider.addExam(exam);

      expect(provider.exams, hasLength(1));
      expect(provider.exams.first.name, '高等数学期末考试');
    });

    test('addExam throws for non-existent course', () async {
      final provider = await createProvider();
      final exam = buildExam(courseId: 'non-existent');

      expect(() => provider.addExam(exam), throwsA(isA<ArgumentError>()));
    });

    test('updateExam modifies existing exam', () async {
      final provider = await createProvider();
      await addTestCourse(provider);
      final exam = buildExam();
      await provider.addExam(exam);

      final updated = exam.copyWith(name: '期中考试', location: 'B-201');
      await provider.updateExam(updated);

      expect(provider.exams.first.name, '期中考试');
      expect(provider.exams.first.location, 'B-201');
    });

    test('deleteExam removes exam', () async {
      final provider = await createProvider();
      await addTestCourse(provider);
      await provider.addExam(buildExam());

      await provider.deleteExam('exam-1');

      expect(provider.exams, isEmpty);
    });

    test('getExamById returns correct exam', () async {
      final provider = await createProvider();
      await addTestCourse(provider);
      await provider.addExam(buildExam(id: 'e1', name: '考试A'));
      await provider.addExam(buildExam(id: 'e2', name: '考试B'));

      expect(provider.getExamById('e1')?.name, '考试A');
      expect(provider.getExamById('e2')?.name, '考试B');
      expect(provider.getExamById('e3'), isNull);
    });
  });

  group('TimetableProvider exam queries', () {
    test('getCourseForExam returns linked course', () async {
      final provider = await createProvider();
      final course = await addTestCourse(provider);
      await provider.addExam(buildExam());

      final linked = provider.getCourseForExam(provider.exams.first);
      expect(linked?.id, course.id);
      expect(linked?.name, '高等数学');
    });

    test('getExamsForCourse filters by courseId', () async {
      final provider = await createProvider();
      await addTestCourse(provider);
      await provider.addCourse(
        Course(
          id: 'course-2',
          name: '大学英语',
          teacher: '李老师',
          location: 'B202',
          dayOfWeek: 3,
          startSection: 3,
          endSection: 4,
          startTime: '10:00',
          endTime: '11:40',
        ),
      );
      await provider.addExam(buildExam(id: 'e1'));
      await provider.addExam(buildExam(id: 'e2', courseId: 'course-2'));
      await provider.addExam(buildExam(id: 'e3'));

      expect(provider.getExamsForCourse('course-1'), hasLength(2));
      expect(provider.getExamsForCourse('course-2'), hasLength(1));
    });

    test(
      'getUpcomingExams returns only non-expired exams sorted by date',
      () async {
        final provider = await createProvider();
        await addTestCourse(provider);
        await provider.addExam(
          buildExam(
            id: 'past',
            dateTime: DateTime.now().subtract(const Duration(days: 5)),
          ),
        );
        await provider.addExam(
          buildExam(
            id: 'future1',
            dateTime: DateTime.now().add(const Duration(days: 10)),
          ),
        );
        await provider.addExam(
          buildExam(
            id: 'future2',
            dateTime: DateTime.now().add(const Duration(days: 3)),
          ),
        );

        final upcoming = provider.getUpcomingExams();
        expect(upcoming, hasLength(2));
        expect(upcoming.first.id, 'future2');
        expect(upcoming.last.id, 'future1');
      },
    );

    test('getUpcomingExams sorts same-day exams by start time', () async {
      final provider = await createProvider();
      await addTestCourse(provider);
      final date = DateTime.now().add(const Duration(days: 10));
      await provider.addExam(
        buildExam(id: 'late', dateTime: date).copyWith(startTime: '15:00'),
      );
      await provider.addExam(
        buildExam(id: 'early', dateTime: date).copyWith(startTime: '09:00'),
      );

      expect(provider.getUpcomingExams().map((exam) => exam.id), [
        'early',
        'late',
      ]);
    });

    test('getUpcomingExams respects limit', () async {
      final provider = await createProvider();
      await addTestCourse(provider);
      await provider.addExam(
        buildExam(
          id: 'e1',
          dateTime: DateTime.now().add(const Duration(days: 1)),
        ),
      );
      await provider.addExam(
        buildExam(
          id: 'e2',
          dateTime: DateTime.now().add(const Duration(days: 2)),
        ),
      );
      await provider.addExam(
        buildExam(
          id: 'e3',
          dateTime: DateTime.now().add(const Duration(days: 3)),
        ),
      );

      expect(provider.getUpcomingExams(limit: 2), hasLength(2));
    });

    test('getNextExam returns nearest future exam', () async {
      final provider = await createProvider();
      await addTestCourse(provider);
      await provider.addExam(
        buildExam(
          id: 'far',
          dateTime: DateTime.now().add(const Duration(days: 20)),
        ),
      );
      await provider.addExam(
        buildExam(
          id: 'near',
          dateTime: DateTime.now().add(const Duration(days: 5)),
        ),
      );

      expect(provider.getNextExam()?.id, 'near');
    });

    test('getNextExam returns null when no exams', () async {
      final provider = await createProvider();
      expect(provider.getNextExam(), isNull);
    });

    test('hasExamOnDate returns true for matching date', () async {
      final provider = await createProvider();
      await addTestCourse(provider);
      final targetDate = DateTime(2026, 6, 15);
      await provider.addExam(buildExam(dateTime: targetDate));

      expect(provider.hasExamOnDate(targetDate), isTrue);
      expect(provider.hasExamOnDate(DateTime(2026, 6, 16)), isFalse);
    });
  });

  /// 考试写入口在落盘失败时的退回边界（第 36 轮）。
  ///
  /// `addExam`（:2895）/ `updateExam`（:2919）/ `deleteExam`（:2937）原先都是
  /// 「改内存 → `await _persistActiveProfileState()` → notify」，没有 try/catch；
  /// 而 `_runMutation` 只是互斥锁（`_mutationGate.runExclusive`），不含回滚。
  /// 与此同时 `exam_list_screen.dart:166-167` 的注释**已经声称** deleteExam
  /// 「按本仓写入契约回滚内存并 rethrow」—— 契约与实现相反：
  ///
  /// - `deleteExam` 失败时条目已从 `_exams` 摘掉、`notifyListeners()` 被跳过，
  ///   于是界面还显示着这一条，用户看到的是「保存失败」，删除却已经进了内存；
  ///   此后任意一次成功写入（切周、加课、30 秒心跳）把它永久坐实。
  /// - `updateExam` 失败时改动同样停在内存里，被下一次成功写入坐实。
  ///
  /// `addExam` 失败**不回滚**是刻意的（与 `addCourse` 同口径）：内存里那条正是
  /// 用户刚填完的内容，表单已经弹了「保存失败」，回滚等于把他填的一屏清空。
  /// 最后一条用例把这个边界钉住，免得后来人以为是漏了一处。
  group('考试写入口的落盘失败回滚', () {
    late _ExamWriteFailingStorage storage;

    Future<TimetableProvider> createProviderWithFailingStorage() async {
      storage = _ExamWriteFailingStorage();
      final provider = TimetableProvider(
        storageService: storage,
        autoInitialize: false,
        enableLiveActivitySync: false,
      );
      await provider.initialize();
      addTearDown(provider.dispose);
      return provider;
    }

    Future<void> seedOneExam(TimetableProvider provider) async {
      await addTestCourse(provider);
      await provider.addExam(buildExam());
      storage.profilesFailures = 0;
      storage.profilesWrites = 0;
    }

    Future<List<String>> examIdsOnDisk(TimetableProvider provider) async {
      final profile = (await storage.getProfiles()).firstWhere(
        (item) => item.id == provider.activeProfile!.id,
      );
      return profile.exams.map((exam) => exam.id).toList();
    }

    test('deleteExam 写盘失败后考试必须还在内存里，并如实上抛', () async {
      final provider = await createProviderWithFailingStorage();
      await seedOneExam(provider);

      storage.profilesFailures = 1;
      await expectLater(
        provider.deleteExam('exam-1'),
        throwsA(isA<StateError>()),
      );

      expect(
        provider.exams.map((exam) => exam.id),
        ['exam-1'],
        reason: '不回滚的话，界面显示的「还在」与内存里的「已删」会一直分叉，'
            '而用户收到的是「保存失败」',
      );
    });

    test('deleteExam 写盘失败后，下一次成功写入不许把它坐实成已删除', () async {
      final provider = await createProviderWithFailingStorage();
      await seedOneExam(provider);

      storage.profilesFailures = 1;
      await expectLater(
        provider.deleteExam('exam-1'),
        throwsA(isA<StateError>()),
      );

      // 任意一次成功写入（这里用加一门课）都会把内存状态落盘。
      await provider.addCourse(
        Course(
          id: 'course-2',
          name: '大学英语',
          teacher: '李老师',
          location: 'B202',
          dayOfWeek: 3,
          startSection: 1,
          endSection: 2,
          startTime: '08:00',
          endTime: '09:40',
        ),
      );

      expect(
        await examIdsOnDisk(provider),
        ['exam-1'],
        reason: '删失败却把「考试没了」写进盘，是最坏的一种：用户以为没删掉，重启后它真没了',
      );
    });

    test('updateExam 写盘失败后改动必须退回', () async {
      final provider = await createProviderWithFailingStorage();
      await seedOneExam(provider);
      final original = provider.exams.first;

      storage.profilesFailures = 1;
      await expectLater(
        provider.updateExam(original.copyWith(name: '期中考试')),
        throwsA(isA<StateError>()),
      );

      expect(provider.exams.first.name, original.name);
    });

    test('addExam 失败不回滚是刻意的（钉住边界，别当漏修）', () async {
      final provider = await createProviderWithFailingStorage();
      await addTestCourse(provider);

      storage.profilesFailures = 1;
      await expectLater(
        provider.addExam(buildExam(id: 'exam-2')),
        throwsA(isA<StateError>()),
      );

      expect(
        provider.exams.map((exam) => exam.id),
        ['exam-2'],
        reason: '内存里那条正是用户刚填完的内容：表单已提示保存失败，回滚等于清空他一屏',
      );
    });
  });
}

/// 落盘失败注入：只在 `saveProfiles` 上抛。它是 `_persistActiveProfileState`
/// 这条链的第一笔磁盘写（`timetable_provider.dart:1434-1435`），考试数据就住在
/// profile 里，所以这一处失败等价于真实场景里的磁盘满 / `commit()` 返回 false。
class _ExamWriteFailingStorage extends StorageService {
  _ExamWriteFailingStorage() : super.forTesting();

  int profilesFailures = 0;
  int profilesWrites = 0;

  @override
  Future<void> saveProfiles(List<TimetableProfile> profiles) {
    profilesWrites++;
    if (profilesFailures > 0) {
      profilesFailures--;
      return Future<void>.error(StateError('test_profiles_write_failed'));
    }
    return super.saveProfiles(profiles);
  }
}
