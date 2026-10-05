import 'timetable_settings.dart';
import '../utils/home_page_background.dart';

/// 某个表面当前生效的材质态。
///
/// 与渲染侧门控**同口径**的纯推导（见各工厂注释对应的渲染分支）；用于
/// 「各表面当前材质」地图卡。系统级降级（无障碍 / 降动效 / 不支持 shader）
/// 依设备实时状态而定，不在此推导范围内。
enum SurfaceMaterial {
  /// 表面已关闭（如「顶栏玻璃」总开关关掉后首页玻璃带不再渲染）。
  off,

  /// 实体（模糊总开关关、「作用范围 → 底栏」关的回退、高斯卡在模糊关时的降级）。
  solid,

  /// 磨砂（BackdropFilter 观感）。高斯模糊档 2026-09-30 退场后，它只剩两处来源：
  /// 玻璃坞的作用范围开关关闭时的回退，以及弹窗家族被技术 / 系统门禁摘下来时
  /// 的回落观感。
  frost,

  /// 渐进模糊（子页顶栏 2026-09-23 起锁死的那一档；也用于高斯卡片表面的展示标签）。
  frostProgressive,

  /// 高斯模糊（课程卡片自己那档的展示标签）。
  frostGaussian,

  /// 液态玻璃（高级材质；也是课程卡片「液态玻璃」档的材质）。
  ///
  /// 课程卡片那一档与弹层/顶栏/玻璃坞走的是**同一份**折射着色器，因此共用
  /// 一个枚举值：它在「各表面当前材质」地图卡上要显示的就是「液态玻璃」，
  /// 没有第二个名字。
  liquidGlass,
}

/// 走液态玻璃、且作用范围开关（[scopeOn]）允许的表面。
///
/// 2026-09-30 高斯模糊退场后，整机不再有第二种玻璃材质，于是判据只剩两条：
/// 模糊总开关（关 → 谁都不液态）与这把作用范围开关。
///
/// ⚠️ **模糊总开关必须排在最前面**：高斯档存在时，模糊总开关关掉的同时还会把
/// 全局档位归位成非液态（`applyGlassModeChoice(solid)` 的旧行为），液态判据因此
/// 顺带被关掉。退场后那层归位没了，若这里不先看模糊总开关，「实体卡片」档下
/// 作用范围开着的坞会被报成液态玻璃 —— 与渲染侧
/// （`LiquidGlassSurface.isAvailable` → `backdropBlurEnabled`）直接矛盾。
SurfaceMaterial _advancedSurfaceMaterial(TimetableSettings s, bool scopeOn) {
  if (!s.frostedBlurEnabled) {
    return SurfaceMaterial.solid;
  }
  return scopeOn ? SurfaceMaterial.liquidGlass : SurfaceMaterial.frost;
}

/// 首页玻璃带（标题栏 + 星期栏共用一条带）。
///
/// 材质独立选择（2026-09-12）：`follow`（跟随全局）/ `liquid` / `solid` 三档。
/// 这里消费**生效值**
/// [TimetableSettings.homeBandGlassMaterialEffective] —— `follow` 已按模糊总开关
/// 解析：模糊开 → 液态带，模糊关 → 实心带。液态带在引擎没有 shader 后端时
/// 自己回落成磨砂带，那是渲染期的事，本推导不参与（故值域里没有磨砂）。
/// 「顶栏玻璃」关 → 不渲染。
SurfaceMaterial homeBandSurfaceMaterial(TimetableSettings s) {
  if (!s.homePageHeaderBlurEnabled) {
    return SurfaceMaterial.off;
  }
  return switch (s.homeBandGlassMaterialEffective) {
    'solid' => SurfaceMaterial.solid,
    _ => s.frostedBlurEnabled
        ? SurfaceMaterial.liquidGlass
        : SurfaceMaterial.solid,
  };
}

/// 子页顶栏（设置等 HyperosSubpage 外壳）。不走液态玻璃。
///
/// 2026-09-23 起**风格锁死为渐进模糊**（设置里不再有这一档），所以这里只剩
/// 「模糊开着 / 关掉」两种结果 —— 模糊开了就一定是渐进。
SurfaceMaterial subpageHeaderSurfaceMaterial(TimetableSettings s) =>
    s.frostedBlurEnabled
    ? SurfaceMaterial.frostProgressive
    : SurfaceMaterial.solid;

/// 玻璃坞（含坞内圆钮）：跟随用户档位，「作用范围 → 底栏」关闭 → 磨砂。
SurfaceMaterial dockSurfaceMaterial(TimetableSettings s) =>
    _advancedSurfaceMaterial(s, s.liquidGlassDockEnabled);

/// 弹窗家族（底部弹窗与对话框 / 对话式全屏选择面板 / 下拉小弹窗 / 壁纸选点
/// 按钮）：**恒为液态玻璃**，与用户设置无关 —— 自 2026-09-19 起这些小件锁成
/// 「永远液态玻璃的标准档」（`LiquidGlassRole.pinnedChrome`），四个「作用范围」
/// 开关已整体删除，材质不再由档位 / 开关 / 模糊总开关决定。
///
/// 设备级的 shader 后端与系统降级不在此推导范围内（见文件头）。
SurfaceMaterial pinnedChromeSurfaceMaterial() => SurfaceMaterial.liquidGlass;

/// 课程卡片。玻璃档同时依赖**可用壁纸**与全局模糊管线：渲染侧
/// （effectiveCourseCardSurfaceStyle 的 hasHomePageBackdrop 口径）在无壁纸时
/// 一律回落实体，地图这里必须同口径，否则会显示一个屏幕上看不到的档位。
SurfaceMaterial courseCardSurfaceMaterial(TimetableSettings s) {
  if (s.courseCardSurfaceStyle == CourseCardSurfaceStyle.solid) {
    return SurfaceMaterial.solid;
  }
  if (!s.frostedBlurEnabled || !hasHomePageBackdrop(s)) {
    return SurfaceMaterial.solid;
  }
  return s.courseCardSurfaceStyle == CourseCardSurfaceStyle.liquidGlass
      ? SurfaceMaterial.liquidGlass
      : SurfaceMaterial.frostGaussian;
}
