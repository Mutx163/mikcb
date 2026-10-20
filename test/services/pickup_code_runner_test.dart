import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/pickup_code_entry.dart';
import 'package:university_timetable/services/pickup_code_launcher.dart';
import 'package:university_timetable/services/pickup_code_runner.dart';

/// 记录调用顺序的假平台：把「多级回退」的纯逻辑钉死，不需要真机也不需要
/// 真实通道。失败原因码用 map 指定，未指定的按成功处理。
class _RecordingPlatform implements PickupCodePlatform {
  _RecordingPlatform({
    this.supported = true,
    this.uriResults = const <String, PickupCodeCallResult>{},
    this.appResults = const <String, PickupCodeCallResult>{},
    this.appDelay = Duration.zero,
  });

  @override
  final bool supported;

  final Map<String, PickupCodeCallResult> uriResults;
  final Map<String, PickupCodeCallResult> appResults;

  /// 每次 launchApp 假装耗时多久（用于跑总预算）。
  final Duration appDelay;

  final List<String> calls = <String>[];

  @override
  Future<PickupCodeCallResult> launchUri({
    required String uri,
    String? package,
    bool clearTask = false,
  }) async {
    calls.add(
      'uri:$uri${package == null ? '' : '|$package'}${clearTask ? '#clear' : ''}',
    );
    return uriResults[uri] ?? const PickupCodeCallResult.success();
  }

  @override
  Future<PickupCodeCallResult> launchApp({
    required String package,
    bool clearTask = false,
  }) async {
    calls.add('app:$package${clearTask ? '#clear' : ''}');
    if (appDelay > Duration.zero) {
      await Future<void>.delayed(appDelay);
    }
    return appResults[package] ?? const PickupCodeCallResult.success();
  }

  @override
  Future<bool> canResolve({required String uri, String? package}) async {
    return false;
  }

  @override
  Future<Set<String>> installedPackages(List<String> packages) async {
    return const <String>{};
  }
}

const _failNoActivity = PickupCodeCallResult(ok: false, reason: 'no_activity');
const _failAppMissing = PickupCodeCallResult(ok: false, reason: 'app_not_found');
const _failInvalid = PickupCodeCallResult(ok: false, reason: 'invalid_uri');

PickupCodeEntry _entry({
  List<PickupCodeLink> links = const <PickupCodeLink>[],
  List<String> appPackages = const <String>[],
  String? webUri,
  bool clearTask = false,
}) {
  return PickupCodeEntry(
    id: 'demo',
    icon: 'qrCode',
    links: links,
    appPackages: appPackages,
    webUri: webUri,
    clearTask: clearTask,
  );
}

void main() {
  test('第一条链接成功就停手，不再试后面的链接 / 应用 / 网页', () async {
    final platform = _RecordingPlatform();
    final runner = PickupCodeRunner(platform: platform);
    final result = await runner.run(
      _entry(
        links: const <PickupCodeLink>[
          PickupCodeLink(uri: 'a://one', package: 'com.a.one'),
          PickupCodeLink(uri: 'a://two'),
        ],
        appPackages: const <String>['com.a.one'],
        webUri: 'https://example.com',
      ),
    );
    expect(result.status, PickupCodeRunStatus.launched);
    expect(platform.calls, <String>['uri:a://one|com.a.one']);
  });

  test('按书写顺序回退：第 1 条失败才试第 2 条', () async {
    final platform = _RecordingPlatform(
      uriResults: const <String, PickupCodeCallResult>{
        'a://one': _failNoActivity,
        'a://two': _failNoActivity,
        'a://three': PickupCodeCallResult.success(),
      },
    );
    final runner = PickupCodeRunner(platform: platform);
    final result = await runner.run(
      _entry(
        links: const <PickupCodeLink>[
          PickupCodeLink(uri: 'a://one'),
          PickupCodeLink(uri: 'a://two'),
          PickupCodeLink(uri: 'a://three'),
        ],
      ),
    );
    expect(result.status, PickupCodeRunStatus.launched);
    expect(platform.calls, <String>[
      'uri:a://one',
      'uri:a://two',
      'uri:a://three',
    ]);
  });

  test('直达全失败 → 拉起官方 App（openedApp）', () async {
    final platform = _RecordingPlatform(
      uriResults: const <String, PickupCodeCallResult>{
        'a://one': _failNoActivity,
      },
      appResults: const <String, PickupCodeCallResult>{
        'com.a.two': _failAppMissing,
      },
    );
    final runner = PickupCodeRunner(platform: platform);
    final result = await runner.run(
      _entry(
        links: const <PickupCodeLink>[PickupCodeLink(uri: 'a://one')],
        appPackages: const <String>['com.a.two', 'com.a.three'],
        webUri: 'https://example.com',
      ),
    );
    expect(result.status, PickupCodeRunStatus.openedApp);
    expect(platform.calls, <String>[
      'uri:a://one',
      'app:com.a.two',
      'app:com.a.three',
    ]);
  });

  test('应用级也失败 → 网页兜底（openedWeb）', () async {
    final platform = _RecordingPlatform(
      uriResults: const <String, PickupCodeCallResult>{
        'a://one': _failNoActivity,
        'https://example.com': PickupCodeCallResult.success(),
      },
      appResults: const <String, PickupCodeCallResult>{
        'com.a.two': _failAppMissing,
      },
    );
    final runner = PickupCodeRunner(platform: platform);
    final result = await runner.run(
      _entry(
        links: const <PickupCodeLink>[PickupCodeLink(uri: 'a://one')],
        appPackages: const <String>['com.a.two'],
        webUri: 'https://example.com',
      ),
    );
    expect(result.status, PickupCodeRunStatus.openedWeb);
    expect(platform.calls.last, 'uri:https://example.com');
  });

  test('全部失败时带回最后一个原因码', () async {
    final platform = _RecordingPlatform(
      uriResults: const <String, PickupCodeCallResult>{
        'a://one': _failInvalid,
        'https://example.com': _failNoActivity,
      },
      appResults: const <String, PickupCodeCallResult>{
        'com.a.two': _failAppMissing,
      },
    );
    final runner = PickupCodeRunner(platform: platform);
    final result = await runner.run(
      _entry(
        links: const <PickupCodeLink>[PickupCodeLink(uri: 'a://one')],
        appPackages: const <String>['com.a.two'],
        webUri: 'https://example.com',
      ),
    );
    expect(result.status, PickupCodeRunStatus.failed);
    expect(result.reason, 'no_activity');
    expect(result.ok, isFalse);
  });

  test('平台不支持时直接返回 unsupported，一次调用都不发', () async {
    final platform = _RecordingPlatform(supported: false);
    final runner = PickupCodeRunner(platform: platform);
    final result = await runner.run(
      _entry(links: const <PickupCodeLink>[PickupCodeLink(uri: 'a://one')]),
    );
    expect(result.status, PickupCodeRunStatus.unsupported);
    expect(platform.calls, isEmpty);
    expect(runner.isSupported, isFalse);
  });

  test('空链接被跳过；clearTask 原样透传给平台', () async {
    final platform = _RecordingPlatform();
    final runner = PickupCodeRunner(platform: platform);
    await runner.run(
      _entry(
        clearTask: true,
        links: const <PickupCodeLink>[
          PickupCodeLink(uri: '  '),
          PickupCodeLink(uri: 'a://one'),
        ],
      ),
    );
    expect(platform.calls, <String>['uri:a://one#clear']);
  });

  group('总预算（防止站在柜子前等一两分钟）', () {
    test('预算用完后不再发起新的调用，直接判超时', () async {
      // 每次 launchApp 耗时 30ms，预算 50ms：第二次开始前应发现预算不足。
      final platform = _RecordingPlatform(
        uriResults: const <String, PickupCodeCallResult>{
          'a://one': _failNoActivity,
        },
        appResults: const <String, PickupCodeCallResult>{
          'com.a.two': _failAppMissing,
          'com.a.three': _failAppMissing,
          'com.a.four': _failAppMissing,
        },
        appDelay: const Duration(milliseconds: 30),
      );
      final runner = PickupCodeRunner(
        platform: platform,
        budget: const Duration(milliseconds: 50),
      );
      final result = await runner.run(
        _entry(
          links: const <PickupCodeLink>[PickupCodeLink(uri: 'a://one')],
          appPackages: const <String>[
            'com.a.two',
            'com.a.three',
            'com.a.four',
          ],
        ),
      );
      expect(result.status, PickupCodeRunStatus.failed);
      expect(result.reason, 'timeout', reason: '预算耗尽要明确报超时');
      // 4 个目标不可能全跑完（每个 30ms，预算 50ms）
      expect(platform.calls.length, lessThan(4));
      expect(result.elapsed, isNotNull);
    });

    test('预算充足时正常跑完，不受影响', () async {
      final platform = _RecordingPlatform(
        uriResults: const <String, PickupCodeCallResult>{
          'a://one': _failNoActivity,
          'https://example.com': PickupCodeCallResult.success(),
        },
      );
      final runner = PickupCodeRunner(platform: platform);
      final result = await runner.run(
        _entry(
          links: const <PickupCodeLink>[PickupCodeLink(uri: 'a://one')],
          webUri: 'https://example.com',
        ),
      );
      expect(result.status, PickupCodeRunStatus.openedWeb);
    });
  });

  group('已安装预判', () {
    test('已知没装的 App 不发起调用（省一轮必然失败的等待）', () async {
      final platform = _RecordingPlatform(
        uriResults: const <String, PickupCodeCallResult>{
          'a://one': _failNoActivity,
        },
        appResults: const <String, PickupCodeCallResult>{
          'com.a.installed': PickupCodeCallResult.success(),
          'com.a.missing': _failAppMissing,
        },
      );
      final runner = PickupCodeRunner(platform: platform);
      final result = await runner.run(
        _entry(
          links: const <PickupCodeLink>[PickupCodeLink(uri: 'a://one')],
          appPackages: const <String>['com.a.installed', 'com.a.missing'],
        ),
        alreadyInstalled: const <String>{'com.a.installed'},
      );
      expect(result.status, PickupCodeRunStatus.openedApp);
      expect(
        platform.calls,
        <String>['uri:a://one', 'app:com.a.installed'],
        reason: 'com.a.missing 已知没装，不该被调用',
      );
    });

    test('preflight 为 null 时退回逐个试（不因查不到就跳过）', () async {
      final platform = _RecordingPlatform(
        uriResults: const <String, PickupCodeCallResult>{
          'a://one': _failNoActivity,
        },
        appResults: const <String, PickupCodeCallResult>{
          'com.a.missing': _failAppMissing,
        },
      );
      final runner = PickupCodeRunner(platform: platform);
      final result = await runner.run(
        _entry(
          links: const <PickupCodeLink>[PickupCodeLink(uri: 'a://one')],
          appPackages: const <String>['com.a.missing'],
        ),
      );
      expect(result.status, PickupCodeRunStatus.failed);
      expect(platform.calls, contains('app:com.a.missing'));
    });

    test('installedPackages 查不到时返回 null（让调用方退回逐个试）', () async {
      final platform = _RecordingPlatform(supported: false);
      final runner = PickupCodeRunner(platform: platform);
      expect(await runner.installedPackages(const <String>['com.a.b']), isNull);
      expect(await runner.installedPackages(const <String>[]), isNull);
    });
  });
}
