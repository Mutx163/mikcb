import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/campus_tool_entry.dart';
import 'package:university_timetable/services/campus_tool_launcher.dart';
import 'package:university_timetable/services/campus_tool_runner.dart';

/// 记录调用顺序的假平台：把「多级回退」的纯逻辑钉死，不需要真机也不需要
/// 真实通道。失败原因码用 map 指定，未指定的按成功处理。
class _RecordingPlatform implements CampusToolPlatform {
  _RecordingPlatform({
    this.supported = true,
    this.uriResults = const <String, CampusToolCallResult>{},
    this.appResults = const <String, CampusToolCallResult>{},
    this.resolveResults = const <String, bool>{},
    this.installed = const <String>{},
  });

  @override
  final bool supported;

  final Map<String, CampusToolCallResult> uriResults;
  final Map<String, CampusToolCallResult> appResults;
  final Map<String, bool> resolveResults;
  final Set<String> installed;

  final List<String> calls = <String>[];

  @override
  Future<CampusToolCallResult> launchUri({
    required String uri,
    String? package,
    bool clearTask = false,
  }) async {
    calls.add('uri:$uri${package == null ? '' : '|$package'}${clearTask ? '#clear' : ''}');
    return uriResults[uri] ?? const CampusToolCallResult.success();
  }

  @override
  Future<CampusToolCallResult> launchApp({
    required String package,
    bool clearTask = false,
  }) async {
    calls.add('app:$package${clearTask ? '#clear' : ''}');
    return appResults[package] ?? const CampusToolCallResult.success();
  }

  @override
  Future<bool> canResolve({required String uri, String? package}) async {
    return resolveResults[uri] ?? false;
  }

  @override
  Future<Set<String>> installedPackages(List<String> packages) async {
    return installed;
  }
}

const _failNoActivity = CampusToolCallResult(
  ok: false,
  reason: 'no_activity',
);
const _failAppMissing = CampusToolCallResult(
  ok: false,
  reason: 'app_not_found',
);
const _failInvalid = CampusToolCallResult(ok: false, reason: 'invalid_uri');

CampusToolEntry _entry({
  List<CampusToolLink> links = const <CampusToolLink>[],
  List<String> appPackages = const <String>[],
  String? webUri,
  bool clearTask = false,
  bool enabled = true,
}) {
  return CampusToolEntry(
    id: 'demo',
    links: links,
    appPackages: appPackages,
    webUri: webUri,
    clearTask: clearTask,
    enabled: enabled,
  );
}

void main() {
  test('第一条链接成功就停手，不再试后面的链接 / 应用 / 网页', () async {
    final platform = _RecordingPlatform();
    final runner = CampusToolRunner(platform: platform);
    final result = await runner.run(
      _entry(
        links: const <CampusToolLink>[
          CampusToolLink(uri: 'a://one', package: 'com.a.one'),
          CampusToolLink(uri: 'a://two'),
        ],
        appPackages: const <String>['com.a.one'],
        webUri: 'https://example.com',
      ),
    );
    expect(result.status, CampusToolRunStatus.launched);
    expect(platform.calls, <String>['uri:a://one|com.a.one']);
  });

  test('按书写顺序回退：第 1 条失败才试第 2 条', () async {
    final platform = _RecordingPlatform(
      uriResults: const <String, CampusToolCallResult>{
        'a://one': _failNoActivity,
        'a://two': _failNoActivity,
        'a://three': CampusToolCallResult.success(),
      },
    );
    final runner = CampusToolRunner(platform: platform);
    final result = await runner.run(
      _entry(
        links: const <CampusToolLink>[
          CampusToolLink(uri: 'a://one'),
          CampusToolLink(uri: 'a://two'),
          CampusToolLink(uri: 'a://three'),
        ],
      ),
    );
    expect(result.status, CampusToolRunStatus.launched);
    expect(platform.calls, <String>[
      'uri:a://one',
      'uri:a://two',
      'uri:a://three',
    ]);
  });

  test('直达全失败 → 拉起官方 App（openedApp）', () async {
    final platform = _RecordingPlatform(
      uriResults: const <String, CampusToolCallResult>{
        'a://one': _failNoActivity,
      },
      appResults: const <String, CampusToolCallResult>{
        'com.a.two': _failAppMissing,
      },
    );
    final runner = CampusToolRunner(platform: platform);
    final result = await runner.run(
      _entry(
        links: const <CampusToolLink>[CampusToolLink(uri: 'a://one')],
        appPackages: const <String>['com.a.two', 'com.a.three'],
        webUri: 'https://example.com',
      ),
    );
    expect(result.status, CampusToolRunStatus.openedApp);
    expect(platform.calls, <String>[
      'uri:a://one',
      'app:com.a.two',
      'app:com.a.three',
    ]);
  });

  test('应用级也失败 → 网页兜底（openedWeb）', () async {
    final platform = _RecordingPlatform(
      uriResults: const <String, CampusToolCallResult>{
        'a://one': _failNoActivity,
        'https://example.com': CampusToolCallResult.success(),
      },
      appResults: const <String, CampusToolCallResult>{
        'com.a.two': _failAppMissing,
      },
    );
    final runner = CampusToolRunner(platform: platform);
    final result = await runner.run(
      _entry(
        links: const <CampusToolLink>[CampusToolLink(uri: 'a://one')],
        appPackages: const <String>['com.a.two'],
        webUri: 'https://example.com',
      ),
    );
    expect(result.status, CampusToolRunStatus.openedWeb);
    expect(platform.calls.last, 'uri:https://example.com');
  });

  test('全部失败时带回最后一个原因码', () async {
    final platform = _RecordingPlatform(
      uriResults: const <String, CampusToolCallResult>{
        'a://one': _failInvalid,
        'https://example.com': _failNoActivity,
      },
      appResults: const <String, CampusToolCallResult>{
        'com.a.two': _failAppMissing,
      },
    );
    final runner = CampusToolRunner(platform: platform);
    final result = await runner.run(
      _entry(
        links: const <CampusToolLink>[CampusToolLink(uri: 'a://one')],
        appPackages: const <String>['com.a.two'],
        webUri: 'https://example.com',
      ),
    );
    expect(result.status, CampusToolRunStatus.failed);
    expect(result.reason, 'no_activity');
    expect(result.ok, isFalse);
  });

  test('平台不支持时直接返回 unsupported，一次调用都不发', () async {
    final platform = _RecordingPlatform(supported: false);
    final runner = CampusToolRunner(platform: platform);
    final result = await runner.run(
      _entry(links: const <CampusToolLink>[CampusToolLink(uri: 'a://one')]),
    );
    expect(result.status, CampusToolRunStatus.unsupported);
    expect(platform.calls, isEmpty);
    expect(runner.isSupported, isFalse);
  });

  test('空链接被跳过；clearTask 原样透传给平台', () async {
    final platform = _RecordingPlatform();
    final runner = CampusToolRunner(platform: platform);
    await runner.run(
      _entry(
        clearTask: true,
        links: const <CampusToolLink>[
          CampusToolLink(uri: '  '),
          CampusToolLink(uri: 'a://one'),
        ],
      ),
    );
    expect(platform.calls, <String>['uri:a://one#clear']);
  });

  test('体检：逐条问 canResolve，应用问是否安装，网页也算一条', () async {
    final platform = _RecordingPlatform(
      resolveResults: const <String, bool>{
        'a://one': true,
        'a://two': false,
        'https://example.com': true,
      },
      installed: const <String>{'com.a.one'},
    );
    final runner = CampusToolRunner(platform: platform);
    final probe = await runner.probe(
      _entry(
        links: const <CampusToolLink>[
          CampusToolLink(uri: 'a://one', package: 'com.a.one'),
          CampusToolLink(uri: 'a://two'),
        ],
        appPackages: const <String>['com.a.one', 'com.a.two'],
        webUri: 'https://example.com',
      ),
    );
    expect(probe.links.length, 2);
    expect(probe.links.first.ok, isTrue);
    expect(probe.links.first.text, 'com.a.one|a://one');
    expect(probe.links.last.ok, isFalse);
    expect(probe.appInstalled, <String, bool>{
      'com.a.one': true,
      'com.a.two': false,
    });
    expect(probe.web?.ok, isTrue);
    expect(probe.web?.text, 'https://example.com');
  });
}
