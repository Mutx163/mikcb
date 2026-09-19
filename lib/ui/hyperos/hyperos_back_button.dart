import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

import 'hyperos_blurred_header.dart';
import 'hyperos_popup_glass.dart';
import 'hyperos_theme.dart';
import 'liquid/liquid_glass_surface.dart';

/// 子页左上角的返回键：**液态玻璃的标准档圆底 + 箭头**。
///
/// ## 圆底只在"内容压到顶栏下面"时出现
///
/// 停在页顶时它是一根光箭头，往下滑到内容钻到顶栏带下面才长出圆底。判据直接复用
/// 顶栏磨砂那一份 [HyperosBlurredHeaderScope.contentUnderHeaderOf]（= `scrollPixels >`
/// 阈值，折叠大标题的页面阈值取大标题展开量），所以圆底与磨砂带**同一时刻**翻面；
/// 翻面是瞬时的 —— 顶栏那条带本身也是瞬时换色（`InspireHeaderBlur` 里没有任何
/// 过渡动画），圆底跟着一起切才读作同一件事。
///
/// ## 材质：锁标准档的液态玻璃（2026-09-19 起）
///
/// 用户口径：「设置页面左上角的返回按钮……只能永远是玻璃然后标准档位」。
/// 所以圆底走 [LiquidGlassRole.pinnedChrome]：全局材质档位、作用范围开关、模糊总
/// 开关、自定义滑杆都不参与，只剩技术 / 系统门禁（见 [LiquidGlassSurface.isAvailable]），
/// 那时的兜底是一颗同色实心圆 + 同一处定义的浮影（不描边 —— 与首页球、弹窗同一条
/// 2026-09-19 决定）。
///
/// ## 为什么这次可以用实时玻璃
///
/// 2026-09-17 那版结论是「不要给它接采样源」，针对的是**快照**那条路：当时
/// [HyperosGlassBackdropHost] 的捕获子树包含玻璃自身，接采样源会读到上一帧的
/// 合成结果。液态玻璃走的是**实时 `BackdropFilter`**，不依赖任何快照，所以
/// 这条顾虑不成立；子页顶栏本来就是实时模糊，背景在它下面一直都在。
///
/// ## 实现细节
///
/// 上游那颗 [MiuixGlassIconButton] 保留下来只负责三件事：图标、44×44 命中区、
/// 按压缩放 —— 用 `surfaceAlpha: 0` 让它自己那层材质一次都不画（上游
/// `MiuixGlass.paint` 在 `cfg.alpha <= 0` 时直接早退），我们把自己那块玻璃叠在
/// 它下面。这样图标、命中区、按压手感与原先逐像素一致，换的只是"底下那层画什么"。
///
/// 没有 tooltip / semantics label：原先那颗也没有，加中文文案会带出一批 l10n 改动，
/// 等真要给无障碍标签时再一起做。
class HyperosBackButton extends StatelessWidget {
  const HyperosBackButton({super.key, required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    // 只有"内容已经压到顶栏带下面"时才长出圆底；停在页顶就是一根光箭头。
    // 判据走 InheritedWidget 依赖，翻面时本元素自己重建，不需要
    // [HyperosSubpage]（StatelessWidget）跟着重建。
    final contentUnder = HyperosBlurredHeaderScope.contentUnderHeaderOf(context);
    return Stack(
      children: [
        if (contentUnder)
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) => LiquidGlassSurface(
                // 正圆：半径取**实际边长**的一半（上游那颗按钮 44×44；它的默认值
                // 将来若变，这里跟着走，不会变成圆角方块）。
                borderRadius: constraints.maxWidth / 2,
                role: LiquidGlassRole.pinnedChrome,
                fallbackBuilder: (fallbackContext) => DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: HyperosColors.surfaceContainer(fallbackContext),
                    boxShadow: const [HyperosGlassShadow.shadow],
                  ),
                  child: const SizedBox.expand(),
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        // 图标 / 命中区 / 按压缩放都由它给；它自己的材质层用 surfaceAlpha 关掉。
        MiuixGlassIconButton(
          onPressed: onPressed,
          surfaceAlpha: 0,
          child: MiuixIcon(vector: MiuixIcons.os4.chevronBackward),
        ),
      ],
    );
  }
}
