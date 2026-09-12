// 质感方案：写穿与派生匹配的口径测试。
//
// 口径（2026-09-12 拍板的「纯增量预设层」）：
// - 每个预设只写穿它声明的字段集，其余字段（含壁纸等非材质字段）原样保留；
// - texturePresetOf 按「当前值 vs 该预设声明字段集」派生命中，不落盘；
// - 任一声名字段被手动改过即回落「自定义」（null）；
// - 「极简实体」只声明 3 个字段，不可达轴（作用范围等）不参与匹配。
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/header_blur_style.dart';
import 'package:university_timetable/models/liquid_glass_tuning.dart';
import 'package:university_timetable/models/soft_glass_tuning.dart';
import 'package:university_timetable/models/texture_preset.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/ui/hyperos/frosted/frosted_appearance.dart'
    show FrostedGlassMode;

void main() {
  group('texturePresetOf：派生匹配', () {
    test('出厂默认命中「经典磨砂」', () {
      expect(texturePresetOf(TimetableSettings.defaults()),
          TexturePreset.classicFrost);
    });

    test('写穿各预设后均命中自身', () {
      for (final preset in TexturePreset.values) {
        final applied = applyTexturePreset(TimetableSettings.defaults(), preset);
        expect(texturePresetOf(applied), preset, reason: '$preset 应命中自身');
      }
    });

    test('改任一声名字段即回落「自定义」', () {
      final liquid = applyTexturePreset(
        TimetableSettings.defaults(),
        TexturePreset.fullLiquid,
      );
      // 拖动液态调参滑杆（tuning 偏离标准预设）→ 不再命中。
      expect(
        texturePresetOf(
          liquid.copyWith(liquidGlassTuning: liquid.liquidGlassTuning!
              .copyWith(blur: liquid.liquidGlassTuning!.blur + 1)),
        ),
        isNull,
      );
      // 关掉一个作用范围开关 → 不再命中。
      expect(
        texturePresetOf(liquid.copyWith(liquidGlassDockEnabled: false)),
        isNull,
      );
    });

    test('「极简实体」不因不可达轴的杂值误判为自定义', () {
      // 实体档下作用范围 / 调参 / 子页风格不可达：残留任意值仍应命中。
      final noisy = applyTexturePreset(
        TimetableSettings.defaults(),
        TexturePreset.minimalSolid,
      ).copyWith(
        liquidGlassPopupEnabled: false,
        liquidGlassDockEnabled: false,
        subpageHeaderBlurStyle: HeaderBlurStyle.gaussian,
        softGlassPreset: SoftGlassPreset.dense,
        liquidGlassTuning: LiquidGlassTuning.presetDense,
      );
      expect(texturePresetOf(noisy), TexturePreset.minimalSolid);
    });

    test('两档顶栏风格被用户改过 → 经典磨砂不再命中（独立轴保留）', () {
      final tweaked = TimetableSettings.defaults().copyWith(
        subpageHeaderBlurStyle: HeaderBlurStyle.gaussian,
      );
      expect(texturePresetOf(tweaked), isNull);
    });
  });

  group('applyTexturePreset：写穿范围', () {
    test('经典磨砂把基础磨砂轴写回出厂值', () {
      final applied = applyTexturePreset(
        TimetableSettings.defaults().copyWith(
          frostedGlassMode: FrostedGlassMode.softGlass,
          frostedSheetBlurSigma: 22,
          frostedSheetTintAlpha: 0.2,
          courseCardSurfaceStyle: CourseCardSurfaceStyle.gaussian,
        ),
        TexturePreset.classicFrost,
      );
      expect(applied.frostedBlurEnabled, isTrue);
      expect(applied.frostedGlassMode, FrostedGlassMode.frosted);
      expect(applied.frostedSheetBlurSigma,
          TimetableSettings.defaultFrostedSheetBlurSigma);
      expect(applied.frostedSheetTintAlpha,
          TimetableSettings.defaultFrostedSheetTintAlpha);
      expect(applied.courseCardSurfaceStyle, CourseCardSurfaceStyle.solid);
    });

    test('全液态：五范围全开 + 顶栏液态 + 液态标准预设 + 高斯卡，不碰子页风格与磨砂滑杆', () {
      final base = TimetableSettings.defaults().copyWith(
        frostedSheetBlurSigma: 20,
        subpageHeaderBlurStyle: HeaderBlurStyle.gaussian,
      );
      final applied = applyTexturePreset(base, TexturePreset.fullLiquid);
      expect(applied.frostedGlassMode, FrostedGlassMode.liquidGlass);
      expect(applied.liquidGlassPopupEnabled, isTrue);
      expect(applied.liquidGlassSelectSheetEnabled, isTrue);
      expect(applied.liquidGlassSheetDialogEnabled, isTrue);
      expect(applied.liquidGlassDockEnabled, isTrue);
      expect(applied.liquidGlassPickerButtonsEnabled, isTrue);
      expect(applied.liquidGlassPreset, LiquidGlassPreset.standard);
      expect(applied.liquidGlassTuning,
          LiquidGlassPreset.standard.recommendedTuning);
      expect(applied.homeBandGlassMaterial, 'liquid');
      expect(applied.courseCardSurfaceStyle, CourseCardSurfaceStyle.gaussian);
      // 未声明的轴原样保留。
      expect(applied.frostedSheetBlurSigma, 20);
      expect(applied.subpageHeaderBlurStyle, HeaderBlurStyle.gaussian);
    });

    test('轻雾柔光：坞/面板/按钮保持磨砂，柔光标准预设 + 实体卡', () {
      final applied = applyTexturePreset(
        TimetableSettings.defaults(),
        TexturePreset.softMist,
      );
      expect(applied.frostedGlassMode, FrostedGlassMode.softGlass);
      expect(applied.liquidGlassPopupEnabled, isTrue);
      expect(applied.liquidGlassSelectSheetEnabled, isFalse);
      expect(applied.liquidGlassSheetDialogEnabled, isTrue);
      expect(applied.liquidGlassDockEnabled, isFalse);
      expect(applied.liquidGlassPickerButtonsEnabled, isFalse);
      expect(applied.softGlassPreset, SoftGlassPreset.standard);
      expect(applied.softGlassTuning,
          SoftGlassPreset.standard.recommendedTuning);
      expect(applied.homeBandGlassMaterial, 'soft');
      expect(applied.courseCardSurfaceStyle, CourseCardSurfaceStyle.solid);
    });

    test('极简实体：模糊关 + 磨砂模式 + 顶栏实体 + 实体卡，作用范围原样保留', () {
      final applied = applyTexturePreset(
        TimetableSettings.defaults().copyWith(liquidGlassDockEnabled: false),
        TexturePreset.minimalSolid,
      );
      expect(applied.frostedBlurEnabled, isFalse);
      expect(applied.frostedGlassMode, FrostedGlassMode.frosted);
      expect(applied.homeBandGlassMaterial, 'solid');
      expect(applied.courseCardSurfaceStyle, CourseCardSurfaceStyle.solid);
      // 未声明的轴原样保留。
      expect(applied.liquidGlassDockEnabled, isFalse);
    });

    test('非材质字段（壁纸路径）不被任何预设触碰', () {
      final base = TimetableSettings.defaults().copyWith(
        homePageWallpaperPath: '/tmp/wallpaper.png',
      );
      for (final preset in TexturePreset.values) {
        expect(
          applyTexturePreset(base, preset).homePageWallpaperPath,
          '/tmp/wallpaper.png',
          reason: '$preset 不应碰壁纸',
        );
      }
    });
  });
}
