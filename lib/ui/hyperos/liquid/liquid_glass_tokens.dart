import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../../models/liquid_glass_tuning.dart';
import '../hyperos_tokens.dart';

/// Fallback [liquid_glass_renderer] settings for mikcb liquid glass.
///
/// Sheet defaults match the package README medium-glass example
/// (`thickness: 20`, `blur: 10`, `glassColor: 0x33FFFFFF`). Every liquid glass
/// surface uses the same material so headers, sheets, menus, popups and course
/// cards do not drift in brightness or refraction.
///
/// Kept separate from HyperOS solid surfaces so gaussian blur tuning stays untouched.
abstract final class MikcbLiquidGlassTokens {
  /// 全 app 液态玻璃**唯一**的渲染质量档：premium。
  ///
  /// 铁律：一个材质只有一种观感。同一材质在不同表面走不同档位 = 两种观感
  /// （standard 档的折射需要抓拍纹理，与 premium 的实时折射完全不是一回事），
  /// 所以这里只保留**一个**常量，任何调用点都不得再传自己的档位。例外只有
  /// 引擎降级（Skia/Web 无 shader filter、系统无障碍高对比、`fake` 预览层）
  /// ——那是全 app 一起降级，不是「某个表面换个观感」。
  ///
  /// 为什么是 premium 而不是 standard：standard 档下想要真折射，唯一通道是
  /// 抓拍纹理（包内 lightweight_glass.frag 的 PATH A，需要 backgroundKey），
  /// 而那条通道每帧只在几何变化时重拍一次、连续 3 帧稳定后 ticker 直接停摆
  /// ——玻璃里是一张**静态照片**（弹窗展开时照片跟着卡片走）。premium 走
  /// `LiquidGlass.withOwnLayer` → `BackdropFilterLayer(ImageFilter.shader)`，
  /// 由合成器每帧实时读底面，折射是真的、底面是活的。
  ///
  /// 历史包袱（勿重犯）：这里一度写成 standard，另给弹窗开 popupQuality =
  /// premium，于是顶栏/卡片/弹窗三种观感并存——用户口径「同一个材质就应该
  /// 一模一样，不要搞那么多观感种类」。
  ///
  /// 代价：premium 每帧为每个自有层抓一次纹理（曾实测拖慢首页）。若真机
  /// 掉帧，**改这一个常量**让全 app 一起回退，绝不允许再出现「某个表面单独
  /// 降级」。
  static const GlassQuality defaultQuality = GlassQuality.premium;

  /// Single liquid-glass material for every surface.
  ///
  /// 与 GlassTabBar 内部默认（kBottomBarGlassDefaults，iOS 26 Apple
  /// News/Safari tab bar 调校）保持一致：深折射、微模糊、24% 白、
  /// 135° 左上光源。全 app 玻璃统一为同一套观感。
  ///
  /// ⚠️ 这一份是 `liquidGlassTuning == null` 时的兜底：新装用户、恢复默认、
  /// 以及内置预设档都走它（`TimetableSettings.liquidGlassTuning` 默认就是
  /// null）。因此**渲染相关的修正必须同时落在 [LiquidGlassTuning] 和这里**，
  /// 否则「用户没进过高级材质页」的那条路根本拿不到修复——本项目已经在这
  /// 个双路上漏过一次。
  ///
  /// 与 [LiquidGlassTuning.defaults] 的唯一有意差异：aberr. 0.12（滑杆上限）
  /// 而非包内底栏的 0.3——0.3 在轻量着色器里是 3.5dp 级的边缘 RGB 分离，
  /// 真机读作「玻璃边缘一条彩虹描边」。refractiveIndex 同理沿用项目已收敛
  /// 的 1.5。
  static const sheetSettings = LiquidGlassSettings(
    thickness: 30,
    blur: 3,
    chromaticAberration: 0.12,
    lightIntensity: 0.6,
    refractiveIndex: 1.5,
    saturation: 0.7,
    ambientStrength: 1,
    glassColor: Color(0x3DFFFFFF),
  );

  /// Dark-mode material — same tuned look (matches the bar defaults).
  static const sheetSettingsDark = LiquidGlassSettings(
    thickness: 30,
    blur: 3,
    chromaticAberration: 0.12,
    lightIntensity: 0.6,
    refractiveIndex: 1.5,
    saturation: 0.7,
    ambientStrength: 1,
    glassColor: Color(0x3DFFFFFF),
  );

  /// 设置页预览专用：把「最容易被读成假」的两个边缘量按住。
  ///
  /// 预览框是一个 ~260×280 的小矩形，而玻璃的形态学是按**大面板**标定的：
  /// - thickness 30 时 `thicknessScale = clamp(baseScale / thickness, 1, 4)`
  ///   （premium 边缘光照）与 `edgeZone = 10`（轻量档折射带）都是绝对值，
  ///   在几十像素的小框上占比过半，读作「一圈描边」而不是「玻璃的边」；
  /// - 色散 0.12–0.3 换算成像素是 1.4–3.5dp 的 RGB 分离，在小框上直接
  ///   变成彩虹轮廓。
  ///
  /// 生效范围仅限预览（[FrostedSheetSettingsPreview]），真机表面一律用
  /// 用户实际调参。默认厚度 30 在此只削色散、不削其它，保留「所见即所得」。
  static const double previewChromaticAberration = 0.03;
  static const double previewEdgeThicknessCap = 22;

  /// Squircle radius matching HyperOS card chrome when possible.
  static double sheetBorderRadius() => HyperosTokens.cardRadius;

  static double nestedTileBorderRadius() => HyperosTokens.cardRadius;

  /// Prefer [tuning] when provided; otherwise fall back to static presets.
  static LiquidGlassSettings sheetSettingsFor(
    Brightness brightness, {
    LiquidGlassTuning? tuning,
  }) {
    if (tuning != null) {
      return tuning.toSheetSettings(brightness: brightness);
    }
    return brightness == Brightness.dark ? sheetSettingsDark : sheetSettings;
  }

  static LiquidGlassSettings nestedTileSettingsFor(
    Brightness brightness, {
    LiquidGlassTuning? tuning,
  }) {
    if (tuning != null) {
      return tuning.toSheetSettings(brightness: brightness);
    }
    return sheetSettingsFor(brightness);
  }

  /// Course-card settings use the same material as every other surface.
  static LiquidGlassSettings courseCardSettingsFor(
    Brightness brightness, {
    LiquidGlassTuning? tuning,
  }) {
    if (tuning != null) {
      return tuning.toSheetSettings(brightness: brightness);
    }
    return sheetSettingsFor(brightness);
  }
}
