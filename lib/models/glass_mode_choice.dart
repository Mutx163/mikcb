import '../ui/hyperos/frosted/frosted_appearance.dart';

import 'timetable_settings.dart';

/// 玻璃模式三档选择（设置页「玻璃模式」与引导页「视觉效果」共用的映射
/// 语义）。
///
/// 历史上 FrostedGlassMode 有 经典磨砂/高斯模糊/半透明/液态玻璃 四档，
/// 其中前三档渲染链路完全相同（BackdropFilter + tint，仅「高斯模糊」
/// 档在设置页多露出两个滑杆），用户无从选起；现将「启用模糊」总开关
/// 并入档位，收敛为三档：实体卡片 / 高斯模糊 / 液态玻璃。
enum GlassModeChoice { solid, gaussian, liquidGlass }

/// 从当前设置推导玻璃模式档位：模糊关 → 实体卡片；液态模式 → 液态玻璃；
/// 其余（含存量 frosted/gaussian，渲染本就等价）→ 高斯模糊。
GlassModeChoice glassModeChoiceOf(TimetableSettings settings) {
  if (!settings.frostedBlurEnabled) {
    return GlassModeChoice.solid;
  }
  if (settings.frostedGlassMode == FrostedGlassMode.liquidGlass) {
    return GlassModeChoice.liquidGlass;
  }
  return GlassModeChoice.gaussian;
}

/// 把玻璃模式档位写回设置。
///
/// 实体卡片在关闭模糊总开关的同时把玻璃模式归位非液态（frosted）：
/// 液态面自带模糊、不受模糊总开关约束，不归位会出现「选了实体卡片，
/// 弹窗仍是液态」的残留。高斯模糊 / 液态玻璃档均保证模糊开启（从实体
/// 卡片切回时恢复采样）。
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
  GlassModeChoice.liquidGlass => settings.copyWith(
    frostedBlurEnabled: true,
    frostedGlassMode: FrostedGlassMode.liquidGlass,
  ),
};
