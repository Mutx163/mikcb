import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

import '../hyperos_blurred_header.dart';
import '../hyperos_glass_backdrop_host.dart';

/// 弹层磨砂面的**稳定快照版**：有采样源就用屏级录帧那条窄带，没有才回落实时模糊。
///
/// ## 为什么要有这个类
///
/// 磨砂档原本走实时 `BackdropFilter.grouped`，而**入场动画（弹簧缩放 + 揭示裁切）
/// 期间它采不到稳定背景** —— 面板会整段渲染成一层平的淡色、动画结束才「啪」地
/// 出现（`hyperos_popup_glass.dart` 里那条历史结论就是这么写的）。同期的柔性/
/// 液态两条高级材质靠**快照带**，入场时背景是定的。于是同一段运动轨迹，四种材质
/// 给出了四种观感：实底全程稳、柔光/液态背景定、磨砂飘。
///
/// 2026-09-16 统一口径：**入场期间所有材质都走同一张稳定背景** —— 也就是这里把
/// 磨砂接到与 [SoftGlassSurface] 完全相同的两条分支上：
///
/// - **本屏有采样源**（`_controller != null`）→ 用 [MiuixGlass] +
///   [MiuixGlassMaterials.popupViewGlass] 渲染，背景来自屏级录帧写进本表面
///   [HyperosZoneBackdrop] 的那条窄带。快照到达前的第一帧画**透明**（与柔光面
///   同一口径：那一段画实底会闪一块"假玻璃"，画透明至少轮廓与文字都在）。
/// - **没有采样源**（模糊总开关关、系统降级、本屏没有宿主）→ 保持改动前的实时
///   `BackdropFilter.grouped` + 底色。这条路是真降级，快照永远不会来，必须维持
///   原观感，不能因为这次统一把它变差。
///
/// 判定「有没有采样源」与柔光面同源（[HyperosGlassBackdropRegistry.resolve] +
/// 被盖住再回来时靠 [TickerMode] 重建依赖），别在这里另起一套。
class StableFrostedSurface extends StatefulWidget {
  const StableFrostedSurface({
    super.key,
    required this.cornerRadius,
    required this.child,
  });

  final double cornerRadius;
  final Widget child;

  @override
  State<StableFrostedSurface> createState() => _StableFrostedSurfaceState();
}

class _StableFrostedSurfaceState extends State<StableFrostedSurface> {
  HyperosGlassBackdropController? _controller;

  /// 本表面自己的采样源：由屏级控制器按"这块面背后那条窄带"写入。
  final HyperosZoneBackdrop _backdrop = HyperosZoneBackdrop();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // `OverlayEntry` 会给被盖住的路由关掉 TickerMode，回来时打开；而
    // [HyperosGlassBackdropRegistry.resolve] 是纯查表、不建立依赖，路由 push/pop
    // 换了栈顶也不会重建本 widget —— 不在这里重新解析，采样源会永远停在旧屏上
    // （柔光面踩过同一个坑，见 soft_glass_surface.dart 的同类注释）。
    TickerMode.valuesOf(context);
    _bindController();
  }

  @override
  void didUpdateWidget(StableFrostedSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    _bindController();
  }

  void _bindController() {
    final resolved = HyperosGlassBackdropRegistry.resolve(context);
    // 已释放的宿主不再持有：它的 backdrop 图已 dispose，继续采样会踩到已释放的
    // ui.Image。
    final next = (resolved == null || resolved.disposed) ? null : resolved;
    if (identical(next, _controller)) {
      return;
    }
    _controller = next;
  }

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(widget.cornerRadius);
    final controller = _controller;

    // 真降级：本屏没有采样源，快照永远不会来 —— 维持改动前的实时模糊观感。
    if (controller == null) {
      final sigma = HyperosBlurredHeader.blurSigmaOf(context);
      final tint = HyperosBlurredHeader.sheetTintColor(context, withBlur: true);
      return ClipRRect(
        borderRadius: borderRadius,
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            Positioned.fill(
              child: BackdropFilter.grouped(
                filter: ImageFilter.blur(
                  sigmaX: sigma,
                  sigmaY: sigma,
                  tileMode: TileMode.clamp,
                ),
                child: ColoredBox(color: tint),
              ),
            ),
            widget.child,
          ],
        ),
      );
    }

    // 统一分支：与柔光面同源的稳定快照路径。模糊半径吃用户档位（与柔光共用
    // `popupViewGlass` 这个基准），底色由材质的三层色给出。
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sigma = HyperosBlurredHeader.blurSigmaOf(context);
    return MiuixGlass(
      backdrop: _backdrop,
      style: MiuixGlassStyles.forTheme(isDark),
      material: MiuixGlassMaterials.popupViewGlass(
        isDark,
      ).copyWith(blurRadius: sigma),
      shape: MiuixGlassShape(borderRadius: borderRadius),
      // 等第一张快照的那一帧画透明（写了这点理由，别改回实底）：快照当帧末就到，
      // 下一帧即真材质；中间那帧画实底会闪一块假玻璃。真降级走上面那条分支。
      fill: const Color(0x00000000),
      shading: false,
      child: HyperosGlassBackdropReporter(
        controller: controller,
        backdrop: _backdrop,
        child: widget.child,
      ),
    );
  }
}
