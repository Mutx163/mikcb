import 'timetable_settings.dart';
import '../ui/hyperos/frosted/frosted_appearance.dart' show FrostedGlassMode;

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

  /// 基础磨砂（坞在范围关闭时的回退，以及弹窗家族被技术 / 系统门禁摘下来时
  /// 的玻璃观感回落）。
  frost,

  /// 渐进模糊（顶栏风格 · 渐进；也用于高斯卡片表面的展示标签）。
  frostProgressive,

  /// 高斯模糊（顶栏风格 · 高斯）。
  frostGaussian,

  /// 液态玻璃（高级材质；也是课程卡片「液态玻璃」档的材质）。
  ///
  /// 课程卡片那一档与弹层/顶栏/玻璃坞走的是**同一份**折射着色器，因此共用
  /// 一个枚举值：它在「各表面当前材质」地图卡上要显示的就是「液态玻璃」，
  /// 没有第二个名字。
  liquidGlass,
}

SurfaceMaterial _advancedSurfaceMaterial(
  TimetableSettings s,
  bool scopeOn,
) {
  final advanced = switch (s.frostedGlassMode) {
    FrostedGlassMode.liquidGlass => SurfaceMaterial.liquidGlass,
    _ => null,
  };
  if (advanced != null) {
    if (scopeOn) {
      return advanced;
    }
    return s.frostedBlurEnabled ? SurfaceMaterial.frost : SurfaceMaterial.solid;
  }
  return s.frostedBlurEnabled ? SurfaceMaterial.frost : SurfaceMaterial.solid;
}

/// 首页玻璃带（标题栏 + 星期栏共用一条带）。
///
/// 材质独立选择（2026-09-12）：`follow`（跟随默认）/ `liquid` / `solid` 三档
/// （2026-09-23 起）。这里消费**生效值**
/// [TimetableSettings.homeBandGlassMaterialEffective] —— `follow` 已按默认档
/// 解析：实体 → 实心带；高斯 → 磨砂带（渐进模糊链路，即该带液态化之前的观感）；
/// 液态 → 液态带（沿用模糊总开关的 useBlur 门，关或系统降级 → 实体衬底，与
/// 渲染侧 build 同口径）。「顶栏玻璃」关 → 不渲染。
SurfaceMaterial homeBandSurfaceMaterial(TimetableSettings s) {
  if (!s.homePageHeaderBlurEnabled) {
    return SurfaceMaterial.off;
  }
  return switch (s.homeBandGlassMaterialEffective) {
    'solid' => SurfaceMaterial.solid,
    // 跟随默认解析出的磨砂带：必然处于模糊开启状态（解析条件保证），走渐进。
    'frost' => SurfaceMaterial.frostProgressive,
    _ => s.frostedBlurEnabled
        ? SurfaceMaterial.liquidGlass
        : SurfaceMaterial.solid,
  };
}

/// 子页顶栏（设置等 HyperosSubpage 外壳）。永不走高级材质。
///
/// 2026-09-23 起**风格锁死为渐进模糊**（设置里不再有这一档），所以这里只剩
/// 「模糊开着 / 关掉」两种结果 —— 模糊开了就一定是渐进，不会再是高斯。
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

/// 课程卡片。玻璃档依赖背景模糊，模糊总开关关时渲染侧回退实体
/// （effectiveCourseCardSurfaceStyle 的 gaussianBlurAvailable 口径）。
SurfaceMaterial courseCardSurfaceMaterial(TimetableSettings s) {
  if (s.courseCardSurfaceStyle == CourseCardSurfaceStyle.solid) {
    return SurfaceMaterial.solid;
  }
  if (!s.frostedBlurEnabled) {
    return SurfaceMaterial.solid;
  }
  return s.courseCardSurfaceStyle == CourseCardSurfaceStyle.liquidGlass
      ? SurfaceMaterial.liquidGlass
      : SurfaceMaterial.frostGaussian;
}
