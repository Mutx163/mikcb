// 全局玻璃材质档（`GlassModeChoice`）：**两档**——实体卡片 / 液态玻璃。
//
// 2026-09-30 高斯模糊档退场（连 `FrostedGlassMode` 枚举一起删），理由与迁移边界见
// `.agents/notes/implemented/simplification/2026-09-30-retire-gaussian-material-tier.md`。
// 退场之后这一档位唯一的输入就是模糊总开关，所以本文件大半是「两档往返自洽」；
// 真正还需要钉的是**存量数据不炸**：老键 `frostedGlassMode` 现在按未知键忽略。
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/glass_mode_choice.dart';
import 'package:university_timetable/models/timetable_settings.dart';

void main() {
  TimetableSettings settings({bool blurEnabled = true}) => TimetableSettings(
    sections: const [],
    frostedBlurEnabled: blurEnabled,
  );

  group('glassModeChoiceOf', () {
    test('模糊关闭 → 实体卡片', () {
      expect(
        glassModeChoiceOf(settings(blurEnabled: false)),
        GlassModeChoice.solid,
      );
    });

    test('模糊开启 → 液态玻璃（出厂默认档）', () {
      expect(glassModeChoiceOf(settings()), GlassModeChoice.liquidGlass);
    });

    test('只有两档，且与模糊总开关一一对应', () {
      // 这条是「高斯模糊已退场」的结构钉：多一档就红。
      expect(GlassModeChoice.values, [
        GlassModeChoice.solid,
        GlassModeChoice.liquidGlass,
      ]);
      for (final enabled in [true, false]) {
        final expected = enabled
            ? GlassModeChoice.liquidGlass
            : GlassModeChoice.solid;
        expect(
          glassModeChoiceOf(settings(blurEnabled: enabled)),
          expected,
          reason: 'frostedBlurEnabled=$enabled',
        );
      }
    });
  });

  group('applyGlassModeChoice', () {
    test('实体卡片：关掉模糊总开关', () {
      final result = applyGlassModeChoice(settings(), GlassModeChoice.solid);
      expect(result.frostedBlurEnabled, isFalse);
    });

    test('液态玻璃：打开模糊总开关', () {
      final result = applyGlassModeChoice(
        settings(blurEnabled: false),
        GlassModeChoice.liquidGlass,
      );
      expect(result.frostedBlurEnabled, isTrue);
    });

    test('两档往返切换后状态自洽', () {
      var s = settings();
      for (final choice in GlassModeChoice.values) {
        s = applyGlassModeChoice(s, choice);
        expect(
          glassModeChoiceOf(s),
          choice,
          reason: '写回 $choice 后必须能原样读回来',
        );
      }
    });

    test('液态玻璃：把底栏作用范围开关一并打开', () {
      // 液态被定位成「整机材质」：选中它时用户期待整个软件都变。另一档不动这个
      // 开关（坞保持用户上一次的取舍），所以这条断言同时钉住了不对称的边界
      // ——只有液态这一档会写它。弹窗家族那四个开关已删除（锁标准档）。
      // 高斯模糊 2026-09-30 退场后，这把开关成了液态档下**唯一**能让某个表面
      // 退回磨砂的口子，别把它也写穿。
      final off = settings().copyWith(liquidGlassDockEnabled: false);
      final result = applyGlassModeChoice(off, GlassModeChoice.liquidGlass);
      expect(result.liquidGlassDockEnabled, isTrue);
    });

    test('实体卡片不碰作用范围开关', () {
      final off = settings().copyWith(liquidGlassDockEnabled: false);
      final result = applyGlassModeChoice(off, GlassModeChoice.solid);
      expect(result.liquidGlassDockEnabled, isFalse);
    });
  });

  group('存量数据：老键按未知键忽略，不炸也不改写别的字段', () {
    // 老机器盘上仍有 `frostedGlassMode`（gaussian / liquidGlass / frosted /
    // translucent …）。字段已删，fromJson 不再解析它 —— 与
    // `headerBlurStyle` / `subpageHeaderBlurStyle` 同一条规矩。
    test('带老键的 JSON 读得进来，且不改变任何在役字段', () {
      final defaults = TimetableSettings.defaults();
      for (final legacy in ['gaussian', 'liquidGlass', 'frosted', 'nope']) {
        final json = defaults.toJson()..['frostedGlassMode'] = legacy;
        final restored = TimetableSettings.fromJson(json);

        expect(restored.frostedBlurEnabled, defaults.frostedBlurEnabled);
        expect(
          restored.homeBandGlassMaterial,
          defaults.homeBandGlassMaterial,
          reason: '老键 $legacy 不该影响顶栏带',
        );
        expect(
          restored.courseCardSurfaceStyle,
          defaults.courseCardSurfaceStyle,
          reason: '老键 $legacy 不该影响课程卡片',
        );
      }
    });

    test('往返写盘不再产生这个键', () {
      final json = TimetableSettings.defaults().toJson();
      expect(json.containsKey('frostedGlassMode'), isFalse);
    });
  });
}
