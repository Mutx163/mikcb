import 'dart:convert';
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

  test('持久化日志与 debugPrint 同口径脱敏（含 extras 里的名字列表）', () async {
    // 这份文件是 `exportMergedLogsFile` 让用户导出、发群、附在 issue 里的那一份，
    // 而它此前一条 redact 都没有（缺口记在
    // `weather_failure_log_privacy_test.dart:18-19`）。2026-10-08 接上同一份字段表。
    final tempDir = await Directory.systemTemp.createTemp('mikcb-log-redact-');
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
      'timetable_profiles':
          '[{"id":"p1","settings":{"liveEnableLocalDiagnostics":true}}]',
    });

    await AppLogService.instance.info(
      'location_time_apply',
      '应用结束 overflow=3 overflowNames=高等数学,大学英语',
      extras: {
        'overflowNames': const ['高等数学', '大学英语'],
        'changeSamples': const ['高等数学|id-1|clock 08:00-09:40'],
        'updated': 2,
      },
    );

    final logs = await AppLogService.instance.readAppLogsText();

    expect(
      logs,
      isNot(contains('高等数学')),
      reason: '课程名是个人信息，不能落进这份会被导出发群的日志',
    );
    expect(logs, isNot(contains('大学英语')));
    expect(logs, contains('overflowNames=**'));
    expect(logs, contains('updated=2'), reason: '计数等取证信息一个字不能少');
    expect(logs, contains('overflow=3'));
  });

  test('嵌套 Map / List 型 extras 也要脱敏，stackTrace 同口径', () async {
    // 2026-10-08 审核复现：`redactPersonalFields` 的正则只认 `key=value`，
    // 序列化后的嵌套值是 `"name": "高等数学"`，一个都匹配不上，实测课程名 /
    // 教师 / 教室三个字段**全部**漏出。stackTrace 那行则紧挨着已脱敏的
    // `error=` 却是原样写出，等于白洗。
    final tempDir = await Directory.systemTemp.createTemp('mikcb-log-nested-');
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
      'timetable_profiles':
          '[{"id":"p1","settings":{"liveEnableLocalDiagnostics":true}}]',
    });

    await AppLogService.instance.error(
      'nested_redaction',
      '状态快照',
      extras: {
        'statusJson': const JsonEncoder.withIndent('  ').convert({
          'currentCourse': {
            'name': '高等数学',
            'teacher': '王老师',
            'location': 'A101',
          },
        }),
        'location': const ['A101', 'B202'],
        'page': 3,
      },
      stackTrace: StackTrace.fromString(
        // `course=` 是个人字段、必须被盖；`school=` 按本仓口径**故意不盖**
        // （`app_debug_log.dart` 字段表头的说明：机构名不是个人信息，且
        // `schoolName` 是教务适配器定位的关键取证信息）。所以断言里不出现它。
        'FormatException: course=高等数学\n#0 main (package:x/y.dart:1)',
      ),
    );

    final logs = await AppLogService.instance.readAppLogsText();

    expect(logs, isNot(contains('高等数学')), reason: '嵌套值里的课程名');
    expect(logs, isNot(contains('王老师')), reason: '嵌套值里的教师名');
    expect(logs, isNot(contains('A101')), reason: '嵌套值里的教室');
    expect(logs, contains('page=3'), reason: '计数等取证信息一个字不能少');
  });

  test('extras 查表大小写不敏感，与 message 出口同口径', () async {
    final tempDir = await Directory.systemTemp.createTemp('mikcb-log-case-');
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
      'timetable_profiles':
          '[{"id":"p1","settings":{"liveEnableLocalDiagnostics":true}}]',
    });

    await AppLogService.instance.info(
      'case_insensitive_keys',
      '大小写变体',
      extras: {
        // 表里是 camelCase 的 `overflowNames`，大小写变体必须同样命中。
        'OVERFLOWNAMES': const ['高等数学'],
        'Teacher': '王老师',
      },
    );

    final logs = await AppLogService.instance.readAppLogsText();
    expect(logs, isNot(contains('高等数学')));
    expect(logs, isNot(contains('王老师')));
  });

  test('watchMergedLogsText emits on appends and stays quiet while idle', () async {    // path_provider 指到临时目录，写入走真实文件（plugin_boundary_smoke_test 同款做法）。
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

  group('force 落盘语义', () {
    /// path_provider 指到临时目录，写入走真实文件（本文件其它用例同款做法）。
    void useTempLogDirectory() {
      final tempDir = Directory.systemTemp.createTempSync('mikcb-log-force-');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      const channel = MethodChannel('plugins.flutter.io/path_provider');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            channel,
            (call) async => tempDir.path,
          );
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });
    }

    test('本地诊断开关关闭时，force 的框架异常仍必须落盘', () async {
      useTempLogDirectory();
      SharedPreferences.setMockInitialValues({
        'accepted_privacy_policy': true,
      });
      await AppLogService.instance.initialize();
      await AppLogService.instance.updatePrivacyAccepted(true);
      await AppLogService.instance.updateLoggingEnabled(false);

      // main.dart:297 的 FlutterError.onError 写着「这里强制落盘（force: true）」，
      // 用来查线上「UI 卡死但看起来没报错」。
      await AppLogService.instance.error(
        'flutter_framework_error',
        'force-marker',
        error: StateError('boom'),
        stackTrace: StackTrace.current,
        force: true,
      );

      expect(
        await AppLogService.instance.readAppLogsText(),
        contains('force-marker'),
        reason: 'force 必须越过 liveEnableLocalDiagnostics 开关；'
            '原实现里 force 在任何分支都改变不了结果，线上崩溃一条都存不下',
      );
    });

    test('force 不能越过隐私同意', () async {
      useTempLogDirectory();
      SharedPreferences.setMockInitialValues({});
      await AppLogService.instance.initialize();
      await AppLogService.instance.updatePrivacyAccepted(false);
      await AppLogService.instance.updateLoggingEnabled(true);

      await AppLogService.instance.error(
        'flutter_framework_error',
        'no-consent-marker',
        force: true,
      );

      expect(
        await AppLogService.instance.readAppLogsText(),
        isNot(contains('no-consent-marker')),
      );
    });

    test('普通日志仍受开关约束', () async {
      useTempLogDirectory();
      SharedPreferences.setMockInitialValues({
        'accepted_privacy_policy': true,
      });
      await AppLogService.instance.initialize();
      await AppLogService.instance.updatePrivacyAccepted(true);
      await AppLogService.instance.updateLoggingEnabled(false);

      await AppLogService.instance.info('force_test', 'plain-marker');

      expect(
        await AppLogService.instance.readAppLogsText(),
        isNot(contains('plain-marker')),
      );
    });
  });
}
