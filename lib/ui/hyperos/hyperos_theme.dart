import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../utils/theme_seed_accent.dart';
import 'hyperos_miuix_spec.dart';
import 'hyperos_radius.dart';
import 'hyperos_tokens.dart';

/// Resolves HyperOS palette values for light / dark via Miuix colors.
abstract final class HyperosColors {
  static Brightness _brightness(BuildContext context) =>
      Theme.of(context).brightness;

  static Color scaffoldBackground(BuildContext context) {
    return _brightness(context) == Brightness.dark
        ? HyperosMiuixDarkColors.background
        : HyperosTokens.background;
  }

  static Color card(BuildContext context) {
    // Miuix's dark `surfaceContainer` intentionally matches the page
    // background (`#242424`). Settings groups are elevated cards, so using
    // that token here makes every HyperOS list group visually disappear in
    // dark mode. Use the highest container level for the card surface instead.
    return _brightness(context) == Brightness.dark
        ? HyperosMiuixDarkColors.surfaceContainerHighest
        : HyperosTokens.card;
  }

  static Color primaryText(BuildContext context) {
    return _brightness(context) == Brightness.dark
        ? HyperosMiuixDarkColors.onBackground
        : HyperosTokens.primaryText;
  }

  static Color secondaryText(BuildContext context) {
    return _brightness(context) == Brightness.dark
        ? HyperosMiuixDarkColors.onSurfaceVariantSummary
        : HyperosTokens.secondaryText;
  }

  /// Miuix `onSurfaceVariantActions` — chevrons and tertiary actions.
  static Color actionIcon(BuildContext context) {
    return _brightness(context) == Brightness.dark
        ? HyperosMiuixDarkColors.onSurfaceVariantActions
        : HyperosTokens.actionIcon;
  }

  static Color rowHighlight(BuildContext context) {
    return _brightness(context) == Brightness.dark
        ? HyperosMiuixDarkColors.secondary
        : HyperosTokens.pressed;
  }

  /// Miuix preference category caption (e.g. 预设主题 / 权限管控).
  static Color sectionLabel(BuildContext context) {
    return _brightness(context) == Brightness.dark
        ? HyperosMiuixDarkColors.onSurfaceVariantActions
        : HyperosTokens.sectionLabelColor;
  }

  // --- PR3: 新增语义颜色 ---

  /// Primary accent color (buttons, active indicators).
  ///
  /// 跟随用户主题 seed（`TimetableSettings.themeSeedColor`，经根部的
  /// [ThemeSeedScope] 下发）：seed 不可读时回落墨色（自动黑白），与八宫格
  /// 瓷贴、课表玻璃卡的「彩色墨回落自动黑白」口径一致。无 seed（未挂
  /// scope 或解析失败）时维持 Miuix 固定蓝。
  static Color primary(BuildContext context) {
    final fallback = _brightness(context) == Brightness.dark
        ? HyperosMiuixDarkColors.primary
        : HyperosMiuixLightColors.primary;
    final scope = ThemeSeedScope.maybeOf(context);
    // 未挂 ThemeSeedScope（测试、预览等早期路径）：维持 Miuix 固定蓝，
    // 保证既有行为与测试断言不因接入主题色而改变。
    if (scope == null) {
      return fallback;
    }
    final accent = resolveThemeSeedAccent(
      scope.seedHex,
      Theme.of(context).brightness,
    );
    // seed 缺失/不可读（深色模式近黑灰、浅色模式亮黄）→ 墨色回落（自动黑白）。
    return accent ?? _inkFallback(context);
  }

  /// 表面强调色（按钮底色、选中井等承载面）：所见即所得跟随 seed。
  ///
  /// 与 [primary] 的区分：承载面上铺 [onPrimary] 的黑白墨兜底文字对比，
  /// 所以浅色模式亮黄等 seed 也直接保留原色（选亮黄主题按钮就是黄底
  /// 黑字，而不是回落成黑按钮），深色模式近黑 seed 由
  /// [resolveThemeSeedSurface] 向白提亮避免融进暗底。未挂 scope 维持
  /// Miuix 固定蓝。
  static Color primarySurface(BuildContext context) {
    final fallback = _brightness(context) == Brightness.dark
        ? HyperosMiuixDarkColors.primary
        : HyperosMiuixLightColors.primary;
    final scope = ThemeSeedScope.maybeOf(context);
    if (scope == null) {
      return fallback;
    }
    return resolveThemeSeedSurface(
          scope.seedHex,
          Theme.of(context).brightness,
        ) ??
        fallback;
  }

  /// seed 不可读时的墨色回落：深色模式白墨、浅色模式黑墨。
  static Color _inkFallback(BuildContext context) {
    return _brightness(context) == Brightness.dark
        ? HyperosMiuixDarkColors.onBackground
        : HyperosTokens.primaryText;
  }

  /// Surface container for sheets, popups, toolbars.
  static Color surfaceContainer(BuildContext context) {
    return _brightness(context) == Brightness.dark
        ? HyperosMiuixDarkColors.surfaceContainer
        : HyperosMiuixLightColors.surfaceContainer;
  }

  /// Highest surface container for elevated elements.
  static Color surfaceContainerHighest(BuildContext context) {
    return _brightness(context) == Brightness.dark
        ? HyperosMiuixDarkColors.surfaceContainerHighest
        : HyperosMiuixLightColors.surfaceContainerHighest;
  }

  /// 危险/破坏性操作强调色（删除、停课等）。此前以 #E05D44 字面量
  /// 散落多处，收编为语义 token（亮暗同值）。
  static const Color destructive = Color(0xFFE05D44);

  /// Error / destructive color.
  static Color error(BuildContext context) {
    return _brightness(context) == Brightness.dark
        ? HyperosMiuixDarkColors.error
        : HyperosMiuixLightColors.error;
  }

  /// On-error color (text/icon on error background).
  static Color onError(BuildContext context) {
    return _brightness(context) == Brightness.dark
        ? HyperosMiuixDarkColors.onError
        : HyperosMiuixLightColors.onError;
  }

  /// Outline / divider color.
  static Color outline(BuildContext context) {
    return _brightness(context) == Brightness.dark
        ? HyperosMiuixDarkColors.outline
        : HyperosMiuixLightColors.outline;
  }

  /// Divider line color.
  static Color dividerLine(BuildContext context) {
    return _brightness(context) == Brightness.dark
        ? HyperosMiuixDarkColors.dividerLine
        : HyperosMiuixLightColors.dividerLine;
  }

  /// Slider background color.
  static Color sliderBackground(BuildContext context) {
    return _brightness(context) == Brightness.dark
        ? HyperosMiuixDarkColors.sliderBackground
        : HyperosMiuixLightColors.sliderBackground;
  }

  /// On-surface color (text on surface).
  static Color onSurface(BuildContext context) {
    return _brightness(context) == Brightness.dark
        ? HyperosMiuixDarkColors.onSurface
        : HyperosMiuixLightColors.onSurface;
  }

  /// Window dimming color for modal barriers.
  static Color windowDimming(BuildContext context) {
    return _brightness(context) == Brightness.dark
        ? HyperosMiuixDarkColors.windowDimming
        : HyperosMiuixLightColors.windowDimming;
  }

  // --- State / surface role colors (Miuix light/dark) ---

  static Color secondary(BuildContext context) {
    return _brightness(context) == Brightness.dark
        ? HyperosMiuixDarkColors.secondary
        : HyperosMiuixLightColors.secondary;
  }

  /// On-primary ink（主按钮/实底强调色上的文字与图标）。
  ///
  /// seed 接入后不再是固定白：按 [primary] 实际亮度自动取黑/白墨，
  /// 亮黄等高亮度 seed 上保持可读。无固定蓝兜底需求——[primary] 恒有值。
  static Color onPrimary(BuildContext context) {
    return onAccentInk(primary(context));
  }

  static Color onSecondary(BuildContext context) {
    return _brightness(context) == Brightness.dark
        ? HyperosMiuixDarkColors.onSecondary
        : HyperosMiuixLightColors.onSecondary;
  }

  static Color secondaryContainer(BuildContext context) {
    return _brightness(context) == Brightness.dark
        ? HyperosMiuixDarkColors.secondaryContainer
        : HyperosMiuixLightColors.secondaryContainer;
  }

  static Color secondaryVariant(BuildContext context) {
    return _brightness(context) == Brightness.dark
        ? HyperosMiuixDarkColors.secondaryVariant
        : HyperosMiuixLightColors.secondaryVariant;
  }

  static Color onBackground(BuildContext context) {
    return _brightness(context) == Brightness.dark
        ? HyperosMiuixDarkColors.onBackground
        : HyperosMiuixLightColors.onBackground;
  }

  static Color onSurfaceVariantSummary(BuildContext context) {
    return _brightness(context) == Brightness.dark
        ? HyperosMiuixDarkColors.onSurfaceVariantSummary
        : HyperosMiuixLightColors.onSurfaceVariantSummary;
  }

  /// 输入框框体填充色。
  ///
  /// Miuix 默认 secondaryContainer 亮色为 #F0F0F0，与 mikcb 页面背景
  /// settingsBackground（#F2F2F2）几乎同色，框体会融进页面；亮色降一级用
  /// secondary（#E6E6E6）。暗色页面背景 #242424 与 secondaryContainer
  /// （#434343）对比已充分，维持 Miuix 默认。
  static Color textFieldContainer(BuildContext context) {
    return _brightness(context) == Brightness.dark
        ? HyperosMiuixDarkColors.secondaryContainer
        : HyperosMiuixLightColors.secondary;
  }

  static Color onSurfaceVariantActions(BuildContext context) {
    return _brightness(context) == Brightness.dark
        ? HyperosMiuixDarkColors.onSurfaceVariantActions
        : HyperosMiuixLightColors.onSurfaceVariantActions;
  }

  static Color surface(BuildContext context) {
    return _brightness(context) == Brightness.dark
        ? HyperosMiuixDarkColors.surface
        : HyperosMiuixLightColors.surface;
  }

  static Color surfaceContainerHigh(BuildContext context) {
    return _brightness(context) == Brightness.dark
        ? HyperosMiuixDarkColors.surfaceContainerHigh
        : HyperosMiuixLightColors.surfaceContainerHigh;
  }

  /// Elevated panel background for snackbar / floating toolbar / tooltip.
  ///
  /// Asymmetric by design: dark uses [surfaceContainerHighest], light uses
  /// [surfaceContainer] (or onSurface for inverse tooltips — see
  /// [inverseSurface]).
  static Color elevatedSurface(BuildContext context) {
    return _brightness(context) == Brightness.dark
        ? HyperosMiuixDarkColors.surfaceContainerHighest
        : HyperosMiuixLightColors.surfaceContainer;
  }

  /// Inverse surface for tooltips / snackbars that sit on dark text in light mode.
  ///
  /// Dark: [surfaceContainerHighest]; light: [onSurface] (dark panel).
  static Color inverseSurface(BuildContext context) {
    return _brightness(context) == Brightness.dark
        ? HyperosMiuixDarkColors.surfaceContainerHighest
        : HyperosMiuixLightColors.onSurface;
  }

  /// Text/icon color on [inverseSurface].
  static Color onInverseSurface(BuildContext context) {
    return _brightness(context) == Brightness.dark
        ? HyperosMiuixDarkColors.onSurface
        : HyperosMiuixLightColors.onPrimary;
  }

  /// On-accent color for text/icons painted over saturated accent fills
  /// (solid primary buttons, chart tooltip panels, unlocked achievement
  /// badges, colored icon tiles).
  ///
  /// Light mode: white — accent fills (#3482FF and the HyperosIconColors
  /// palette) are all dark enough for white ink (WCAG AA vs. #3482FF).
  /// Dark mode: near-white (#F2F2F2, matches dark onSurface) so glassy or
  /// luminous accent renders stay harmonious instead of pure-white glare.
  /// Resolution is context-driven; never hardcode Colors.white for on-accent
  /// ink (see issue #84).
  static Color onAccent(BuildContext context) {
    return _brightness(context) == Brightness.dark
        ? HyperosMiuixDarkColors.onSurface
        : HyperosMiuixLightColors.onPrimary;
  }

  // --- Disabled role colors ---

  static Color disabledPrimary(BuildContext context) {
    return _brightness(context) == Brightness.dark
        ? HyperosMiuixDarkColors.disabledPrimary
        : HyperosMiuixLightColors.disabledPrimary;
  }

  static Color disabledSecondary(BuildContext context) {
    return _brightness(context) == Brightness.dark
        ? HyperosMiuixDarkColors.disabledSecondary
        : HyperosMiuixLightColors.disabledSecondary;
  }

  static Color disabledOnPrimary(BuildContext context) {
    return _brightness(context) == Brightness.dark
        ? HyperosMiuixDarkColors.disabledOnPrimary
        : HyperosMiuixLightColors.disabledOnPrimary;
  }

  static Color disabledOnSecondary(BuildContext context) {
    return _brightness(context) == Brightness.dark
        ? HyperosMiuixDarkColors.disabledOnSecondary
        : HyperosMiuixLightColors.disabledOnSecondary;
  }

  static Color disabledPrimaryButton(BuildContext context) {
    return _brightness(context) == Brightness.dark
        ? HyperosMiuixDarkColors.disabledPrimaryButton
        : HyperosMiuixLightColors.disabledPrimaryButton;
  }

  static Color disabledOnPrimaryButton(BuildContext context) {
    return _brightness(context) == Brightness.dark
        ? HyperosMiuixDarkColors.disabledOnPrimaryButton
        : HyperosMiuixLightColors.disabledOnPrimaryButton;
  }

  static Color disabledPrimarySlider(BuildContext context) {
    return _brightness(context) == Brightness.dark
        ? HyperosMiuixDarkColors.disabledPrimarySlider
        : HyperosMiuixLightColors.disabledPrimarySlider;
  }

  static Color disabledOnSurface(BuildContext context) {
    return _brightness(context) == Brightness.dark
        ? HyperosMiuixDarkColors.disabledOnSurface
        : HyperosMiuixLightColors.disabledOnSurface;
  }

  static Color onSecondaryVariant(BuildContext context) {
    return _brightness(context) == Brightness.dark
        ? HyperosMiuixDarkColors.onSecondaryVariant
        : HyperosMiuixLightColors.onSecondaryVariant;
  }

  static Color disabledSecondaryVariant(BuildContext context) {
    return _brightness(context) == Brightness.dark
        ? HyperosMiuixDarkColors.disabledSecondaryVariant
        : HyperosMiuixLightColors.disabledSecondaryVariant;
  }

  static Color disabledOnSecondaryVariant(BuildContext context) {
    return _brightness(context) == Brightness.dark
        ? HyperosMiuixDarkColors.disabledOnSecondaryVariant
        : HyperosMiuixLightColors.disabledOnSecondaryVariant;
  }

  /// Status bar icons/background aligned to a solid page or header color.
  ///
  /// [background] must be opaque (alpha == 1.0): computeLuminance ignores
  /// the alpha channel, so a transparent or translucent color is classified
  /// purely by its RGB and typically reads as dark - producing white icons
  /// over a light page. Callers rendering over blur/wallpaper must derive an
  /// opaque representative color first (see resolveHomePageStatusBarBackground)
  /// or build the SystemUiOverlayStyle explicitly.
  static SystemUiOverlayStyle systemOverlayForBackground(Color background) {
    assert(
      background.a == 1.0,
      'systemOverlayForBackground: background must be opaque; got '
      '$background. computeLuminance() ignores alpha, so translucent colors '
      'are classified by RGB alone and yield the wrong icon polarity.',
    );
    final light = background.computeLuminance() > 0.5;
    return SystemUiOverlayStyle(
      statusBarColor: background,
      statusBarIconBrightness: light ? Brightness.dark : Brightness.light,
      statusBarBrightness: light ? Brightness.light : Brightness.dark,
      // 金标联盟「谷歌Android导航条适配」（Edge-to-Edge）：导航条保持
      // 透明、无分割线，内容延伸到手势指示条下方；图标极性跟随页面
      // 背景明暗。systemNavigationBarContrastEnforced=false 关闭 API 29+
      // 的系统对比度遮罩，避免透明导航条被强制加半透明灰色 scrim。
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness:
          light ? Brightness.dark : Brightness.light,
      systemNavigationBarContrastEnforced: false,
    );
  }
}

abstract final class HyperosTypography {
  /// Canonical settings title — list rows, card headers, page/sheet/dialog titles.
  /// 全站统一 w400，与首页设置一致；字号与颜色承担层级，避免二级页“全加粗”。
  static TextStyle title(BuildContext context) {
    return TextStyle(
      fontSize: HyperosTokens.titleSize,
      fontWeight: FontWeight.w400,
      color: HyperosColors.primaryText(context),
      height: 1.25,
    );
  }

  static TextStyle listTitle(BuildContext context) => title(context);

  /// Preference row helper / trailing summary (muted vs [title], system style).
  ///
  /// Explicit [height] keeps multi-line Chinese captions from stacking too
  /// tightly (system default metrics are often cramped under CJK fonts).
  static TextStyle listDetail(BuildContext context) {
    return TextStyle(
      fontSize: HyperosTokens.listDetailSize,
      fontWeight: FontWeight.w400,
      height: 1.4,
      color: HyperosColors.secondaryText(context),
    );
  }

  /// Miuix preference category caption above list groups (e.g. 预设主题).
  static TextStyle sectionLabel(BuildContext context) {
    return TextStyle(
      fontSize: HyperosTokens.sectionLabelSize,
      fontWeight: FontWeight.w400,
      height: 1.3,
      color: HyperosColors.sectionLabel(context),
    );
  }

  /// Footnote under list groups (muted secondary ink).
  static TextStyle sectionDescription(BuildContext context) {
    return TextStyle(
      fontSize: HyperosTokens.sectionDescriptionSize,
      fontWeight: FontWeight.w400,
      height: 1.5,
      color: HyperosColors.secondaryText(context),
    );
  }

  /// Large title on bottom sheets (e.g. memory-extension picker).
  static TextStyle sheetTitle(BuildContext context) =>
      title(context).copyWith(height: 1.2);

  /// Summary card primary line.
  static TextStyle summaryTitle(BuildContext context) => title(context);

  /// Summary card secondary line (Miuix footnote + summary ink).
  static TextStyle summarySubtitle(BuildContext context) {
    return TextStyle(
      fontSize: HyperosMiuixTypography.footnote1,
      fontWeight: FontWeight.w400,
      height: 1.4,
      color: HyperosColors.onSurfaceVariantSummary(context),
    );
  }

  /// Statistics "big number" styles — canonical 24px metric ink (w500).
  ///
  /// 统计页三张头部卡片的大数字统一走这里，避免各处 copyWith(fontSize: 24)
  /// 各自定义字重。等宽数字（tabular figures）保证多位数变化时位宽稳定。
  static TextStyle metricLarge(BuildContext context) {
    return TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w500,
      height: 1,
      color: HyperosColors.primaryText(context),
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  /// Secondary metric level (18px, e.g. semester progress “%”/“剩余 X 节”).
  static TextStyle metricMedium(BuildContext context) {
    return TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w500,
      height: 1.1,
      color: HyperosColors.primaryText(context),
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  /// Metric label under a big number (footnote2 / w400).
  static TextStyle metricCaption(BuildContext context) {
    return TextStyle(
      fontSize: HyperosMiuixTypography.footnote2,
      fontWeight: FontWeight.w400,
      height: 1.4,
      color: HyperosColors.secondaryText(context),
    );
  }
}

abstract final class HyperosTheme {
  /// Pressed overlay for list rows — Material 3 ignores [InkWell.highlightColor].
  static WidgetStateProperty<Color?> rowPressOverlay(Color pressed) {
    return WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.pressed)) {
        return pressed;
      }
      return null;
    });
  }

  static BorderRadius get cardBorderRadius =>
      BorderRadius.circular(HyperosTokens.cardRadius);

  static BorderRadius get controlBorderRadius =>
      BorderRadius.circular(HyperosTokens.controlRadius);

  /// Squircle / rounded rect for a known corner radius.
  ///
  /// Tall surfaces keep the HyperOS superellipse; short ones use a plain
  /// rounded rect so corners do not read as a stadium.
  static ShapeBorder roundedShape(
    double radius, {
    BorderSide side = BorderSide.none,
  }) {
    final borderRadius = BorderRadius.circular(radius);
    if (radius >= HyperosTokens.controlRadius + 2) {
      return RoundedSuperellipseBorder(borderRadius: borderRadius, side: side);
    }
    return RoundedRectangleBorder(borderRadius: borderRadius, side: side);
  }

  /// Squircle card used by tall settings list groups (HyperOS measured 24dp).
  ///
  /// Prefer [HyperosAdaptiveCard] when the surface may be a single short row.
  static ShapeBorder cardShape({BorderSide side = BorderSide.none}) {
    return roundedShape(HyperosTokens.cardRadius, side: side);
  }

  /// Compact control shape (Miuix button / text field radius).
  static ShapeBorder controlShape({BorderSide side = BorderSide.none}) {
    return roundedShape(HyperosTokens.controlRadius, side: side);
  }

  /// Shape for a measured height — clamps so top/bottom arcs never merge.
  static ShapeBorder surfaceShapeForHeight(
    double height, {
    double? preferred,
    BorderSide side = BorderSide.none,
  }) {
    return roundedShape(
      HyperosRadius.surfaceRadiusForHeight(height, preferred: preferred),
      side: side,
    );
  }

  /// Single-line status strip: control radius, not a full stadium capsule.
  static ShapeBorder stripShape({BorderSide side = BorderSide.none}) {
    return roundedShape(HyperosTokens.controlRadius, side: side);
  }

  static CardTheme cardStyle(
    BuildContext context, {
    required Color cardColor,
  }) {
    return CardTheme(
      color: cardColor,
    );
  }
}
