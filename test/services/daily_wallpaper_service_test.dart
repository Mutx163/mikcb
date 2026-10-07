import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/wallpaper_daily_source.dart';
import 'package:university_timetable/services/bing_wallpaper_service.dart';
import 'package:university_timetable/services/bing_wallpaper_store.dart';
import 'package:university_timetable/services/daily_wallpaper_service.dart';
import 'package:university_timetable/services/wallhaven_wallpaper_service.dart';

/// 图源调度层（[DailyWallpaperService]）的行为。
///
/// 三条要钉住的口径：换源只对**自动换**生效、换源对用户透明但两个源都失败时报原源、
/// 以及「今天已换过」在切源之后立刻失效（靠图源世代号）。
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
    WallhavenWallpaperService.testClientFactory = null;
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
    WallhavenWallpaperService.testClientFactory = null;
    if (documentsDir.existsSync()) {
      await documentsDir.delete(recursive: true);
    }
  });

  /// Bing 清单里的一项（**手写 JSON 字符串**，不走 Map 再 `jsonEncode`）。
  ///
  /// ⚠️ `http.Response(String, 200)` 的 `bodyBytes` 按 **latin1** 编码，所以
  /// `jsonEncode(Map)` 里那些中文会变成非法字节 → `utf8.decode` 抛错 → service
  /// 静默返回空清单 → 测试表现为「给了合法响应却什么都拿不到」。真 HTTP 客户端给的
  /// 是 UTF-8 字节，所以生产代码没问题，是测试构造方式的问题（与
  /// `bing_wallpaper_service_test.dart` 里那段⚠️同源）。
  const bingItemJson =
      '{"startdate":"20261007","urlbase":"/th?id=OHR.BingDay_ZH-CN111",'
      '"title":"bing","copyright":"bing"}';

  /// Wallhaven 清单里的一项（同上，纯 ASCII 所以没有那个坑）。
  const whItemJson =
      '{"id":"w53vkq","dimension_x":2250,"dimension_y":4000,'
      '"path":"https://w.wallhaven.cc/full/w5/wallhaven-w53vkq.jpg",'
      '"file_size":6089000,"category":"general",'
      '"thumbs":{"large":"https://th.wallhaven.cc/lg/w5/w53vkq.jpg"}}';

  /// 图源清单与图片请求混在同一个 MockClient 里，所以按 URL 形状分别应答。
  ///
  /// ⚠️ 清单与图片的判据要分开：`downloadToManagedImage` 会验 `content-type` 必须以
  /// `image/` 开头，混用就会把清单当成「不是图片」而失败。
  String jsonBodyFor(Uri url) {
    if (url.path.contains('HPImageArchive')) {
      return '{"images":[$bingItemJson]}';
    }
    if (url.path.contains('api/v1/search')) {
      return '{"data":[$whItemJson]}';
    }
    return '';
  }

  bool isListRequest(Uri url) =>
      url.path.contains('HPImageArchive') ||
      url.path.contains('api/v1/search');

  http.Client clientFor({
    required bool bingOk,
    required bool wallhavenOk,
    void Function(Uri url)? onRequest,
  }) => MockClient((request) async {
    onRequest?.call(request.url);
    if (isListRequest(request.url)) {
      final ok = request.url.host.contains('wallhaven.cc')
          ? wallhavenOk
          : bingOk;
      return ok
          ? http.Response(jsonBodyFor(request.url), 200)
          : http.Response('boom', 500);
    }
    // 图片请求：给一张最小合法 JPEG。
    return http.Response.bytes(
      <int>[0xFF, 0xD8, 0xFF, 0xE0],
      200,
      headers: <String, String>{'content-type': 'image/jpeg'},
    );
  });

  Future<void> enableAutoApply(BingWallpaperStore store) =>
      store.setAutoApplyEnabled(true);

  group('按选中的图源执行', () {
    test('默认走 Bing', () async {
      await enableAutoApply(BingWallpaperStore.instance);
      BingWallpaperService.testClientFactory = () =>
          clientFor(bingOk: true, wallhavenOk: false);

      final result = await DailyWallpaperService.applyDaily(
        now: DateTime(2026, 10, 7, 12),
      );
      expect(result.outcome, DailyWallpaperApplyOutcome.appliedToday);
      expect(result.source, WallpaperDailySource.bing);
      expect(result.path, contains('wallpaper_bing_'));
    });

    test('选了 Wallhaven 就走 Wallhaven（Bing 完全不碰）', () async {
      final store = BingWallpaperStore.instance;
      await enableAutoApply(store);
      await store.setDailySource(WallpaperDailySource.wallhaven);

      var bingListCalls = 0;
      var whListCalls = 0;
      BingWallpaperService.testClientFactory =
          () => clientFor(
            bingOk: true,
            wallhavenOk: true,
            onRequest: (url) { if (isListRequest(url)) bingListCalls++; },
          );
      WallhavenWallpaperService.testClientFactory =
          () => clientFor(
            bingOk: true,
            wallhavenOk: true,
            onRequest: (url) { if (isListRequest(url)) whListCalls++; },
          );

      final result = await DailyWallpaperService.applyDaily(
        now: DateTime(2026, 10, 7, 12),
      );
      expect(result.outcome, DailyWallpaperApplyOutcome.appliedToday);
      expect(result.source, WallpaperDailySource.wallhaven);
      expect(result.path, contains('wallpaper_wh_'));
      expect(whListCalls, greaterThan(0), reason: 'Wallhaven 清单要被拉');
      expect(
        bingListCalls,
        0,
        reason: '选了 Wallhaven 就不该碰 Bing —— 否则等于白下一次 3.5 MB',
      );
    });

    test('开关关着 → disabled，且一个请求都不发', () async {
      var calls = 0;
      BingWallpaperService.testClientFactory =
          () => clientFor(
            bingOk: true,
            wallhavenOk: true,
            onRequest: (url) { if (isListRequest(url)) calls++; },
          );
      WallhavenWallpaperService.testClientFactory =
          () => clientFor(
            bingOk: true,
            wallhavenOk: true,
            onRequest: (url) { if (isListRequest(url)) calls++; },
          );

      final result = await DailyWallpaperService.applyDaily(
        now: DateTime(2026, 10, 7),
      );
      expect(result.outcome, DailyWallpaperApplyOutcome.disabled);
      expect(calls, 0, reason: '未开的用户连网络都不该碰');
    });
  });

  group('换源兜底', () {
    test('Wallhaven 失败 → 自动换改用 Bing（换源对用户透明）', () async {
      final store = BingWallpaperStore.instance;
      await enableAutoApply(store);
      await store.setDailySource(WallpaperDailySource.wallhaven);

      WallhavenWallpaperService.testClientFactory =
          () => clientFor(bingOk: true, wallhavenOk: false);
      BingWallpaperService.testClientFactory =
          () => clientFor(bingOk: true, wallhavenOk: true);

      final result = await DailyWallpaperService.applyDaily(
        now: DateTime(2026, 10, 7, 12),
      );
      expect(result.outcome, DailyWallpaperApplyOutcome.appliedToday);
      expect(
        result.source,
        WallpaperDailySource.bing,
        reason: '实际生效的源必须如实记（换源是对用户透明的，但日志/那张是哪来的要知道）',
      );
      expect(result.path, contains('wallpaper_bing_'));
    });

    test('⭐ 两个源都失败 → 报「原源」的结局，不说谎', () async {
      final store = BingWallpaperStore.instance;
      await enableAutoApply(store);
      await store.setDailySource(WallpaperDailySource.wallhaven);

      WallhavenWallpaperService.testClientFactory =
          () => clientFor(bingOk: false, wallhavenOk: false);
      BingWallpaperService.testClientFactory =
          () => clientFor(bingOk: false, wallhavenOk: false);

      final result = await DailyWallpaperService.applyDaily(
        now: DateTime(2026, 10, 7, 12),
      );
      expect(result.outcome, DailyWallpaperApplyOutcome.failed);
      // 用户用的是 Wallhaven，提示不该因为内部换过源就变成「Bing 也失败了」。
      expect(result.source, isNull, reason: '失败时不谎报是哪个源换上的');
      expect(result.path, isNull);
    });

    test('「不换源」策略下，Wallhaven 失败就只是失败（不偷跑 Bing）', () async {
      final store = BingWallpaperStore.instance;
      await enableAutoApply(store);
      await store.setDailySource(WallpaperDailySource.wallhaven);
      await store.setSourceFallback(WallpaperSourceFallback.never);

      var bingListCalls = 0;
      WallhavenWallpaperService.testClientFactory =
          () => clientFor(bingOk: true, wallhavenOk: false);
      BingWallpaperService.testClientFactory =
          () => clientFor(
            bingOk: true,
            wallhavenOk: true,
            onRequest: (url) { if (isListRequest(url)) bingListCalls++; },
          );

      final result = await DailyWallpaperService.applyDaily(
        now: DateTime(2026, 10, 7, 12),
      );
      expect(result.outcome, DailyWallpaperApplyOutcome.failed);
      expect(bingListCalls, 0, reason: '选了「不换源」就不该动另一个源');
    });
  });

  group('⭐ 切源之后「今天已换过」必须立刻失效', () {
    test('用 Bing 换过一次 → 切到 Wallhaven → 当天还能再换一次', () async {
      final store = BingWallpaperStore.instance;
      await enableAutoApply(store);
      BingWallpaperService.testClientFactory =
          () => clientFor(bingOk: true, wallhavenOk: true);

      final now = DateTime(2026, 10, 7, 9);
      final first = await DailyWallpaperService.applyDaily(now: now);
      expect(first.outcome, DailyWallpaperApplyOutcome.appliedToday);
      expect(first.source, WallpaperDailySource.bing);

      // 同一天、同一个源 → 已换过（这条是幂等基线）。
      final again = await DailyWallpaperService.applyDaily(now: now);
      expect(again.outcome, DailyWallpaperApplyOutcome.alreadyApplied);

      // 切源：图源世代号自增，当天就该允许再换一次。
      await store.setDailySource(WallpaperDailySource.wallhaven);
      WallhavenWallpaperService.testClientFactory =
          () => clientFor(bingOk: true, wallhavenOk: true);

      final afterSwitch = await DailyWallpaperService.applyDaily(now: now);
      expect(
        afterSwitch.outcome,
        DailyWallpaperApplyOutcome.appliedToday,
        reason: '不换就正好是「我切了图源但什么都没发生」这个报障',
      );
      expect(afterSwitch.source, WallpaperDailySource.wallhaven);
      expect(afterSwitch.path, contains('wallpaper_wh_'));
    });

    test('Wallhaven 换过一次 → 切回 Bing → 当天还能再换一次', () async {
      final store = BingWallpaperStore.instance;
      await enableAutoApply(store);
      await store.setDailySource(WallpaperDailySource.wallhaven);
      WallhavenWallpaperService.testClientFactory =
          () => clientFor(bingOk: true, wallhavenOk: true);
      BingWallpaperService.testClientFactory =
          () => clientFor(bingOk: true, wallhavenOk: true);

      final now = DateTime(2026, 10, 7, 9);
      expect(
        (await DailyWallpaperService.applyDaily(now: now)).outcome,
        DailyWallpaperApplyOutcome.appliedToday,
      );
      await store.setDailySource(WallpaperDailySource.bing);

      // ⭐ 这里能成立，靠的是 Wallhaven 的台账**不留 autoApplied 标记**
      // （见 `recordWallhaven`）：否则 `lastAutoAppliedDate` 会返回 `wh:w53vkq`，
      // 与 Bing 的 `20261007` 永不相等，「今天已换过」就永远判不成立 ——
      // 表现是切回 Bing 之后它每天都在重下同一天那张。
      expect(store.lastAutoAppliedDate, isNull);
      expect(
        (await DailyWallpaperService.applyDaily(now: now)).outcome,
        DailyWallpaperApplyOutcome.appliedToday,
      );
    });
  });

  group('归一化口径', () {
    test('Bing 的 appliedStale 被保留成一档（只有 Bing 会有）', () async {
      final store = BingWallpaperStore.instance;
      await enableAutoApply(store);
      // 清单首项是昨天 —— 真实响应里这是常态（Bing 何时放当天那张不由本 App 控制）。
      BingWallpaperService.testClientFactory = () =>
          MockClient((request) async {
            if (request.url.path.contains('HPImageArchive')) {
              return http.Response(
                '{"images":[{"startdate":"20261006",'
                '"urlbase":"/th?id=OHR.Yesterday_ZH-CN1",'
                '"title":"y","copyright":"y"}]}',
                200,
              );
            }
            return http.Response.bytes(
              <int>[0xFF, 0xD8, 0xFF, 0xE0],
              200,
              headers: <String, String>{'content-type': 'image/jpeg'},
            );
          });

      final result = await DailyWallpaperService.applyDaily(
        now: DateTime(2026, 10, 7, 20),
      );
      expect(
        result.outcome,
        DailyWallpaperApplyOutcome.appliedStale,
        reason: '「换了但不是今天那张」要能如实报出来，不能混成 appliedToday',
      );
      expect(result.itemId, '20261006');
    });

    test('外层吞掉意外，绝不抛给启动路径', () async {
      final store = BingWallpaperStore.instance;
      await enableAutoApply(store);
      BingWallpaperService.testClientFactory = () => MockClient((_) async {
        throw StateError('模拟内部炸了');
      });
      // 不该抛 —— 自动换挂在启动流程上（`main.dart` 的 `_handleAppResumedWithCloudPull`）。
      final result = await DailyWallpaperService.applyDaily(
        now: DateTime(2026, 10, 7),
      );
      expect(result.outcome, DailyWallpaperApplyOutcome.failed);
    });
  });

  }