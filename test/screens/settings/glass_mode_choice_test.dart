import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/glass_mode_choice.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/ui/hyperos/frosted/frosted_appearance.dart';

void main() {
  TimetableSettings settings({
    bool blurEnabled = true,
    FrostedGlassMode mode = FrostedGlassMode.frosted,
  }) => TimetableSettings(
    sections: const [],
    frostedBlurEnabled: blurEnabled,
    frostedGlassMode: mode,
  );

  group('glassModeChoiceOf', () {
    test('模糊关闭 → 实体卡片', () {
      expect(
        glassModeChoiceOf(settings(blurEnabled: false)),
        GlassModeChoice.solid,
      );
    });

    test('模糊关 + 液态模式（存量混搭）仍推导为实体卡片', () {
      expect(
        glassModeChoiceOf(
          settings(blurEnabled: false, mode: FrostedGlassMode.liquidGlass),
        ),
        GlassModeChoice.solid,
      );
    });

    test('开模糊 + 液态模式 → 液态玻璃', () {
      expect(
        glassModeChoiceOf(settings(mode: FrostedGlassMode.liquidGlass)),
        GlassModeChoice.liquidGlass,
      );
    });

    test('开模糊 + 存量 frosted / gaussian → 高斯模糊', () {
      expect(glassModeChoiceOf(settings()), GlassModeChoice.gaussian);
      expect(
        glassModeChoiceOf(settings(mode: FrostedGlassMode.gaussian)),
        GlassModeChoice.gaussian,
      );
    });

    test('模糊关 + 液态模式（存量混搭）仍推导为实体卡片', () {
      expect(
        glassModeChoiceOf(
          settings(blurEnabled: false, mode: FrostedGlassMode.liquidGlass),
        ),
        GlassModeChoice.solid,
      );
    });
  });

  group('applyGlassModeChoice', () {
    test('实体卡片：关模糊并把玻璃模式归位非液态（从液态切换不残留液态）', () {
      final result = applyGlassModeChoice(
        settings(mode: FrostedGlassMode.liquidGlass),
        GlassModeChoice.solid,
      );
      expect(result.frostedBlurEnabled, isFalse);
      expect(result.frostedGlassMode, FrostedGlassMode.frosted);
    });

    test('高斯模糊：开模糊 + gaussian 模式', () {
      final result = applyGlassModeChoice(
        settings(blurEnabled: false),
        GlassModeChoice.gaussian,
      );
      expect(result.frostedBlurEnabled, isTrue);
      expect(result.frostedGlassMode, FrostedGlassMode.gaussian);
    });

    test('液态玻璃：开模糊 + liquidGlass 模式', () {
      final result = applyGlassModeChoice(
        settings(blurEnabled: false),
        GlassModeChoice.liquidGlass,
      );
      expect(result.frostedBlurEnabled, isTrue);
      expect(result.frostedGlassMode, FrostedGlassMode.liquidGlass);
    });

    test('三档往返切换后状态自洽', () {
      var s = settings(mode: FrostedGlassMode.liquidGlass);
      s = applyGlassModeChoice(s, GlassModeChoice.solid);
      expect(glassModeChoiceOf(s), GlassModeChoice.solid);
      s = applyGlassModeChoice(s, GlassModeChoice.gaussian);
      expect(glassModeChoiceOf(s), GlassModeChoice.gaussian);
      s = applyGlassModeChoice(s, GlassModeChoice.liquidGlass);
      expect(glassModeChoiceOf(s), GlassModeChoice.liquidGlass);
      s = applyGlassModeChoice(s, GlassModeChoice.solid);
      expect(glassModeChoiceOf(s), GlassModeChoice.solid);
    });

    test('液态玻璃：把底栏作用范围开关一并打开', () {
      // 液态被定位成「整机材质」：选中它时用户期待整个软件都变。其余两档不动
      // 这个开关（坞保持用户上一次的取舍），所以这条断言同时钉住了对称性的
      // 边界——只有液态这一档会写它。弹窗家族那四个开关已删除（锁标准档）。
      final off = settings().copyWith(liquidGlassDockEnabled: false);
      final result = applyGlassModeChoice(off, GlassModeChoice.liquidGlass);
      expect(result.liquidGlassDockEnabled, isTrue);
    });

    test('其余两档不碰作用范围开关', () {
      final off = settings().copyWith(liquidGlassDockEnabled: false);
      for (final choice in const [
        GlassModeChoice.solid,
        GlassModeChoice.gaussian,
      ]) {
        final result = applyGlassModeChoice(off, choice);
        expect(
          result.liquidGlassDockEnabled,
          isFalse,
          reason: '$choice 不该动作用范围开关',
        );
      }
    });

    test('三档往返切换后状态自洽', () {
      var s = settings(mode: FrostedGlassMode.liquidGlass);
      for (final choice in GlassModeChoice.values) {
        s = applyGlassModeChoice(s, choice);
        expect(
          glassModeChoiceOf(s),
          choice,
          reason: '写回 $choice 后必须能原样读回来',
        );
      }
    });
  });

  test('存量 translucent 持久化值经 fromValue 归一为 frosted（渲染等价）', () {
    expect(
      FrostedGlassModeX.fromValue('translucent'),
      FrostedGlassMode.frosted,
    );
    expect(FrostedGlassModeX.fromValue('gaussian'), FrostedGlassMode.gaussian);
    expect(FrostedGlassModeX.fromValue(null), FrostedGlassMode.frosted);
  });

  test('存量 refractionGlass 持久化值读作液态玻璃（旧档位已并入）', () {
    expect(
      FrostedGlassModeX.fromValue('refractionGlass'),
      FrostedGlassMode.liquidGlass,
    );
    expect(
      FrostedGlassModeX.fromValue('liquidGlass'),
      FrostedGlassMode.liquidGlass,
    );
  });

  test('存量 softGlass 持久化值读作液态玻璃（2026-09-22 柔光档退场）', () {
    // 柔光玻璃从用户可选材质里撤下（引导页那一档已删），存量值一律读作液态 ——
    // 这正是外观编辑器此前对它的显示口径（归桶成液态），改成读入即迁移之后，
    // 界面说液态、渲染就真的画液态。撤下之前这里断言的是「读回 softGlass」。
    // 见 .agents/notes/implemented/simplification/2026-09-22-retire-soft-glass-mode.md
    expect(
      FrostedGlassModeX.fromValue('softGlass'),
      FrostedGlassMode.liquidGlass,
    );
  });
}
