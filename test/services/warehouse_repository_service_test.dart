import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/models/warehouse_repository_models.dart';
import 'package:university_timetable/services/warehouse_repository_service.dart';

class _FakeClient extends http.BaseClient {
  final Map<String, http.Response> responses;

  _FakeClient(this.responses);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = responses[request.url.toString()];
    if (response == null) {
      return http.StreamedResponse(Stream.value(utf8.encode('not found')), 404);
    }
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
      request: request,
    );
  }
}

void main() {
  test('parse GitHub source and build raw URLs', () {
    final source = WarehouseRepositorySource.fromGitHubUrl(
      'https://github.com/Mutx163/qingyu_warehouse',
    );

    expect(source.owner, 'Mutx163');
    expect(source.repo, 'qingyu_warehouse');
    expect(
      source.buildRawFileUri('index/root_index.yaml').toString(),
      'https://raw.githubusercontent.com/Mutx163/qingyu_warehouse/main/index/root_index.yaml',
    );
  });

  test('fetch root index and adapters index', () async {
    const rootYaml = '''
schools:
  - id: "CQU"
    name: "重庆大学"
    initial: "C"
    resource_folder: "CQU"
''';
    const adaptersYaml = '''
adapters:
  - adapter_id: "CQU_01"
    adapter_name: "重庆大学教务"
    category: "BACHELOR_AND_ASSOCIATE"
    asset_js_path: "cqu_01.js"
    import_url: "https://example.com/login"
    maintainer: "Mutx"
    description: "测试适配器"
''';
    const scriptBody = 'console.log("hello");';

    final client = _FakeClient({
      'https://raw.githubusercontent.com/Mutx163/qingyu_warehouse/main/index/root_index.yaml':
          http.Response.bytes(utf8.encode(rootYaml), 200),
      'https://raw.githubusercontent.com/Mutx163/qingyu_warehouse/main/resources/CQU/adapters.yaml':
          http.Response.bytes(utf8.encode(adaptersYaml), 200),
      'https://raw.githubusercontent.com/Mutx163/qingyu_warehouse/main/resources/CQU/cqu_01.js':
          http.Response(scriptBody, 200),
    });
    final service = WarehouseRepositoryService(client: client);
    final source = WarehouseRepositorySource.fromGitHubUrl(
      'https://github.com/Mutx163/qingyu_warehouse',
    );
    const options = WarehouseFetchOptions(
      downloadSource: AppUpdateDownloadSource.original,
      mirrorPreset: AppUpdateMirrorPreset.ghfast,
      customMirrorUrlPrefix: defaultAppUpdateMirrorUrlPrefix,
    );

    final rootIndex = await service.fetchRootIndex(source, options: options);
    expect(rootIndex.schools, hasLength(1));
    expect(rootIndex.schools.first.name, '重庆大学');

    final adapters = await service.fetchAdaptersIndex(
      source,
      rootIndex.schools.first,
      options: options,
    );
    expect(adapters.adapters, hasLength(1));
    expect(adapters.adapters.first.adapterId, 'CQU_01');

    final script = await service.fetchAdapterScript(
      source,
      school: rootIndex.schools.first,
      adapter: adapters.adapters.first,
      options: options,
    );
    expect(script, contains('console.log'));
  });

  test('adapters index parses declared sha256 for integrity gate', () async {
    const adaptersYaml = '''
adapters:
  - adapter_id: "CQU_01"
    adapter_name: "重庆大学教务"
    category: "BACHELOR_AND_ASSOCIATE"
    asset_js_path: "cqu_01.js"
    import_url: "https://example.com/login"
    maintainer: "Mutx"
    description: "测试适配器"
    sha256: "ABCDEF0123456789abcdef0123456789abcdef0123456789abcdef0123456789"
''';
    final client = _FakeClient({
      'https://raw.githubusercontent.com/Mutx163/qingyu_warehouse/main/resources/CQU/adapters.yaml':
          http.Response.bytes(utf8.encode(adaptersYaml), 200),
    });
    final service = WarehouseRepositoryService(client: client);
    final source = WarehouseRepositorySource.fromGitHubUrl(
      'https://github.com/Mutx163/qingyu_warehouse',
    );
    const school = WarehouseSchoolEntry(
      id: 'CQU',
      name: '重庆大学',
      initial: 'C',
      resourceFolder: 'CQU',
    );

    final adapters = await service.fetchAdaptersIndex(source, school);
    // Declared checksums are stored verbatim; case is normalized when compared.
    expect(adapters.adapters.single.sha256,
        'ABCDEF0123456789abcdef0123456789abcdef0123456789abcdef0123456789');
  });

  test('fetchAdapterScript accepts bytes matching declared sha256', () async {
    const scriptBody = 'console.log("verified");';
    final digest = sha256.convert(utf8.encode(scriptBody)).toString();
    final adapter = WarehouseAdapterEntry(
      adapterId: 'CQU_01',
      adapterName: '重庆大学教务',
      category: 'BACHELOR_AND_ASSOCIATE',
      assetJsPath: 'cqu_01.js',
      importUrl: 'https://example.com/login',
      maintainer: 'Mutx',
      description: '测试适配器',
      sha256: digest.toUpperCase(),
    );
    final client = _FakeClient({
      'https://raw.githubusercontent.com/Mutx163/qingyu_warehouse/main/resources/CQU/cqu_01.js':
          http.Response(scriptBody, 200),
    });
    final service = WarehouseRepositoryService(client: client);
    final source = WarehouseRepositorySource.fromGitHubUrl(
      'https://github.com/Mutx163/qingyu_warehouse',
    );
    const school = WarehouseSchoolEntry(
      id: 'CQU',
      name: '重庆大学',
      initial: 'C',
      resourceFolder: 'CQU',
    );

    final script = await service.fetchAdapterScript(
      source,
      school: school,
      adapter: adapter,
    );
    expect(script, scriptBody);
  });

  test('fetchAdapterScript rejects tampered script when sha256 declared',
      () async {
    const servedBody = 'alert("tampered");// poisoned mirror payload';
    final adapter = WarehouseAdapterEntry(
      adapterId: 'CQU_01',
      adapterName: '重庆大学教务',
      category: 'BACHELOR_AND_ASSOCIATE',
      assetJsPath: 'cqu_01.js',
      importUrl: 'https://example.com/login',
      maintainer: 'Mutx',
      description: '测试适配器',
      sha256: sha256.convert(utf8.encode('console.log("trusted");')).toString(),
    );
    final client = _FakeClient({
      'https://raw.githubusercontent.com/Mutx163/qingyu_warehouse/main/resources/CQU/cqu_01.js':
          http.Response(servedBody, 200),
    });
    final service = WarehouseRepositoryService(client: client);
    final source = WarehouseRepositorySource.fromGitHubUrl(
      'https://github.com/Mutx163/qingyu_warehouse',
    );
    const school = WarehouseSchoolEntry(
      id: 'CQU',
      name: '重庆大学',
      initial: 'C',
      resourceFolder: 'CQU',
    );

    await expectLater(
      service.fetchAdapterScript(source, school: school, adapter: adapter),
      throwsA(
        isA<WarehouseRepositoryException>().having(
          (error) => error.message,
          'message',
          'warehouse_script_checksum_failed',
        ),
      ),
    );
  });

  test('fetchAdapterScript skips verification for legacy indexes without sha256',
      () async {
    const scriptBody = 'console.log("legacy");';
    const adapter = WarehouseAdapterEntry(
      adapterId: 'CQU_01',
      adapterName: '重庆大学教务',
      category: 'BACHELOR_AND_ASSOCIATE',
      assetJsPath: 'cqu_01.js',
      importUrl: 'https://example.com/login',
      maintainer: 'Mutx',
      description: '测试适配器',
    );
    final client = _FakeClient({
      'https://raw.githubusercontent.com/Mutx163/qingyu_warehouse/main/resources/CQU/cqu_01.js':
          http.Response(scriptBody, 200),
    });
    final service = WarehouseRepositoryService(client: client);
    final source = WarehouseRepositorySource.fromGitHubUrl(
      'https://github.com/Mutx163/qingyu_warehouse',
    );
    const school = WarehouseSchoolEntry(
      id: 'CQU',
      name: '重庆大学',
      initial: 'C',
      resourceFolder: 'CQU',
    );

    final script = await service.fetchAdapterScript(
      source,
      school: school,
      adapter: adapter,
    );
    expect(script, scriptBody);
  });

  test('gitcode host builds contents API uri with github raw fallback', () {
    const gitcodeSource = WarehouseRepositorySource(
      owner: 'mutx',
      repo: 'qingyu_warehouse',
      host: WarehouseRepositoryHost.gitcode,
    );

    expect(
      gitcodeSource.buildFileUri('index/root_index.yaml').toString(),
      'https://api.gitcode.com/api/v5/repos/mutx/qingyu_warehouse/contents/index/root_index.yaml?ref=main',
    );
    expect(
      gitcodeSource.buildGitHubRawFileUri('index/root_index.yaml').toString(),
      'https://raw.githubusercontent.com/mutx/qingyu_warehouse/main/index/root_index.yaml',
    );
    expect(
      WarehouseRepositorySource.fromGitHubUrl(
        'https://gitcode.com/mutx/qingyu_warehouse',
      ).host,
      WarehouseRepositoryHost.gitcode,
    );
  });

  test('default source maps GitHub Mutx163 to GitCode mutx namespace', () {
    // GitHub 主仓 raw 直链不变。
    expect(
      defaultQingyuWarehouseSource
          .buildGitHubRawFileUri('index/root_index.yaml')
          .toString(),
      'https://raw.githubusercontent.com/Mutx163/qingyu_warehouse/main/index/root_index.yaml',
    );
    // GitCode contents API 用 mutx 命名空间（实测 Mutx163 会 404 Project not found）。
    expect(
      defaultQingyuWarehouseSource
          .withHost(WarehouseRepositoryHost.gitcode)
          .buildFileUri('index/root_index.yaml')
          .toString(),
      'https://api.gitcode.com/api/v5/repos/mutx/qingyu_warehouse/contents/index/root_index.yaml?ref=main',
    );
    // 切回 GitHub 宿主后仍走 GitHub 主仓名。
    expect(
      defaultQingyuWarehouseSource.withHost(WarehouseRepositoryHost.github).host,
      WarehouseRepositoryHost.github,
    );
  });

  test('fromSettings derives preferGitCode from download channel', () {
    // 默认渠道就是 gitcode。
    expect(
      WarehouseFetchOptions.fromSettings(
        const TimetableSettings(sections: []),
      ).preferGitCode,
      isTrue,
    );
    // 蒲公英同为国内源，同步 API 也应优先 GitCode 镜像。
    expect(
      WarehouseFetchOptions.fromSettings(
        const TimetableSettings(sections: []).copyWith(
          appUpdateDownloadChannel: 'pgyer',
        ),
      ).preferGitCode,
      isTrue,
    );
    expect(
      WarehouseFetchOptions.fromSettings(
        const TimetableSettings(sections: []).copyWith(
          appUpdateDownloadChannel: 'github',
        ),
      ).preferGitCode,
      isFalse,
    );
  });

  test('preferGitCode fetches root index via GitCode contents API', () async {
    const rootYaml = '''
schools:
  - id: "CQU"
    name: "重庆大学"
    initial: "C"
    resource_folder: "CQU"
''';
    final apiBody = jsonEncode({
      'type': 'file',
      'encoding': 'base64',
      'size': utf8.encode(rootYaml).length,
      'name': 'root_index.yaml',
      'path': 'index/root_index.yaml',
      'content': base64Encode(utf8.encode(rootYaml)),
    });

    final client = _FakeClient({
      // 命名空间覆盖：GitHub Mutx163 → GitCode mutx。
      'https://api.gitcode.com/api/v5/repos/mutx/qingyu_warehouse/contents/index/root_index.yaml?ref=main':
          http.Response.bytes(utf8.encode(apiBody), 200),
    });
    final service = WarehouseRepositoryService(client: client);
    const source = defaultQingyuWarehouseSource;
    const options = WarehouseFetchOptions(
      downloadSource: AppUpdateDownloadSource.mirror,
      mirrorPreset: AppUpdateMirrorPreset.ghfast,
      customMirrorUrlPrefix: defaultAppUpdateMirrorUrlPrefix,
      preferGitCode: true,
    );

    final rootIndex = await service.fetchRootIndex(source, options: options);
    expect(rootIndex.schools, hasLength(1));
    expect(rootIndex.schools.first.name, '重庆大学');
  });

  test('preferGitCode falls back to GitHub raw when GitCode API fails',
      () async {
    const rootYaml = '''
schools:
  - id: "CQU"
    name: "重庆大学"
    initial: "C"
    resource_folder: "CQU"
''';

    // GitCode API 无响应（_FakeClient 默认 404），应回退到 GitHub raw。
    final client = _FakeClient({
      'https://raw.githubusercontent.com/Mutx163/qingyu_warehouse/main/index/root_index.yaml':
          http.Response.bytes(utf8.encode(rootYaml), 200),
    });
    final service = WarehouseRepositoryService(client: client);
    final source = WarehouseRepositorySource.fromGitHubUrl(
      'https://github.com/Mutx163/qingyu_warehouse',
    );
    const options = WarehouseFetchOptions(
      downloadSource: AppUpdateDownloadSource.original,
      mirrorPreset: AppUpdateMirrorPreset.ghfast,
      customMirrorUrlPrefix: defaultAppUpdateMirrorUrlPrefix,
      preferGitCode: true,
    );

    final rootIndex = await service.fetchRootIndex(source, options: options);
    expect(rootIndex.schools, hasLength(1));
  });

  test('fetch search index parses adapters per school', () async {
    const searchIndexYaml = '''
# index/search_index.yaml
# 由 scripts/build_search_index.py 自动生成，请勿手动编辑。
version_id: "IDX_713836364e98a319"
schools:
  - id: "GLOBAL_TOOLS"
    adapters:
      - adapter_id: "WakeUp"
        adapter_name: "WakeUp课程表分享口令导入(支持新版)"
      - adapter_id: "StarLink"
        adapter_name: "星链课表分享码导入"
  - id: "CQU"
    adapters:
      - adapter_id: "CQU"
        adapter_name: "重庆大学教务"
''';
    final client = _FakeClient({
      'https://raw.githubusercontent.com/Mutx163/qingyu_warehouse/main/index/search_index.yaml':
          http.Response.bytes(utf8.encode(searchIndexYaml), 200),
    });
    final service = WarehouseRepositoryService(client: client);
    final source = WarehouseRepositorySource.fromGitHubUrl(
      'https://github.com/Mutx163/qingyu_warehouse',
    );

    final searchIndex = await service.fetchSearchIndex(source);
    expect(searchIndex.versionId, 'IDX_713836364e98a319');
    expect(searchIndex.schools, hasLength(2));
    final globalTools = searchIndex.schools.first;
    expect(globalTools.id, 'GLOBAL_TOOLS');
    expect(
      globalTools.matchedAdapterNames('wakeup'),
      ['WakeUp课程表分享口令导入(支持新版)'],
    );
  });

  test('fetch search index missing (legacy repo) throws repository exception',
      () async {
    // _FakeClient 对未知 URL 返回 404：旧版适配仓没有全局搜索索引，
    // 调用方（教务导入页）捕获后降级为仅按学校字段搜索。
    final client = _FakeClient(const {});
    final service = WarehouseRepositoryService(client: client);
    final source = WarehouseRepositorySource.fromGitHubUrl(
      'https://github.com/Mutx163/qingyu_warehouse',
    );

    await expectLater(
      service.fetchSearchIndex(source),
      throwsA(isA<WarehouseRepositoryException>()),
    );
  });

  test('search index parser tolerates blanks, comments and loose quoting', () {
    const yaml = '''
# 顶部注释
version_id: IDX_plain
schools:
  - id: CQU
    adapters:
      # 注释穿插
      - adapter_id: CQU_01
        adapter_name: 重庆大学教务

      - adapter_id: "PARTIAL"
  - id: "EMPTY"

next_top_level:
  - id: "IGNORED"
''';
    final index = parseWarehouseSearchIndexYaml(yaml);
    expect(index.versionId, 'IDX_plain');
    expect(index.schools, hasLength(1));
    final school = index.schools.single;
    expect(school.id, 'CQU');
    // 没有名称的条目仍保留（展示时回退用 ID），不完整学校被跳过
    expect(school.adapters.map((a) => a.adapterId), ['CQU_01', 'PARTIAL']);
  });
}
