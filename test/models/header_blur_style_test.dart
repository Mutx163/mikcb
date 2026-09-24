// 首页顶栏玻璃带材质（独立自由选择）与子页顶栏模糊风格：模型层口径。
//
// 历史：2026-09-12 拍板首页顶栏材质自由五档（渐进磨砂 / 高斯磨砂 / 柔光 /
// 液态 / 实体），不再跟随全局玻璃模式或「作用范围 → 首页玻璃带」开关。
// 旧轴（headerBlurStyle + homeChromeGlassMaterial 镜像 + 首页玻璃带范围开
// 关）在 fromJson 里迁移到新字段 homeBandGlassMaterial。
//
// 2026-09-20 口径收成两档（液态玻璃 / 实体）：外观编辑器里那个开关**只有**
// 这两个选项，而存量中间档曾被"就近归桶"显示成液态 —— 于是界面上看到
// 「液态玻璃」被选中、实际渲染的却是渐进磨砂（只有模糊 + 衬底，没有折射也
// 没有边光那一圈），真机口径就是「顶栏没有玻璃效果」而底栏（走全局材质）却
// 有（用户 2026-09-20 报的正是这个）。现在**读取 / 写入口 / 渲染三层同口径**：
// 非实体即液态，中间档一律归到液态。
//
// 2026-09-23：子页顶栏那把轴（渐进 / 高斯两档）整体撤下 —— 用户口径
// 「子页顶部可以锁定渐变模糊」，所以设置模型里不再有 subpageHeaderBlurStyle，
// 渲染侧恒为渐进。本文件只剩顶栏材质那一轴。
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/glass_mode_choice.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/ui/hyperos/frosted/frosted_appearance.dart';

void main() {
  group('首页顶栏玻璃带材质：液态 / 实体两档', () {
    test('默认值为液态玻璃档', () {
      expect(TimetableSettings.defaults().homeBandGlassMaterial, 'liquid');
      expect(FrostedAppearance.defaults.homeBandGlassMaterial, 'liquid');
      expect(TimetableSettings.homeBandGlassMaterialValues, ['liquid', 'solid']);
    });

    test('非实体一律归到液态：非法值 / 三个存量中间档 / 缺键', () {
      for (final legacy in ['progressive', 'gaussian', 'soft', 'nope', null]) {
        expect(
          TimetableSettings.sanitizeHomeBandGlassMaterial(legacy),
          'liquid',
          reason: '$legacy 必须归到液态 —— 界面只承诺「实体 / 液态玻璃」两档',
        );
      }
      expect(TimetableSettings.sanitizeHomeBandGlassMaterial('solid'), 'solid');
      // 缺键（全新安装 / 老备份）走默认档。
      final fresh = TimetableSettings.fromJson(const {'sections': []});
      expect(fresh.homeBandGlassMaterial, 'liquid');
    });

    test('JSON 往返保留材质档（两档逐一）', () {
      for (final material in TimetableSettings.homeBandGlassMaterialValues) {
        final custom = TimetableSettings.defaults().copyWith(
          homeBandGlassMaterial: material,
        );
        final restored = TimetableSettings.fromJson(custom.toJson());
        expect(restored.homeBandGlassMaterial, material, reason: material);
      }
    });

    test('JSON 往返把存量中间档收敛到液态', () {
      for (final legacy in ['progressive', 'gaussian', 'soft']) {
        final json = TimetableSettings.defaults().toJson()
          ..['homeBandGlassMaterial'] = legacy;
        expect(
          TimetableSettings.fromJson(json).homeBandGlassMaterial,
          'liquid',
          reason: '$legacy 落盘再读回来必须是液态',
        );
      }
    });

    test('frostedAppearance 映射顶栏材质', () {
      final settings = TimetableSettings.defaults().copyWith(
        homeBandGlassMaterial: 'solid',
      );
      expect(settings.frostedAppearance.homeBandGlassMaterial, 'solid');
    });

    test('FrostedAppearance 相等性包含顶栏材质', () {
      const a = FrostedAppearance.defaults;
      final b = FrostedAppearance(
        sheetBlurSigma: a.sheetBlurSigma,
        sheetTintAlpha: a.sheetTintAlpha,
        sheetBarrierAlpha: a.sheetBarrierAlpha,
        homeBandGlassMaterial: 'solid',
      );
      expect(a == b, isFalse);
      expect(a.hashCode == b.hashCode, isFalse);
    });

    test('applyHomeBandGlassMaterial 只动顶栏材质，不碰全局', () {
      final base = TimetableSettings.defaults().copyWith(
        frostedGlassMode: FrostedGlassMode.liquidGlass,
      );
      final s = applyHomeBandGlassMaterial(base, 'solid');
      expect(s.homeBandGlassMaterial, 'solid');
      expect(s.frostedGlassMode, FrostedGlassMode.liquidGlass);
    });

    test('applyHomeBandGlassMaterial 的写入口也过同一道收敛', () {
      // 写入口是 UI 那一侧的最后一道闸：即使有人传了中间档，落盘也只能是液态。
      final s = applyHomeBandGlassMaterial(
        TimetableSettings.defaults(),
        'progressive',
      );
      expect(s.homeBandGlassMaterial, 'liquid');
    });
  });

  group('顶栏材质迁移：旧轴 → homeBandGlassMaterial（中间档一律收敛到液态）', () {
    test('旧「独立三档 liquid」+ 模糊开 → 上提全局液态 + 顶栏液态（观感不变）', () {
      final json = TimetableSettings.defaults().toJson()
        ..remove('homeBandGlassMaterial')
        ..['homeChromeGlassMaterial'] = 'liquid';
      final restored = TimetableSettings.fromJson(json);

      expect(restored.frostedGlassMode, FrostedGlassMode.liquidGlass);
      expect(restored.homeBandGlassMaterial, 'liquid');
    });

    test('旧 liquid + 模糊关（实体卡片档）不提升全局，顶栏仍是液态档', () {
      final json = TimetableSettings.defaults().toJson()
        ..remove('homeBandGlassMaterial')
        ..['homeChromeGlassMaterial'] = 'liquid'
        ..['frostedBlurEnabled'] = false;
      final restored = TimetableSettings.fromJson(json);

      expect(restored.frostedBlurEnabled, isFalse);
      expect(restored.frostedGlassMode, isNot(FrostedGlassMode.liquidGlass));
      // 顶栏材质与模糊总开关无关：模糊关只让渲染回落实底衬底，材质档仍是液态。
      expect(restored.homeBandGlassMaterial, 'liquid');
    });

    test('旧范围开 + 全局柔光 / 旧镜像高斯：都收敛到液态', () {
      final scopeOn = TimetableSettings.defaults()
          .copyWith(frostedGlassMode: FrostedGlassMode.liquidGlass)
          .toJson()
        ..remove('homeBandGlassMaterial')
        ..['liquidGlassHomeChromeEnabled'] = true;
      expect(TimetableSettings.fromJson(scopeOn).homeBandGlassMaterial, 'liquid');

      final scopeOff = Map<String, dynamic>.from(scopeOn)
        ..['liquidGlassHomeChromeEnabled'] = false;
      expect(
        TimetableSettings.fromJson(scopeOff).homeBandGlassMaterial,
        'liquid',
      );

      final mirrorGaussian = TimetableSettings.defaults().toJson()
        ..remove('homeBandGlassMaterial')
        ..['homeChromeGlassMaterial'] = 'gaussian';
      expect(
        TimetableSettings.fromJson(mirrorGaussian).homeBandGlassMaterial,
        'liquid',
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

    test('新键优先于旧轴，不被迁移覆盖', () {
      // 新键取「实体」才与旧轴（会迁出液态）可区分，否则测不出优先级。
      final json = TimetableSettings.defaults()
          .copyWith(homeBandGlassMaterial: 'solid')
          .toJson()
        ..['homeChromeGlassMaterial'] = 'liquid'
        ..['liquidGlassHomeChromeEnabled'] = true
        ..['frostedGlassMode'] = 'liquid';
      final restored = TimetableSettings.fromJson(json);
      expect(restored.homeBandGlassMaterial, 'solid');
    });
  });

  group('子页顶栏模糊风格（2026-09-23 起锁死为渐进）', () {
    test('设置里不再有这一档，存量 JSON 里的旧值一律被忽略', () {
      // 用户口径「子页顶部可以锁定渐变模糊」：这条轴整体撤下 —— 设置模型不再
      // 有 subpageHeaderBlurStyle 字段，渲染侧恒为渐进（见
      // `HyperosBlurredHeader.subpageHeaderBlurStyleOf`，接线钉在
      // `header_blur_style_wiring_test`）。
      //
      // 这条钉的是**老档不炸**：盘上还带着旧键的配置读进来要照常工作，
      // 两个旧键（新键与更早的 headerBlurStyle）都当未知键忽略。
      final json = TimetableSettings.defaults().toJson()
        ..['subpageHeaderBlurStyle'] = 'gaussian'
        ..['headerBlurStyle'] = 'gaussian';
      final restored = TimetableSettings.fromJson(json);

      expect(
        restored.homeBandGlassMaterial,
        TimetableSettings.defaults().homeBandGlassMaterial,
        reason: '旧键不该影响别的字段',
      );
    });
  });
}
