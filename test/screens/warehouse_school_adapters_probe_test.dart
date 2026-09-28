import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/models/warehouse_repository_models.dart';
import 'package:university_timetable/screens/course_import_screen.dart';
import 'package:university_timetable/services/storage_service.dart';
import 'package:university_timetable/services/warehouse_repository_service.dart';
import '../helpers_test_app.dart';

const _school = WarehouseSchoolEntry(
  id: 'CQCST',
  name: '重庆城市科技学院',
  initial: 'C',
  resourceFolder: 'CQCST',
);

const _source = WarehouseRepositorySource(
  owner: 'Mutx163',
  repo: 'qingyu_warehouse',
);

const _options = WarehouseFetchOptions(
  downloadSource: AppUpdateDownloadSource.original,
  mirrorPreset: AppUpdateMirrorPreset.ghfast,
  customMirrorUrlPrefix: defaultAppUpdateMirrorUrlPrefix,
);

const _standardAdapterName = '重庆城市科技学院强智适配';
const _extrasAdapterName = '重庆城市科技学院强智适配（按教学楼自动分流作息）';

const _standardYaml = '''
adapters:
  - adapter_id: "CQCST_01"
    adapter_name: "$_standardAdapterName"
    category: "BACHELOR_AND_ASSOCIATE"
    asset_js_path: "cqcst_01.js"
    import_url: "http://jw.cqcst.edu.cn/cqdxcskjxy_jsxsd/"
    maintainer: "Mutx163"
    description: "标准版"
''';

const _extrasYaml = '''
adapters:
  - adapter_id: "CQCST_02"
    adapter_name: "$_extrasAdapterName"
    category: "BACHELOR_AND_ASSOCIATE"
    asset_js_path: "cqcst_01.js"
    import_url: "http://jw.cqcst.edu.cn/cqdxcskjxy_jsxsd/"
    maintainer: "Mutx163"
    description: "专属版"
    time_schemes_file: "time_schemes.json"
''';

/// 专属目录探测的三种行为。
enum ProbeBehavior {
  /// 404：绝大多数学校的常态。
  notFound,

  /// 永不返回：这是本文件要治的那个 bug 的原型。
  hang,

  /// 返回一条专属条目。
  found,
}

class _StubClient extends http.BaseClient {
  _StubClient(this.probe);

  final ProbeBehavior probe;
  final requested = <String>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final url = request.url.toString();
    requested.add(url);
    if (url.contains('/qingyu_only/')) {
      switch (probe) {
        case ProbeBehavior.hang:
          return Completer<http.StreamedResponse>().future;
        case ProbeBehavior.notFound:
          return http.StreamedResponse(const Stream<List<int>>.empty(), 404);
        case ProbeBehavior.found:
          return http.StreamedResponse(
            Stream<List<int>>.value(utf8.encode(_extrasYaml)),
            200,
          );
      }
    }
    if (url.contains('adapters.yaml')) {
      return http.StreamedResponse(
        Stream<List<int>>.value(utf8.encode(_standardYaml)),
        200,
      );
    }
    return http.StreamedResponse(const Stream<List<int>>.empty(), 404);
  }
}

Future<void> _pump(WidgetTester tester, _StubClient client) async {
  await tester.pumpWidget(
    TestApp(
      home: WarehouseSchoolAdaptersScreen(
        source: _source,
        school: _school,
        fetchOptions: _options,
        repositoryServiceOverride: WarehouseRepositoryService(client: client),
      ),
    ),
  );
  // 真实 I/O 要跑出 FakeAsync 才有结果（见 helpers_test_app.runRealAsync 的说明）。
  // 挂起的那条探测在 runAsync 里也永远不会返回——这正是要验的场景。
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 120)),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    StorageService().resetForTesting();
  });

  testWidgets('专属目录探测永不返回时，标准适配器照样立刻显示', (tester) async {
    // 回归测试：曾经把标准索引与专属探测塞进同一个 Future，于是页面只能等探测结束
    // 才渲染 —— 探测走 5 个候选地址、且 http.Client 默认没有超时，学校页就一直转圈。
    // 判据不是「探测有没有完成」，而是「探测没完成时页面是否可用」。
    final client = _StubClient(ProbeBehavior.hang);
    await _pump(tester, client);

    expect(
      find.text(_standardAdapterName),
      findsOneWidget,
      reason: '标准适配器必须在探测完成之前就显示出来',
    );
    // 探测结果此刻还没到，专属条目不该出现——但也不能因此挡住上面那条。
    expect(find.text(_extrasAdapterName), findsNothing);

    // 把探测那个 6 秒超时走完，否则 teardown 会抱怨「还有 Timer 没走」。
    // 顺带验证超时本身：超时后页面依旧正常，探测失败不会把页面带崩。
    await tester.pump(WarehouseRepositoryService.qingyuOnlyProbeTimeout +
        const Duration(seconds: 1));
    await tester.pump();
    expect(find.text(_standardAdapterName), findsOneWidget);
  });

  testWidgets('探测返回 404 时，页面照常显示且不报错', (tester) async {
    final client = _StubClient(ProbeBehavior.notFound);
    await _pump(tester, client);

    expect(find.text(_standardAdapterName), findsOneWidget);
    expect(
      client.requested.any((u) => u.contains('/qingyu_only/')),
      isTrue,
      reason: '应当确实发起了探测（否则等于没实现）',
    );
    // 探测只打一次主地址：404 是绝大多数学校的常态，走 5 个候选等于白花 5 个来回。
    expect(
      client.requested.where((u) => u.contains('/qingyu_only/')).length,
      1,
    );
  });

  testWidgets('探测到达后，专属条目追加在标准条目之后', (tester) async {
    await _pump(tester, _StubClient(ProbeBehavior.found));

    expect(find.text(_standardAdapterName), findsOneWidget);
    expect(find.text(_extrasAdapterName), findsOneWidget);

    final standard = tester.getTopLeft(find.text(_standardAdapterName));
    final extras = tester.getTopLeft(find.text(_extrasAdapterName));
    expect(
      standard.dy,
      lessThan(extras.dy),
      reason: '专属条目必须追加在标准条目之后，标准那条永远排在前面',
    );
  });
}
