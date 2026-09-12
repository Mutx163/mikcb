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

/// 写回「首页顶栏玻璃带材质」（独立自由选择，2026-09-12：渐进磨砂 / 高斯
/// 磨砂 / 柔光 / 液态 / 实体）。
///
/// 顶栏材质不再跟随全局玻璃模式或「作用范围」开关；柔光/液态只通过各自
/// 的范围开关作用于弹窗、玻璃坞等其他表面。
TimetableSettings applyHomeBandGlassMaterial(
  TimetableSettings settings,
  String material,
) => settings.copyWith(homeBandGlassMaterial: material);

/// 写回「子页顶栏模糊风格」（渐进模糊 / 高斯模糊）。
///
/// 子页顶栏（设置等 HyperosSubpage 页）与首页玻璃带材质相互独立；子页
/// 永不走高级材质，此风格始终生效。
TimetableSettings applySubpageChromeBlurStyle(
  TimetableSettings settings,
  HeaderBlurStyle style,
) => settings.copyWith(subpageHeaderBlurStyle: style);

