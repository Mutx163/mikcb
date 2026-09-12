// 首页顶栏玻璃带材质（独立自由选择）与子页顶栏模糊风格：模型层口径。
//
// 历史：2026-09-12 拍板首页顶栏材质自由五档（渐进磨砂 / 高斯磨砂 / 柔光 /
// 液态 / 实体），不再跟随全局玻璃模式或「作用范围 → 首页玻璃带」开关。
// 旧轴（headerBlurStyle + homeChromeGlassMaterial 镜像 + 首页玻璃带范围开
// 关）在 fromJson 里迁移到新字段 homeBandGlassMaterial，观感逐条不变。
// 子页顶栏永不走高级材质，仍用 HeaderBlurStyle 两档（渐进 / 高斯）。
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/glass_mode_choice.dart';
import 'package:university_timetable/models/header_blur_style.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/ui/hyperos/frosted/frosted_appearance.dart';

void main() {
  group('首页顶栏玻璃带材质：独立自由选择', () {
    test('默认值为渐进磨砂档', () {
      expect(
        TimetableSettings.defaults().homeBandGlassMaterial,
        'progressive',
      );
      expect(FrostedAppearance.defaults.homeBandGlassMaterial, 'progressive');
    });

    test('非法值兜底渐进档', () {
      expect(
        TimetableSettings.sanitizeHomeBandGlassMaterial(null),
        'progressive',
      );
      expect(
        TimetableSettings.sanitizeHomeBandGlassMaterial('nope'),
        'progressive',
      );
      expect(
        TimetableSettings.sanitizeHomeBandGlassMaterial('gaussian'),
        'gaussian',
      );
      expect(
        TimetableSettings.sanitizeHomeBandGlassMaterial('solid'),
        'solid',
      );
      final legacy = TimetableSettings.fromJson(const {'sections': []});
      expect(legacy.homeBandGlassMaterial, 'progressive');
    });

    test('JSON 往返保留材质档（五档逐一）', () {
      for (final material in TimetableSettings.homeBandGlassMaterialValues) {
        final custom = TimetableSettings.defaults().copyWith(
          homeBandGlassMaterial: material,
        );
        final restored = TimetableSettings.fromJson(custom.toJson());
        expect(restored.homeBandGlassMaterial, material, reason: material);
      }
    });

    test('frostedAppearance 映射顶栏材质', () {
      final settings = TimetableSettings.defaults().copyWith(
        homeBandGlassMaterial: 'liquid',
      );
      expect(settings.frostedAppearance.homeBandGlassMaterial, 'liquid');
    });

    test('FrostedAppearance 相等性包含顶栏材质', () {
      const a = FrostedAppearance.defaults;
      final b = FrostedAppearance(
        sheetBlurSigma: a.sheetBlurSigma,
        sheetTintAlpha: a.sheetTintAlpha,
        sheetBarrierAlpha: a.sheetBarrierAlpha,
        homeBandGlassMaterial: 'liquid',
      );
      expect(a == b, isFalse);
      expect(a.hashCode == b.hashCode, isFalse);
    });

    test('applyHomeBandGlassMaterial 只动顶栏材质，不碰全局', () {
      final base = TimetableSettings.defaults().copyWith(
        frostedGlassMode: FrostedGlassMode.softGlass,
      );
      final s = applyHomeBandGlassMaterial(base, 'gaussian');
      expect(s.homeBandGlassMaterial, 'gaussian');
      expect(s.frostedGlassMode, FrostedGlassMode.softGlass);
    });
  });

  group('顶栏材质迁移：旧轴 → homeBandGlassMaterial', () {
    test('旧「独立三档 liquid」+ 模糊开 → 上提全局液态 + 顶栏液态（观感不变）', () {
      final json = TimetableSettings.defaults().toJson()
        ..remove('homeBandGlassMaterial')
        ..['homeChromeGlassMaterial'] = 'liquid';
      final restored = TimetableSettings.fromJson(json);

      expect(restored.frostedGlassMode, FrostedGlassMode.liquidGlass);
      expect(restored.homeBandGlassMaterial, 'liquid');
    });

    test('旧 liquid + 模糊关（实体卡片档）不提升，顶栏回渐进磨砂', () {
      final json = TimetableSettings.defaults().toJson()
        ..remove('homeBandGlassMaterial')
        ..['homeChromeGlassMaterial'] = 'liquid'
        ..['frostedBlurEnabled'] = false;
      final restored = TimetableSettings.fromJson(json);

      expect(restored.frostedBlurEnabled, isFalse);
      expect(restored.frostedGlassMode, isNot(FrostedGlassMode.liquidGlass));
      expect(restored.homeBandGlassMaterial, 'progressive');
    });

    test('全局柔光 + 旧范围开 → 顶栏柔光；范围关 → 按旧镜像磨砂', () {
      final scopeOn = TimetableSettings.defaults()
          .copyWith(frostedGlassMode: FrostedGlassMode.softGlass)
          .toJson()
        ..remove('homeBandGlassMaterial')
        ..['liquidGlassHomeChromeEnabled'] = true;
      expect(
        TimetableSettings.fromJson(scopeOn).homeBandGlassMaterial,
        'soft',
      );

      final scopeOff = Map<String, dynamic>.from(scopeOn)
        ..['liquidGlassHomeChromeEnabled'] = false;
      expect(
        TimetableSettings.fromJson(scopeOff).homeBandGlassMaterial,
        'progressive',
      );
    });

    test('全局液态 + 旧范围开 → 顶栏液态', () {
      final json = TimetableSettings.defaults()
          .copyWith(frostedGlassMode: FrostedGlassMode.liquidGlass)
          .toJson()
        ..remove('homeBandGlassMaterial')
        ..['liquidGlassHomeChromeEnabled'] = true;
      expect(
        TimetableSettings.fromJson(json).homeBandGlassMaterial,
        'liquid',
      );
    });

    test('旧镜像高斯（headerBlurStyle=高斯 时代）→ 顶栏高斯磨砂', () {
      final json = TimetableSettings.defaults().toJson()
        ..remove('homeBandGlassMaterial')
        ..['homeChromeGlassMaterial'] = 'gaussian';
      expect(
        TimetableSettings.fromJson(json).homeBandGlassMaterial,
        'gaussian',
      );
    });

    test('新键优先于旧轴，不被迁移覆盖', () {
      final json = TimetableSettings.defaults()
          .copyWith(homeBandGlassMaterial: 'soft')
          .toJson()
        ..['homeChromeGlassMaterial'] = 'liquid'
        ..['liquidGlassHomeChromeEnabled'] = true
        ..['frostedGlassMode'] = 'liquid';
      final restored = TimetableSettings.fromJson(json);
      expect(restored.homeBandGlassMaterial, 'soft');
    });
  });

  group('子页顶栏模糊风格：与首页材质相互独立', () {
    test('默认值为渐进模糊档', () {
      expect(TimetableSettings.defaults().subpageHeaderBlurStyle,
          HeaderBlurStyle.inspire);
      expect(FrostedAppearance.defaults.subpageHeaderBlurStyle,
          HeaderBlurStyle.inspire);
    });

    test('存量迁移：JSON 缺新键时沿旧 headerBlurStyle，观感不变', () {
      final json = TimetableSettings.defaults().toJson()
        ..remove('subpageHeaderBlurStyle')
        ..remove('homeBandGlassMaterial')
        ..['headerBlurStyle'] = 'gaussian';
      final restored = TimetableSettings.fromJson(json);

      expect(restored.subpageHeaderBlurStyle, HeaderBlurStyle.gaussian);
    });

    test('新键存在时不被旧键覆盖，JSON 往返保留', () {
      final custom = TimetableSettings.defaults().copyWith(
        homeBandGlassMaterial: 'gaussian',
        subpageHeaderBlurStyle: HeaderBlurStyle.inspire,
      );
      final restored = TimetableSettings.fromJson(custom.toJson());

      expect(restored.homeBandGlassMaterial, 'gaussian');
      expect(restored.subpageHeaderBlurStyle, HeaderBlurStyle.inspire);
    });

    test('frostedAppearance 映射子页模糊风格', () {
      final settings = TimetableSettings.defaults().copyWith(
        subpageHeaderBlurStyle: HeaderBlurStyle.gaussian,
      );
      expect(
        settings.frostedAppearance.subpageHeaderBlurStyle,
        HeaderBlurStyle.gaussian,
      );
    });

    test('applySubpageChromeBlurStyle 只动子页字段，不碰首页材质', () {
      final s = applySubpageChromeBlurStyle(
        TimetableSettings.defaults().copyWith(
          homeBandGlassMaterial: 'liquid',
        ),
        HeaderBlurStyle.inspire,
      );

      expect(s.subpageHeaderBlurStyle, HeaderBlurStyle.inspire);
      expect(s.homeBandGlassMaterial, 'liquid');
    });
  });
}
