import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:university_timetable/services/wallhaven_wallpaper_service.dart';

/// 竖版高清图库页的**接线**护栏：超时档位与失败文案。
///
/// ## 为什么扫源码而不是渲染 widget
///
/// 两条护栏盯的都是「**哪个常量 / 哪个 l10n 键被接上去**」，而 widget 测试里这两者都由
/// 测试自己搭出来 —— 无论接错还是接对，渲染出来的树都是绿的，抓不到回归。
/// 本仓已有同款做法（见 `bing_wallpaper_switch_wiring_test.dart` 与
/// `test/architecture/dependency_guards_test.dart`）。
final String pageSource = File(
  'lib/screens/settings/wallhaven_wallpaper_gallery_page.dart',
).readAsStringSync();

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

    test('图库页显式传前台档，不吃 fetchPortrait 的默认值', () {
      expect(
        pageSource,
        contains('timeout: WallhavenWallpaperService.foregroundListTimeout'),
        reason:
            '漏传就等于又回到 8 秒 —— 2026-10-07 用户两次图库拉取都在第 8 秒整'
            '被判失败（同一台手机同一次会话里 Bing 拉取成功）',
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
