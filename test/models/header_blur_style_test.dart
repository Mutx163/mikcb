import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/glass_mode_choice.dart';
import 'package:university_timetable/models/header_blur_style.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/ui/hyperos/frosted/frosted_appearance.dart';
import 'package:university_timetable/widgets/home_page_region_blur.dart'
    show homeChromeAdvancedModeOf;

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

  group('首页玻璃带材质：跟随全局高级材质 + 作用范围', () {
    test('基础材质（实体/高斯）→ 不走高级材质面', () {
      expect(
        homeChromeAdvancedModeOf(
          glassMode: FrostedGlassMode.frosted,
          homeChromeScopeEnabled: true,
        ),
        isNull,
      );
      expect(
        homeChromeAdvancedModeOf(
          glassMode: FrostedGlassMode.gaussian,
          homeChromeScopeEnabled: true,
        ),
        isNull,
      );
    });

    test('液态 + 作用范围开 → 液态；关 → 基础磨砂', () {
      expect(
        homeChromeAdvancedModeOf(
          glassMode: FrostedGlassMode.liquidGlass,
          homeChromeScopeEnabled: true,
        ),
        FrostedGlassMode.liquidGlass,
      );
      expect(
        homeChromeAdvancedModeOf(
          glassMode: FrostedGlassMode.liquidGlass,
          homeChromeScopeEnabled: false,
        ),
        isNull,
      );
    });

    test('柔光与液态同口径（历史 bug：柔光完全读不到作用范围）', () {
      expect(
        homeChromeAdvancedModeOf(
          glassMode: FrostedGlassMode.softGlass,
          homeChromeScopeEnabled: true,
        ),
        FrostedGlassMode.softGlass,
      );
      expect(
        homeChromeAdvancedModeOf(
          glassMode: FrostedGlassMode.softGlass,
          homeChromeScopeEnabled: false,
        ),
        isNull,
      );
    });
  });

  group('顶栏模糊风格：applyChromeBlurStyle', () {
    test('渐进档：写风格并同步存量材质键', () {
      final s = applyChromeBlurStyle(
        TimetableSettings.defaults().copyWith(
          homeChromeGlassMaterial: 'gaussian',
          headerBlurStyle: HeaderBlurStyle.gaussian,
        ),
        HeaderBlurStyle.inspire,
      );

      expect(s.headerBlurStyle, HeaderBlurStyle.inspire);
      expect(s.homeChromeGlassMaterial, 'progressive');
    });

    test('高斯档：写风格并同步存量材质键', () {
      final s = applyChromeBlurStyle(
        TimetableSettings.defaults(),
        HeaderBlurStyle.gaussian,
      );

      expect(s.headerBlurStyle, HeaderBlurStyle.gaussian);
      expect(s.homeChromeGlassMaterial, 'gaussian');
    });

    test('不再静默关掉首页玻璃带的高级材质作用范围', () {
      final base = TimetableSettings.defaults().copyWith(
        frostedGlassMode: FrostedGlassMode.softGlass,
        liquidGlassHomeChromeEnabled: true,
      );
      final s = applyChromeBlurStyle(base, HeaderBlurStyle.gaussian);
      expect(s.liquidGlassHomeChromeEnabled, isTrue);
      expect(
        homeChromeAdvancedModeOf(
          glassMode: s.frostedGlassMode,
          homeChromeScopeEnabled: s.liquidGlassHomeChromeEnabled,
        ),
        FrostedGlassMode.softGlass,
      );
    });

    test('不改全局材质（只动首页玻璃带的衰减风格）', () {
      final base = TimetableSettings.defaults().copyWith(
        frostedGlassMode: FrostedGlassMode.softGlass,
      );
      final s = applyChromeBlurStyle(base, HeaderBlurStyle.gaussian);
      expect(s.frostedGlassMode, FrostedGlassMode.softGlass);
    });
  });

  group('存量迁移：独立材质键 liquid 上提为全局液态', () {
    test('有 liquid 键 + 模糊开 → 全局液态 + 首页玻璃带作用范围开', () {
      final json = TimetableSettings.defaults().copyWith(
        homeChromeGlassMaterial: 'liquid',
      ).toJson();
      final restored = TimetableSettings.fromJson(json);

      expect(restored.frostedGlassMode, FrostedGlassMode.liquidGlass);
      expect(restored.liquidGlassHomeChromeEnabled, isTrue);
      expect(restored.homeChromeGlassMaterial, 'progressive');
    });

    test('模糊总开关关（实体卡片档）时不提升，保持实录', () {
      final json = TimetableSettings.defaults().copyWith(
        frostedBlurEnabled: false,
        homeChromeGlassMaterial: 'liquid',
      ).toJson();
      final restored = TimetableSettings.fromJson(json);

      expect(restored.frostedBlurEnabled, isFalse);
      expect(restored.frostedGlassMode, isNot(FrostedGlassMode.liquidGlass));
    });
  });
}
