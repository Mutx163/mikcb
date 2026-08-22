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
    final adapter = WarehouseAdapterEntry(
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
}
