import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:university_timetable/services/wallhaven_wallpaper_service.dart';

/// 竖版高清图库页的**接线**护栏：超时档位、清单来路、失败文案。
///
/// ## 为什么扫源码而不是渲染 widget
///
/// 三条护栏盯的都是「**哪个常量 / 哪个入口 / 哪个 l10n 键被接上去**」，而 widget 测试
/// 里那三样都由测试自己搭出来 —— 无论接错还是接对，渲染出来的树都是绿的。本仓已有
/// 同款做法（`bing_wallpaper_switch_wiring_test.dart`、`dependency_guards_test.dart`）。
final String pageSource = File(
  'lib/screens/settings/wallhaven_wallpaper_gallery_page.dart',
).readAsStringSync();

final String serviceSource = File(
  'lib/services/wallhaven_wallpaper_service.dart',
).readAsStringSync();

/// 从 `name(` 起截到下一个**成员声明或文档注释**为止。
///
/// 文档注释也要当边界：`///` 行属于**下一个**成员，吞进来会让「不该出现某串」
/// 那类断言凭空通过。
String memberBody(String source, String name) {
  final start = source.indexOf(name);
  expect(start, greaterThanOrEqualTo(0), reason: '找不到 $name');
  final tail = source.substring(start);
  final next = RegExp(
    r'\n  (?:///|static |Future<|void |bool |int |String |List<|Duration )[^\n]*\n',
  ).firstMatch(tail.substring(1));
  return next == null ? tail : tail.substring(0, next.start + 1);
}

void main() {
  group('清单超时是一档 8 秒（曾拆成两档，已按实测合回）', () {
    test('预算是 8 秒', () {
      expect(
        WallhavenWallpaperService.listTimeout,
        const Duration(seconds: 8),
        reason: '与 BingWallpaperService 同档',
      );
    });

    test('⭐ 不许再拆成「前台更宽」的两档', () {
      // 拆成两档的理由是「前台是用户盯着等的界面，而这个源只是慢」。**实测否掉了
      // 这个理由**：2026-10-07 分段探测显示 DNS 返回 `103.97.3.19` 与
      // `2a03:2880:…face:b00c…`（Facebook 段），而权威答案是三个 Cloudflare IP
      // —— 域名在中国大陆被 **DNS 污染**，请求压根没发到图源服务器。
      //
      // 「慢」与「被拦」的处理是相反的：慢 → 多等划算；被拦 → 等多久都没用，
      // 让用户白等 25 秒比白等 8 秒更糟。所以合并回一档。
      //
      // 这条钉的是「别凭猜测又拆开」：要让某个源更宽，必须有实测的「它确实慢」，
      // 而判断慢/被拦只能靠 probeReachability 比对 DNS 答案与权威答案。
      expect(
        serviceSource,
        isNot(contains('foregroundListTimeout')),
        reason: '前台更宽的档只对「慢」成立，对「被 DNS 拦」是纯粹的浪费',
      );
      expect(
        serviceSource,
        isNot(contains('backgroundListTimeout')),
        reason: '两档已合并成单一的 listTimeout',
      );
    });

    test('两条路径都吃那一个默认值', () {
      final loadBody = memberBody(
        serviceSource,
        'static Future<List<WallhavenWallpaperItem>> loadPortrait(',
      );
      final applyBody = memberBody(
        serviceSource,
        'static Future<WallhavenAutoApplyResult> maybeApplyDaily(',
      );
      expect(
        loadBody,
        contains('service.fetchPortrait()'),
        reason: '图库页吃默认值',
      );
      expect(
        applyBody,
        contains('service.fetchPortrait()'),
        reason:
            '自动换也吃默认值（它挂在启动路径上，显式传参说明有人把宽预算'
            '漏进了启动流程）',
      );
    });
  });

  group('图库页必须走带缓存回落的那条入口', () {
    test('调的是 loadPortrait，不是裸 fetchPortrait', () {
      expect(
        pageSource,
        contains('WallhavenWallpaperService.loadPortrait('),
        reason:
            '裸调 fetchPortrait 就没有「拉不到给上次结果」这层 —— 于是这个源'
            '常态性慢（Cloudflare）在缓存过期后必然白屏一次',
      );
      expect(
        pageSource,
        isNot(contains('service.fetchPortrait(')),
        reason: '绕过 loadPortrait 就绕过了缓存回落',
      );
    });

    test('会把「这次显示的是旧数据」记下来并在页面上说明', () {
      expect(
        pageSource,
        contains('_showingCached'),
        reason: '不给用户说明「这是上次的结果」，他只会以为图库就这么几张',
      );
      expect(
        pageSource,
        contains('l10n.wallpaperGalleryShowingCached'),
        reason: '提示条得真的渲染出来，光有状态没人看',
      );
    });
  });

  group('失败文案不许说 Bing', () {
    test('用的是 Wallhaven 自己那一句', () {
      expect(
        pageSource,
        contains('l10n.wallhavenGalleryFailed'),
        reason: '「竖版高清图库」页不该让用户看到 Bing',
      );
    });

    test('没有残留 bingWallpaperGalleryFailed', () {
      // 钉的是 `l10n.` 引用而不是裸字符串：文件里那句⚠️注释里就写了旧键名，
      // 按裸字符串匹配会把自己刚写的注释判成违规。
      expect(
        pageSource,
        isNot(contains('l10n.bingWallpaperGalleryFailed')),
        reason:
            '这句在竖版图库页显示成「没能取到 Bing 每日壁纸」，用户分不清是'
            '选错图源还是 App 坏了',
      );
    });
  });
}
