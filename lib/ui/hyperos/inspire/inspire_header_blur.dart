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
    super.key,
  });

  /// 玻璃衬底色（与高斯档共用同一套取色逻辑，保证两档观感连续）。
  final Color tint;

  /// 玻璃带内容（标题行等）。
  final Widget child;

  final bool blurEnabled;
  final HeaderBlurStyle style;

  /// 模糊强度上限（对应 `InspireBlurConfig` 的 sigma）。
  final double blurSigma;

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

  /// 渐进档衬底在底边保留的不透明度比例。
  ///
  /// 均匀 tint 会把 inspire 模糊的「上浓下淡」抹平成一整条半透明；渐进
  /// 档必须让衬底也随方向衰减。底边取 0：玻璃带与课表之间不得出现
  /// 可见切边，完全靠顶区对比度保证状态栏/标题可读。
  static const progressiveTintBottomScale = 0.0;

  /// 设备是否支持 shader filter（Inspire Blur 的兜底条件）。
  static bool get _shaderFilterSupported => ImageFilter.isShaderFilterSupported;

  /// 是否允许在给定 context 下使用渐进模糊。
  static bool canRender(BuildContext context) {
    if (!_shaderFilterSupported) {
      return false;
    }
    return HyperosBlurredHeader.backdropBlurEnabled(context);
  }

  /// 高斯档：整带均匀强度。
  ///
  /// ⚠️ 必须用 [UniformDistribution]：包的 `extent` 语义是「模糊从顶边衰减
  /// 到 0 的位置（占带宽比例）」，不是「底边收边宽度」——曾把 0.12 当收边
  /// 区传入，结果整条带只有顶部 12% 有模糊、下面全清晰（2026-09-12 真机
  /// 「全局柔光 + 子页高斯 = 顶栏全透明」的根因）。渐隐收边如需保留，应改
  /// 用带自定义 stops 的渐变分布，而不是缩 extent。
  static InspireBlurConfig configFor(
    HeaderBlurStyle style, {
    required double sigma,
  }) {
    return switch (style) {
      // 渐进档：模糊自顶边满强度向下衰减到 0。
      // 默认 extent=1：完全清晰正好落在带底，与课表衔接处无残留模糊切边。
      HeaderBlurStyle.inspire => InspireBlurConfig.topToBottom(
        sigma: sigma,
      ),
      // 高斯档：整带均匀模糊。
      HeaderBlurStyle.gaussian => InspireBlurConfig(
        distribution: const UniformDistribution(),
        sigma: sigma,
      ),
    };
  }

  /// 渐进档衬底：随方向上浓下淡，与模糊强度梯度对齐。
  ///
  /// 高斯档保持均匀 [tint]。渐进档若继续盖一层整幅半透明色，观感会退化
  /// 成「一致的半透明条」，完全看不出 iOS 式的顶浓底清。
  Widget _tintLayer() {
    final useGradient = style == HeaderBlurStyle.inspire && !opaqueAtRest;
    final base = useGradient ? tint : null;
    if (base == null) {
      return Positioned.fill(child: ColoredBox(color: tint));
    }
    final bottom = base.withValues(
      alpha: base.a * progressiveTintBottomScale,
    );
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [base, bottom],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final useBlur = blurEnabled && canRender(context);

    return ClipRect(
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          if (useBlur)
            Positioned.fill(
              child: IgnorePointer(
                child: Inspire.backdropBlur(
                  config: configFor(style, sigma: blurSigma),
                  // 顶栏不参与手势，无需截获指针；自身已经裁剪在带内。
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          // 衬底画在模糊之上：模糊负责「糊」，衬底负责可读对比度。
          _tintLayer(),
          child,
        ],
      ),
    );
  }
}
