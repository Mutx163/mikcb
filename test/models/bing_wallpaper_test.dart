import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/bing_wallpaper.dart';

/// 钉住三件事（每一条都对应一个真实踩过的坑）：
///
/// ① 尺寸档位必须与 Bing **实际预生成**的那组对齐 —— 任意尺寸是 404，所以不能
///    「按用户输入拼尺寸」。`fromStorageKey` 对未知值回退默认档，不能抛。
/// ② 缩略图 URL 的 `id` **必须带 `_UHD.jpg`**：拿裸 `urlbase` 当 `id` 实测 404。
///    这是唯一一处「看起来能拼、实际拼不出来」的写法，最容易被后人「顺手简化」掉。
/// ③ 落盘文件名必须以 `wallpaper` 开头：`deleteEvictedWallpaperFiles` 按这个前缀
///    判定「这张图归我管」，改名成别的开头会导致它被挤出历史后**删不掉**。
void main() {
  group('BingWallpaperResolution', () {
    test('三档全是竖屏，且默认是 1080×1920（用户 2026-10-06 口径）', () {
      expect(
        BingWallpaperResolution.values.map((v) => v.pixelHeight),
        everyElement(greaterThan(0)),
      );
      // 每一档都必须**高 > 宽**（竖屏）。横屏档在这个 App 里没用，且曾因两档共用
      // 「高清」名字被用户指出「为啥有两个高清档位」。
      for (final value in BingWallpaperResolution.values) {
        expect(
          value.pixelHeight,
          greaterThan(value.pixelWidth),
          reason: '${value.storageKey} 不是竖屏 —— 横图铺竖屏会被裁掉七成横向',
        );
      }
      expect(
        BingWallpaperResolution.fromStorageKey(null),
        BingWallpaperResolution.standard,
      );
      expect(
        BingWallpaperResolution.standard.pixelWidth,
        1080,
        reason: '默认档是 1080×1920',
      );
      expect(BingWallpaperResolution.standard.pixelHeight, 1920);
    });

    test('预生成档走尺寸后缀，resize 档 sizeSuffix 为 null', () {
      expect(BingWallpaperResolution.standard.sizeSuffix, '_1080x1920.jpg');
      // Bing 不预生成这两个（实测 `_1440x2560` / `_1080x2400` 是 404），要现裁。
      expect(BingWallpaperResolution.tall.sizeSuffix, isNull);
      expect(BingWallpaperResolution.high.sizeSuffix, isNull);
    });

    test('体积标签都是 KB 级（横屏 4K 那档已随横屏一起删掉）', () {
      expect(BingWallpaperResolution.standard.approximateSizeLabel, '322 KB');
      expect(BingWallpaperResolution.tall.approximateSizeLabel, '492 KB');
      expect(BingWallpaperResolution.high.approximateSizeLabel, '764 KB');
      for (final value in BingWallpaperResolution.values) {
        expect(
          value.approximateSizeLabel,
          endsWith('KB'),
          reason: '三档都在 1MB 以内，不该出现 MB 写法',
        );
      }
    });

    test('⭐ 顶档必须够高，否则 App 会在 Bing 之后再放大一次（用户报「最高清还是糊」）', () {
      // Bing 原图是横屏 3840×2160（实测）。顶档只到 2560 时，1440×3200 的机器上
      // Bing 先放大 1.19×、App 再为铺满 3200 放大 1.25× —— 两次放大叠在一起。
      // 顶档给到 3200 后 App 不再参与放大。
      expect(
        BingWallpaperResolution.high.pixelHeight,
        greaterThanOrEqualTo(3200),
        reason: '顶档要覆盖当前主流高分屏的高度（1440×3200），否则 App 会二次放大',
      );
      // 每一档都该「高 > 宽」（竖屏）
      for (final value in BingWallpaperResolution.values) {
        expect(value.pixelHeight, greaterThan(value.pixelWidth));
      }
    });

    test('storageKey 往返无损', () {
      for (final value in BingWallpaperResolution.values) {
        expect(
          BingWallpaperResolution.fromStorageKey(value.storageKey),
          value,
          reason: '枚举往返必须无损',
        );
      }
    });

    test('退档按枚举顺序退到紧邻的下一档', () {
      expect(
        BingWallpaperResolution.standard.fallbackResolution,
        isNull,
        reason: '最小档没有退路',
      );
      expect(
        BingWallpaperResolution.tall.fallbackResolution,
        BingWallpaperResolution.standard,
      );
      expect(
        BingWallpaperResolution.high.fallbackResolution,
        BingWallpaperResolution.tall,
      );
    });

    test('三档的名字互不相同（用户 2026-10-06：为啥有两个高清档位）', () {
      // 曾经的根因不是文案而是多了一档没用的横屏：横屏两档都叫「高清」。
      // 现在只有三档竖屏，靠这条断言钉住「胶囊文案不会退化得重名」。
      final names = BingWallpaperResolution.values
          .map((value) => value.storageKey)
          .toList();
      expect(names.toSet().length, names.length);
      expect(names, ['standard', 'tall', 'high']);
    });
  });

  group('BingWallpaperItem URL 拼装', () {
    const item = BingWallpaperItem(
      dateKey: '20261005',
      urlBase: '/th?id=OHR.AdelieTeacher_EN-US5343194378',
      title: 'Taking the plunge, one lesson at a time',
      copyright: '阿德利企鹅，南极洲',
    );

    test('预生成档：绝对化基址 + 尺寸后缀', () {
      expect(
        item.fullUrl(BingWallpaperResolution.standard),
        'https://www.bing.com/th?id=OHR.AdelieTeacher_EN-US5343194378'
        '_1080x1920.jpg',
      );
      expect(
        item.fullUrl(BingWallpaperResolution.high),
        contains('_UHD.jpg'),
      );
    });

    test('resize 档走 w/h 接口，且必须带 c=4（否则 Bing 补白边不裁）', () {
      // ⚠️ 2026-10-06 实测：同一张图 `?w=1080&h=2400` 不带 c 时 Bing 把整张缩进去、
      // 上下留两条大白边；当壁纸极其难看。带 c=4 才是填满裁切（且裁的是有内容的
      // 部分 —— 丹霞那张整条公路与山脊都保住了）。
      final url = item.fullUrl(BingWallpaperResolution.tall);
      expect(url, contains('w=1080'));
      expect(url, contains('h=2400'));
      expect(url, contains('c=4'), reason: '缺 c=4 会得到白边图，不是裁切图');
      expect(url, contains('id=OHR.AdelieTeacher_EN-US5343194378_UHD.jpg'));
      expect(url, isNot(contains('id=/th')));

      final high = item.fullUrl(BingWallpaperResolution.high);
      expect(high, contains('w=1440'));
      expect(high, contains('h=3200'));
      expect(high, contains('c=4'));
    });

    test('缩略图默认是竖屏比例（与最终拿到的那张同朝向）', () {
      // 图库卡片也是竖的；缩略图若取横比例，用户点进去才发现「预览横、成品竖」。
      final thumb = item.thumbnailUrl();
      expect(thumb, contains('w=480'));
      expect(thumb, contains('h=854'));
      expect(thumb, contains('c=4'));
      expect(
        thumb,
        contains('id=OHR.AdelieTeacher_EN-US5343194378_UHD.jpg'),
        reason: 'id 必须是纯图片 id + _UHD.jpg；带 /th?id= 实测 404（全屏叉叉）',
      );
      expect(
        thumb,
        isNot(contains('id=/th')),
        reason: 'urlBase 里的 /th?id= 前缀不能进查询串，否则整个 id 参数被毁',
      );
      expect(thumb, isNot(contains('?id=?id=')));
    });

    test('imageId 剥掉 /th?id= 前缀；绝对基址由它重拼', () {
      expect(item.imageId, 'OHR.AdelieTeacher_EN-US5343194378');
      expect(
        item.absoluteUrlBase,
        'https://www.bing.com/th?id=OHR.AdelieTeacher_EN-US5343194378',
      );
    });

    test('绝对地址的基址不重复拼 host', () {
      const absolute = BingWallpaperItem(
        dateKey: '20261005',
        urlBase: 'https://www.bing.com/th?id=OHR.X_EN-US1',
        title: '',
        copyright: '',
      );
      expect(
        absolute.fullUrl(BingWallpaperResolution.standard),
        'https://www.bing.com/th?id=OHR.X_EN-US1_1080x1920.jpg',
      );
      // 已是绝对地址的 urlBase 也要能剥出纯 id（否则缩略图同样会拼出 /th?id=）。
      expect(absolute.imageId, 'OHR.X_EN-US1');
      expect(
        absolute.thumbnailUrl(),
        contains('id=OHR.X_EN-US1_UHD.jpg'),
      );
    });

    test('落盘文件名以 wallpaper 开头，否则既有的删除守卫会放行它', () {
      for (final resolution in BingWallpaperResolution.values) {
        final name = item.fileName(resolution);
        expect(
          name,
          startsWith('wallpaper'),
          reason: 'deleteEvictedWallpaperFiles 按 kHomePageWallpaperFilePrefix '
              '（wallpaper）判定归属，前缀不符会变成永不回收的孤儿文件',
        );
        expect(name, endsWith('.jpg'));
      }
      expect(
        item.fileName(BingWallpaperResolution.standard),
        'wallpaper_bing_20261005_standard.jpg',
      );
    });

    test('同一天同一档位落在同一个文件名上（重复下载直接覆盖）', () {
      // 这是台账之外的一道保险：文件名由 dateKey+档位决定，不是时间戳。
      expect(
        item.fileName(BingWallpaperResolution.high),
        item.fileName(BingWallpaperResolution.high),
      );
      expect(
        item.fileName(BingWallpaperResolution.standard),
        isNot(item.fileName(BingWallpaperResolution.high)),
      );
    });
  });

  group('BingWallpaperItem JSON', () {
    test('往返无损', () {
      const item = BingWallpaperItem(
        dateKey: '20261005',
        urlBase: '/th?id=OHR.X_EN-US1',
        title: '标题',
        copyright: '版权说明',
      );
      final restored = BingWallpaperItem.fromJson(item.toJson());
      expect(restored, item);
    });

    test('缺 urlbase / startdate / 类型不对的条目逐条丢弃', () {
      final items = BingWallpaperItem.listFromJson(<Object?>[
        <String, Object?>{'urlbase': '/th?id=A', 'startdate': '20261005'},
        <String, Object?>{'startdate': '20261005'},
        <String, Object?>{'urlbase': '/th?id=B'},
        // 字符串数字：字段要求 String，传 int 必须当坏值丢掉
        <String, Object?>{'urlbase': 42, 'startdate': '20261005'},
        // 空串 = 无意义条目
        <String, Object?>{
          'urlbase': '   ',
          'startdate': '20261005',
        },
        'not-a-map',
        <String, Object?>{'urlbase': '/th?id=C', 'startdate': '20261004'},
      ]);
      expect(
        items.map((item) => item.dateKey),
        ['20261005', '20261004'],
        reason: '一条坏值不得炸掉整份清单（Bing 改字段时要能部分可用）',
      );
    });

    test('title / copyright 缺失或类型不对时留空串，条目本身仍有效', () {
      final item = BingWallpaperItem.fromJson(<String, Object?>{
        'urlbase': '/th?id=A',
        'startdate': '20261005',
        'title': 123,
      });
      expect(item, isNotNull);
      expect(item!.title, '');
      expect(item.copyright, '');
    });

    test('非 List 输入返回空列表', () {
      expect(BingWallpaperItem.listFromJson(null), isEmpty);
      expect(BingWallpaperItem.listFromJson(<String, Object?>{}), isEmpty);
    });

    test('解析 Bing 真实响应的形状（format=js 是标准 JSON）', () {
      // 截一段实测响应：keys 都是双引号，urlbase 不带尺寸后缀。
      const payload = '''
{"images":[{"startdate":"20261005","fullstartdate":"202610050700",
"enddate":"20261006","url":"/th?id=OHR.AdelieTeacher_EN-US5343194378_1920x1080.jpg&rf=LaDigue_1920x1080.jpg&pid=hp",
"urlbase":"/th?id=OHR.AdelieTeacher_EN-US5343194378",
"copyright":"阿德利企鹅，南极洲 (? Otto Plantema/Minden Pictures)",
"copyrightlink":"https://www.bing.com/search?q=x","title":"Taking the plunge"}]}''';
      final decoded = jsonDecode(payload) as Map<String, Object?>;
      final items = BingWallpaperItem.listFromJson(decoded['images']);
      expect(items, hasLength(1));
      expect(items.single.dateKey, '20261005');
      expect(items.single.urlBase, '/th?id=OHR.AdelieTeacher_EN-US5343194378');
      expect(items.single.title, 'Taking the plunge');
    });
  });
}