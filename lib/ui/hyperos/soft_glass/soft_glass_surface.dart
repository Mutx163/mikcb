import 'package:flutter/material.dart';

/// 玻璃坞药丸的几何 / 按压动效 / 亮暗 token —— 底栏药丸（`SoftGlassTabBar`）
/// 与坞内圆钮共用这一份数值；亮暗极性的取值范围见 [SoftGlassPolarity]。
///
/// 与「材质」无关：坞的三种材质（液态 / 磨砂 / 实体）都共用这套几何与动效，
/// 材质差异只由药丸的 `surfaceBuilder` 决定。
abstract final class SoftGlassTokens {
  // ---------------------------------------------------------------------
  // 底栏几何（MiuixFloatingTabBarDefaults）
  // ---------------------------------------------------------------------
  static const double barHeight = 54;
  static const double horizontalContentPadding = 7;
  static const double verticalContentPadding = 3;
  static const double indicatorHorizontalOverflow = 3;
  static const double maximumWidth = 380;
  static const double maximumItemWidth = 80;
  static const double tabIconSize = 26;
  static const double detachedIconSize = 28;
  static const double roundButtonSize = 56;

  // ---------------------------------------------------------------------
  // 按压与动效（FloatingTabMotionDefaults）
  // ---------------------------------------------------------------------
  static const double pressedScale = 52 / 56;
  static const double selectedIconPressedScale = 0.90;
  static const double maximumStretch = 0.18;
  static const double fullStretchTabsPerSecond = 8;
  static const double maximumPanelOffsetDp = 4;

  // ---------------------------------------------------------------------
  // 模糊（AdvancedMaterialTuning.DefaultBlurRadius + GlassBlurSpec）
  // ---------------------------------------------------------------------

  /// 模糊半径基准：磨砂药丸的**成本旋钮，同时也是雾度旋钮**。
  ///
  /// ## 这个数为什么这么敏感
  ///
  /// 它同时决定三件事，而三件都在每帧、每块磨砂面上重算
  /// （上游 `MiuixGlass` 的 `_RenderGlass.prepare`）：
  ///
  /// | 派生量 | 公式 | 影响 |
  /// |---|---|---|
  /// | 模糊核 | σ = radius × 0.45 | 高斯卷积的采样数（近似线性） |
  /// | 离屏边距 | padding = radius × 1.5（每边） | 纹理面积 ∝ (宽 + 3r)(高 + 3r) |
  /// | 纹理尺寸 | (元素尺寸 + 2×padding) × `(dpr/4).clamp(.5,1)` | 两次同步 GPU 回读的量 |
  ///
  /// 而且 `prepare()` 每帧要**同步回读 GPU 两次**（`picture.toImageSync`：一次出模糊底，
  /// 一次出三层颜色混合的结果），缓存键含元素的位置与尺寸 —— **任何入场/位移动画都是
  /// 逐帧缓存不命中**，也就是逐帧两次同步回读。
  ///
  /// 真机实测（25079RPDCC / dpr 2.75）：弹层入场期间渲染线程 9.4~11ms 对 8.2ms 预算，
  /// 帧率 35~66，`over` 13~21 帧；主线程只有 1.5ms（即与 Dart 侧无关）。把材质换成
  /// 「实体卡片」后整个软件流畅 —— 玻璃是那一段的全部账。
  ///
  /// ## 取值
  ///
  /// 2026-09-17：60 → 32。原值 60（= 上游 `popupViewGlass.blurRadius`）推出 σ=27，
  /// 比常见磨砂玻璃的 σ=10~20 重得多，而成本按上面的公式**超线性**放大：降到 32 后
  /// σ=14.4、padding=48，一块面板的离屏纹理约小 1.3 倍、模糊核约省 1.9 倍，合计
  /// 约 2.5 倍。
  ///
  /// 这是**观感取舍**，不是纯性能修复：雾度会比原来淡一档。想找回原观感就回 60。
  /// 真正的结构性问题（每块玻璃每帧两次同步回读）没解决。
  static const double baseBlurRadius = 32;

  /// Miuix 材质的半径上限（上游 `MiuixGlassMaterial.blurRadius` 的实际天花板
  /// 由离屏目标尺寸决定，这里只做兜底 clamp）。
  static const double maximumBlurRadius = 256;

  // ---------------------------------------------------------------------
  // 边缘光学
  // ---------------------------------------------------------------------
  //
  // 自绘的双影描边（0.5dp 描边 + 上/中/下三档垂直渐变高光 + 暗色折减）已随
  // 自研链路删除。现在边缘由上游 `MiuixGlassStrokes.forTheme(isDark)` 提供，
  // [edgeHighlightAlpha] 就是它三处高光（color / primary / secondary）的强度。

  // ---------------------------------------------------------------------
  // 兜底底色（没有 backdrop 时画的那层实底）
  // ---------------------------------------------------------------------
  //
  // ⚠️ 有 backdrop 时**这些数值一个都不参与渲染**：那时玻璃的底色由上游
  // `popupViewGlass` 的三层颜色层 + blend shader 决定，`fill` 只在
  // `MiuixGlass` 的"无背景兜底"分支（`canvas.drawPath(shapePath, fill)`）被读。
  //
  // 所以这一段服务于两件事，别拿它去解释玻璃的观感：
  // 1. **模糊关闭 / 系统降级时的实底**（`StableFrostedSurface` 的实底分支）；
  // 2. **静态替身的等效底色**（转场期间用，见
  //    `HomePageChromeGlassFill.standInWashColor`）。

  /// 亮/暗底色的不透明度基准（0.75）。
  static const double navigationTintAlpha = 0.75;

  /// 底色基准的配方倍率（0.90）。
  ///
  /// 两个常量相乘 ≈ 0.675，是"亮色 252@67.5% / 暗色 31@67.5%"这个对外口径的
  /// 来源。之所以拆成两个而不是一个 0.675，是为了让"倍率"这一层可单独调。
  static const double navigationTintAlphaMultiplier = 0.90;

  /// 亮色底灰度（glassTintLightGray）→ 252。
  static const double tintLightGray = 0.99;

  /// 暗色底灰度（glassTintDarkGray）→ 31。
  static const double tintDarkGray = 0.12;

  /// 模糊总开关关闭时的底色不透明度。
  ///
  /// 上游玻璃组件在材质未启用（`advancedMaterial.enabled == false`）
  /// 时写死 0.92；本项目约定「模糊关闭即实底」（见
  /// HyperosBlurredHeader.sheetTintColor），故这里收紧到 0.90，属**有意偏离**：
  /// 既不能透出底下的课表，又要保住玻璃面的层级。
  static const double tintAlphaNoBlur = 0.90;

  // ---------------------------------------------------------------------
  // 极性
  // ---------------------------------------------------------------------

  static bool _dark(BuildContext context, SoftGlassPolarity? polarity) =>
      switch (polarity) {
        SoftGlassPolarity.dark => true,
        SoftGlassPolarity.light => false,
        null => Theme.of(context).brightness == Brightness.dark,
      };

  /// 兜底底色（灰度取自 [tintLightGray] / [tintDarkGray]）。
  ///
  /// - [blurEnabled] 为 true 时给**静态替身**用：不透明度 =
  ///   [navigationTintAlpha] × [navigationTintAlphaMultiplier] ×
  ///   [tintAlphaMultiplier]（≈ 0.675 × 用户倍率）。
  /// - 为 false（模糊关闭 / 系统降级）时是**实底**：[tintAlphaNoBlur]。
  ///
  /// 真实玻璃（有 backdrop）不走这里，见类头的说明。
  static Color tint(
    BuildContext context, {
    required bool blurEnabled,
    SoftGlassPolarity? polarity,
    double tintAlphaMultiplier = 1,
  }) {
    final gray = _dark(context, polarity) ? tintDarkGray : tintLightGray;
    final channel = (gray * 255).round();
    final alpha = blurEnabled
        ? (navigationTintAlpha *
                  navigationTintAlphaMultiplier *
                  tintAlphaMultiplier)
              .clamp(0.0, 1.0)
        : tintAlphaNoBlur;
    return Color.fromARGB(
      255,
      channel,
      channel,
      channel,
    ).withValues(alpha: alpha);
  }

  /// 指示器填充：暗色白 13% / 亮色黑 7.5%。
  static Color indicatorFill(
    BuildContext context, {
    SoftGlassPolarity? polarity,
  }) => _dark(context, polarity)
      ? Colors.white.withValues(alpha: 0.13)
      : Colors.black.withValues(alpha: 0.075);
}

/// 玻璃坞药丸与坞内圆钮的亮暗极性：暗壁纸用深灰玻璃 + 白墨，否则乳白 + 黑墨。
enum SoftGlassPolarity { light, dark }

