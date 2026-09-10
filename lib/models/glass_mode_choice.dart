import '../ui/hyperos/frosted/frosted_appearance.dart';

import 'header_blur_style.dart';
import 'timetable_settings.dart';

/// 玻璃模式选择（设置页「玻璃模式」与引导页「视觉效果」共用的映射语义）。
///
/// - [solid]：关闭模糊总开关，表面回落实体卡片。
/// - [progressive]：非液态磨砂 + inspire 渐进模糊（上浓下淡）。
/// - [gaussian]：非液态磨砂 + 均匀高斯观感（inspire 均匀档）。
/// - [liquidGlass]：液态玻璃折射面。
enum GlassModeChoice { solid, progressive, gaussian, liquidGlass }

/// 从当前设置推导玻璃模式档位。
///
/// 渐进 / 高斯共用非液态磨砂链路，由 [TimetableSettings.headerBlurStyle]
/// 区分过渡形态；液态与实体卡片优先判定。
GlassModeChoice glassModeChoiceOf(TimetableSettings settings) {
  if (!settings.frostedBlurEnabled) {
    return GlassModeChoice.solid;
  }
  if (settings.frostedGlassMode == FrostedGlassMode.liquidGlass) {
    return GlassModeChoice.liquidGlass;
  }
  return settings.headerBlurStyle == HeaderBlurStyle.inspire
      ? GlassModeChoice.progressive
      : GlassModeChoice.gaussian;
}

/// 把玻璃模式档位写回设置。
///
/// 实体卡片关闭模糊总开关并归位非液态；渐进 / 高斯保证模糊开启且非
/// 液态，并同步 [headerBlurStyle]（磨砂弹层与顶栏共用该字段）。
TimetableSettings applyGlassModeChoice(
  TimetableSettings settings,
  GlassModeChoice choice,
) => switch (choice) {
  GlassModeChoice.solid => settings.copyWith(
    frostedBlurEnabled: false,
    frostedGlassMode: FrostedGlassMode.frosted,
  ),
  GlassModeChoice.progressive => settings.copyWith(
    frostedBlurEnabled: true,
    frostedGlassMode: FrostedGlassMode.gaussian,
    headerBlurStyle: HeaderBlurStyle.inspire,
    liquidGlassHomeChromeEnabled: false,
  ),
  GlassModeChoice.gaussian => settings.copyWith(
    frostedBlurEnabled: true,
    frostedGlassMode: FrostedGlassMode.gaussian,
    headerBlurStyle: HeaderBlurStyle.gaussian,
  ),
  GlassModeChoice.liquidGlass => settings.copyWith(
    frostedBlurEnabled: true,
    frostedGlassMode: FrostedGlassMode.liquidGlass,
  ),
};

/// 课表壁纸区「顶栏玻璃材质」三档（与全局玻璃模式解耦）。
///
/// - [progressive]：首页玻璃带用 inspire 渐进模糊（上浓下淡）。
/// - [gaussian]：首页玻璃带用 inspire 均匀高斯观感。
/// - [liquid]：首页玻璃带走液态玻璃折射面。
///
/// 渐进 / 高斯只关「首页玻璃带」的液态开关，不改全局 glassMode——
/// 弹窗、坞等仍跟外观页的玻璃模式走。
enum ChromeGlassMaterial { progressive, gaussian, liquid }

/// 从设置推导首页玻璃带材质。
ChromeGlassMaterial chromeGlassMaterialOf(TimetableSettings settings) {
  if (settings.liquidGlassHomeChromeEnabled &&
      settings.frostedGlassMode == FrostedGlassMode.liquidGlass) {
    return ChromeGlassMaterial.liquid;
  }
  return settings.headerBlurStyle == HeaderBlurStyle.gaussian
      ? ChromeGlassMaterial.gaussian
      : ChromeGlassMaterial.progressive;
}

/// 写回首页玻璃带材质。
///
/// 液态档需要全局 glassMode 为液态（渲染入口仍按 glassMode ×
/// liquidGlassHomeChromeEnabled 判定），故一并打开；渐进 / 高斯只关
/// 首页液态开关，不动全局模式。
TimetableSettings applyChromeGlassMaterial(
  TimetableSettings settings,
  ChromeGlassMaterial material,
) => switch (material) {
  ChromeGlassMaterial.progressive => settings.copyWith(
    headerBlurStyle: HeaderBlurStyle.inspire,
    liquidGlassHomeChromeEnabled: false,
  ),
  ChromeGlassMaterial.gaussian => settings.copyWith(
    headerBlurStyle: HeaderBlurStyle.gaussian,
    liquidGlassHomeChromeEnabled: false,
  ),
  ChromeGlassMaterial.liquid => settings.copyWith(
    frostedBlurEnabled: true,
    frostedGlassMode: FrostedGlassMode.liquidGlass,
    liquidGlassHomeChromeEnabled: true,
  ),
};
