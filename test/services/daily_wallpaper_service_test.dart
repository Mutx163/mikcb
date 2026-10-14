import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/services/bing_wallpaper_service.dart';
import 'package:university_timetable/services/bing_wallpaper_store.dart';
import 'package:university_timetable/services/daily_wallpaper_service.dart';

/// 图源调度层（[DailyWallpaperService]）的行为。
///
/// 2026-10-14 图源收敛回 Bing 之后的剩余口径：调度层吞掉一切意外（启动路径铁律）、
/// 「今天已换过」幂等、`appliedStale` 归一保留。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// path_provider 的渠道名；把「应用文档目录」指到临时目录，让下载走真实文件写入
  /// （与 `bing_wallpaper_service_test.dart` 同款做法）。
  ///
  /// 少了这一步，所有下载都会走 `write` 失败那条路 → 自动换一律 `failed`，而症状
  /// 看起来像「图源拉不到」，与真实故障一模一样。
  const MethodChannel pathProviderChannel = MethodChannel(
    'plugins.flutter.io/path_provider',
  );

  late Directory documentsDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    BingWallpaperStore.debugResetForTesting();
    BingWallpaperService.testClientFactory = null;
    documentsDir = await Directory.systemTemp.createTemp('daily-wp');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          pathProviderChannel,
          (call) async => documentsDir.path,
        );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
    BingWallpaperService.testClientFactory = null;
    if (documentsDir.existsSync()) {
      await documentsDir.delete(recursive: true);
    }
  });

  /// ⚠️ 纯 ASCII 的 JSON 字符串字面量，**不要**走 `jsonEncode(Map)` ——
  /// `Response(String, 200)` 的 `bodyBytes` 按 latin1 编码，中文会变成非法字节，
  /// `utf8.decode` 抛错，service 静默返回空清单（症状与「图源拉不到」一模一样）。
  Response bingListOk() => Response(
    '{"images":[{"startdate":"20261007","urlbase":"/th?id=OHR.BingDay_ZH-CN111",'
    '"title":"bing","copyright":"bing"}]}',
    200,
    headers: <String, String>{'content-type': 'application/json'},
  );

  /// 清单与图片请求混在同一个 MockClient 里，按 URL 形状分别应答。
  ///
  /// ⚠️ 清单与图片的判据要分开：`downloadToManagedImage` 会验 `content-type` 必须以
  /// `image/` 开头，混用就会把清单当成「不是图片」而失败。
  MockClient clientFor({required bool bingOk}) => MockClient((request) async {
    if (request.url.path.contains('HPImageArchive')) {
      return bingOk ? bingListOk() : Response('boom', 500);
    }
    // 图片请求：给一张最小合法 JPEG。
    return Response.bytes(
      <int>[0xFF, 0xD8, 0xFF, 0xE0],
      200,
      headers: <String, String>{'content-type': 'image/jpeg'},
    );
  });

  Future<void> enableAutoApply(BingWallpaperStore store) =>
      store.setAutoApplyEnabled(true);

  group('按图源执行', () {
    test('走 Bing 并换上今天那张', () async {
      await enableAutoApply(BingWallpaperStore.instance);
      BingWallpaperService.testClientFactory = () => clientFor(bingOk: true);

      final result = await DailyWallpaperService.applyDaily(
        now: DateTime(2026, 10, 7, 12),
      );
      expect(result.outcome, DailyWallpaperApplyOutcome.appliedToday);
      expect(result.path, contains('wallpaper_bing_'));
    });

    test('开关关着 → disabled，且一个请求都不发', () async {
      var calls = 0;
      BingWallpaperService.testClientFactory = () => MockClient((request) async {
        calls++;
        return Response('nope', 500);
      });

      final result = await DailyWallpaperService.applyDaily(
        now: DateTime(2026, 10, 7),
      );
      expect(result.outcome, DailyWallpaperApplyOutcome.disabled);
      expect(calls, 0, reason: '未开的用户连网络都不该碰');
    });

    test('⭐ 同一天第二次启动不再换（幂等）', () async {
      // 历史背景：这条钉的是「没切源时必须幂等」—— 否则把判据改成
      // 「永不 alreadyApplied」也能过，代价是每次冷启动都重下一次 3.5 MB 的图。
      final store = BingWallpaperStore.instance;
      await enableAutoApply(store);
      BingWallpaperService.testClientFactory = () => clientFor(bingOk: true);

      final now = DateTime(2026, 10, 7, 9);
      expect(
        (await DailyWallpaperService.applyDaily(now: now)).outcome,
        DailyWallpaperApplyOutcome.appliedToday,
      );
      expect(
        (await DailyWallpaperService.applyDaily(now: now)).outcome,
        DailyWallpaperApplyOutcome.alreadyApplied,
      );
    });
  });

  group('归一化口径', () {
    test('Bing 的 appliedStale 被保留成一档', () async {
      final store = BingWallpaperStore.instance;
      await enableAutoApply(store);
      // 清单首项是昨天 —— 真实响应里这是常态（Bing 何时放当天那张不由本 App 控制）。
      BingWallpaperService.testClientFactory = () =>
          MockClient((request) async {
            if (request.url.path.contains('HPImageArchive')) {
              return Response(
                '{"images":[{"startdate":"20261006",'
                '"urlbase":"/th?id=OHR.Yesterday_ZH-CN1",'
                '"title":"y","copyright":"y"}]}',
                200,
              );
            }
            return Response.bytes(
              <int>[0xFF, 0xD8, 0xFF, 0xE0],
              200,
              headers: <String, String>{'content-type': 'image/jpeg'},
            );
          });

      final result = await DailyWallpaperService.applyDaily(
        now: DateTime(2026, 10, 7, 12),
      );
      expect(result.outcome, DailyWallpaperApplyOutcome.appliedStale);
      expect(result.itemId, '20261006', reason: 'itemId 是那张图自己的 dateKey');
    });

    test('外层吞掉意外，绝不抛给启动路径', () async {
      final store = BingWallpaperStore.instance;
      await enableAutoApply(store);
      BingWallpaperService.testClientFactory = () =>
          MockClient((request) async => throw StateError('模拟内部炸了'));

      final result = await DailyWallpaperService.applyDaily(
        now: DateTime(2026, 10, 7, 12),
      );
      expect(result.outcome, DailyWallpaperApplyOutcome.failed);
    });
  });
}
