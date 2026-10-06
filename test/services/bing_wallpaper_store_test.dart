import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/bing_wallpaper.dart';
import 'package:university_timetable/services/bing_wallpaper_store.dart';

/// 钉住台账的三个职责：**复用**（不重复下载）、**封顶清理**（不攒垃圾）、
/// **按天判据**（同一天不重复换）。
///
/// 其中「封顶」那条是最容易在评审时被当成「过度设计」砍掉的，而它的后果是
/// 每天自动换一年攒 365 个文件、约 119 MB 且无人回收（自动换不进「最近使用」，
/// 那条 10 条上限的清理路径管不到它）。所以在这里钉死。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    BingWallpaperStore.debugResetForTesting();
  });

  group('画质档位', () {
    test('默认是 standard；读档位后往返一致', () async {
      final store = BingWallpaperStore.instance;
      expect(store.resolution, BingWallpaperResolution.standard);

      await store.setResolution(BingWallpaperResolution.high);
      // 新单例（模拟重启）要能读回来
      BingWallpaperStore.debugResetForTesting();
      final reloaded = BingWallpaperStore.instance;
      await reloaded.load();
      expect(reloaded.resolution, BingWallpaperResolution.high);
    });

    test('⚠️ 不调 load() → 存档读不回来（这正是生产里漏掉的那一步）', () async {
      // 2026-10-06 review 实测的 P0：`BingWallpaperStore.load()` 全仓没有任何一处调用，
      // 而 `_prefs` 只在 load() 里赋值。于是冷启动后档位恒为默认 —— 用户选的「高清」
      // 每次重启都被吃掉，而 `autoApplyEnabled` 恒为 false，「每天自动更换」等于没开。
      //
      // 本条钉住 load() 的**必要性**：它一改成本构造器里同步读、或改成惰性读，这条就红。
      await BingWallpaperStore.instance.setResolution(
        BingWallpaperResolution.high,
      );
      BingWallpaperStore.debugResetForTesting();

      final notLoaded = BingWallpaperStore.instance;
      expect(
        notLoaded.resolution,
        BingWallpaperResolution.standard,
        reason: '这条断言的是「漏调 load() 会怎样」，不是期望行为；'
            '若将来改成构造器/惰性加载，请连同 main.dart 的启动调用一起改掉本条',
      );

      // 而 load() 一调就回来 —— 这才是生产必须走的那条路。
      await notLoaded.load();
      expect(notLoaded.resolution, BingWallpaperResolution.high);
    });

    test('存档里是陌生档位字符串时回退默认，不抛错', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        BingWallpaperStore.resolutionKey: '从没有过的档位',
      });
      BingWallpaperStore.debugResetForTesting();
      final store = BingWallpaperStore.instance;
      await store.load();
      expect(store.resolution, BingWallpaperResolution.standard);
    });
  });

  group('自动换开关', () {
    test('默认关 —— 新功能不该在用户没选择时就联网换壁纸', () async {
      expect(BingWallpaperStore.instance.autoApplyEnabled, isFalse);
    });

    test('写进去之后读回来是开', () async {
      final store = BingWallpaperStore.instance;
      await store.setAutoApplyEnabled(true);
      BingWallpaperStore.debugResetForTesting();
      final reloaded = BingWallpaperStore.instance;
      await reloaded.load();
      expect(reloaded.autoApplyEnabled, isTrue);
    });
  });

  group('按天判据 lastAutoAppliedDate', () {
    test('没有自动换记录时为 null', () async {
      expect(BingWallpaperStore.instance.lastAutoAppliedDate, isNull);
    });

    test('自动换记的那条算数，手动挑的不算数', () async {
      // 手动挑的也记账（为封顶清理），但若它顶掉了「今天已换过」的判据，
      // 自动换就会以为今天已完成而跳过 —— 用户开了自动换却看不到换。
      final store = BingWallpaperStore.instance;
      await store.recordApplied(
        dateKey: '20261005',
        resolution: BingWallpaperResolution.standard,
        path: '/tmp/wallpaper_bing_20261005_standard.jpg',
        autoApplied: false,
      );
      expect(
        store.lastAutoAppliedDate,
        isNull,
        reason: '手动挑的那张不算「自动换已完成」',
      );

      await store.recordApplied(
        dateKey: '20261004',
        resolution: BingWallpaperResolution.standard,
        path: '/tmp/wallpaper_bing_20261004_standard.jpg',
      );
      expect(store.lastAutoAppliedDate, '20261004');
    });

    test('撤回自动换的认领 → 判据放开，但台账与文件都留着可复用', () async {
      // 场景：自动换下好了图、也记了「今天已换过」，用户却在「调整位置」页点了退出。
      // 若不撤回，当天剩下的启动/回前台全被跳过 ——「开了自动换却什么都没发生」。
      final store = BingWallpaperStore.instance;
      await store.recordApplied(
        dateKey: '20261005',
        resolution: BingWallpaperResolution.high,
        path: '/tmp/wallpaper_bing_20261005_high.jpg',
      );
      expect(store.lastAutoAppliedDate, '20261005');

      await store.releaseAutoApplyClaim('20261005');
      expect(
        store.lastAutoAppliedDate,
        isNull,
        reason: '壁纸没真的换上，就不该判成「今天已换过」',
      );
      expect(
        store.downloadedPaths,
        contains('/tmp/wallpaper_bing_20261005_high.jpg'),
        reason: '文件已经下好了，必须留在台账里：既能被 findExisting 复用，'
            '也在封顶清理的白名单上（不会被当垃圾删掉）',
      );

      // 撤回之后还能再认领一次（当天稍后重试）。
      await store.recordApplied(
        dateKey: '20261005',
        resolution: BingWallpaperResolution.high,
        path: '/tmp/wallpaper_bing_20261005_high.jpg',
      );
      expect(store.lastAutoAppliedDate, '20261005');
    });

    test('撤回不存在的认领 → 幂等，不抛错也不写盘', () async {
      final store = BingWallpaperStore.instance;
      await store.releaseAutoApplyClaim('20261005');
      await store.releaseAutoApplyClaim('20261005');
      expect(store.lastAutoAppliedDate, isNull);
      expect(store.downloadedPaths, isEmpty);
    });

    test('撤回只影响那一天，别天的自动换记录照旧算数', () async {
      final store = BingWallpaperStore.instance;
      await store.recordApplied(
        dateKey: '20261005',
        resolution: BingWallpaperResolution.standard,
        path: '/tmp/wallpaper_bing_20261005_standard.jpg',
      );
      await store.recordApplied(
        dateKey: '20261004',
        resolution: BingWallpaperResolution.standard,
        path: '/tmp/wallpaper_bing_20261004_standard.jpg',
      );
      await store.releaseAutoApplyClaim('20261005');
      expect(
        store.lastAutoAppliedDate,
        '20261004',
        reason: '撤回 10-05 不该把 10-04 的记录也抹掉',
      );
    });

    test('同一天重复记账不产生第二条，lastAutoAppliedDate 仍是那天', () async {
      final store = BingWallpaperStore.instance;
      for (var i = 0; i < 3; i++) {
        await store.recordApplied(
          dateKey: '20261005',
          resolution: BingWallpaperResolution.standard,
          path: '/tmp/wallpaper_bing_20261005_standard.jpg',
        );
      }
      expect(store.lastAutoAppliedDate, '20261005');

      BingWallpaperStore.debugResetForTesting();
      final reloaded = BingWallpaperStore.instance;
      await reloaded.load();
      expect(reloaded.lastAutoAppliedDate, '20261005');
    });
  });

  group('复用 findExisting', () {
    test('同一天同一档位、文件还在 → 命中，不重复下载', () async {
      final dir = await Directory.systemTemp.createTemp('bing-wp-test');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/wallpaper_bing_20261005_standard.jpg')
        ..writeAsStringSync('x');

      final store = BingWallpaperStore.instance;
      await store.recordApplied(
        dateKey: '20261005',
        resolution: BingWallpaperResolution.standard,
        path: file.path,
      );

      expect(
        await store.findExisting(
          '20261005',
          BingWallpaperResolution.standard,
        ),
        file.path,
      );
    });

    test('文件已被历史淘汰删掉 → 不命中（否则会拿到一条死路径）', () async {
      final dir = await Directory.systemTemp.createTemp('bing-wp-test');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/wallpaper_bing_20261005_standard.jpg')
        ..writeAsStringSync('x');
      final store = BingWallpaperStore.instance;
      await store.recordApplied(
        dateKey: '20261005',
        resolution: BingWallpaperResolution.standard,
        path: file.path,
      );
      await file.delete();

      expect(
        await store.findExisting(
          '20261005',
          BingWallpaperResolution.standard,
        ),
        isNull,
      );
    });

    test('档位不同算另一张，各算各的', () async {
      final dir = await Directory.systemTemp.createTemp('bing-wp-test');
      addTearDown(() => dir.delete(recursive: true));
      final standard = File('${dir.path}/wallpaper_bing_20261005_standard.jpg')
        ..writeAsStringSync('x');
      final store = BingWallpaperStore.instance;
      await store.recordApplied(
        dateKey: '20261005',
        resolution: BingWallpaperResolution.standard,
        path: standard.path,
      );

      expect(
        await store.findExisting('20261005', BingWallpaperResolution.standard),
        standard.path,
      );
      expect(
        await store.findExisting('20261005', BingWallpaperResolution.high),
        isNull,
        reason: '换档位就是换一张图，不能拿旧的顶替',
      );
    });
  });

  group('封顶清理', () {
    test('超过上限时把溢出路径交回调用方去真删', () async {
      final store = BingWallpaperStore.instance;
      final evicted = <String>[];
      const total = BingWallpaperStore.kMaxDownloadedEntries + 3;
      for (var i = 1; i <= total; i++) {
        final key = '202610${i.toString().padLeft(2, '0')}';
        evicted.addAll(
          await store.recordApplied(
            dateKey: key,
            resolution: BingWallpaperResolution.standard,
            path: '/tmp/wallpaper_bing_${key}_standard.jpg',
          ),
        );
      }
      expect(evicted, hasLength(3), reason: '超出的那几条必须交回去删，否则就是孤儿文件');
    });

    test('同一张重复记账不占额外名额', () async {
      final store = BingWallpaperStore.instance;
      for (var i = 0; i < 6; i++) {
        expect(
          await store.recordApplied(
            dateKey: '20261005',
            resolution: BingWallpaperResolution.standard,
            path: '/tmp/wallpaper_bing_20261005_standard.jpg',
          ),
          isEmpty,
        );
      }
    });
  });

  group('坏数据', () {
    test('台账整串是坏 JSON → 当没有台账，不抛错', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'bing_wallpaper_v1': '{不是 json',
      });
      BingWallpaperStore.debugResetForTesting();
      final store = BingWallpaperStore.instance;
      await store.load();
      expect(store.lastAutoAppliedDate, isNull);
    });

    test('台账里混着坏条目时逐条丢弃，剩下能读出来', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'bing_wallpaper_v1':
            '[{"dateKey":123,"path":"/a"},'
            '{"dateKey":"20261005","path":"/b","resolution":"standard","autoApplied":true},'
            '"garbage"]',
      });
      BingWallpaperStore.debugResetForTesting();
      final store = BingWallpaperStore.instance;
      await store.load();
      expect(store.lastAutoAppliedDate, '20261005');
    });

    test('台账里档位是陌生字符串时按默认档读，不把已下的图当成没下过', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'bing_wallpaper_v1':
            '[{"dateKey":"20261005","path":"/x","resolution":"future_tier"}]',
      });
      BingWallpaperStore.debugResetForTesting();
      final store = BingWallpaperStore.instance;
      await store.load();
      expect(
        await store.findExisting(
          '20261005',
          BingWallpaperResolution.standard,
        ),
        isNull, // 文件 /x 不存在
      );
      expect(store.lastAutoAppliedDate, '20261005');
    });
  });

  group('缓存容量（用户 2026-10-06：看过的图要能直接再打开）', () {
    test('上限至少盖住图库一次展示的 8 天，否则往回翻必然重新下载', () {
      expect(
        BingWallpaperStore.kMaxDownloadedEntries,
        greaterThanOrEqualTo(8),
        reason: '图库一次展示 8 天；缓存比它小的话，用户从第 9 张往回点就重下',
      );
    });

    test('逐张记录 8 天（= 图库可见范围）时一条都不该被淘汰', () async {
      // 这条是「看过的图重新打开不重新下载」的直接钉子：早先上限 4，用户从第 5 张
      // 往回翻必被淘汰 → 重新下载一遍。
      final store = BingWallpaperStore.instance;
      final evicted = <String>[];
      for (var day = 1; day <= 8; day++) {
        final key = '2026100$day';
        evicted.addAll(
          await store.recordApplied(
            dateKey: key,
            resolution: BingWallpaperResolution.standard,
            path: '/tmp/wallpaper_bing_${key}_standard.jpg',
          ),
        );
      }
      expect(
        evicted,
        isEmpty,
        reason: '整个图库范围内的图都该留在缓存里',
      );
      expect(store.downloadedPaths, hasLength(8));
    });

    test('超过上限才淘汰，且淘汰最旧的', () async {
      final store = BingWallpaperStore.instance;
      final evicted = <String>[];
      const total = BingWallpaperStore.kMaxDownloadedEntries + 3;
      for (var i = 1; i <= total; i++) {
        final key = '2026${i.toString().padLeft(4, '0')}';
        evicted.addAll(
          await store.recordApplied(
            dateKey: key,
            resolution: BingWallpaperResolution.standard,
            path: '/tmp/$key.jpg',
          ),
        );
      }
      expect(evicted, hasLength(3), reason: '只该淘汰超出的那几条');
      expect(
        store.downloadedPaths,
        hasLength(BingWallpaperStore.kMaxDownloadedEntries),
      );
      expect(
        evicted.first,
        '/tmp/20260001.jpg',
        reason: '淘汰最旧的（先记进去的那几条）',
      );
    });

    test('downloadedPaths 就是「别当垃圾删掉」的清单（最新在前）', () async {
      final store = BingWallpaperStore.instance;
      for (final key in const <String>['20261001', '20261002', '20261003']) {
        await store.recordApplied(
          dateKey: key,
          resolution: BingWallpaperResolution.standard,
          path: '/tmp/$key.jpg',
        );
      }
      expect(
        store.downloadedPaths,
        <String>['/tmp/20261003.jpg', '/tmp/20261002.jpg', '/tmp/20261001.jpg'],
      );
    });
  });
}