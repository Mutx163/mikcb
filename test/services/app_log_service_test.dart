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
      'flutter.timetable_settings': '{bad-json',
    });

    await expectLater(AppLogService.instance.initialize(), completes);
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
      'flutter.accepted_privacy_policy': true,
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
