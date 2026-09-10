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

    test('高斯档：headerBlurStyle=gaussian 且首页液态关', () {
      final s = applyChromeGlassMaterial(
        TimetableSettings.defaults(),
        ChromeGlassMaterial.gaussian,
      );
      expect(chromeGlassMaterialOf(s), ChromeGlassMaterial.gaussian);
      expect(s.headerBlurStyle, HeaderBlurStyle.gaussian);
      expect(s.liquidGlassHomeChromeEnabled, isFalse);
    });

    test('渐进档：清掉首页液态，不动全局 glassMode', () {
      final base = TimetableSettings.defaults().copyWith(
        frostedGlassMode: FrostedGlassMode.liquidGlass,
        liquidGlassHomeChromeEnabled: true,
      );
      final s = applyChromeGlassMaterial(base, ChromeGlassMaterial.progressive);
      expect(chromeGlassMaterialOf(s), ChromeGlassMaterial.progressive);
      expect(s.headerBlurStyle, HeaderBlurStyle.inspire);
      expect(s.liquidGlassHomeChromeEnabled, isFalse);
      expect(s.frostedGlassMode, FrostedGlassMode.liquidGlass);
    });

    test('液态档：打开全局液态 + 首页液态开关', () {
      final s = applyChromeGlassMaterial(
        TimetableSettings.defaults().copyWith(frostedBlurEnabled: false),
        ChromeGlassMaterial.liquid,
      );
      expect(chromeGlassMaterialOf(s), ChromeGlassMaterial.liquid);
      expect(s.frostedGlassMode, FrostedGlassMode.liquidGlass);
      expect(s.liquidGlassHomeChromeEnabled, isTrue);
      expect(s.frostedBlurEnabled, isTrue);
    });
  });
}
