import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/glass_mode_choice.dart';
import 'package:university_timetable/models/header_blur_style.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/ui/hyperos/frosted/frosted_appearance.dart';

void main() {
  TimetableSettings settings({
    bool blurEnabled = true,
    FrostedGlassMode mode = FrostedGlassMode.frosted,
    HeaderBlurStyle headerBlurStyle = HeaderBlurStyle.gaussian,
  }) => TimetableSettings(
    sections: const [],
    frostedBlurEnabled: blurEnabled,
    frostedGlassMode: mode,
    headerBlurStyle: headerBlurStyle,
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
        glassModeChoiceOf(
          settings(mode: FrostedGlassMode.liquidGlass),
        ),
        GlassModeChoice.liquidGlass,
      );
    });

    test('开模糊 + 非液态 + headerBlurStyle=inspire → 渐进模糊', () {
      expect(
        glassModeChoiceOf(
          settings(headerBlurStyle: HeaderBlurStyle.inspire),
        ),
        GlassModeChoice.progressive,
      );
    });

    test('开模糊 + 存量 frosted / gaussian + headerBlurStyle=gaussian → 高斯模糊', () {
      expect(
        glassModeChoiceOf(settings()),
        GlassModeChoice.gaussian,
      );
      expect(
        glassModeChoiceOf(settings(mode: FrostedGlassMode.gaussian)),
        GlassModeChoice.gaussian,
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

    test('渐进模糊：开模糊 + 非液态 + inspire', () {
      final result = applyGlassModeChoice(
        settings(blurEnabled: false),
        GlassModeChoice.progressive,
      );
      expect(result.frostedBlurEnabled, isTrue);
      expect(result.frostedGlassMode, FrostedGlassMode.gaussian);
      expect(result.headerBlurStyle, HeaderBlurStyle.inspire);
      expect(result.liquidGlassHomeChromeEnabled, isFalse);
    });

    test('高斯模糊：开模糊 + gaussian 模式 + headerBlurStyle=gaussian', () {
      final result = applyGlassModeChoice(
        settings(blurEnabled: false),
        GlassModeChoice.gaussian,
      );
      expect(result.frostedBlurEnabled, isTrue);
      expect(result.frostedGlassMode, FrostedGlassMode.gaussian);
      expect(result.headerBlurStyle, HeaderBlurStyle.gaussian);
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
      s = applyGlassModeChoice(s, GlassModeChoice.progressive);
      expect(glassModeChoiceOf(s), GlassModeChoice.progressive);
      s = applyGlassModeChoice(s, GlassModeChoice.gaussian);
      expect(glassModeChoiceOf(s), GlassModeChoice.gaussian);
      s = applyGlassModeChoice(s, GlassModeChoice.liquidGlass);
      expect(glassModeChoiceOf(s), GlassModeChoice.liquidGlass);
      s = applyGlassModeChoice(s, GlassModeChoice.solid);
      expect(glassModeChoiceOf(s), GlassModeChoice.solid);
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
}
