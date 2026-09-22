import '../ui/hyperos/frosted/frosted_appearance.dart';

import 'header_blur_style.dart';
import 'timetable_settings.dart';

/// 玻璃模式三档选择（设置页「玻璃模式」与引导页「视觉效果」共用的映射
/// 语义）：**实体卡片 / 磨砂玻璃 / 液态玻璃**。
///
/// 历史上 FrostedGlassMode 有过更多档（经典磨砂/半透明/柔光…），其中大部分
/// 渲染链路完全相同（BackdropFilter + tint，差别只在有没有模糊），用户无从
/// 选起；现将「启用模糊」总开关并入档位，只留三种真实观感：
/// 不模糊（实体）/ 模糊（磨砂）/ 模糊 + 折射（液态）。
enum GlassModeChoice { solid, gaussian, liquidGlass }

/// 从当前设置推导玻璃模式档位：模糊关 → 实体卡片；液态 → 液态玻璃；
/// 其余（磨砂 / 存量档）→ 磨砂玻璃。
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
/// 弹窗仍是液态」的残留。磨砂 / 液态玻璃档均保证模糊开启。
///
/// 底栏不再由这里写入独立材质：底栏材质现在**跟随全局**
/// （见 `_buildGlassDockBar`），不再会出现「全局磨砂 + 底栏液态」这类脱钩。
///
/// 液态档额外打开唯一保留的「作用范围 → 底栏」开关（见分支内注释）；**顶栏两处的写穿**
/// （首页玻璃带材质、子页顶栏风格）与液态的顶栏渲染分支同批落地，见
/// `.agents/notes/implemented/architecture/2026-09-18-liquid-glass-surface.md`。
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
    // 液态是「整机材质」，选中它时用户期待整个软件都变：连同唯一保留的
    // 「作用范围 → 底栏」开关一起打开。弹窗家族的四个开关已删除（那些表面
    // 锁标准档，恒为玻璃，没有开关可开）。其余两档不动坞的取舍。
    liquidGlassDockEnabled: true,
  ),
};

/// 写回「首页顶栏玻璃带材质」（独立自由选择，2026-09-12）。
///
/// 2026-09-20 起这个轴只有「液态玻璃 / 实体」两档（与外观编辑器里那两个选项
/// 逐字一致）：写入口一律过一遍 [TimetableSettings.sanitizeHomeBandGlassMaterial]，
/// 非 `solid` 的取值（含历史中间档）都落到液态，免得界面与渲染再次错位。
///
/// 顶栏材质不跟随全局玻璃模式或「作用范围」开关；液态只通过各自的范围开关
/// 作用于弹窗、玻璃坞等其他表面。
TimetableSettings applyHomeBandGlassMaterial(
  TimetableSettings settings,
  String material,
) => settings.copyWith(
  homeBandGlassMaterial: TimetableSettings.sanitizeHomeBandGlassMaterial(
    material,
  ),
);

/// 写回「子页顶栏模糊风格」（渐进模糊 / 高斯模糊）。
///
/// 子页顶栏（设置等 HyperosSubpage 页）与首页玻璃带材质相互独立；子页
/// 永不走高级材质，此风格始终生效。
TimetableSettings applySubpageChromeBlurStyle(
  TimetableSettings settings,
  HeaderBlurStyle style,
) => settings.copyWith(subpageHeaderBlurStyle: style);
