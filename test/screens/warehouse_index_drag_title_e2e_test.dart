import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/screens/import/warehouse/warehouse_course_import_screen.dart';
import 'package:university_timetable/services/app_http_client.dart';
import 'package:university_timetable/services/storage_service.dart';
import 'package:university_timetable/ui/hyperos/hyperos_collapsible_top_app_bar.dart';

import '../helpers_test_app.dart';

/// 端到端回归（2026-10-10 两轮实机反馈）：进页面后手指直接在字母条上
/// 下滑 → 滑上去 → 再下滑第二次，每次之后大标题都必须像手动滑动那样收起。
///
/// 组件级测试（warehouse_index_jump_collapsible_title_test）喂不出真实页面
/// 的完整链路，第一轮修复在组件级全绿、真机却复现——根因是抓滚动位用的
/// `itemBuilder` context 在 `Scrollable` **上方**，`Scrollable.maybeOf` 只向
/// 上找、永远返回 null，页面的补同步回调每帧都跑、每次都空手而归。这条测试
/// 用真实 `WarehouseCourseImportScreen` + 桩 HTTP + `TestGesture` 在真实字母
/// 条上拖动，钉住「Builder 包裹后的 context 抓取」这条链路不再回归。
///
/// ⚠️ 本文件曾以 `warehouse_school_index_drag_title_sync_test.dart` 为名开发，
/// 该文件名被反复中断的测试进程污染（同名必挂、内容相同改名即过），故改用
/// 现名。若未来此文件莫名挂起，先换个文件名再怀疑代码。
///
/// 判据：顶栏（`HyperosCollapsibleTopAppBar`）的实际盒子高。展开 ≈ 折叠行
/// 52 + 大标题 38.4 + 4（实测 172），折叠 ≈ 56（实测 134，含 SafeArea 状态栏
/// 78），相差恰好一个大标题的高度。
const double _kExpandedFloor = 80;

/// 24 所学校、首字母 A-X 各一个：字母条 24 格，每格跳到对应组。
String _schoolYaml() {
  final buf = StringBuffer('schools:\n');
  for (var i = 0; i < 24; i++) {
    final letter = String.fromCharCode(65 + i); // A..X
    buf
      ..writeln('  - id: "S$letter"')
      ..writeln('    name: "学校$letter"')
      ..writeln('    initial: "$letter"')
      ..writeln('    resource_folder: "R$letter"');
  }
  return buf.toString();
}

class _StubClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final path = request.url.path;
    final isWarehouseIndex =
        path.contains('root_index') || path.contains('search_index');
    if (!isWarehouseIndex) {
      // 其余域名（天气/节假日等）回 404 走各自降级路径。
      return http.StreamedResponse(const Stream<List<int>>.empty(), 404);
    }
    final body = path.contains('root_index') ? _schoolYaml() : '';
    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(body)),
      200,
    );
  }
}

Future<void> _pumpScreen(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  StorageService().resetForTesting();
  // Provider 先建：它自己的 HTTP 在测试环境即时失败，不能被共享桩截胡。
  final provider = await createInitializedTestProvider(tester);
  // 页面的 WarehouseRepositoryService 在首次 build 时才 createAppHttpClient()；
  // 这里把共享桩 client 装上，页面的仓库请求就会被注住（桩只应仓库索引）。
  if (!kReleaseMode) {
    setupAppHttpClientForBlackBox(_StubClient());
  }
  await tester.pumpWidget(
    ChangeNotifierProvider<TimetableProvider>.value(
      value: provider,
      child: const TestApp(home: WarehouseCourseImportScreen()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  // 让 initState 里那几条 Future 走一走（桩即时返回）。
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 150)),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

double _headerHeight(WidgetTester tester) =>
    tester.getSize(find.byType(HyperosCollapsibleTopAppBar)).height;

/// 找到字母条上某个字母的中心点（自建 IndexBar 的字母 Text）。
///
/// `.last`：字母跳转的浮层提示（indexHint）可能短暂持有同文字副本，取最后一
/// 个才是字母条本体的行。
Offset _letterCenter(WidgetTester tester, String letter) =>
    tester.getCenter(find.text(letter).last);

/// 手指从 [from] 连续拖到 [to]（分 12 步、每步一帧），模拟不落定的滑动。
Future<void> _dragFromTo(WidgetTester tester, Offset from, Offset to) async {
  final gesture = await tester.startGesture(from);
  await gesture.moveBy(Offset.zero);
  await tester.pump();
  const steps = 12;
  final delta = (to - from) / steps.toDouble();
  for (var i = 0; i < steps; i++) {
    await gesture.moveBy(delta);
    await tester.pump();
  }
  await gesture.up();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    StorageService().resetForTesting();
  });

  testWidgets('进页面直接在字母条上：下滑→滑上去→再下滑，第二次也收起', (tester) async {
    await _pumpScreen(tester);

    expect(find.text('学校A'), findsOneWidget);
    final expandedHeight = _headerHeight(tester);
    expect(expandedHeight, greaterThan(_kExpandedFloor));

    // 字母条在屏幕右缘：从 E 拖到 T（下滑），拖回 B（滑上去），再拖到 T。
    final barE = _letterCenter(tester, 'E');
    final barT = _letterCenter(tester, 'T');
    final barB = _letterCenter(tester, 'B');

    // ① 下滑第一次：收起（实测 172 → 134）。
    await _dragFromTo(tester, barE, barT);
    final firstDown = _headerHeight(tester);
    expect(
      firstDown,
      lessThan(expandedHeight - 30),
      reason: '第一次下滑后大标题应收起',
    );

    // ② 滑上去：滑回 B 组。内容仍被大标题盖住，标题保持收起；手势落点不同
    //    字母时也可能重新展开，所以只要求不超过展开态。
    await _dragFromTo(tester, barT, barB);
    final afterUp = _headerHeight(tester);
    expect(afterUp, lessThanOrEqualTo(expandedHeight));

    // ③ 下滑第二次：必须与第一次一致（第二轮实机反馈的复现序列）。
    await _dragFromTo(tester, barB, barT);
    final secondDown = _headerHeight(tester);
    expect(
      secondDown,
      firstDown,
      reason: '第二次下滑后大标题必须照常收起',
    );
  });
}
