import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/services/storage_service.dart';

Course _buildCourse(String id, {String? name}) {
  return Course(
    id: id,
    name: name ?? id,
    teacher: '测试教师',
    location: '测试教室',
    dayOfWeek: 1,
    startSection: 1,
    endSection: 2,
    startTime: '08:00',
    endTime: '09:40',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    StorageService().resetForTesting();
    SharedPreferences.setMockInitialValues({});
  });

  group('StorageService.init() caching', () {
    test('multiple init() calls are idempotent', () async {
      final storage = StorageService();

      // 多次调用 init() 应该都能正常完成
      await storage.init();
      await storage.init();
      await storage.init();

      // 初始化后应该能正常读写数据
      await storage.setCompletedOnboarding(true);
      final result = await storage.hasCompletedOnboarding();
      expect(result, isTrue);
    });

    test('init() can be called concurrently from multiple callers', () async {
      final storage = StorageService();

      // 模拟多个调用者同时调用 init()
      final results = await Future.wait([
        storage.init(),
        storage.init(),
        storage.init(),
      ]);

      // 所有调用都应该成功完成
      expect(results, hasLength(3));
    });

    test(
      'init() completes successfully and enables storage operations',
      () async {
        final storage = StorageService();
        await storage.init();

        // 初始化后应该能正常读写数据
        await storage.setCompletedOnboarding(true);
        final result = await storage.hasCompletedOnboarding();

        expect(result, isTrue);
      },
    );

    test('init() after completion returns immediately', () async {
      final storage = StorageService();

      // 第一次初始化
      await storage.init();

      // 写入一些数据
      await storage.setAcceptedPrivacyPolicy(true);

      // 再次调用 init() 应该立即返回
      final stopwatch = Stopwatch()..start();
      await storage.init();
      stopwatch.stop();

      // 应该很快完成（< 10ms）
      expect(stopwatch.elapsedMilliseconds, lessThan(10));

      // 数据应该仍然存在
      final result = await storage.hasAcceptedPrivacyPolicy();
      expect(result, isTrue);
    });
  });

  // 本组钉的是 `StorageService._runCoursesWrite` 的**写队列语义**（并发写不丢、
  // 混合写按调用顺序应用、saveCourses 先抓输入快照）。
  //
  // ⚠️ 2026-10-20 复查：这一组用的四个写方法（saveCourses / addCourse /
  // updateCourse / deleteCourse）**在生产代码里已零调用**——课程写入统一走
  // `TimetableRepository` 了。本组因此是在给「已停用的写通道」保语义。
  //
  // 之所以保留：该写链与老用户升级迁移的读取路径（`_doEnsureProfilesInitialized`
  // 里的 `getCourses()`）共用 `_runCoursesWrite` / `_readCoursesWithoutLock`，
  // 删除要连共享机制一起动，风险大于收益。详见
  // `lib/services/storage_service.dart` 中 `saveCourses` 上方的整段说明。
  //
  // 别误判：`TimetableProvider.addCourse` 等是另一套实现，与本组无关。
  group('StorageService course write serialization', () {
    test('preserves all concurrently added courses', () async {
      final storage = StorageService();
      await storage.init();

      await Future.wait([
        storage.addCourse(_buildCourse('course-a')),
        storage.addCourse(_buildCourse('course-b')),
        storage.addCourse(_buildCourse('course-c')),
      ]);

      final storedCourseIds = (await storage.getCourses())
          .map((course) => course.id)
          .toSet();
      expect(storedCourseIds, {'course-a', 'course-b', 'course-c'});
    });

    test('applies mixed course writes in invocation order', () async {
      final storage = StorageService();
      await storage.init();
      await storage.saveCourses([_buildCourse('existing', name: '原课程')]);

      await Future.wait([
        storage.addCourse(_buildCourse('added')),
        storage.updateCourse(_buildCourse('existing', name: '已更新课程')),
        storage.deleteCourse('added'),
      ]);

      final storedCourses = await storage.getCourses();
      expect(storedCourses, hasLength(1));
      expect(storedCourses.single.id, 'existing');
      expect(storedCourses.single.name, '已更新课程');
    });

    test('captures saveCourses input before queued execution', () async {
      final storage = StorageService();
      await storage.init();
      final mutableCourses = [_buildCourse('snapshot')];

      final saveFuture = storage.saveCourses(mutableCourses);
      mutableCourses.add(_buildCourse('late-mutation'));
      await saveFuture;

      final storedCourseIds = (await storage.getCourses())
          .map((course) => course.id)
          .toList();
      expect(storedCourseIds, ['snapshot']);
    });
  });
}
