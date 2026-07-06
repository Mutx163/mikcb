import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/services/storage_service.dart';

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
}
