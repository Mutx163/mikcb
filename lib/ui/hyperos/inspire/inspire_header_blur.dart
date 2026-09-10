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

  /// 高斯档底边渐隐收边所占的玻璃带比例。
  ///
  /// 取值很小：整条带子保持均匀强度，只在最下方一小段收边，避免玻璃带
  /// 与内容之间出现硬切边。
  static const gaussianFadeExtent = 0.12;

  /// 设备是否支持 shader filter（Inspire Blur 的兜底条件）。
  static bool get _shaderFilterSupported => ImageFilter.isShaderFilterSupported;

  /// 是否允许在给定 context 下使用渐进模糊。
  static bool canRender(BuildContext context) {
    if (!_shaderFilterSupported) {
      return false;
    }
    return HyperosBlurredHeader.backdropBlurEnabled(context);
  }

  static InspireBlurConfig configFor(
    HeaderBlurStyle style, {
    required double sigma,
  }) {
    return switch (style) {
      // 渐进档：模糊自顶边满强度向下衰减到 0。
      // extent 略大于 1，让「完全清晰」落在带底之外，玻璃带内部不会出现
      // 一段死平的零模糊区。
      HeaderBlurStyle.inspire => InspireBlurConfig.topToBottom(
        sigma: sigma,
        extent: 1.15,
      ),
      // 高斯档：整带均匀强度，仅底边一小段渐隐收边。
      HeaderBlurStyle.gaussian => InspireBlurConfig.topToBottom(
        sigma: sigma,
        extent: gaussianFadeExtent,
        fadeCurve: Curves.easeInOutSine,
      ),
    };
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
          // 衬底色始终画在模糊之上：模糊把壁纸压成色块，衬底负责对比度。
          Positioned.fill(child: ColoredBox(color: tint)),
          child,
        ],
      ),
    );
  }
}
