import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/timetable_settings.dart';
import '../../ui/hyperos/hyperos.dart';
import '../../ui/hyperos/liquid/liquid_glass_surface.dart'
    show LiquidGlassSurface, LiquidGlassSurfaceState;
import '../home_menu_catalog.dart';

/// 玻璃坞底栏实际生效的材质。
enum TimetableDockMaterial { liquid, frosted, solid }

const double _kDockGlassDarkLuminance = 0.35;

/// 玻璃坞底栏材质：由全局材质 + 「作用范围 → 玻璃坞导航」推导。
///
/// ⚠️ 模糊总开关排在最前：高斯档存在时它同时兼作「关掉液态」的信号，
/// 2026-09-30 高斯退场后那层归位没了，这里必须自己先判一次，否则实体卡片档下
/// 坞仍会被派成液态 —— 与渲染侧 [LiquidGlassSurface.isAvailable] 的
/// `backdropBlurEnabled` 判据直接矛盾。
TimetableDockMaterial _resolveDockMaterial(BuildContext context) {
  if (!HyperosBlurredHeader.backdropBlurEnabled(context)) {
    return TimetableDockMaterial.solid;
  }
  final appearance = FrostedAppearanceScope.of(context);
  if (!LiquidGlassDegradation.familyFallsBackToSolid(
    context,
    advancedFamilyEnabled: appearance.liquidGlassDockEnabled,
  )) {
    return TimetableDockMaterial.liquid;
  }
  return TimetableDockMaterial.frosted;
}

/// 玻璃坞（药丸 + 右侧独立圆钮）视图层（2026-10-19 从 timetable_screen 的
/// State 方法搬出）。
///
/// ⚠️ **必须画在采样宿主之外** —— 由调用方摆到宿主之外，与顶栏两颗常驻玻璃球
/// 同一条规则。坞层原来长在宿主子树的末尾，于是每次录帧都把坞层自己的画面烘进
/// 采样快照，坞层再拿这张"含自己"的图去算材质：展开 / 收起内嵌页那几帧里，
/// 圆钮的明暗会来回颤几下才收敛。
///
/// 视图层不读 provider / State：当前页下标、圆钮图标与两个点击动作全部由调用方
/// 注入；材质、墨色、采样与弹簧动画都留在这里。
class TimetableGlassDockLayer extends StatelessWidget {
  const TimetableGlassDockLayer({
    super.key,
    required this.settings,
    required this.isInlinePage,
    required this.wallpaperBodyLuminance,
    required this.selectedIndex,
    required this.roundButtonIcon,
    required this.onTabSelected,
    required this.onRoundButtonTap,
    required this.pillKey,
    required this.roundKey,
  });

  final TimetableSettings settings;
  final bool isInlinePage;
  final double? wallpaperBodyLuminance;
  final int selectedIndex;
  final Widget roundButtonIcon;
  final ValueChanged<String> onTabSelected;
  final VoidCallback onRoundButtonTap;
  final GlobalKey<LiquidGlassSurfaceState> pillKey;
  final GlobalKey<LiquidGlassSurfaceState> roundKey;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dockMaterial = _resolveDockMaterial(context);
    // 内嵌页表态只看主题，不跟着壁纸亮度走。
    final lum = isInlinePage ? null : wallpaperBodyLuminance;
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    // 通用底栏墨色判据（chrome 阈值 0.45）。
    // 实体卡片档的药丸/圆钮是不透明**主题色**面（浅色主题≈纯白），
    // 墨色极性必须跟主题走；半透明材质（液态/磨砂）的面 =
    // 壁纸 + 玻璃，继续按壁纸亮度判——否则浅色主题 + 暗壁纸会
    // 出现白底白字。
    final inkIsLight = dockMaterial == TimetableDockMaterial.solid
        ? isDarkTheme
        : (lum != null ? lum < 0.45 : isDarkTheme);
    final ink = inkIsLight
        ? Colors.white.withValues(alpha: 0.9)
        : Colors.black.withValues(alpha: 0.75);
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: Align(
        alignment: Alignment.bottomCenter,
        // 官方 iOS 26 形态：居中药丸 + 右侧独立圆钮，整组居中。
        // 圆钮固定展开（加课程唯一主动入口，不再随页收起）；
        // 材质经 dockBtnSettings 与药丸显式同源。
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 272),
              child: _buildBar(context, l10n, dockMaterial),
            ),
            if (settings.glassDockShowAddButton) ...[
              const SizedBox(width: 8),
              _buildMergeSlot(context, ink, l10n, dockMaterial),
            ],
          ],
        ),
      ),
    );
  }

  /// 玻璃坞底部导航：周课表 / 日课表 / 设置。
  ///
  /// 四种材质共用同一套底栏实现（[SoftGlassTabBar]：浮动药丸 + 拖拽指示器 +
  /// 弹簧动画），材质差异只由注入的 `surfaceBuilder` 决定（见
  /// [_dockPillSurface]）。
  Widget _buildBar(
    BuildContext context,
    AppLocalizations l10n,
    TimetableDockMaterial dockMaterial,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final appearance = FrostedAppearanceScope.of(context);
    // 底栏文字极性分派：课表态跟随壁纸亮度（表面 = 壁纸 + 白玻璃）；
    // 内嵌页表态底栏浮在纯色页面上，只看主题——否则白底设置页会沿用
    // 暗壁纸的浅色墨，白字看不见（自动反色失效的根因）。
    // 实体卡片档例外：药丸是不透明主题色面（浅色主题≈纯白），墨色必须
    // 跟主题走，按壁纸亮度翻白会在暗壁纸上得到白底白字。
    final wallpaperLuminance = isInlinePage ? null : wallpaperBodyLuminance;
    final barUsesLightInk =
        dockMaterial == TimetableDockMaterial.solid
        ? isDark
        : (wallpaperLuminance != null ? wallpaperLuminance < 0.45 : isDark);
    final unselectedColor = barUsesLightInk
        ? Colors.white.withValues(alpha: 0.62)
        : Colors.black.withValues(alpha: 0.48);
    // 选中色：暗表面用白色；亮表面上浅色主题的 primary 本身偏深可用，
    // 深色主题的 primary 偏浅在亮玻璃上对比度不足 → 切深色墨。
    final selectedColor = barUsesLightInk
        ? Colors.white
        : (isDark && wallpaperLuminance != null && wallpaperLuminance >= 0.45
              ? Colors.black.withValues(alpha: 0.80)
              : colorScheme.primary);
    // 实体药丸的底：与主题卡面同色、不含模糊。
    final solidDockFill = HyperosColors.surfaceContainer(context);
    // 动态入口列表：底栏最多 5 槽，用户在「首页与导航」自由编排
    // （'day'/'week' 视图动作 + 目录任意条目，含设置页）。
    final dockIds = resolveGlassDockActionIds(settings);
    // 玻璃药丸的布局与极性：
    //
    // 布局用 Stacked（图标上、文字下）：5 槽 + maxWidth 272 时 Horizontal
    // 会把「日课表」挤成一个字。极性阈值只给底栏药丸自己用（决定它的
    // 亮暗与指示器配色）：仅明确暗壁纸才用深灰玻璃，中等亮度壁纸走
    // 乳白+黑墨（截图里浅橄榄壁纸配黑玻璃像一块塑料），故阈值取 0.35
    // 而非通用 chrome 的 0.45。
    final dockGlassDark = wallpaperLuminance != null
        ? wallpaperLuminance < _kDockGlassDarkLuminance
        : isDark;

    return SoftGlassTabBar(
      tabs: [
        for (final id in dockIds)
          SoftGlassTab(
            icon: Icon(glassDockActionIcon(id)),
            label: glassDockActionLabel(l10n, id),
          ),
      ],
      selectedIndex: selectedIndex,
      onTabSelected: (index) => onTabSelected(dockIds[index]),
      selectedColor: selectedColor,
      unselectedColor: unselectedColor,
      iconSize: 22,
      blurEnabled: appearance.blurEnabled,
      polarity: dockGlassDark
          ? SoftGlassPolarity.dark
          : SoftGlassPolarity.light,
      surfaceBuilder: (child) => _dockPillSurface(
        context,
        material: dockMaterial,
        solidFill: solidDockFill,
        child: child,
      ),
    );
  }

  /// 药丸底材质分派（四种材质共用同一套底栏实现，见 [_buildBar]）。
  Widget _dockPillSurface(
    BuildContext context, {
    required TimetableDockMaterial material,
    required Color solidFill,
    required Widget child,
  }) {
    const radius = SoftGlassTokens.barHeight / 2;
    final surface = switch (material) {
      TimetableDockMaterial.liquid => LiquidGlassSurface(
        probeName: 'glassDock',
        key: pillKey,
        borderRadius: radius,
        // 实时采样（不跟祖先组）：坞层被调用方摆在采样宿主**之外**，拿不到
        // `homeStack` 那个 `BackdropGroup` —— 原先这里的 `grouped: true`
        // 一直是**空转**，观感全靠实时采样（用户口径：药丸的折射会跟着下面
        // 内容变，最好看）。这里不再写它，把"要实时采样"写实：一旦将来坞层
        // 被包进某个组，`true` 会静默把它变成一块壁纸快照底
        // （2026-09-20 两颗悬浮钮踩的就是这个坑）。
        fallbackBuilder: (_) =>
            _frostedDockSurface(context, radius: radius, child: child),
        child: child,
      ),
      TimetableDockMaterial.frosted => _frostedDockSurface(
        context,
        radius: radius,
        child: child,
      ),
      // 实体卡片：不透明主题色面，不含模糊。
      TimetableDockMaterial.solid => ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: ColoredBox(color: solidFill, child: child),
      ),
    };

    // 与设置页左上角返回圆钮共用同款小浮影。纯白主题且没有壁纸时，药丸与
    // 页面底色几乎相同；只补轻阴影即可拉开边界，不必改玻璃本身的颜色。
    return HyperosGlassShadow.wrap(
      borderRadius: BorderRadius.circular(radius),
      shadowOverride: HyperosGlassShadow.compactShadow,
      shadowKey: const ValueKey('glass-dock-pill-shadow'),
      child: surface,
    );
  }

  /// 磨砂底（高斯药丸 / 圆钮共用）：blur 与 tint 都从 scope 出，与弹窗 frosted
  /// 档同参。也是液态玻璃不可用时的回落——仍是玻璃观感，不会突然变实底。
  Widget _frostedDockSurface(
    BuildContext context, {
    required double radius,
    required Widget child,
  }) {
    final appearance = FrostedAppearanceScope.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: FrostedHeaderBackground(
        blurEnabled: appearance.blurEnabled,
        blurSigma: appearance.sheetBlurSigma,
        tint: HyperosBlurredHeader.sheetTintColor(context, withBlur: true),
        child: child,
      ),
    );
  }

  /// 独立圆钮：与药丸**同一份材质**的 56 正圆（材质由同一个
  /// [_resolveDockMaterial] 推出，见 [_dockPillSurface]）。
  Widget _buildMergeSlot(
    BuildContext context,
    Color ink,
    AppLocalizations l10n,
    TimetableDockMaterial material,
  ) {
    final label = l10n.glassDockExtraButtonSemanticLabel;
    // 56 正圆。
    const radius = 28.0;
    final body = Center(
      child: IconTheme.merge(
        data: IconThemeData(color: ink, size: 22),
        child: roundButtonIcon,
      ),
    );
    final face = SizedBox(
      width: 56,
      height: 56,
      child: Semantics(
        button: true,
        label: label,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onRoundButtonTap,
            child: switch (material) {
              TimetableDockMaterial.liquid => LiquidGlassSurface(
                probeName: 'glassDock',
                key: roundKey,
                borderRadius: radius,
                // 实时采样，理由同 [_dockPillSurface]（坞层在采样宿主之外）。
                fallbackBuilder: (_) => _frostedDockSurface(
                  context,
                  radius: radius,
                  child: body,
                ),
                child: body,
              ),
              TimetableDockMaterial.frosted => _frostedDockSurface(
                context,
                radius: radius,
                child: body,
              ),
              // 实体卡片：不透明主题色面，不含模糊。
              TimetableDockMaterial.solid => ClipRRect(
                borderRadius: BorderRadius.circular(radius),
                child: ColoredBox(
                  color: HyperosColors.surfaceContainer(context),
                  child: body,
                ),
              ),
            },
          ),
        ),
      ),
    );
    // 圆钮与药丸共用同一套阴影系统（2026-10-23 用户口径：「右边独立的圈圈
    // 也要加上底栏一样的阴影」）。此前只有药丸在 [_dockPillSurface] 里垫了
    // [HyperosGlassShadow.compactShadow]，圆钮是一块裸玻璃 —— 纯白主题无壁纸
    // 时两者并排，药丸有边界、圆钮与页面底糊成一片。
    return HyperosGlassShadow.wrap(
      borderRadius: BorderRadius.circular(radius),
      shadowOverride: HyperosGlassShadow.compactShadow,
      shadowKey: const ValueKey('glass-dock-round-shadow'),
      child: face,
    );
  }
}
