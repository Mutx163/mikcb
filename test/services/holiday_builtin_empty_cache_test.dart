import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/services/holiday_service.dart';

/// 回归钉（2026-10-05 审查第 17 轮）：空兜底不许当成"已知事实"写进持久缓存。
///
/// 内置资产是按年份一个个文件的（仓库目前只带 `assets/holidays/2026.json`）。
/// 远程失败 + 该年没有内置文件时，`_loadBuiltin` 返回空 entries，而旧代码把这份
/// 空结果 `_saveToLocalCache` 落盘 —— 等于宣布"这一年确定没有假期"。之后每次启动
/// 都在「本地缓存命中」那一步短路返回空，只发一次后台刷新；只要远程继续失败
/// （离线、被墙、接口变更），后来版本新带的该年内置假期数据就永远读不到了。
class _AlwaysFailingClient extends http.BaseClient {
  int requestCount = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requestCount++;
    return http.StreamedResponse(
      Stream.value(utf8.encode('service unavailable')),
      503,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('该年没有内置资产时返回空，但不把空写进持久缓存', () async {
    final client = _AlwaysFailingClient();
    final service = HolidayService(client: client);

    final data = await service.getDataForYear(2027);

    // 本会话仍然拿到空结果（不假装成功）。
    expect(data.entries, isEmpty);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('holiday_data_2027'), isFalse);
  });

  test('内存缓存照旧生效：同一会话第二次取回的是同一份结果', () async {
    // 这条是刻意保留的旧行为：不落盘不等于每次访问都重新阻塞等远程。
    // （第二次仍会安排一次后台刷新，所以不能拿 requestCount 不变来断言 ——
    // 命中内存缓存的那条路径本身就会 _backgroundRefresh。）
    final client = _AlwaysFailingClient();
    final service = HolidayService(client: client);

    final first = await service.getDataForYear(2027);
    final second = await service.getDataForYear(2027);

    expect(identical(first, second), isTrue);
    expect(second.entries, isEmpty);
  });

  test('对照：该年确有内置资产时照常落盘（不能一刀切关掉缓存）', () async {
    final service = HolidayService(client: _AlwaysFailingClient());

    final data = await service.getDataForYear(2026);
    expect(data.entries, isNotEmpty);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('holiday_data_2026'), isTrue);
  });
}
