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
//
// 2026-09-30：高斯模糊作为**全局档**退场（见
// `.agents/notes/implemented/simplification/2026-09-30-retire-gaussian-material-tier.md`）。
// 对本文件的两处影响：①「跟随默认」的解析只剩模糊总开关一个判据（原来还分
// 「默认档高斯 → 磨砂带」那一支）；②2026-09-12 那段「旧轴 → homeBandGlassMaterial」
// 迁移的三个分支全部收敛到缺键默认值 `liquid`，整段删除，只留一条
// 「缺新键即液态」的正钉。老键 `frostedGlassMode` / `homeChromeGlassMaterial` /
// `liquidGlassHomeChromeEnabled` 现在都按未知键忽略。
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/glass_mode_choice.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/ui/hyperos/frosted/frosted_appearance.dart';

void main() {
  group('首页顶栏玻璃带材质：跟随默认 / 液态 / 实体三档', () {
    test('出厂值仍是单独指定液态（观感与引入「跟随」前一致）', () {
      expect(TimetableSettings.defaults().homeBandGlassMaterial, 'liquid');
      expect(FrostedAppearance.defaults.homeBandGlassMaterial, 'liquid');
      expect(TimetableSettings.homeBandGlassMaterialValues, [
        'follow',
        'liquid',
        'solid',
      ]);
    });

    test('非三档取值一律归到液态：三个存量中间档 / 非法值 / 缺键', () {
      for (final legacy in ['progressive', 'gaussian', 'soft', 'nope', null]) {
        expect(
          TimetableSettings.sanitizeHomeBandGlassMaterial(legacy),
          'liquid',
          reason: '$legacy 必须归到液态 —— 界面只承诺「跟随默认 / 实体 / 液态」',
        );
      }
      expect(TimetableSettings.sanitizeHomeBandGlassMaterial('solid'), 'solid');
      expect(
        TimetableSettings.sanitizeHomeBandGlassMaterial('follow'),
        'follow',
      );
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

    test('frostedAppearance 映射顶栏材质（显式档原样，follow 解析成生效值）', () {
      final settings = TimetableSettings.defaults().copyWith(
        homeBandGlassMaterial: 'solid',
      );
      expect(settings.frostedAppearance.homeBandGlassMaterial, 'solid');
    });

    group('follow 生效值解析（homeBandGlassMaterialEffective）', () {
      test('显式档不受影响，原样返回', () {
        for (final material in ['liquid', 'solid']) {
          final s = TimetableSettings.defaults().copyWith(
            homeBandGlassMaterial: material,
            frostedBlurEnabled: false,
          );
          expect(s.homeBandGlassMaterialEffective, material, reason: material);
        }
      });

      test('跟随默认：模糊开 → 液态带，模糊关 → 实心带', () {
        // 2026-09-30 高斯模糊退场后「跟随」只剩这一个判据（此前还有「默认档是
        // 高斯 → 磨砂带」那一支，那一支随枚举一起没了）。
        final on = TimetableSettings.defaults().copyWith(
          homeBandGlassMaterial: 'follow',
          frostedBlurEnabled: true,
        );
        final off = on.copyWith(frostedBlurEnabled: false);
        expect(on.homeBandGlassMaterialEffective, 'liquid');
        expect(off.homeBandGlassMaterialEffective, 'solid');
      });

      test('跟随默认解析进外观对象：下游拿到的永远是生效值', () {
        final follow = TimetableSettings.defaults().copyWith(
          homeBandGlassMaterial: 'follow',
          frostedBlurEnabled: true,
        );
        expect(follow.frostedAppearance.homeBandGlassMaterial, 'liquid');
        // 生效值不写回存储：原字段仍是 follow，JSON 往返不丢「跟随」这个选择。
        expect(follow.homeBandGlassMaterial, 'follow');
        expect(
          TimetableSettings.fromJson(follow.toJson()).homeBandGlassMaterial,
          'follow',
        );
      });
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
        frostedBlurEnabled: false,
      );
      final s = applyHomeBandGlassMaterial(base, 'solid');
      expect(s.homeBandGlassMaterial, 'solid');
      expect(
        s.frostedBlurEnabled,
        isFalse,
        reason: '顶栏那把轴与模糊总开关互不影响',
      );
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

  group('顶栏材质：缺新键即按出厂值（旧的「旧轴迁移」已删）', () {
    // 2026-09-12 那段迁移（输入是 `homeChromeGlassMaterial` /
    // `liquidGlassHomeChromeEnabled` / `frostedGlassMode`）的三个分支，在高斯模糊
    // 2026-09-30 退场后**全部收敛到 `liquid`** —— 而 `liquid` 正是缺键时的出厂值，
    // 于是整段迁移连同那两个只被它读过的旧键一起删除（见
    // `TimetableSettings.fromJson` 开头）。这里留一条钉：老数据缺新键时读到的
    // 仍是液态带，观感与迁移那套一模一样。
    test('缺新键 + 各种旧轴组合，一律读成液态带', () {
      final base = TimetableSettings.defaults().toJson()
        ..remove('homeBandGlassMaterial');
      expect(
        TimetableSettings.fromJson(base).homeBandGlassMaterial,
        'liquid',
        reason: '全新安装',
      );

      for (final legacy in ['liquid', 'gaussian', 'progressive', 'soft']) {
        final json = Map<String, dynamic>.from(base)
          ..['homeChromeGlassMaterial'] = legacy;
        for (final scope in [true, false]) {
          final scoped = Map<String, dynamic>.from(json)
            ..['liquidGlassHomeChromeEnabled'] = scope;
          expect(
            TimetableSettings.fromJson(scoped).homeBandGlassMaterial,
            'liquid',
            reason: 'homeChromeGlassMaterial=$legacy, 范围开=$scope',
          );
        }
      }
    });

    test('新键优先，不被任何旧轴覆盖', () {
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
