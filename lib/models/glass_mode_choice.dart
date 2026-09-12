import '../ui/hyperos/frosted/frosted_appearance.dart';

import 'header_blur_style.dart';
import 'timetable_settings.dart';

/// 玻璃模式四档选择（设置页「玻璃模式」与引导页「视觉效果」共用的映射
/// 语义）。
///
/// 历史上 FrostedGlassMode 有 经典磨砂/高斯模糊/半透明/液态玻璃 四档，
/// 其中前三档渲染链路完全相同（BackdropFilter + tint，仅「高斯模糊」
/// 档在设置页多露出两个滑杆），用户无从选起；现将「启用模糊」总开关
/// 并入档位：实体卡片 / 高斯模糊 / 柔光玻璃 / 液态玻璃。
enum GlassModeChoice { solid, gaussian, softGlass, liquidGlass }

/// 从当前设置推导玻璃模式档位：模糊关 → 实体卡片；液态 → 液态玻璃；
/// 柔光 → 柔光玻璃；其余（含存量 frosted/gaussian）→ 高斯模糊。
GlassModeChoice glassModeChoiceOf(TimetableSettings settings) {
  if (!settings.frostedBlurEnabled) {
    return GlassModeChoice.solid;
  }
  if (settings.frostedGlassMode == FrostedGlassMode.liquidGlass) {
    return GlassModeChoice.liquidGlass;
  }
  if (settings.frostedGlassMode == FrostedGlassMode.softGlass) {
    return GlassModeChoice.softGlass;
  }
  return GlassModeChoice.gaussian;
}

/// 把玻璃模式档位写回设置。
///
/// 实体卡片在关闭模糊总开关的同时把玻璃模式归位非液态（frosted）：
/// 液态面自带模糊、不受模糊总开关约束，不归位会出现「选了实体卡片，
/// 弹窗仍是液态」的残留。高斯 / 柔光 / 液态玻璃档均保证模糊开启。
///
/// 底栏不再由这里写入独立材质：底栏材质现在**跟随全局**
/// （见 `_buildGlassDockBar`），不再会出现「全局高斯 + 底栏柔光」这类脱钩。
TimetableSettings applyGlassModeChoice(
  TimetableSettings settings,
  GlassModeChoice choice,
) => switch (choice) {
  GlassModeChoice.solid => settings.copyWith(
    frostedBlurEnabled: false,
    frostedGlassMode: FrostedGlassMode.frosted,
  ),
  GlassModeChoice.gaussian => settings.copyWith(
    frostedBlurEnabled: true,
    frostedGlassMode: FrostedGlassMode.gaussian,
  ),
  GlassModeChoice.softGlass => settings.copyWith(
    frostedBlurEnabled: true,
    frostedGlassMode: FrostedGlassMode.softGlass,
  ),
  GlassModeChoice.liquidGlass => settings.copyWith(
    frostedBlurEnabled: true,
    frostedGlassMode: FrostedGlassMode.liquidGlass,
  ),
};

/// 写回「顶栏模糊风格」（渐进模糊 / 高斯模糊）。
///
/// 同步写 `homeChromeGlassMaterial`（渐进 → progressive、高斯 → gaussian），
/// 保持存量字段与实际衰减风格一致。
///
/// **不再**关掉 `liquidGlassHomeChromeEnabled`：该开关现在是「首页玻璃带跟随
/// 全局高级材质」的作用范围开关，改模糊风格与它无关；原先一并关掉
/// 会把用户的柔光 / 液态顶栏静默降级成基础磨砂。
TimetableSettings applyChromeBlurStyle(
  TimetableSettings settings,
  HeaderBlurStyle style,
) => settings.copyWith(
  headerBlurStyle: style,
  homeChromeGlassMaterial: style == HeaderBlurStyle.gaussian
      ? 'gaussian'
      : 'progressive',
);

/// 写回「子页顶栏模糊风格」（渐进模糊 / 高斯模糊）。
///
/// 子页顶栏（设置等 HyperosSubpage 页）与首页玻璃带相互独立，不涉及
/// homeChromeGlassMaterial 同步，也不受首页「高级材质」作用范围影响。
TimetableSettings applySubpageChromeBlurStyle(
  TimetableSettings settings,
  HeaderBlurStyle style,
) => settings.copyWith(subpageHeaderBlurStyle: style);

