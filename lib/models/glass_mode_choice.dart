import 'timetable_settings.dart';

/// 玻璃材质档（设置页「默认材质」与引导页「视觉效果」共用的映射语义）：
/// **实体卡片 / 液态玻璃**。
///
/// 整机只剩**一种**玻璃材质（液态玻璃）：2026-09-30 高斯模糊档退场，那一档承诺的
/// 「全局都是磨砂」从来不存在（子页顶栏锁死渐进模糊、弹窗家族锁标准液态、课程
/// 卡片另有自己一档）。所以这两档问的其实是「要不要玻璃」——不模糊（实体卡片）
/// / 模糊 + 圆角 SDF 边缘折射（液态玻璃）。「磨砂」仍作为**渲染回落与个别表面**
/// 存在（着色器不可用时的回落带、子页顶栏、课程卡片自己那档），只是不再是整机档位。
enum GlassModeChoice { solid, liquidGlass }

/// 从当前设置推导玻璃材质档：模糊关 → 实体卡片；否则 → 液态玻璃。
GlassModeChoice glassModeChoiceOf(TimetableSettings settings) =>
    settings.frostedBlurEnabled
    ? GlassModeChoice.liquidGlass
    : GlassModeChoice.solid;

/// 把玻璃材质档写回设置。
///
/// 实体卡片 = 关闭模糊总开关；液态玻璃 = 打开它。仅此两件事。
///
/// 底栏材质跟随全局（见 `_buildGlassDockBar`），不再有独立开关：想让坞单独走
/// 磨砂，用唯一留着的「作用范围 → 玻璃坞」开关（液态档下它是唯一的例外口）。
///
/// 液态档顺带打开那把开关（见分支内注释）；顶栏带那把轴不参与本函数，由
/// [applyHomeBandGlassMaterial] 单独写。
TimetableSettings applyGlassModeChoice(
  TimetableSettings settings,
  GlassModeChoice choice,
) => switch (choice) {
  GlassModeChoice.solid => settings.copyWith(frostedBlurEnabled: false),
  GlassModeChoice.liquidGlass => settings.copyWith(
    frostedBlurEnabled: true,
    // 液态是「整机材质」，选中它时用户期待整个软件都变：连同唯一保留的
    // 「作用范围 → 底栏」开关一起打开。弹窗家族的四个开关已删除（那些表面
    // 锁标准档，恒为玻璃，没有开关可开）。另一档不动坞的取舍。
    liquidGlassDockEnabled: true,
  ),
};

/// 写回「首页顶栏玻璃带材质」（独立自由选择，2026-09-12）。
///
/// 2026-09-23 起这个轴是「跟随默认 / 实体 / 液态」三档：写入口一律过一遍
/// [TimetableSettings.sanitizeHomeBandGlassMaterial]，非三档取值（含历史
/// 中间档）都落到液态，免得界面与渲染再次错位。「跟随默认」的解析在
/// [TimetableSettings.homeBandGlassMaterialEffective]，渲染层只消费生效值。
///
/// 顶栏材质与「作用范围」开关互不影响；液态只通过各自的范围开关
/// 作用于弹窗、玻璃坞等其他表面。
TimetableSettings applyHomeBandGlassMaterial(
  TimetableSettings settings,
  String material,
) => settings.copyWith(
  homeBandGlassMaterial: TimetableSettings.sanitizeHomeBandGlassMaterial(
    material,
  ),
);
