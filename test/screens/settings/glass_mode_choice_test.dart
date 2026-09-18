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

    test('开模糊 + 柔光模式 → 柔光玻璃', () {
      expect(
        glassModeChoiceOf(settings(mode: FrostedGlassMode.softGlass)),
        GlassModeChoice.softGlass,
      );
    });

    test('模糊关 + 柔光模式（存量混搭）仍推导为实体卡片', () {
      expect(
        glassModeChoiceOf(
          settings(blurEnabled: false, mode: FrostedGlassMode.softGlass),
        ),
        GlassModeChoice.solid,
      );
    });

    test('开模糊 + 折射模式 → 折射玻璃', () {
      expect(
        glassModeChoiceOf(settings(mode: FrostedGlassMode.refractionGlass)),
        GlassModeChoice.refractionGlass,
      );
    });

    test('模糊关 + 折射模式（存量混搭）仍推导为实体卡片', () {
      expect(
        glassModeChoiceOf(
          settings(blurEnabled: false, mode: FrostedGlassMode.refractionGlass),
        ),
        GlassModeChoice.solid,
      );
    });
  });

  group('applyGlassModeChoice', () {
    test('实体卡片：关模糊并把玻璃模式归位非液态（从液态切换不残留折射）', () {
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

    test('柔光玻璃：开模糊 + softGlass 模式（底栏自动跟随，无需另写）', () {
      final result = applyGlassModeChoice(
        settings(blurEnabled: false),
        GlassModeChoice.softGlass,
      );
      expect(result.frostedBlurEnabled, isTrue);
      expect(result.frostedGlassMode, FrostedGlassMode.softGlass);
    });

    test('液态玻璃：开模糊 + liquidGlass 模式', () {
      final result = applyGlassModeChoice(
        settings(blurEnabled: false),
        GlassModeChoice.liquidGlass,
      );
      expect(result.frostedBlurEnabled, isTrue);
      expect(result.frostedGlassMode, FrostedGlassMode.liquidGlass);
    });

    test('四档往返切换后状态自洽', () {
      var s = settings(mode: FrostedGlassMode.liquidGlass);
      s = applyGlassModeChoice(s, GlassModeChoice.solid);
      expect(glassModeChoiceOf(s), GlassModeChoice.solid);
      s = applyGlassModeChoice(s, GlassModeChoice.gaussian);
      expect(glassModeChoiceOf(s), GlassModeChoice.gaussian);
      s = applyGlassModeChoice(s, GlassModeChoice.softGlass);
      expect(glassModeChoiceOf(s), GlassModeChoice.softGlass);
      s = applyGlassModeChoice(s, GlassModeChoice.liquidGlass);
      expect(glassModeChoiceOf(s), GlassModeChoice.liquidGlass);
      s = applyGlassModeChoice(s, GlassModeChoice.solid);
      expect(glassModeChoiceOf(s), GlassModeChoice.solid);
    });

    test('折射玻璃：开模糊 + 折射模式', () {
      final result = applyGlassModeChoice(
        settings(blurEnabled: false),
        GlassModeChoice.refractionGlass,
      );
      expect(result.frostedBlurEnabled, isTrue);
      expect(result.frostedGlassMode, FrostedGlassMode.refractionGlass);
    });

    test('折射玻璃：把五个作用范围开关一并打开', () {
      // 折射被定位成「整机材质」：选中它时用户期待整个软件都变。其余四档不动
      // 这些开关（各表面保持用户上一次的取舍），所以这条断言同时钉住了对称性
      // 的边界——只有折射这一档会写它们。
      final off = settings().copyWith(
        liquidGlassPopupEnabled: false,
        liquidGlassSelectSheetEnabled: false,
        liquidGlassSheetDialogEnabled: false,
        liquidGlassDockEnabled: false,
        liquidGlassPickerButtonsEnabled: false,
      );
      final result = applyGlassModeChoice(off, GlassModeChoice.refractionGlass);
      expect(result.liquidGlassPopupEnabled, isTrue);
      expect(result.liquidGlassSelectSheetEnabled, isTrue);
      expect(result.liquidGlassSheetDialogEnabled, isTrue);
      expect(result.liquidGlassDockEnabled, isTrue);
      expect(result.liquidGlassPickerButtonsEnabled, isTrue);
    });

    test('其余四档不碰作用范围开关', () {
      final off = settings().copyWith(
        liquidGlassPopupEnabled: false,
        liquidGlassSelectSheetEnabled: false,
        liquidGlassSheetDialogEnabled: false,
        liquidGlassDockEnabled: false,
        liquidGlassPickerButtonsEnabled: false,
      );
      for (final choice in const [
        GlassModeChoice.solid,
        GlassModeChoice.gaussian,
        GlassModeChoice.softGlass,
        GlassModeChoice.liquidGlass,
      ]) {
        final result = applyGlassModeChoice(off, choice);
        expect(
          result.liquidGlassPopupEnabled,
          isFalse,
          reason: '$choice 不该动作用范围开关',
        );
        expect(result.liquidGlassDockEnabled, isFalse);
      }
    });

    test('五档往返切换后状态自洽', () {
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
    expect(
      FrostedGlassModeX.fromValue('softGlass'),
      FrostedGlassMode.softGlass,
    );
    expect(FrostedGlassModeX.fromValue(null), FrostedGlassMode.frosted);
  });
}
