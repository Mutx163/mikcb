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
  group('前台 / 后台超时是两个档，不能塌回一个', () {
    test('前台预算明显大于后台预算', () {
      expect(
        WallhavenWallpaperService.foregroundListTimeout,
        greaterThan(WallhavenWallpaperService.backgroundListTimeout),
        reason:
            'Wallhaven 挂在 Cloudflare 后面，大陆是「降级」不是「不通」；'
            '图库页是用户盯着等的界面，预算必须比后台自动换宽',
      );
    });

    test('后台预算仍是 8 秒（它挂在启动路径上，不能拖慢启动）', () {
      expect(
        WallhavenWallpaperService.backgroundListTimeout,
        const Duration(seconds: 8),
        reason: '每天自动换走后台路径，宁可失败也不该让 App 启动变慢',
      );
    });

    test('展示路径用前台档：loadPortrait 显式传它', () {
      // ⚠️ 这里钉的是 **loadPortrait**（而不是图库页）：图库页不再直接调
      // `fetchPortrait`，它调的是带缓存回落的 `loadPortrait`。于是「谁传前台档」
      // 这件事落到了 service 里 —— 钉错地方会让人以为页面漏传而白改页面。
      expect(
        memberBody(
          serviceSource,
          'static Future<List<WallhavenWallpaperItem>> loadPortrait(',
        ),
        contains('timeout: foregroundListTimeout'),
        reason:
            '漏了就等于又回到 8 秒 —— 2026-10-07 用户两次图库拉取都在第 8 秒整'
            '被判失败（同一台手机同一次会话里 Bing 拉取成功）',
      );
    });

    test('自动换那条路径仍吃 8 秒默认值', () {
      final body = memberBody(
        serviceSource,
        'static Future<WallhavenAutoApplyResult> maybeApplyDaily(',
      );
      expect(
        body,
        contains('service.fetchPortrait()'),
        reason:
            '自动换必须吃 fetchPortrait 的默认档（后台 8 秒）。显式传参说明有人'
            '把前台预算漏到了启动路径上，会让 App 开机变慢',
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
