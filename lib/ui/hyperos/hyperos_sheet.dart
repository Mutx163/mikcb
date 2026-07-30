import 'package:flutter/material.dart';

import 'hyperos_blurred_header.dart';
import 'hyperos_miuix_spec.dart';
import 'hyperos_theme.dart';
import 'hyperos_tokens.dart';
import 'hyperos_widgets.dart';
import 'liquid/hyperos_liquid_glass_surface.dart';

/// Marks descendants as sitting on a frosted (blur + milky tint) panel.
///
/// Used by [HyperosButton] secondary fill so cancel / neutral actions stay
/// readable against glass instead of blending into white-on-white.
class HyperosFrostedPanelScope extends InheritedWidget {
  const HyperosFrostedPanelScope({required super.child, super.key});

  static bool of(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<HyperosFrostedPanelScope>() !=
        null;
  }

  @override
  bool updateShouldNotify(covariant HyperosFrostedPanelScope oldWidget) {
    return false;
  }
}

/// Visual chrome for [HyperosSheetFrame] / [HyperosSheet].
enum HyperosSheetChrome {
  /// Floating card: left/right/bottom outer gap + full rounded corners.
  /// Matches [HyperosDialog] (settings / form sheets).
  floating,

  /// Edge-flush panel: full width, top corners only, sits on screen bottom.
  /// Preferred for home timetable menus and action sheets.
  edge,
}

/// Provides default [HyperosSheetChrome] for nested [HyperosSheetFrame]s.
class HyperosSheetChromeScope extends InheritedWidget {
  const HyperosSheetChromeScope({
    required this.chrome,
    required super.child,
    super.key,
  });

  final HyperosSheetChrome chrome;

  static HyperosSheetChrome? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<HyperosSheetChromeScope>()
        ?.chrome;
  }

  static HyperosSheetChrome of(BuildContext context) {
    return maybeOf(context) ?? HyperosSheetChrome.floating;
  }

  @override
  bool updateShouldNotify(covariant HyperosSheetChromeScope oldWidget) {
    return chrome != oldWidget.chrome;
  }
}

/// HyperOS bottom sheet panel shell.
///
/// Defaults to frosted glass using [HyperosBlurredHeader.blurSigmaOf] (same
/// strength as 外观与配色). Defaults to [HyperosSheetChrome.floating] unless an
/// ancestor [HyperosSheetChromeScope] or [chrome] overrides it.
class HyperosSheetFrame extends StatelessWidget {
  const HyperosSheetFrame({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 16),
    this.maxHeight,
    this.frosted = true,
    this.chrome,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double? maxHeight;

  /// When true (default), milky frosted glass + live blur when enabled in
  /// settings. Sigma / tint / master switch come from [FrostedAppearanceScope].
  final bool frosted;

  /// When null, uses [HyperosSheetChromeScope] or [HyperosSheetChrome.floating].
  final HyperosSheetChrome? chrome;

  @override
  Widget build(BuildContext context) {
    final resolvedChrome = chrome ?? HyperosSheetChromeScope.of(context);
    final panel = switch (resolvedChrome) {
      HyperosSheetChrome.floating => _buildFloatingPanel(context),
      HyperosSheetChrome.edge => _buildEdgePanel(context),
    };

    if (maxHeight == null) {
      return panel;
    }

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight!),
      child: panel,
    );
  }

  Widget _buildFloatingPanel(BuildContext context) {
    final outerInset = HyperosMiuixDialog.outsideMarginHorizontal;
    final bottomSafeInset = MediaQuery.paddingOf(context).bottom;
    final borderRadius = BorderRadius.circular(HyperosTokens.cardRadius);
    final content = Padding(padding: padding, child: child);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        outerInset,
        0,
        outerInset,
        outerInset + bottomSafeInset,
      ),
      child: frosted
          ? _buildFrostedSurface(
              context: context,
              borderRadius: borderRadius,
              content: content,
            )
          : Material(
              color: HyperosColors.surfaceContainer(context),
              shape: HyperosTheme.cardShape(),
              clipBehavior: Clip.antiAlias,
              child: content,
            ),
    );
  }

  Widget _buildEdgePanel(BuildContext context) {
    final borderRadius = BorderRadius.vertical(
      top: Radius.circular(HyperosTokens.cardRadius),
    );
    final content = SafeArea(
      top: false,
      child: Padding(padding: padding, child: child),
    );

    if (frosted) {
      return ClipRRect(
        borderRadius: borderRadius,
        child: SizedBox(
          width: double.infinity,
          child: _buildFrostedSurface(
            context: context,
            borderRadius: borderRadius,
            content: content,
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: HyperosColors.scaffoldBackground(context),
        borderRadius: borderRadius,
      ),
      child: content,
    );
  }

  Widget _buildFrostedSurface({
    required BuildContext context,
    required BorderRadius borderRadius,
    required Widget content,
  }) {
    final appearance = FrostedAppearanceScope.of(context);
    final useBlur = HyperosBlurredHeader.backdropBlurEnabled(context);

    // Blur off → solid opaque panel (no translucent scrim over the page).
    if (!useBlur) {
      return HyperosFrostedPanelScope(
        child: Material(
          color: HyperosColors.surfaceContainer(context),
          borderRadius: borderRadius,
          clipBehavior: Clip.antiAlias,
          child: content,
        ),
      );
    }

    // Liquid glass mode: real-time refraction shader panel.
    if (appearance.glassMode == FrostedGlassMode.liquidGlass) {
      return HyperosFrostedPanelScope(
        child: HyperosLiquidGlassSurface(
          role: HyperosLiquidGlassRole.sheet,
          borderRadius: borderRadius.topLeft.x,
          instantUnderlay: true,
          child: content,
        ),
      );
    }

    // Frosted / gaussian / translucent: BackdropFilter + tint.
    final tint = HyperosBlurredHeader.sheetTintColor(context, withBlur: true);

    return HyperosFrostedPanelScope(
      child: ClipRRect(
        borderRadius: borderRadius,
        child: FrostedHeaderBackground(
          blurEnabled: true,
          blurSigma: HyperosBlurredHeader.blurSigmaOf(context),
          tint: tint,
          child: content,
        ),
      ),
    );
  }
}

/// Bottom sheet body with optional title (uses [HyperosSheetFrame] chrome).
class HyperosSheet extends StatelessWidget {
  const HyperosSheet({
    super.key,
    this.title,
    required this.child,
    this.description,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 16),
    this.frosted = true,
    this.chrome,
  });

  final String? title;
  final Widget child;
  final String? description;
  final EdgeInsetsGeometry padding;
  final bool frosted;
  final HyperosSheetChrome? chrome;

  @override
  Widget build(BuildContext context) {
    return HyperosSheetFrame(
      frosted: frosted,
      padding: padding,
      chrome: chrome,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(title!, style: HyperosTypography.sheetTitle(context)),
            const SizedBox(height: 16),
          ],
          child,
          if (description != null) ...[
            const SizedBox(height: 12),
            HyperosSectionDescription(text: description!),
          ],
        ],
      ),
    );
  }
}

/// Shows a HyperOS-styled modal bottom sheet (replaces Forui `showFSheet`).
///
/// Content should use [HyperosSheetFrame] / [HyperosSheet] / [HyperosDialog].
/// Default chrome is [HyperosSheetChrome.floating] unless [chrome] or a
/// [HyperosSheetChromeScope] says otherwise.
///
/// When [padForKeyboard] is true (default), the sheet is lifted by
/// [MediaQuery.viewInsets] so it sits above the IME. Set it to false when the
/// sheet body manages keyboard avoidance itself (e.g. scroll-to-field).
///
/// The dim layer is painted as a **sibling** of the glass panel (not below it)
/// so [BackdropFilter] inside the glass samples only the original page content
/// — the glass interior stays bright while the surrounding area darkens.
Future<T?> showHyperosSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isDismissible = true,
  bool enableDrag = true,
  bool useRootNavigator = false,
  bool padForKeyboard = true,
  Color? barrierColor,
  HyperosSheetChrome chrome = HyperosSheetChrome.floating,
}) {
  final resolvedDim =
      barrierColor ?? HyperosBlurredHeader.modalBarrierColor(context);

  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: false,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.transparent,
    // No route-level FadeTransition: wrapping LiquidGlass in an animated
    // Opacity layer causes a black flash on shader warmup / teardown.
    transitionDuration: Duration.zero,
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return _HyperosSheetRouteBody(
        dimColor: resolvedDim,
        isDismissible: isDismissible,
        padForKeyboard: padForKeyboard,
        chrome: chrome,
        builder: builder,
      );
    },
  );
}

/// Full-screen route body: dim sibling + bottom-aligned sheet panel.
///
/// 压暗层以渐变（300ms fade-in）淡入，并通过 [_SheetDimPainter]（evenOdd 路径挖孔）
/// 排除面板所在区域，使面板内的液态玻璃 / BackdropFilter 只采样未被压暗的页面内容。
///
/// Layout 顺序：
/// 1. dim 层先渲染（面板之下），用 evenOdd 路径在面板位置"挖洞"，只压暗面板以外的区域
/// 2. 面板后渲染（dim 之上），Stack hitTest 反向遍历，面板先接收事件 → 按钮正常响应
///    dim 后接收事件 → 点击面板外部时关闭弹窗
///
/// 面板位置通过 [GlobalKey] 在首帧布局完成后测量，随后启动 dim 动画。
/// 首帧测量的延迟（~1 frame）对视觉效果无影响，因为 dim 从 alpha=0 开始淡入。
///
/// 退出时 route 被直接 pop（无 route-level 过渡），dim 随 widget 一同销毁，
/// 未经渐隐—与旧行为一致。如需渐隐退出，后续可改用 [_dimController.reverse()]
/// 并在完成时回调 Navigator.pop。
class _HyperosSheetRouteBody extends StatefulWidget {
  const _HyperosSheetRouteBody({
    required this.dimColor,
    required this.isDismissible,
    required this.padForKeyboard,
    required this.chrome,
    required this.builder,
  });

  final Color dimColor;
  final bool isDismissible;
  final bool padForKeyboard;
  final HyperosSheetChrome chrome;
  final WidgetBuilder builder;

  @override
  State<_HyperosSheetRouteBody> createState() => _HyperosSheetRouteBodyState();
}

class _HyperosSheetRouteBodyState extends State<_HyperosSheetRouteBody>
    with SingleTickerProviderStateMixin {
  late final AnimationController _dimController;
  final GlobalKey _panelKey = GlobalKey();
  Rect? _panelGlobalRect;

  @override
  void initState() {
    super.initState();
    _dimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    // 延后一帧以便面板布局就绪后再测量
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _measurePanel();
      _dimController.forward();
    });
  }

  @override
  void dispose() {
    _dimController.dispose();
    super.dispose();
  }

  void _measurePanel() {
    final renderBox =
        _panelKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize || !renderBox.attached) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _measurePanel());
      return;
    }
    setState(() {
      _panelGlobalRect = renderBox.localToGlobal(Offset.zero) & renderBox.size;
    });
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = widget.padForKeyboard
        ? MediaQuery.viewInsetsOf(context).bottom
        : 0.0;

    return Stack(
      fit: StackFit.expand,
      children: [
        // 压暗层先渲染（面板之下），用 evenOdd 挖空面板区域，
        // 使面板的 BackdropFilter / 液态玻璃只采样未压暗的原始页面内容。
        GestureDetector(
          behavior: HitTestBehavior.deferToChild,
          onTap: widget.isDismissible
              ? () => Navigator.of(context).pop()
              : null,
          child: AnimatedBuilder(
            animation: _dimController,
            builder: (context, _) {
              return CustomPaint(
                painter: _SheetDimPainter(
                  dimColor: widget.dimColor,
                  dimProgress: _dimController.value,
                  excludeRect: _panelGlobalRect,
                ),
                child: const SizedBox.expand(),
              );
            },
          ),
        ),
        // 面板后渲染（压暗层之上），正常接收触摸事件
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Padding(
            key: _panelKey,
            padding: EdgeInsets.only(bottom: keyboardInset),
            child: HyperosSheetChromeScope(
              chrome: widget.chrome,
              child: widget.builder(context),
            ),
          ),
        ),
      ],
    );
  }
}

/// 在面板区域以外绘制压暗层（evenOdd 挖孔），避免 BackdropFilter / 液态玻璃采样到已压暗内容。
///
/// dim 先渲染（全屏 ColoredBox），然后面板的 BackdropFilter 采样时会把 dim 也包含进去，
/// 导致玻璃面板看起来也被压暗了。这个 painter 用 evenOdd 路径在面板区域"挖洞"，
/// 让压暗只覆盖面板以外的区域。
class _SheetDimPainter extends CustomPainter {
  _SheetDimPainter({
    required this.dimColor,
    required this.dimProgress,
    this.excludeRect,
  });

  final Color dimColor;
  final double dimProgress;
  final Rect? excludeRect;

  @override
  void paint(Canvas canvas, Size size) {
    if (dimProgress <= 0.001) return;

    final paint = Paint()
      ..color = dimColor.withValues(alpha: dimColor.a * dimProgress);
    final fullRect = Offset.zero & size;

    if (excludeRect == null ||
        excludeRect!.isEmpty ||
        excludeRect!.isInfinite) {
      canvas.drawRect(fullRect, paint);
      return;
    }

    // 确保挖孔区域不超出画布边界
    final hole = excludeRect!.intersect(fullRect);
    if (hole.isEmpty || hole.width <= 0 || hole.height <= 0) {
      canvas.drawRect(fullRect, paint);
      return;
    }

    // evenOdd 模式：外框（全屏）填色，内框（面板）挖空
    final path = Path()
      ..addRect(fullRect)
      ..addRect(hole)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SheetDimPainter oldDelegate) {
    return oldDelegate.dimColor != dimColor ||
        oldDelegate.dimProgress != dimProgress ||
        oldDelegate.excludeRect != excludeRect;
  }
}

/// Home timetable sheets: edge-flush chrome + lighter barrier.
/// Nested [HyperosSheetFrame]s default to frosted glass.
Future<T?> showHomeHyperosSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isDismissible = true,
  bool enableDrag = true,
  bool useRootNavigator = false,
  bool padForKeyboard = true,
  Color? barrierColor,
  HyperosSheetChrome chrome = HyperosSheetChrome.edge,
}) {
  return showHyperosSheet<T>(
    context: context,
    builder: builder,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    useRootNavigator: useRootNavigator,
    padForKeyboard: padForKeyboard,
    chrome: chrome,
    barrierColor:
        barrierColor ??
        Colors.black.withValues(
          alpha: HyperosBlurredHeader.sheetBarrierAlphaOf(context),
        ),
  );
}
