import 'header_blur_style.dart';
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

  /// 实体（模糊总开关关、高级材质范围关的回退、高斯卡在模糊关时的降级）。
  solid,

  /// 基础磨砂（坞 / 弹窗 / 选择按钮等表面的均匀高斯磨砂）。
  frost,

  /// 渐进模糊（顶栏风格 · 渐进；也用于高斯卡片表面的展示标签）。
  frostProgressive,

  /// 高斯模糊（顶栏风格 · 高斯）。
  frostGaussian,

  /// 柔光玻璃（高级材质）。
  softGlass,

  /// 液态玻璃（高级材质）。
  liquidGlass,
}

/// 范围开关关闭时高级材质表面的回退形态。
///
/// 渲染侧各表面回退不同：弹窗面板（HyperosSheetFrame / 弹窗气泡）按 solid
/// 分支回**实体**；玻璃坞与壁纸选点按钮回**磨砂**（见 timetable_screen
/// 「范围关闭时回磨砂圆片」与 wallpaper_position_picker_sheet 的磨砂分支）。
enum _AdvancedFallback { frost, solid }

SurfaceMaterial _advancedSurfaceMaterial(
  TimetableSettings s,
  bool scopeOn,
  _AdvancedFallback fallback,
) {
  final advanced = switch (s.frostedGlassMode) {
    FrostedGlassMode.softGlass => SurfaceMaterial.softGlass,
    FrostedGlassMode.liquidGlass => SurfaceMaterial.liquidGlass,
    _ => null,
  };
  if (advanced != null) {
    if (scopeOn) {
      return advanced;
    }
    return fallback == _AdvancedFallback.frost && s.frostedBlurEnabled
        ? SurfaceMaterial.frost
        : SurfaceMaterial.solid;
  }
  return s.frostedBlurEnabled ? SurfaceMaterial.frost : SurfaceMaterial.solid;
}

/// 首页玻璃带（标题栏 + 星期栏共用一条带）。
///
/// 「顶栏玻璃」关 → 不渲染；模糊总开关关 → 实体衬底（高级材质也不上，
/// 见 home_page_region_blur 的 `useBlur ? advanced : null` 门）；全局高级
/// 材质 + 「作用范围 → 首页玻璃带」开 → 跟随全局；否则按顶栏模糊风格。
SurfaceMaterial homeBandSurfaceMaterial(TimetableSettings s) {
  if (!s.homePageHeaderBlurEnabled) {
    return SurfaceMaterial.off;
  }
  if (!s.frostedBlurEnabled) {
    return SurfaceMaterial.solid;
  }
  if (s.liquidGlassHomeChromeEnabled) {
    if (s.frostedGlassMode == FrostedGlassMode.softGlass) {
      return SurfaceMaterial.softGlass;
    }
    if (s.frostedGlassMode == FrostedGlassMode.liquidGlass) {
      return SurfaceMaterial.liquidGlass;
    }
  }
  return s.headerBlurStyle == HeaderBlurStyle.gaussian
      ? SurfaceMaterial.frostGaussian
      : SurfaceMaterial.frostProgressive;
}

/// 子页顶栏（设置等 HyperosSubpage 外壳）。永不走高级材质，风格始终生效。
SurfaceMaterial subpageHeaderSurfaceMaterial(TimetableSettings s) {
  if (!s.frostedBlurEnabled) {
    return SurfaceMaterial.solid;
  }
  return s.subpageHeaderBlurStyle == HeaderBlurStyle.gaussian
      ? SurfaceMaterial.frostGaussian
      : SurfaceMaterial.frostProgressive;
}

/// 玻璃坞（含坞内圆钮）。
SurfaceMaterial dockSurfaceMaterial(TimetableSettings s) =>
    _advancedSurfaceMaterial(s, s.liquidGlassDockEnabled, _AdvancedFallback.frost);

/// 底部弹窗与对话框（showHyperosSheet 系）。
SurfaceMaterial sheetDialogSurfaceMaterial(TimetableSettings s) =>
    _advancedSurfaceMaterial(
      s,
      s.liquidGlassSheetDialogEnabled,
      _AdvancedFallback.solid,
    );

/// 对话式全屏选择面板。
SurfaceMaterial selectSheetSurfaceMaterial(TimetableSettings s) =>
    _advancedSurfaceMaterial(
      s,
      s.liquidGlassSelectSheetEnabled,
      _AdvancedFallback.solid,
    );

/// 下拉选择小弹窗（设置行值选择气泡）。
SurfaceMaterial popupSurfaceMaterial(TimetableSettings s) =>
    _advancedSurfaceMaterial(s, s.liquidGlassPopupEnabled, _AdvancedFallback.solid);

/// 选择器按钮（壁纸选点等处的圆形按钮）。
SurfaceMaterial pickerButtonsSurfaceMaterial(TimetableSettings s) =>
    _advancedSurfaceMaterial(
      s,
      s.liquidGlassPickerButtonsEnabled,
      _AdvancedFallback.frost,
    );

/// 课程卡片。高斯卡依赖背景模糊，模糊总开关关时渲染侧回退实体
/// （resolveCourseCardSurfaceStyle 的 gaussianBlurAvailable 口径）。
SurfaceMaterial courseCardSurfaceMaterial(TimetableSettings s) {
  if (s.courseCardSurfaceStyle == CourseCardSurfaceStyle.solid) {
    return SurfaceMaterial.solid;
  }
  return s.frostedBlurEnabled ? SurfaceMaterial.frostGaussian : SurfaceMaterial.solid;
}
