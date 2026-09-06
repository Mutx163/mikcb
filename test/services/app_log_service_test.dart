import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/services/app_log_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(AppLogService.instance.resetForTesting);

  test('initialize tolerates corrupted timetable settings json', () async {
    SharedPreferences.setMockInitialValues({
      'timetable_settings': '{bad-json',
    });

    await expectLater(AppLogService.instance.initialize(), completes);
  });

  test('logs issued inside the initialization window are not dropped', () async {
    // path_provider 指到临时目录，写入走真实文件（plugin_boundary_smoke_test 同款做法）。
    final tempDir = await Directory.systemTemp.createTemp('mikcb-log-race-');
    addTearDown(() => tempDir.delete(recursive: true));
    const pathProviderChannel = MethodChannel(
      'plugins.flutter.io/path_provider',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async => tempDir.path);
    addTearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathProviderChannel, null);
    });

    // 开关走 profiles 真实读取路径，而非测试内手动 updateLoggingEnabled：
    // 竞态窗口内 _loggingEnabled 尚未从 prefs 加载，这才是被丢弃的根源。
    SharedPreferences.setMockInitialValues({
      'accepted_privacy_policy': true,
      'timetable_profiles':
          '[{"id":"p1","settings":{"liveEnableLocalDiagnostics":true}}]',
    });

    // 两条日志与初始化并发触发（模拟冷启动多入口同时 info()），
    // 不先 await initialize。
    final first = AppLogService.instance.info('race_test', 'entry-a');
    final second = AppLogService.instance.info('race_test', 'entry-b');
    await Future.wait([first, second]);

    final logs = await AppLogService.instance.readAppLogsText();
    expect(logs, contains('entry-a'));
    expect(
      logs,
      contains('entry-b'),
      reason: '窗口期并发日志必须等待共享初始化 Future 完成后按已加载开关落盘，'
          '不得因开关尚未加载被静默丢弃',
    );
  });

  test('watchMergedLogsText emits on appends and stays quiet while idle', () async {
    // path_provider 指到临时目录，写入走真实文件（plugin_boundary_smoke_test 同款做法）。
    final tempDir = await Directory.systemTemp.createTemp('mikcb-log-watch-');
    addTearDown(() => tempDir.delete(recursive: true));
    const pathProviderChannel = MethodChannel(
      'plugins.flutter.io/path_provider',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async => tempDir.path);
    addTearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathProviderChannel, null);
    });

    SharedPreferences.setMockInitialValues({
      'accepted_privacy_policy': true,
    });
    await AppLogService.instance.initialize();
    await AppLogService.instance.updatePrivacyAccepted(true);
    await AppLogService.instance.updateLoggingEnabled(true);
    await AppLogService.instance.info('watch_test', 'entry-1');

    final emissions = <String>[];
    final sub = AppLogService.instance
        .watchMergedLogsText(loadNativeRawLog: () async => null)
        .listen(emissions.add, onError: (Object error) {});
    addTearDown(sub.cancel);

    // 首帧：产出当前全部内容。
    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect(emissions, isNotEmpty, reason: '监听后应先产出一份当前日志');
    expect(emissions.last, contains('entry-1'));

    // 静置超过一个轮询周期（1s）：无新增日志时不得反复产出——
    // 轮询指纹没变化要直接跳过重读+重合并，否则日志页每秒被自己拖死。
    await Future<void>.delayed(const Duration(milliseconds: 1700));
    expect(emissions.length, 1, reason: '静置期间轮询不应产生额外产出');

    // 追加日志后必须产出增量内容。
    await AppLogService.instance.info('watch_test', 'entry-2');
    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect(emissions.length, 2);
    expect(emissions.last, contains('entry-2'));
  });
}
