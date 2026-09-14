import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:inspire_blur/inspire_blur.dart';

import '../../../models/header_blur_style.dart';
import '../../../models/progressive_blur_tuning.dart';
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
    this.tuning,
    this.opaqueAtRest = false,
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
  /// 「模糊强度」滑杆（`FrostedAppearance.sheetBlurSigma`）决定。渐进档改用
  /// 它自己的档位 [tuning]，两者互不干扰。
  final double blurSigma;

  /// 渐进档参数（预设 + 自定义）。null = 读 [FrostedAppearanceScope] 里的
  /// 全局设置（与柔光/液态调参同一口径：调用方只在预览等场景显式覆盖）。
  final ProgressiveBlurTuning? tuning;

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

  /// 高斯档：整带均匀强度。
  ///
  /// ⚠️ 必须用 [UniformDistribution]：包的 `extent` 语义是「模糊从顶边衰减
  /// 到 0 的位置（占带宽比例）」，不是「底边收边宽度」——曾把 0.12 当收边
  /// 区传入，结果整条带只有顶部 12% 有模糊、下面全清晰（2026-09-12 真机
  /// 「全局柔光 + 子页高斯 = 顶栏全透明」的根因）。渐隐收边如需保留，应改
  /// 用带自定义 stops 的渐变分布，而不是缩 extent。
  ///
  /// 纯函数便于测试：渐进档的 sigma / extent 全部来自 [tuning]，高斯档
  /// 用 [gaussianSigma]（全局「模糊强度」滑杆）并整带均匀。
  static InspireBlurConfig configFor(
    HeaderBlurStyle style, {
    required double gaussianSigma,
    required ProgressiveBlurTuning tuning,
  }) {
    return switch (style) {
      // 渐进档：模糊自顶边满强度向下按 extent 衰减到 0。
      // tuning.extent = 1（预设「标准」的默认）：完全清晰正好落在带底，
      // 与课表衔接处无残留模糊切边。
      HeaderBlurStyle.inspire => InspireBlurConfig.topToBottom(
        sigma: tuning.sigma,
        extent: tuning.extent,
      ),
      // 高斯档：整带均匀模糊，粗细走全局模糊强度。
      HeaderBlurStyle.gaussian => InspireBlurConfig(
        distribution: const UniformDistribution(),
        sigma: gaussianSigma,
      ),
    };
  }

  /// 当前生效的渐进档参数：显式 [tuning] 优先，否则读全局设置。
  ProgressiveBlurTuning resolveTuning(BuildContext context) =>
      tuning ?? FrostedAppearanceScope.of(context).progressiveBlurTuning;

  /// 渐进档衬底渐变：顶边满浓度，沿方向衰减，**带底恒为全透明**。
  ///
  /// 带底必须是 0：玻璃带外面是清晰内容，衬底只要在交界处还不是透明，就会
  /// 切出一条横向硬边（真机口径「最浓状态下底部出现一条横向」）。所以
  /// [ProgressiveBlurTuning.tintBottomScale] 只抬高下半段的浓度（多一个中间
  /// stop），末段一律收敛到 0——任何取值都只在带内加雾，不带边。
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
  Widget _tintLayer(ProgressiveBlurTuning tuning) {
    final useGradient = style == HeaderBlurStyle.inspire && !opaqueAtRest;
    if (!useGradient) {
      return Positioned.fill(child: ColoredBox(color: tint));
    }
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: tintGradient(tint, tuning.tintBottomScale),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final useBlur = blurEnabled && canRender(context);
    final tuning = resolveTuning(context);

    return ClipRect(
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          if (useBlur)
            Positioned.fill(
              child: IgnorePointer(
                child: Inspire.backdropBlur(
                  config: configFor(
                    style,
                    gaussianSigma: blurSigma,
                    tuning: tuning,
                  ),
                  // 顶栏不参与手势，无需截获指针；自身已经裁剪在带内。
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          // 衬底画在模糊之上：模糊负责「糊」，衬底负责可读对比度。
          _tintLayer(tuning),
          child,
        ],
      ),
    );
  }
}
