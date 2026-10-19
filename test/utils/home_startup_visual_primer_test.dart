import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/utils/home_startup_visual_primer.dart';
import 'package:university_timetable/widgets/preblurred_wallpaper_glass.dart';

void main() {
  group('resolveHomePreblurSigma', () {
    test('液态 chrome 优先：『卡片是玻璃档』不许再抢决定权（2026-10-19 修复）', () {
      // 这个 getter 的定义是「**不是实体档**」，液态卡片也为真 —— 它一旦抢在前面，
      // 液态玻璃带的冻结位图就会被烤成全局顶栏模糊量（十几到二十几），而实时那条路
      // 只有 lgBlurSigma（1.0）：转场一开始整块带糊成一团，用户读到的是「变成高斯模糊」。
      expect(
        resolveHomePreblurSigma(
          gaussianCardsDrive: true,
          liquidGlassChrome: true,
          sheetBlurSigma: 15,
          liquidGlassTunedBlur: 8,
        ),
        8,
      );
    });

    test('液态 chrome 用调校值：只夹上限 24，**不抬下限**（冻结必须与实时同 σ）', () {
      // 抬下限会重演同一场灾难：实时是 0.5，冻结烤成 2.0 就是糊了 4 倍。
      expect(
        resolveHomePreblurSigma(
          gaussianCardsDrive: false,
          liquidGlassChrome: true,
          sheetBlurSigma: 15,
          liquidGlassTunedBlur: 0.5,
        ),
        0.5,
      );
      expect(
        resolveHomePreblurSigma(
          gaussianCardsDrive: false,
          liquidGlassChrome: true,
          sheetBlurSigma: 15,
          liquidGlassTunedBlur: 99,
        ),
        24.0,
      );
    });

    test('无高斯卡且非液态玻璃时回退 sheet sigma', () {
      expect(
        resolveHomePreblurSigma(
          gaussianCardsDrive: false,
          liquidGlassChrome: false,
          sheetBlurSigma: 12,
          liquidGlassTunedBlur: null,
        ),
        12,
      );
      // 液态玻璃但无调校值：同样回退 sheet sigma（与首页内联逻辑一致）。
      expect(
        resolveHomePreblurSigma(
          gaussianCardsDrive: false,
          liquidGlassChrome: true,
          sheetBlurSigma: 9,
          liquidGlassTunedBlur: null,
        ),
        9,
      );
    });
  });

  group('HomeStartupVisualPrimer.prime', () {
    test('无壁纸路径时立即返回且不产生种子亮度带', () async {
      await HomeStartupVisualPrimer.prime(TimetableSettings.defaults());
      expect(HomeStartupVisualPrimer.seededBandsFor(null), isNull);
      expect(HomeStartupVisualPrimer.seededBandsFor('/any/path.png'), isNull);
    });

    test('壁纸文件不存在时立即返回且不产生种子亮度带', () async {
      const missing = r'C:\__definitely_missing_wallpaper__.png';
      await HomeStartupVisualPrimer.prime(
        TimetableSettings.defaults().copyWith(homePageWallpaperPath: missing),
      );
      expect(HomeStartupVisualPrimer.seededBandsFor(missing), isNull);
    });

    test('seededBandsFor 仅对预热时的同一路径返回采样带', () {
      const bands = (top: 0.1, weekday: 0.2, body: 0.3);
      HomeStartupVisualPrimer.debugSeedBands('/w.png', bands);

      expect(HomeStartupVisualPrimer.seededBandsFor('/w.png'), bands);
      expect(HomeStartupVisualPrimer.seededBandsFor('/other.png'), isNull);
      expect(HomeStartupVisualPrimer.seededBandsFor(null), isNull);
    });
  });
}
