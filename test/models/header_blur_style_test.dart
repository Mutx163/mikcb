import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/glass_mode_choice.dart';
import 'package:university_timetable/models/header_blur_style.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/ui/hyperos/frosted/frosted_appearance.dart';

void main() {
  group('顶栏模糊风格：模型层', () {
    test('默认值为渐进模糊档', () {
      expect(TimetableSettings.defaults().headerBlurStyle,
          HeaderBlurStyle.inspire);
      expect(FrostedAppearance.defaults.headerBlurStyle,
          HeaderBlurStyle.inspire);
    });

    test('缺键 / 未知值回退渐进模糊', () {
      expect(HeaderBlurStyleX.fromValue(null), HeaderBlurStyle.inspire);
      expect(HeaderBlurStyleX.fromValue('nope'), HeaderBlurStyle.inspire);
      expect(HeaderBlurStyleX.fromValue('gaussian'), HeaderBlurStyle.gaussian);
      expect(HeaderBlurStyleX.fromValue('inspire'), HeaderBlurStyle.inspire);
      final legacy = TimetableSettings.fromJson(const {'sections': []});
      expect(legacy.headerBlurStyle, HeaderBlurStyle.inspire);
    });

    test('JSON 往返保留档位', () {
      final custom = TimetableSettings.defaults().copyWith(
        headerBlurStyle: HeaderBlurStyle.gaussian,
      );
      final restored = TimetableSettings.fromJson(custom.toJson());
      expect(restored.headerBlurStyle, HeaderBlurStyle.gaussian);
    });

    test('frostedAppearance 映射顶栏模糊风格', () {
      final settings = TimetableSettings.defaults().copyWith(
        headerBlurStyle: HeaderBlurStyle.gaussian,
      );
      expect(
        settings.frostedAppearance.headerBlurStyle,
        HeaderBlurStyle.gaussian,
      );
    });

    test('FrostedAppearance 相等性包含顶栏模糊风格', () {
      const a = FrostedAppearance.defaults;
      final b = FrostedAppearance(
        sheetBlurSigma: a.sheetBlurSigma,
        sheetTintAlpha: a.sheetTintAlpha,
        sheetBarrierAlpha: a.sheetBarrierAlpha,
        headerBlurStyle: HeaderBlurStyle.gaussian,
      );
      expect(a == b, isFalse);
      expect(a.hashCode == b.hashCode, isFalse);
    });
  });

  group('顶栏玻璃材质三档：映射', () {
    test('默认推导为渐进模糊', () {
      expect(chromeGlassMaterialOf(TimetableSettings.defaults()),
          ChromeGlassMaterial.progressive);
    });

    test('高斯档：写 homeChromeGlassMaterial，不动全局 glassMode', () {
      final s = applyChromeGlassMaterial(
        TimetableSettings.defaults(),
        ChromeGlassMaterial.gaussian,
      );
      expect(chromeGlassMaterialOf(s), ChromeGlassMaterial.gaussian);
      expect(s.homeChromeGlassMaterial, 'gaussian');
      expect(s.headerBlurStyle, HeaderBlurStyle.gaussian);
      expect(s.frostedGlassMode, FrostedGlassMode.frosted);
    });

    test('渐进档：清掉首页液态，不动全局 glassMode', () {
      final base = TimetableSettings.defaults().copyWith(
        frostedGlassMode: FrostedGlassMode.gaussian,
        liquidGlassHomeChromeEnabled: true,
        homeChromeGlassMaterial: 'liquid',
      );
      final s = applyChromeGlassMaterial(base, ChromeGlassMaterial.progressive);
      expect(chromeGlassMaterialOf(s), ChromeGlassMaterial.progressive);
      expect(s.homeChromeGlassMaterial, 'progressive');
      expect(s.headerBlurStyle, HeaderBlurStyle.inspire);
      expect(s.liquidGlassHomeChromeEnabled, isFalse);
      expect(s.frostedGlassMode, FrostedGlassMode.gaussian);
    });

    test('液态档：只改首页材质键，不动全局 glassMode', () {
      final s = applyChromeGlassMaterial(
        TimetableSettings.defaults(),
        ChromeGlassMaterial.liquid,
      );
      expect(chromeGlassMaterialOf(s), ChromeGlassMaterial.liquid);
      expect(s.homeChromeGlassMaterial, 'liquid');
      expect(s.frostedGlassMode, FrostedGlassMode.frosted);
      expect(s.liquidGlassHomeChromeEnabled, isTrue);
    });

    test('存量无新键时从旧字段推导', () {
      final legacy = TimetableSettings.defaults().copyWith(
        frostedGlassMode: FrostedGlassMode.liquidGlass,
        liquidGlassHomeChromeEnabled: true,
        // 模拟无 homeChromeGlassMaterial 键的旧档：用非法值触发兜底。
        homeChromeGlassMaterial: '',
      );
      expect(chromeGlassMaterialOf(legacy), ChromeGlassMaterial.liquid);
    });
  });

  group('顶栏模糊风格独立行：applyChromeBlurStyle', () {
    test('渐进档：写风格并同步材质键，材质行不会显示成高斯', () {
      final s = applyChromeBlurStyle(
        TimetableSettings.defaults().copyWith(
          homeChromeGlassMaterial: 'gaussian',
          headerBlurStyle: HeaderBlurStyle.gaussian,
        ),
        HeaderBlurStyle.inspire,
      );

      expect(s.headerBlurStyle, HeaderBlurStyle.inspire);
      expect(s.homeChromeGlassMaterial, 'progressive');
      expect(chromeGlassMaterialOf(s), ChromeGlassMaterial.progressive);
    });

    test('高斯档：写风格并同步材质键', () {
      final s = applyChromeBlurStyle(
        TimetableSettings.defaults(),
        HeaderBlurStyle.gaussian,
      );

      expect(s.headerBlurStyle, HeaderBlurStyle.gaussian);
      expect(s.homeChromeGlassMaterial, 'gaussian');
      expect(chromeGlassMaterialOf(s), ChromeGlassMaterial.gaussian);
    });

    test('从液态切回风格档：材质行不再停在液态玻璃', () {
      final liquid = applyChromeGlassMaterial(
        TimetableSettings.defaults(),
        ChromeGlassMaterial.liquid,
      );
      expect(chromeGlassMaterialOf(liquid), ChromeGlassMaterial.liquid);

      final s = applyChromeBlurStyle(liquid, HeaderBlurStyle.inspire);

      expect(s.homeChromeGlassMaterial, 'progressive');
      expect(s.liquidGlassHomeChromeEnabled, isFalse);
      expect(chromeGlassMaterialOf(s), ChromeGlassMaterial.progressive);
    });

    test('两行往返切换后状态自洽（材质行与风格行不打架）', () {
      var s = TimetableSettings.defaults();
      // 材质行选高斯 → 风格行跟着显示高斯。
      s = applyChromeGlassMaterial(s, ChromeGlassMaterial.gaussian);
      expect(s.headerBlurStyle, HeaderBlurStyle.gaussian);
      // 风格行改渐进 → 材质行跟着回到渐进。
      s = applyChromeBlurStyle(s, HeaderBlurStyle.inspire);
      expect(chromeGlassMaterialOf(s), ChromeGlassMaterial.progressive);
      expect(s.headerBlurStyle, HeaderBlurStyle.inspire);
      // 材质行选液态 → 风格行隐藏，风格值原样保留。
      s = applyChromeGlassMaterial(s, ChromeGlassMaterial.liquid);
      expect(chromeGlassMaterialOf(s), ChromeGlassMaterial.liquid);
      expect(s.headerBlurStyle, HeaderBlurStyle.inspire);
    });

    test('不改全局玻璃模式（只动首页玻璃带）', () {
      final base = TimetableSettings.defaults().copyWith(
        frostedGlassMode: FrostedGlassMode.softGlass,
      );
      final s = applyChromeBlurStyle(base, HeaderBlurStyle.gaussian);
      expect(s.frostedGlassMode, FrostedGlassMode.softGlass);
    });
  });
}
