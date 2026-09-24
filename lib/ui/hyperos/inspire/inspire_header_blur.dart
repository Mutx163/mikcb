import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:inspire_blur/inspire_blur.dart';

import '../../../models/header_blur_style.dart';
import '../hyperos_blurred_header.dart';

/// 顶栏玻璃带的渐进模糊实现（基于 `inspire_blur`）。
///
/// 与 [FrostedHeaderBackground] 的均匀 `BackdropFilter` 不同，这里用
/// `Inspire.backdropBlur` 的自定义 GPU shader 做**变量**模糊：模糊强度
/// 在玻璃带内按方向连续变化，观感更接近 iOS 系统栏。
///
/// 两个调用点共享同一份配置与降级判定：
/// - 首页玻璃带（`HomePageChromeGlassFill`）
/// - 子页顶栏外壳（`HyperosFrostedHeaderShell`）
///
/// 降级链与既有材质保持一致：系统无障碍 / 降动效 / 高对比度、全局模糊
/// 开关关闭、Web / 桌面（[HyperosBlurredHeader.liveBlurSupported]）、或
/// 设备不支持 shader filter（`ImageFilter.isShaderFilterSupported`）时，
/// 只画 tint 衬底。
class InspireHeaderBlur extends StatelessWidget {
  const InspireHeaderBlur({
    required this.tint,
    required this.child,
    this.blurEnabled = true,
    this.style = HeaderBlurStyle.inspire,
    this.blurSigma = HyperosBlurredHeader.blurSigma,
    this.opaqueAtRest = false,
    this.bottomOverhang = 0,
    super.key,
  });

  /// 玻璃衬底色（与高斯档共用同一套取色逻辑，保证两档观感连续）。
  final Color tint;

  /// 玻璃带内容（标题行等）。
  final Widget child;

  final bool blurEnabled;
  final HeaderBlurStyle style;

  /// 高斯档的模糊强度上限（`InspireBlurConfig` 的 sigma）。
  ///
  /// **只服务 [HeaderBlurStyle.gaussian]**：高斯是基础模糊材质，粗细由全局
  /// 「模糊强度」（`FrostedAppearance.sheetBlurSigma`）决定。渐进档用
  /// [progressiveSigma] 等固定常量，不受此处影响。
  final double blurSigma;

  /// 模糊 / 衬底这条带比内容**再往下多画**的高度。
  ///
  /// 子页顶栏传 [HyperosBlurredHeader.subpageBandBottomOverhang]（用户口径
  /// 2026-09-23：「最底下模糊的边界再往下，超过标题底部一个字空间」）；其他
  /// 调用方（卡片、菜单井、弹窗面板）保持 0，观感逐像素不变。
  ///
  /// 实现是**只把下面这两层撑下去**：Stack 的高度仍由 [child] 决定，所以标题
  /// 位置、以及外壳被测量到的高度都不变 —— 只有"糊到哪儿为止"往下挪。
  final double bottomOverhang;

  /// 无内容压在带下时，是否把衬底铺满整条带（不向下渐隐）。
  ///
  /// 可折叠顶栏的模糊层是常驻挂载的（见 [HyperosFrostedHeaderShell]），
  /// 而 [HeaderBlurStyle.inspire] 的衬底会在底边渐隐到全透明。两者叠加会
  /// 留出一条「透明窗口」：内容还没真正压到带底、`contentUnderHeader`
  /// 仍为 false 时，模糊采样已把即将进入带内的内容糊进这条窗口——于是
  /// 内容先以一层无衬底的虚影出现，衬底随后才整条切进来，读起来就是
  /// 「内容快插到标题栏时顿一下」。顶上这一档后，常驻模糊在无内容时被
  /// 不透明衬底完全盖住，翻转点只剩一次衬底切换。
  final bool opaqueAtRest;

  /// 设备是否支持 shader filter（Inspire Blur 的兜底条件）。
  static bool get _shaderFilterSupported => ImageFilter.isShaderFilterSupported;

  /// 是否允许在给定 context 下使用渐进模糊。
  static bool canRender(BuildContext context) {
    if (!_shaderFilterSupported) {
      return false;
    }
    return HyperosBlurredHeader.backdropBlurEnabled(context);
  }

  /// 渐进档的**固定**参数（2026-09-23 用户口径：浓淡只要一个档位）。
  ///
  /// 这三个数不是随手取的，与
  /// [HyperosBlurredHeader.subpageBandBottomOverhang] 是一组：
  ///
  /// * [progressiveSigma] = 22（原来 15）：顶部更糊。抬到 22 是因为带子下半段
  ///   被 overhang 拉长之后，同样的 sigma 在视觉上会显得更薄。
  /// * [progressiveExtent] = 1：模糊自顶边满强度向下、**正好在带底**衰减到 0。
  ///   带底已经被 overhang 推到标题下方，所以"最底下那条模糊边界"落在标题底部
  ///   之下；而 extent = 1 保证边界处没有残留模糊，不会和下方清晰内容硬切。
  /// * [progressiveTintBottomScale] = 0：不加下部衬底（真机上衬底在带底留过
  ///   一条横向硬边，见 [tintGradient]）。
  static const progressiveSigma = 22.0;
  static const progressiveExtent = 1.0;
  static const progressiveTintBottomScale = 0.0;

  /// 高斯档：整带均匀强度。
  ///
  /// ⚠️ 必须用 [UniformDistribution]：包的 `extent` 语义是「模糊从顶边衰减
  /// 到 0 的位置（占带宽比例）」，不是「底边收边宽度」——曾把 0.12 当收边
  /// 区传入，结果整条带只有顶部 12% 有模糊、下面全清晰（2026-09-12 真机
  /// 「全局柔光 + 子页高斯 = 顶栏全透明」的根因）。渐隐收边如需保留，应改
  /// 用带自定义 stops 的渐变分布，而不是缩 extent。
  ///
  /// 纯函数便于测试：渐进档的 sigma / extent 全部来自上面的固定常量，
  /// 高斯档用 [gaussianSigma]（全局「模糊强度」）并整带均匀。
  static InspireBlurConfig configFor(
    HeaderBlurStyle style, {
    required double gaussianSigma,
  }) {
    return switch (style) {
      // 渐进档：模糊自顶边满强度向下按 extent 衰减到 0。
      // extent = 1：完全清晰正好落在**带底**（已含 overhang），与下方内容
      // 衔接处无残留模糊切边。
      HeaderBlurStyle.inspire => InspireBlurConfig.topToBottom(
        sigma: progressiveSigma,
        // 故意写死 1.0：这是"边界正好落在带底"的契约本身，后面调 sigma 时
        // 不该顺手把它当成可省的默认值。
        // ignore: avoid_redundant_argument_values
        extent: progressiveExtent,
      ),
      // 高斯档：整带均匀模糊，粗细走全局模糊强度。
      HeaderBlurStyle.gaussian => InspireBlurConfig(
        distribution: const UniformDistribution(),
        sigma: gaussianSigma,
      ),
    };
  }

  /// 渐进档衬底渐变：顶边满浓度，沿方向衰减，**带底恒为全透明**。
  ///
  /// 带底必须是 0：玻璃带外面是清晰内容，衬底只要在交界处还不是透明，就会
  /// 切出一条横向硬边（真机口径「最浓状态下底部出现一条横向」）。所以
  /// [progressiveTintBottomScale] 只抬高下半段的浓度（多一个中间 stop），
  /// 末段一律收敛到 0——任何取值都只在带内加雾，不带边。
  ///
  /// [bottomScale] = 0（默认）时退化成 [top, 透明] 两段，与接入调参前的观感
  /// 逐像素一致。
  @visibleForTesting
  static LinearGradient tintGradient(Color top, double bottomScale) {
    final transparent = top.withValues(alpha: 0);
    if (bottomScale <= 0) {
      return LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [top, transparent],
      );
    }
    final mid = top.withValues(alpha: top.a * bottomScale);
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [top, mid, transparent],
      stops: const [0, 0.75, 1],
    );
  }

  /// 渐进档衬底：随方向上浓下淡，与模糊强度梯度对齐；带底恒为透明。
  ///
  /// 高斯档保持均匀 [tint]。渐进档若继续盖一层整幅半透明色，观感会退化
  /// 成「一致的半透明条」，完全看不出 iOS 式的顶浓底清。
  Widget _tintLayer() {
    final useGradient = style == HeaderBlurStyle.inspire && !opaqueAtRest;
    if (!useGradient) {
      return _bandLayer(child: ColoredBox(color: tint));
    }
    return _bandLayer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: tintGradient(tint, progressiveTintBottomScale),
        ),
      ),
    );
  }

  /// 把一层铺满整条带，并按 [bottomOverhang] 往下多画一截。
  ///
  /// Stack 的高度由非定位的 [child] 决定，所以这两层撑出去的部分**不参与布局**
  /// —— 下沿能往下走，标题与外壳高度都不动。
  Widget _bandLayer({required Widget child}) {
    if (bottomOverhang <= 0) {
      return Positioned.fill(child: child);
    }
    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      bottom: -bottomOverhang,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final useBlur = blurEnabled && canRender(context);

    final band = Stack(
      fit: StackFit.passthrough,
      // Positioned bottom=-overhang 的模糊/衬底层要越过原始带高；
      // 内层 Stack 默认会在自身尺寸处裁掉那一截，外层扩展裁剪框也救不回来。
      clipBehavior: Clip.none,
      children: [
        if (useBlur)
          _bandLayer(
            child: IgnorePointer(
              child: Inspire.backdropBlur(
                config: configFor(style, gaussianSigma: blurSigma),
                // 顶栏不参与手势，无需截获指针；自身已经裁剪在带内。
                child: const SizedBox.expand(),
              ),
            ),
          ),
        // 衬底画在模糊之上：模糊负责「糊」，衬底负责可读对比度。
        _tintLayer(),
        child,
      ],
    );

    if (bottomOverhang <= 0) {
      return ClipRect(child: band);
    }
    // 默认 ClipRect 按自身尺寸裁剪，会把下沿那一截切掉 —— 这里把裁剪框往下
    // 放到带底（左右与上方仍是原框），其余行为不变。
    return ClipRect(clipper: _BandOverhangClipper(bottomOverhang), child: band);
  }
}

/// 把裁剪框按 [overhang] 往下扩一截的裁剪器（见 [InspireHeaderBlur.bottomOverhang]）。
class _BandOverhangClipper extends CustomClipper<Rect> {
  const _BandOverhangClipper(this.overhang);

  final double overhang;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width, size.height + overhang);

  @override
  bool shouldReclip(_BandOverhangClipper oldClipper) =>
      oldClipper.overhang != overhang;
}
