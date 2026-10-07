import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/bing_wallpaper.dart';
import 'package:university_timetable/models/wallhaven_wallpaper.dart';
import 'package:university_timetable/models/wallpaper_daily_source.dart';
import 'package:university_timetable/services/bing_wallpaper_store.dart';
import 'package:university_timetable/services/wallhaven_wallpaper_service.dart';
import 'package:university_timetable/utils/home_page_background.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 钉住 Wallhaven 这条链路的三个要害：
///
/// ① **竖图过滤参数写错不报错**（实测 `ratios=0.5` 与 `ratios=9:16` 都静默返回横图），
///    所以可用值写死在枚举里并在这里钉住「发出的参数必须是像素尺寸写法」；
/// ② **anime 一律丢** —— 二次元插画当课程表背景，文字压在人物脸上；
/// ③ **原生竖图**是这一整条链路存在的理由，所以任何降级到「按屏幕缩放」的做法都要红。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WallhavenWallpaperItem 解析', () {
    test('正常条目：尺寸是竖的才算数', () {
      final item = WallhavenWallpaperItem.fromJson(<String, Object?>{
        'id': 'w53vkq',
        'dimension_x': 2250,
        'dimension_y': 4000,
        'path': 'https://w.wallhaven.cc/full/w5/wallhaven-w53vkq.jpg',
        'file_size': 6230016,
        'category': 'general',
        'thumbs': <String, Object?>{
          'large': 'https://th.wallhaven.cc/lg/w5/w53vkq.jpg',
        },
      });
      expect(item, isNotNull);
      expect(item!.id, 'w53vkq');
      expect(item.width, 2250);
      expect(item.height, 4000);
      expect(
        item.isPortrait,
        isTrue,
        reason: '原生竖图是这条链路存在的理由（放大 1.0）',
      );
      expect(item.sizeLabel, '5.9 MB');
      expect(item.galleryThumbnailUrl, contains('th.wallhaven.cc/lg'));
    });

    test('⚠️ 缺尺寸的条目直接丢 —— 尺寸是这条链路的全部意义', () {
      for (final raw in <Object?>[
        <String, Object?>{
          'id': 'a',
          'path': 'https://w.wallhaven.cc/full/a.jpg',
          'category': 'general',
        },
        <String, Object?>{
          'id': 'a',
          'path': 'https://w.wallhaven.cc/full/a.jpg',
          'dimension_x': 0,
          'dimension_y': 4000,
          'category': 'general',
        },
        <String, Object?>{
          'id': 'a',
          'path': 'https://w.wallhaven.cc/full/a.jpg',
          'dimension_x': '2250',
          'dimension_y': 4000,
          'category': 'general',
        },
      ]) {
        expect(
          WallhavenWallpaperItem.fromJson(raw),
          isNull,
          reason: '拿不到尺寸就判断不了是不是够大的竖图，不能放行',
        );
      }
    });

    test('anime 一律丢（人物脸上压课表文字）', () {
      expect(
        WallhavenWallpaperItem.fromJson(<String, Object?>{
          'id': 'a',
          'path': 'https://w.wallhaven.cc/full/a.jpg',
          'dimension_x': 1200,
          'dimension_y': 2133,
          'category': 'anime',
        }),
        isNull,
      );
      // 大写也丢
      expect(
        WallhavenWallpaperItem.fromJson(<String, Object?>{
          'id': 'a',
          'path': 'https://w.wallhaven.cc/full/a.jpg',
          'dimension_x': 1200,
          'dimension_y': 2133,
          'category': 'Anime',
        }),
        isNull,
      );
    });

    test('path 不是 http 开头 / id 空 → 丢', () {
      expect(
        WallhavenWallpaperItem.fromJson(<String, Object?>{
          'id': 'a',
          'path': '/relative.jpg',
          'dimension_x': 1200,
          'dimension_y': 2133,
          'category': 'general',
        }),
        isNull,
      );
      expect(
        WallhavenWallpaperItem.fromJson(<String, Object?>{
          'id': '  ',
          'path': 'https://w.wallhaven.cc/full/a.jpg',
          'dimension_x': 1200,
          'dimension_y': 2133,
          'category': 'general',
        }),
        isNull,
      );
      expect(WallhavenWallpaperItem.fromJson('not-a-map'), isNull);
    });

    test('listFromJson：脏条目逐条丢弃，不炸掉整份清单', () {
      final items = WallhavenWallpaperItem.listFromJson(<Object?>[
        <String, Object?>{
          'id': 'ok1',
          'path': 'https://w.wallhaven.cc/full/1.jpg',
          'dimension_x': 1200,
          'dimension_y': 2133,
          'category': 'general',
        },
        'bad',
        <String, Object?>{
          'id': 'ok2',
          'path': 'https://w.wallhaven.cc/full/2.jpg',
          'dimension_x': 1080,
          'dimension_y': 1920,
          'category': 'general',
        },
      ]);
      expect(items.map((e) => e.id), ['ok1', 'ok2']);
      expect(WallhavenWallpaperItem.listFromJson(null), isEmpty);
    });

    test('落盘文件名以 wallpaper 开头（删除守卫按前缀判归属）', () {
      const item = WallhavenWallpaperItem(
        id: 'w53vkq',
        width: 2250,
        height: 4000,
        fileUrl: 'https://w.wallhaven.cc/full/w5/x.jpg',
      );
      expect(item.fileName, startsWith('wallpaper'));
      expect(item.fileName, endsWith('.jpg'));
      expect(WallhavenWallpaperItem.fileNameFor('w53vkq'), item.fileName);
    });

    test('下载地址就是原图 —— 绝不向图源要 resize', () {
      const item = WallhavenWallpaperItem(
        id: 'a',
        width: 2250,
        height: 4000,
        fileUrl: 'https://w.wallhaven.cc/full/a.jpg',
      );
      expect(
        item.downloadUrl,
        item.fileUrl,
        reason: '竖图本来就大于屏幕，缩下来只会丢细节并让「原生竖图」作废',
      );
    });

    test('JSON 往返无损', () {
      const item = WallhavenWallpaperItem(
        id: 'w53vkq',
        width: 2250,
        height: 4000,
        fileUrl: 'https://w.wallhaven.cc/full/a.jpg',
        thumbnailUrl: 'https://th.wallhaven.cc/lg/a.jpg',
        fileSizeBytes: 123,
        category: 'general',
      );
      expect(WallhavenWallpaperItem.fromJson(item.toJson()), item);
    });
  });

  group('WallhavenQuery 参数', () {
    test('⭐ ratios 必须是「像素尺寸」写法（实测写成比例会静默给横图）', () {
      // 这条是踩过的坑：`ratios=0.5` 与 `ratios=9:16` 实测**都不报错，但返回横图**
      // （首条 6666×6666、次条 6666×3750）。只有 `1080x1920` 这种写法才真筛竖图。
      // 所以断言钉住**发出的字符**，不是钉住我们的意图。
      const query = WallhavenQuery(
        ratios: <String>['1080x1920', '1440x2560'],
        minimumSize: WallpaperTargetSize(1080, 1920),
      );
      final params = query.toQueryParameters();
      expect(params['ratios'], '1080x1920,1440x2560');
      for (final ratio in params['ratios']!.split(',')) {
        expect(
          RegExp(r'^\d+x\d+$').hasMatch(ratio),
          isTrue,
          reason: '「$ratio」不是像素尺寸写法 —— 接口会静默返回横图',
        );
      }
      expect(params['atleast'], '1080x1920');
      expect(params['purity'], '100', reason: '只要 SFW，别给用户推 NSFW');
      expect(params['categories'], '100');
      expect(params['sort'], 'toplist');
    });

    test('page_size 取 24（接口上限）', () {
      const query = WallhavenQuery(
        ratios: <String>['1080x1920'],
        minimumSize: WallpaperTargetSize(1080, 1920),
      );
      expect(query.toQueryParameters()['page_size'], '24');
    });

    test('服务里那三个比例值全部是像素写法', () {
      for (final ratio in WallhavenWallpaperService.kPortraitRatios) {
        expect(RegExp(r'^\d+x\d+$').hasMatch(ratio), isTrue, reason: ratio);
      }
    });
  });

  group('「今天该换哪一张」的确定性', () {
    test('⭐ 同一个日子永远算出同一个下标 —— 判据靠它成立', () {
      final now = DateTime(2026, 10, 7);
      expect(
        WallhavenWallpaperService.dailyIndex(now),
        WallhavenWallpaperService.dailyIndex(DateTime(2026, 10, 7, 23, 59)),
        reason: '时刻不同但同一天必须同答案，否则同一天会换两次',
      );
    });

    test('隔天一定不同 —— 否则「每天自动换」名不副实', () {
      final today = WallhavenWallpaperService.dailyIndex(DateTime(2026, 10, 7));
      final tomorrow = WallhavenWallpaperService.dailyIndex(
        DateTime(2026, 10, 8),
      );
      expect(today, isNot(tomorrow));
      // 月份边界也要跨过去（30→31 日）。
      expect(
        WallhavenWallpaperService.dailyIndex(DateTime(2026, 4, 30)),
        isNot(WallhavenWallpaperService.dailyIndex(DateTime(2026, 5))),
      );
      // 年份边界。`DateTime(2026)` 即 2026-01-01（月份默认 1）。
      expect(
        WallhavenWallpaperService.dailyIndex(DateTime(2025, 12, 31)),
        isNot(WallhavenWallpaperService.dailyIndex(DateTime(2026))),
      );
    });

    test('跨月的连续日子不会因为「同余」撞出同一个下标', () {
      // 取模到清单长度（24）之后要真的转得开：连续 24 天内不许出现重复。
      final seen = <int>{};
      var cursor = DateTime(2026);
      for (var i = 0; i < 24; i++) {
        seen.add(
          WallhavenWallpaperService.dailyIndex(cursor) % 24,
        );
        cursor = DateTime(cursor.year, cursor.month, cursor.day + 1);
      }
      expect(
        seen.length,
        24,
        reason: '基数取小了会让相邻几天取到清单同一格，那就不是「每天换」',
      );
    });
  });

  group('图源枚举', () {
    test('默认是 Bing（每天必换优先于更清晰）', () {
      expect(WallpaperDailySource.values.first, WallpaperDailySource.bing);
      expect(WallpaperDailySource.fromStorageKey(null), WallpaperDailySource.bing);
      expect(
        WallpaperDailySource.fromStorageKey('unknown'),
        WallpaperDailySource.bing,
        reason: '坏值不该把设置页炸掉',
      );
      for (final value in WallpaperDailySource.values) {
        expect(
          WallpaperDailySource.fromStorageKey(value.storageKey),
          value,
          reason: '枚举往返必须无损',
        );
      }
    });

    test('换源只对自动换生效（手动挑图时替用户换图是错的）', () {
      expect(
        WallpaperSourceFallback.onAutoApplyOnly.appliesToAutoApply,
        isTrue,
      );
      expect(WallpaperSourceFallback.never.appliesToAutoApply, isFalse);
      expect(
        WallpaperSourceFallback.fromStorageKey(null),
        WallpaperSourceFallback.onAutoApplyOnly,
      );
    });
  });

  group('台账：Wallhaven 那边共用同一张表', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      BingWallpaperStore.debugResetForTesting();
    });

    test('按 id 复用已下过的那张', () async {
      final store = BingWallpaperStore.instance;
      final dir = Directory.systemTemp.createTempSync('wallhaven_ledger');
      final file = File('${dir.path}${Platform.pathSeparator}wallpaper_wh_a.jpg')
        ..writeAsBytesSync(<int>[1]);
      addTearDown(() => dir.deleteSync(recursive: true));

      await store.recordWallhaven(
        id: 'a',
        sourceSize: const WallpaperTargetSize(2250, 4000),
        path: file.path,
      );
      expect(await store.findExistingWallhaven('a'), file.path);
    });

    test('⭐ Wallhaven 台账不得留下 autoApplied 标记', () async {
      // 它会污染 `lastAutoAppliedDate`（Bing 的按天判据）：那个 getter 只认
      // `autoApplied` 的条目，而它的返回值会被拿去和 Bing 的 `dateKey`（`20261007`）
      // 比 —— `wh:…` 永不相等，于是**切回 Bing 之后「今天已换过」永远判不成立**，
      // 表现为每天重复下载同一张。
      final store = BingWallpaperStore.instance;
      final dir = Directory.systemTemp.createTempSync('wallhaven_ledger');
      final file = File('${dir.path}${Platform.pathSeparator}wallpaper_wh_a.jpg')
        ..writeAsBytesSync(<int>[1]);
      addTearDown(() => dir.deleteSync(recursive: true));

      await store.recordWallhaven(
        id: 'a',
        sourceSize: const WallpaperTargetSize(2250, 4000),
        path: file.path,
      );
      expect(
        store.lastAutoAppliedDate,
        isNull,
        reason: 'Wallhaven 的记账绝不能让 Bing 的按天判据拿到一个 `wh:…` 的值',
      );
    });

    test('⭐ Wallhaven 的键不与 Bing 撞（同一天两源可共存）', () async {
      final store = BingWallpaperStore.instance;
      final dir = Directory.systemTemp.createTempSync('wallhaven_ledger');
      final bing = File('${dir.path}${Platform.pathSeparator}wallpaper_bing.jpg')
        ..writeAsBytesSync(<int>[1]);
      final wh = File('${dir.path}${Platform.pathSeparator}wallpaper_wh.jpg')
        ..writeAsBytesSync(<int>[2]);
      addTearDown(() => dir.deleteSync(recursive: true));

      await store.recordApplied(
        dateKey: '20261007',
        resolution: BingWallpaperResolution.standard,
        targetSize: const WallpaperTargetSize(1080, 1920),
        path: bing.path,
      );
      await store.recordWallhaven(
        id: '20261007',
        sourceSize: const WallpaperTargetSize(2250, 4000),
        path: wh.path,
      );
      // 两条都在（尺寸不同 → 键不同），互不顶替。
      expect(store.downloadedPaths, containsAll(<String>[bing.path, wh.path]));
    });

    test('⭐ 图源世代号：切源后「今天已换过」立刻失效', () async {
      final store = BingWallpaperStore.instance;
      expect(store.sourceEpoch, 0);
      expect(store.lastAutoAppliedSourceEpoch, isNull);

      await store.recordAutoAppliedEpoch(store.sourceEpoch);
      expect(store.lastAutoAppliedSourceEpoch, 0);

      // 重复设同一个值**不算**切换（否则每次打开设置页都会把判据清掉）。
      await store.setDailySource(WallpaperDailySource.bing);
      expect(store.sourceEpoch, 0, reason: '值没变就不该自增');

      await store.setDailySource(WallpaperDailySource.wallhaven);
      expect(store.sourceEpoch, 1);
      expect(
        store.lastAutoAppliedSourceEpoch,
        isNot(store.sourceEpoch),
        reason: '切了源，当天就还能再换一次（否则用户看到「我切了图源但没反应」）',
      );
    });

    test('⭐ 换源后重载仍能读回世代号与 id', () async {
      final store = BingWallpaperStore.instance;
      await store.setDailySource(WallpaperDailySource.wallhaven);
      await store.recordAutoAppliedItem('w53vkq');

      BingWallpaperStore.debugResetForTesting();
      final reloaded = BingWallpaperStore.instance;
      await reloaded.load();
      expect(reloaded.dailySource, WallpaperDailySource.wallhaven);
      expect(reloaded.sourceEpoch, 1);
      expect(reloaded.lastAutoAppliedItemId, 'w53vkq');
    });

    test('「今天该换的那张」按 id 判，而不是日期', () async {
      final store = BingWallpaperStore.instance;
      await store.recordAutoAppliedItem('w53vkq');
      expect(store.lastAutoAppliedItemId, 'w53vkq');
      // 换成 null 要真的把存档清掉（否则判据会永远卡住）。
      await store.recordAutoAppliedItem(null);
      expect(store.lastAutoAppliedItemId, isNull);
    });
  });
}