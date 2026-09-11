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
/// 底栏：选柔光 → 底栏柔光；选回高斯/液态/实体 → 底栏回液态路径
/// （GlassTabBar），否则用户切全局材质时底栏一直卡在 SoftGlassTabBar，
/// 和高斯观感分不开。
TimetableSettings applyGlassModeChoice(
  TimetableSettings settings,
  GlassModeChoice choice,
) => switch (choice) {
  GlassModeChoice.solid => settings.copyWith(
    frostedBlurEnabled: false,
    frostedGlassMode: FrostedGlassMode.frosted,
    glassDockStyle: DockGlassStyle.liquid,
  ),
  GlassModeChoice.gaussian => settings.copyWith(
    frostedBlurEnabled: true,
    frostedGlassMode: FrostedGlassMode.gaussian,
    glassDockStyle: DockGlassStyle.liquid,
  ),
  GlassModeChoice.softGlass => settings.copyWith(
    frostedBlurEnabled: true,
    frostedGlassMode: FrostedGlassMode.softGlass,
    glassDockStyle: DockGlassStyle.soft,
  ),
  GlassModeChoice.liquidGlass => settings.copyWith(
    frostedBlurEnabled: true,
    frostedGlassMode: FrostedGlassMode.liquidGlass,
    glassDockStyle: DockGlassStyle.liquid,
  ),
};

/// 写回「顶栏模糊风格」独立行（渐进模糊 / 高斯模糊）。
///
/// 该行从「玻璃材质」里拆回来后与后者的渐进/高斯两档语义重叠，所以这里
/// **同步**写 `homeChromeGlassMaterial`：否则用户先选「玻璃材质 = 渐进模糊」
/// 再改「模糊风格 = 高斯模糊」，材质行会仍显示「渐进模糊」，与实际渲染的
/// 衰减风格自相矛盾。液态档走折射面、不看 [HeaderBlurStyle]，这里一并关掉
/// 首页液态开关（与 [ChromeGlassMaterial.progressive] 同款收尾）。
TimetableSettings applyChromeBlurStyle(
  TimetableSettings settings,
  HeaderBlurStyle style,
) => settings.copyWith(
  headerBlurStyle: style,
  homeChromeGlassMaterial: style == HeaderBlurStyle.gaussian
      ? 'gaussian'
      : 'progressive',
  liquidGlassHomeChromeEnabled: false,
);
/// 课表壁纸区「顶栏玻璃材质」三档（与全局玻璃模式完全解耦）。
///
/// - [progressive]：首页玻璃带用 inspire 渐进模糊（上浓下淡）。
/// - [gaussian]：首页玻璃带用 inspire 均匀高斯观感。
/// - [liquid]：首页玻璃带走液态玻璃折射面。**仅首页**——子页顶栏与
///   弹窗不读 [homeChromeGlassMaterial]，永不被此档带动。
enum ChromeGlassMaterial { progressive, gaussian, liquid }

/// 存量数据：无 `homeChromeGlassMaterial` 时从旧字段推导。
ChromeGlassMaterial chromeGlassMaterialOf(TimetableSettings settings) {
  return switch (settings.homeChromeGlassMaterial) {
    'liquid' => ChromeGlassMaterial.liquid,
    'gaussian' => ChromeGlassMaterial.gaussian,
    'progressive' => ChromeGlassMaterial.progressive,
    // 兜底：旧数据无新键时沿用 headerBlurStyle / 全局液态启发式。
    _ =>
      settings.liquidGlassHomeChromeEnabled &&
              settings.frostedGlassMode == FrostedGlassMode.liquidGlass
          ? ChromeGlassMaterial.liquid
          : settings.headerBlurStyle == HeaderBlurStyle.gaussian
          ? ChromeGlassMaterial.gaussian
          : ChromeGlassMaterial.progressive,
  };
}

/// 写回首页玻璃带材质。
///
/// 只写 `homeChromeGlassMaterial` + `headerBlurStyle`，**不改**全局
/// `frostedGlassMode`——设置页弹窗/Sheet 材质跟外观页走。
TimetableSettings applyChromeGlassMaterial(
  TimetableSettings settings,
  ChromeGlassMaterial material,
) => switch (material) {
  ChromeGlassMaterial.progressive => settings.copyWith(
    homeChromeGlassMaterial: 'progressive',
    headerBlurStyle: HeaderBlurStyle.inspire,
    liquidGlassHomeChromeEnabled: false,
  ),
  ChromeGlassMaterial.gaussian => settings.copyWith(
    homeChromeGlassMaterial: 'gaussian',
    headerBlurStyle: HeaderBlurStyle.gaussian,
    liquidGlassHomeChromeEnabled: false,
  ),
  ChromeGlassMaterial.liquid => settings.copyWith(
    homeChromeGlassMaterial: 'liquid',
    liquidGlassHomeChromeEnabled: true,
  ),
};
