import 'dart:convert';

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
}
