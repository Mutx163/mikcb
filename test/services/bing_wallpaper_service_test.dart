import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/bing_wallpaper.dart';
import 'package:university_timetable/services/bing_wallpaper_service.dart';
import 'package:university_timetable/services/bing_wallpaper_store.dart';
import 'package:university_timetable/utils/managed_image_storage.dart';

/// 钉住拉列表与下载的行为，重点是**失败一律静默**。
///
/// `maybeApplyDaily` 挂在 `main.dart` 的启动流程与每次回前台上；它一旦抛错会波及
/// `_handleStartupFlows`，把一次"壁纸下载失败"升级成"App 启动异常"。所以「断网 /
/// 非 2xx / 返回 HTML / 下载中断」这几条都必须只表现为"今天没换"，不冒泡。
/// 「应用文档目录」的替身（每个用例建一个新的临时目录）。
///
/// 做成**文件级**变量：`main()` 之外的断言辅助函数（`_wallpaperFiles`）也要读它。
late Directory documentsDir;

/// 收到列表请求的次数 —— 用来验证缓存真的挡住了重复请求。
var listRequestCount = 0;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// path_provider 的渠道名；把「应用文档目录」指到临时目录，让下载走真实文件写入
  /// （`plugin_boundary_smoke_test.dart` / `app_log_service_test.dart` 同款做法）。
  const MethodChannel pathProviderChannel = MethodChannel(
    'plugins.flutter.io/path_provider',
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    BingWallpaperStore.debugResetForTesting();
    listRequestCount = 0;
    documentsDir = await Directory.systemTemp.createTemp('bing-wp-svc');
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

  /// 把一段 JSON **按 UTF-8 字节**包成 200 响应。
  ///
  /// ⚠️ 不能用 `http.Response(String, 200)`：它的 `bodyBytes` 按 **latin1** 编码，
  /// 于是响应里的中文版权说明在到达解码前就已经被毁成乱码，`utf8.decode` 抛错 →
  /// service 走「静默返回空列表」那条路 → 测试表现为「明明给了合法响应却拿到空清单」。
  /// 真实 HTTP 客户端给的就是真 UTF-8 字节，所以生产代码没问题，是测试构造方式的问题。
  http.Response utf8Json(String body, {int status = 200}) =>
      http.Response.bytes(utf8.encode(body), status);

  /// 一份合法的列表响应（字段形状取自 2026-10-05 实测）。
  String listBody({String startDate = '20261005'}) => jsonEncode(<String, Object?>{
    'images': <Object?>[
      <String, Object?>{
        'startdate': startDate,
        'urlbase': '/th?id=OHR.AdelieTeacher_EN-US5343194378',
        'title': 'Taking the plunge',
        'copyright': '阿德利企鹅，南极洲',
      },
      <String, Object?>{
        'startdate': '20261004',
        'urlbase': '/th?id=OHR.ArtemisRocket_EN-US5256990037',
        'title': 'The universe is calling',
        'copyright': 'Artemis I 火箭',
      },
    ],
  });

  group('fetchRecent', () {
    test('解析出清单，按接口顺序（新→旧）', () async {
      final service = BingWallpaperService(
        client: MockClient((request) async => utf8Json(listBody())),
      );
      addTearDown(service.dispose);

      final items = await service.fetchRecent();
      expect(items, hasLength(2));
      expect(items.first.dateKey, '20261005');
      expect(
        items.first.fullUrl(BingWallpaperResolution.standard),
        contains('_1080x1920.jpg'),
      );
    });

    test('请求带 mkt=zh-CN（版权说明要中文）', () async {
      late Uri seen;
      final service = BingWallpaperService(
        client: MockClient((request) async {
          seen = request.url;
          return utf8Json(listBody());
        }),
      );
      addTearDown(service.dispose);

      await service.fetchRecent();
      expect(seen.queryParameters['mkt'], 'zh-CN');
      expect(seen.queryParameters['format'], 'js');
      expect(seen.queryParameters['n'], '8');
    });

    test('响应体是 UTF-8：中文版权说明不能变乱码', () async {
      final service = BingWallpaperService(
        client: MockClient(
          (request) async => utf8Json(listBody()),
        ),
      );
      addTearDown(service.dispose);

      final items = await service.fetchRecent();
      expect(
        items.first.copyright,
        '阿德利企鹅，南极洲',
        reason: 'Bing 对 mkt=zh-CN 返回合法 UTF-8；解错码会直接变成乱码',
      );
    });

    test('非 2xx → 空列表，不抛', () async {
      final service = BingWallpaperService(
        client: MockClient((request) async => http.Response('nope', 503)),
      );
      addTearDown(service.dispose);
      expect(await service.fetchRecent(), isEmpty);
    });

    test('网络层抛异常 → 空列表，不抛', () async {
      final service = BingWallpaperService(
        client: MockClient((request) async => throw const SocketException('断网')),
      );
      addTearDown(service.dispose);
      expect(await service.fetchRecent(), isEmpty);
    });

    test('响应不是 JSON 对象 → 空列表，不抛', () async {
      final service = BingWallpaperService(
        client: MockClient((request) async => http.Response('<html>err</html>', 200)),
      );
      addTearDown(service.dispose);
      expect(await service.fetchRecent(), isEmpty);
    });

    test('images 全是坏条目 → 空列表（逐条丢弃后不剩东西）', () async {
      final service = BingWallpaperService(
        client: MockClient(
          (request) async => utf8Json(
            jsonEncode(<String, Object?>{
              'images': <Object?>[
                <String, Object?>{'urlbase': '/th?id=A'}, // 缺 startdate
                'garbage',
              ],
            }),
          ),
        ),
      );
      addTearDown(service.dispose);
      expect(await service.fetchRecent(), isEmpty);
    });
  });

  group('download', () {
    test('下载成功落到受管目录，文件名以 wallpaper 开头', () async {
      final service = BingWallpaperService(
        client: MockClient(
          (request) async => http.Response.bytes(
            <int>[0xFF, 0xD8, 0xFF, 0xE0],
            200,
            headers: <String, String>{'content-type': 'image/jpeg'},
          ),
        ),
      );
      addTearDown(service.dispose);

      const item = BingWallpaperItem(
        dateKey: '20261005',
        urlBase: '/th?id=OHR.AdelieTeacher_EN-US5343194378',
        title: '',
        copyright: '',
      );
      final result = await service.download(
        item,
        BingWallpaperResolution.standard,
      );
      expect(result.succeeded, isTrue);
      expect(result.downgraded, isFalse);
      expect(result.path, contains('home_page_wallpaper'));
      expect(
        result.path,
        endsWith('wallpaper_bing_20261005_standard.jpg'),
        reason: '前缀必须是 wallpaper，否则 deleteEvictedWallpaperFiles 的守卫放行它',
      );
      expect(File(result.path!).existsSync(), isTrue);
    });

    test('所选档位 404 → 退到本朝向下一档并如实标记 downgraded', () async {
      // 竖屏 1080×2400 走 resize 接口；某天 Bing 给不出那个尺寸时不能直接失败。
      final service = BingWallpaperService(
        client: MockClient((request) async {
          // ⚠️ 目标尺寸在**查询串**里（`?w=1080&h=2400&…`），不在 path 里 ——
          // 按 `url.path` 判会永远不匹配，于是这个「404」分支一次都进不去，
          // 测试会假绿。
          if (request.url.queryParameters['h'] == '2400') {
            return http.Response('not found', 404);
          }
          return http.Response.bytes(
            <int>[0xFF, 0xD8],
            200,
            headers: <String, String>{'content-type': 'image/jpeg'},
          );
        }),
      );
      addTearDown(service.dispose);

      const item = BingWallpaperItem(
        dateKey: '20261003',
        urlBase: '/th?id=OHR.ArtemisRocket_ZH-CN1768541365',
        title: '',
        copyright: '',
      );
      final result = await service.download(
        item,
        BingWallpaperResolution.tall,
      );
      expect(
        result.succeeded,
        isTrue,
        reason: '缺档也要给用户一张图，不能直接失败',
      );
      expect(result.downgraded, isTrue);
      expect(
        result.resolution,
        BingWallpaperResolution.standard,
        reason: '实际档位必须是退到的 portraitStandard（台账与文件名都按它算）',
      );
      expect(result.path, endsWith('_standard.jpg'));
    });

    test('断网（超时）→ 不退档重试：换尺寸也救不了，只会让用户白等两个超时', () async {
      // 退档解决的是「这个尺寸 Bing 没生成」，不是「网络坏了」。网络类失败重下同一张图
      // 必然同样失败，而每次尝试都要赔上一个 20 秒超时（2026-10-06 review 定）。
      var attempts = 0;
      final service = BingWallpaperService(
        client: MockClient((request) async {
          attempts++;
          throw http.ClientException('模拟断网');
        }),
      );
      addTearDown(service.dispose);

      const item = BingWallpaperItem(
        dateKey: '20261003',
        urlBase: '/th?id=OHR.ArtemisRocket_ZH-CN1768541365',
        title: '',
        copyright: '',
      );
      final result = await service.download(
        item,
        BingWallpaperResolution.tall,
      );
      expect(result.succeeded, isFalse);
      expect(result.failure, ManagedImageDownloadFailure.network);
      expect(attempts, 1, reason: '网络类失败只该试一次');
    });

    test('两档都拿不到 → 失败，并把状态码带出来给界面/日志', () async {
      final service = BingWallpaperService(
        client: MockClient((request) async => http.Response('nope', 404)),
      );
      addTearDown(service.dispose);
      const item = BingWallpaperItem(
        dateKey: '20261005',
        urlBase: '/th?id=A_EN-US1',
        title: '',
        copyright: '',
      );
      final result = await service.download(
        item,
        BingWallpaperResolution.tall,
      );
      expect(result.succeeded, isFalse);
      // ⭐ 这条是 2026-10-06「点大图下载失败无从查起」的正面解药：失败必须自带
      // 原因，否则界面只能弹一句没有信息量的话、日志里也只有一句 failed。
      expect(result.statusCode, 404);
      expect(result.failure, ManagedImageDownloadFailure.status);
      expect(result.describe(), contains('status=404'));
    });

    test('断网 → failure=network 且没有状态码（界面据此改用通用文案）', () async {
      final service = BingWallpaperService(
        client: MockClient(
          (request) async => throw const SocketException('断网'),
        ),
      );
      addTearDown(service.dispose);
      const item = BingWallpaperItem(
        dateKey: '20261005',
        urlBase: '/th?id=A_EN-US1',
        title: '',
        copyright: '',
      );
      final result = await service.download(
        item,
        BingWallpaperResolution.standard,
      );
      expect(result.succeeded, isFalse);
      expect(result.failure, ManagedImageDownloadFailure.network);
      expect(result.statusCode, isNull);
    });

    test('返回 HTML 而非图片 → failure=notImage（不能把 HTML 存成 .jpg）', () async {
      final service = BingWallpaperService(
        client: MockClient(
          (request) async => http.Response.bytes(
            utf8.encode('<html>err</html>'),
            200,
            headers: <String, String>{'content-type': 'text/html'},
          ),
        ),
      );
      addTearDown(service.dispose);
      const item = BingWallpaperItem(
        dateKey: '20261005',
        urlBase: '/th?id=A_EN-US1',
        title: '',
        copyright: '',
      );
      final result = await service.download(
        item,
        BingWallpaperResolution.standard,
      );
      expect(result.succeeded, isFalse);
      expect(result.failure, ManagedImageDownloadFailure.notImage);
      expect(result.contentType, 'text/html');
      expect(_wallpaperFiles(), isEmpty);
    });

    test('Content-Type 不是 image → 拒绝（防止把 HTML 错误页存成 .jpg）', () async {
      final service = BingWallpaperService(
        client: MockClient(
          (request) async => http.Response.bytes(
            utf8.encode('<html>404</html>'),
            200,
            headers: <String, String>{'content-type': 'text/html'},
          ),
        ),
      );
      addTearDown(service.dispose);

      const item = BingWallpaperItem(
        dateKey: '20261005',
        urlBase: '/th?id=A_EN-US1',
        title: '',
        copyright: '',
      );
      final result = await service.download(
        item,
        BingWallpaperResolution.standard,
      );
      expect(result.succeeded, isFalse);
      expect(result.failure, ManagedImageDownloadFailure.notImage);
      // 也不能留下半个 .jpg
      expect(_wallpaperFiles(), isEmpty);
    });

    test('下载失败不留 .part 残留', () async {
      final service = BingWallpaperService(
        client: MockClient((request) async => http.Response('', 404)),
      );
      addTearDown(service.dispose);
      const item = BingWallpaperItem(
        dateKey: '20261005',
        urlBase: '/th?id=A_EN-US1',
        title: '',
        copyright: '',
      );
      expect(
        (
          await service.download(item, BingWallpaperResolution.standard)
        ).succeeded,
        isFalse,
      );
      expect(
        _wallpaperFiles().where((file) => file.path.endsWith('.part')),
        isEmpty,
        reason: '写了一半的 .part 不能留在受管目录里被后续逻辑当成图',
      );
    });

    test('并发下同一张 → 两次都成功、最终文件字节完整、不留 .part', () async {
      // 冷启动的「每天自动换」与用户在图库里手动点同一张能撞在一起，两条路各下各的、
      // 谁都不知道对方在下载。临时名若固定，两个 writer 会往同一路径交错写、或在对方
      // rename 之后再去 rename 一个已不存在的文件，于是要么得到坏图、要么让其中一次
      // 白失败，而它随后会被当成合法壁纸交给首页。
      //
      // ⚠️ 本条是**兜底断言**，不是那条竞态的精确复现：真实交错依赖内核文件锁与
      // 调度顺序，`flutter test` 里很难稳定造出来（试过：不加门时两次写盘会被排成
      // 前后脚，共用临时名也能过）。所以这里钉的是「无论怎么交错，结果都必须自洽」
      // 这条不变量 —— 真出问题时它会给出线索（哪一次失败 / 字节混了），而不是保证
      // 每次都能复现那次竞态。
      final bodies = <List<int>>[
        List<int>.filled(4096, 0x11),
        List<int>.filled(4096, 0x22),
      ];
      // 用一道「门」让两次下载尽量贴近：第二个请求到达之前，第一个先不回包。不这么做的话
      // MockClient 立刻回包，两次写盘更容易被事件循环排成前后脚。
      final firstRequestArrived = Completer<void>();
      final secondRequestArrived = Completer<void>();
      var served = 0;
      final service = BingWallpaperService(
        client: MockClient((request) async {
          final index = served++;
          if (index == 0) {
            firstRequestArrived.complete();
            await secondRequestArrived.future;
          } else if (index == 1) {
            secondRequestArrived.complete();
          }
          return http.Response.bytes(
            bodies[index % bodies.length],
            200,
            headers: <String, String>{'content-type': 'image/jpeg'},
          );
        }),
      );
      addTearDown(() {
        // 门没被推开时别让测试挂在未完成的 Future 上。
        if (!firstRequestArrived.isCompleted) {
          firstRequestArrived.complete();
        }
        if (!secondRequestArrived.isCompleted) {
          secondRequestArrived.complete();
        }
      });
      expect(firstRequestArrived.future, completes);
      addTearDown(service.dispose);
      const item = BingWallpaperItem(
        dateKey: '20261005',
        urlBase: '/th?id=A_EN-US1',
        title: '',
        copyright: '',
      );

      final pending = <Future<BingWallpaperDownload>>[
        service.download(item, BingWallpaperResolution.standard),
        service.download(item, BingWallpaperResolution.standard),
      ];
      await firstRequestArrived.future;
      await secondRequestArrived.future;
      final results = await Future.wait(pending);
      for (final result in results) {
        expect(result.succeeded, isTrue, reason: '并发不该让任何一次失败');
      }

      final finalFile = File(results.first.path!);
      expect(finalFile.existsSync(), isTrue);
      final bytes = finalFile.readAsBytesSync();
      expect(
        bytes.length,
        4096,
        reason: '字节数不对 = 两个 writer 交错写过 = 文件已损坏',
      );
      // 字节必须**一致**（全是 0x11 或全是 0x22），不能首尾混着两种。
      expect(
        bytes.toSet().length,
        1,
        reason: '文件里混着两次写入的字节 —— 交错写坏了',
      );
      expect(
        _wallpaperFiles().where((file) => file.path.endsWith('.part')),
        isEmpty,
        reason: '两次尝试的临时名都要被 rename 掉或清掉，不能留残留',
      );
    });
  });

  group('maybeApplyDaily', () {
    test('开关关着 → 不发任何请求', () async {
      BingWallpaperService.testClientFactory = () => MockClient((request) async {
        listRequestCount++;
        return utf8Json(listBody());
      });
      try {
        expect(
          await BingWallpaperService.maybeApplyDaily(now: _pinnedNow),
          isNull,
        );
      } finally {
        BingWallpaperService.testClientFactory = null;
      }
      expect(
        listRequestCount,
        0,
        reason: '开关关着时连列表都不该拉（未开的用户不该有任何网络请求）',
      );
    });

    test('开着且今天没换过 → 下到本地并返回路径', () async {
      await BingWallpaperStore.instance.setAutoApplyEnabled(true);
      final path = await _runMaybeApplyDaily(
        listResponse: () => utf8Json(listBody()),
        imageResponse: () => http.Response.bytes(
          <int>[0xFF, 0xD8],
          200,
          headers: <String, String>{'content-type': 'image/jpeg'},
        ),
      );
      expect(path, isNotNull);
      expect(path, contains('wallpaper_bing_20261005_standard.jpg'));
      expect(BingWallpaperStore.instance.lastAutoAppliedDate, '20261005');
    });

    test('同一天再跑一次 → 直接返回 null，不重复下载', () async {
      await BingWallpaperStore.instance.setAutoApplyEnabled(true);
      var imageRequests = 0;
      await _runMaybeApplyDaily(
        listResponse: () => utf8Json(listBody()),
        imageResponse: () {
          imageRequests++;
          return http.Response.bytes(
            <int>[0xFF, 0xD8],
            200,
            headers: <String, String>{'content-type': 'image/jpeg'},
          );
        },
      );
      expect(imageRequests, 1);

      // 第二次：同一天
      expect(
        await BingWallpaperService.maybeApplyDaily(now: _pinnedNow),
        isNull,
      );
      expect(imageRequests, 1, reason: '判据在下载之前，不该重复下同一张');
    });

    test('拉不到清单 → null，且不记「今天已换过」（明天还能重试）', () async {
      await BingWallpaperStore.instance.setAutoApplyEnabled(true);
      final path = await _runMaybeApplyDaily(
        listResponse: () => http.Response('err', 503),
        imageResponse: () => http.Response('', 500),
      );
      expect(path, isNull);
      expect(BingWallpaperStore.instance.lastAutoAppliedDate, isNull);
    });

    test('图片下载失败 → null，也不记「今天已换过」', () async {
      // ⚠️ 记早了这一天就再也不会重试（要等用户手动进设置页才可能补上）。
      await BingWallpaperStore.instance.setAutoApplyEnabled(true);
      final path = await _runMaybeApplyDaily(
        listResponse: () => utf8Json(listBody()),
        imageResponse: () => http.Response('', 404),
      );
      expect(path, isNull);
      expect(
        BingWallpaperStore.instance.lastAutoAppliedDate,
        isNull,
        reason: '下载失败时记日期会让这一天永远不再尝试',
      );
    });

    test('清单首项不是今天 → 强制重拉；重拉后仍没有今天那张就不换', () async {
      // 跨零点场景：23:50 缓存的清单到 00:10 仍在 3 小时 TTL 内，首项已经是**昨天**。
      // 直接信「首项即今天」会把隔夜的图挂上去、还把昨天记成「今天已换过」，
      // 于是今天真正的壁纸当天再也上不来。
      await BingWallpaperStore.instance.setAutoApplyEnabled(true);
      var listRequests = 0;
      BingWallpaperService.testClientFactory = () => MockClient((request) async {
        if (request.url.path.contains('HPImageArchive')) {
          listRequests++;
          return utf8Json(listBody());
        }
        return http.Response.bytes(
          <int>[0xFF, 0xD8],
          200,
          headers: <String, String>{'content-type': 'image/jpeg'},
        );
      });
      String? path;
      try {
        // 「今天」是 10-06，接口只给得到 10-05 那张。
        path = await BingWallpaperService.maybeApplyDaily(
          now: DateTime(2026, 10, 6),
        );
      } finally {
        BingWallpaperService.testClientFactory = null;
      }

      expect(listRequests, 2, reason: '首项验不过必须强制重拉一次再验');
      expect(path, isNull, reason: '宁可今天不换，也不能挂一张隔夜的图');
      expect(
        BingWallpaperStore.instance.lastAutoAppliedDate,
        isNull,
        reason: '没换上就绝不记「今天已换过」',
      );
      expect(_wallpaperFiles(), isEmpty, reason: '判据就该拦在下载之前');
    });

    test('清单首项不是今天但重拉后有了 → 用今天那张', () async {
      await BingWallpaperStore.instance.setAutoApplyEnabled(true);
      // 先把缓存填成「昨天 23:50 拉到的那份」（saveCachedItems 会把 fetchedAt 记成
      // 现在，于是它落在 3 小时 TTL 内、会被直接命中 —— 这正是要复现的现场）。
      await _seedCache(listBody());

      var listRequests = 0;
      BingWallpaperService.testClientFactory = () => MockClient((request) async {
        if (request.url.path.contains('HPImageArchive')) {
          listRequests++;
          return utf8Json(listBody(startDate: '20261006'));
        }
        return http.Response.bytes(
          <int>[0xFF, 0xD8],
          200,
          headers: <String, String>{'content-type': 'image/jpeg'},
        );
      });
      String? path;
      try {
        path = await BingWallpaperService.maybeApplyDaily(
          now: DateTime(2026, 10, 6),
        );
      } finally {
        BingWallpaperService.testClientFactory = null;
      }

      expect(listRequests, 1, reason: '命中旧缓存不该发请求，强制重拉才发');
      expect(path, contains('wallpaper_bing_20261006_standard.jpg'));
      expect(BingWallpaperStore.instance.lastAutoAppliedDate, '20261006');
    });
  });

  group('loadItems 缓存', () {
    test('命中缓存不再请求', () async {
      await _runLoadItems(listResponse: () {
        listRequestCount++;
        return utf8Json(listBody());
      });
      expect(listRequestCount, 1);

      final cached = await _runLoadItems(listResponse: () {
        listRequestCount++;
        return utf8Json(listBody());
      });
      expect(cached, isNotEmpty);
      expect(listRequestCount, 1, reason: 'TTL 内不该重复请求');
    });

    test('forceRefresh 绕过缓存', () async {
      await _runLoadItems(listResponse: () {
        listRequestCount++;
        return utf8Json(listBody());
      });
      await _runLoadItems(
        listResponse: () {
          listRequestCount++;
          return utf8Json(listBody());
        },
        forceRefresh: true,
      );
      expect(listRequestCount, 2);
    });

    test('空清单不写缓存（否则一次失败会被缓存 3 小时）', () async {
      await _runMaybeApplyDaily(
        listResponse: () => http.Response('err', 503),
        imageResponse: () => http.Response('', 500),
      );
      expect(BingWallpaperStore.instance.cachedItems, isEmpty);
      expect(BingWallpaperStore.instance.cachedItemsFetchedAt, isNull);
    });
  });
}

/// 受管壁纸目录里现存的普通文件（目录本身可能还没被创建过，所以先判存在）。
List<File> _wallpaperFiles() {
  final dir = Directory(
    '${documentsDir.path}${Platform.pathSeparator}home_page_wallpaper',
  );
  if (!dir.existsSync()) {
    return const [];
  }
  return dir.listSync().whereType<File>().toList();
}

/// 用一个「按路径分流」的 MockClient 跑一次自动换，返回下载到的路径。
///
/// 靠 [BingWallpaperService.testClientFactory] 把 service 内部自建的 client 换成
/// MockClient —— 那两个入口刻意自建 service（自动换没有调用方持有 client 可传），
/// 所以只能这样注入。跑完必须清钩子，否则后续用例会串到这个 client 上。
///
/// [now] 默认钉在 `listBody()` 首项那个日期（2026-10-05）上：`maybeApplyDaily` 会验
/// 「清单首项真的是今天吗」（跨零点的旧缓存防护），不钉住的话这些用例会随测试运行
/// 时刻漂移，今天早上跑和明年跑结论完全不同。
Future<String?> _runMaybeApplyDaily({
  required http.Response Function() listResponse,
  required http.Response Function() imageResponse,
  DateTime? now,
}) async {
  BingWallpaperService.testClientFactory = () => MockClient((request) async {
    if (request.url.path.contains('HPImageArchive')) {
      return listResponse();
    }
    return imageResponse();
  });
  try {
    return await BingWallpaperService.maybeApplyDaily(
      now: now ?? _pinnedNow,
    );
  } finally {
    BingWallpaperService.testClientFactory = null;
  }
}

/// 「今天」在自动换那组用例里的固定取值，与 `listBody()` 的首项 `20261005` 对齐。
final DateTime _pinnedNow = DateTime(2026, 10, 5);

/// 同上，但用于 `loadItems`（需要自己控 HTTP 返回并统计请求次数）。
Future<List<BingWallpaperItem>> _runLoadItems({
  required http.Response Function() listResponse,
  bool forceRefresh = false,
}) async {
  BingWallpaperService.testClientFactory = () =>
      MockClient((request) async => listResponse());
  try {
    return await BingWallpaperService.loadItems(forceRefresh: forceRefresh);
  } finally {
    BingWallpaperService.testClientFactory = null;
  }
}

/// 纯本地写入缓存（不发请求），用来铺「跨零点前 23:50 拉到的那份清单」这种现场。
Future<void> _seedCache(String body) async {
  final decoded = jsonDecode(body);
  await BingWallpaperStore.instance.saveCachedItems(
    BingWallpaperItem.listFromJson(
      decoded is Map ? decoded['images'] : null,
    ),
  );
}

