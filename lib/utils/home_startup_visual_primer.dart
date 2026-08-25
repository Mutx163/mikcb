import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import '../models/timetable_settings.dart';
import '../ui/hyperos/frosted/frosted_appearance.dart';
import '../widgets/preblurred_wallpaper_glass.dart';
import 'home_page_background.dart';

/// 冷启动「首帧视觉预热」：在放行第一帧之前，把首页首屏依赖的视觉资产
/// （壁纸位图、课程卡/摘要卡的预模糊位图、墨色极性亮度采样）全部准备完毕。
///
/// 背景：系统启动画面的退出由首帧放行驱动（main.dart 的 deferFirstFrame），
/// 而壁纸预加载与预模糊位图此前都是放行后才异步进行——放行后的头几帧只能
/// 画出主题兜底底色（夜间 ≈ #121212），用户看到的就是「启动动画结束后先黑
/// 一下再恢复」。这里把这部分等待挪进启动画面的存续期内：splash 多停留数百
/// 毫秒用户无感，换来 splash → 完整首页的硬切。
///
/// 所有子步骤自带超时/异常兜底，整体受 [_budget] 约束；任何失败都只降级为
/// 「未预热」（后台管线继续自行完成，行为退化为修复前的渐进显示），绝不
/// 阻塞或拖死启动管线——main.dart 的 6s 首帧看门狗仍是最后一道保险。
abstract final class HomeStartupVisualPrimer {
  /// 整体预算：覆盖低端机两次解码 + GPU 模糊 + 小图采样；超时即放行首帧。
  static const _budget = Duration(milliseconds: 3000);

  static ({double top, double weekday, double body})? _seededBands;
  static String? _seededBandsPath;

  /// 启动期采样到的壁纸亮度带，供首页首帧直接取用、消除墨色极性闪变。
  /// 仅当 [path] 与预热时一致才返回；未预热过返回 null。
  static ({double top, double weekday, double body})? seededBandsFor(
    String? path,
  ) {
    if (path == null || path.isEmpty || _seededBandsPath != path) {
      return null;
    }
    return _seededBands;
  }

  @visibleForTesting
  static void debugSeedBands(
    String path,
    ({double top, double weekday, double body}) bands,
  ) {
    _seededBandsPath = path;
    _seededBands = bands;
  }

  /// 预热首页首帧全部视觉资产。永不抛出。
  static Future<void> prime(TimetableSettings settings) async {
    try {
      final path = resolveHomePageBackdropImagePath(settings);
      if (path == null || path.isEmpty) {
        return;
      }
      if (!File(path).existsSync()) {
        return;
      }
      final devicePixelRatio = _devicePixelRatio();
      final appearance = settings.frostedAppearance;
      final sigma = resolveHomePreblurSigma(
        gaussianCardsDrive:
            settings.courseCardSurfaceStyle == CourseCardSurfaceStyle.gaussian,
        // 与首页玻璃带消费点同判：家族开关关闭时按磨砂 sigma 预热，
        // 否则预热位图和首帧实际材质不一致。
        liquidGlassChrome: appearance.glassMode == FrostedGlassMode.liquidGlass &&
            appearance.liquidGlassHomeChromeEnabled,
        sheetBlurSigma: appearance.sheetBlurSigma,
        liquidGlassTunedBlur: appearance.liquidGlassTuning?.blur,
      );

      // 亮度带单独 await：避免用列表下标对齐可选的预模糊任务。
      final bandsFuture = sampleHomePageWallpaperLuminanceBands(path);
      final jobs = <Future<Object?>>[
        // 全尺寸壁纸进 ImageCache：首页背景 Image 首帧即有像素。
        precacheHomePageBackdropImage(settings).then((_) => null),
        // 预模糊位图进 PreblurredWallpaperCache：高斯卡片/摘要卡首帧即为
        // 成品磨砂，不经过实时 BackdropFilter 过渡。克隆句柄即刻释放，
        // 缓存自留的那份就是首页稍后 obtain 到的同一份。
        if (devicePixelRatio > 0)
          PreblurredWallpaperCache.instance
              .obtain(
                path: path,
                logicalSigma: sigma,
                devicePixelRatio: devicePixelRatio,
              )
              .then((image) => image?.dispose()),
      ];
      await Future.wait(
        jobs,
      ).timeout(_budget, onTimeout: () => <Object?>[]);
      final bands = await bandsFuture.timeout(_budget, onTimeout: () => null);
      if (bands != null) {
        _seededBandsPath = path;
        _seededBands = bands;
      }
    } catch (error, stackTrace) {
      // 预热是纯优化：任何失败都不能挡住首帧放行。
      debugPrint('HomeStartupVisualPrimer.prime failed: $error\n$stackTrace');
    }
  }

  static double _devicePixelRatio() {
    final views = ui.PlatformDispatcher.instance.views;
    if (views.isEmpty) {
      return 0;
    }
    return views.first.devicePixelRatio;
  }
}
