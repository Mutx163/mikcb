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
/// ## 边缘不外推采样（2026-09-21）
///
/// 真机口径：「返回键圆钮的**圆内部顶上有黑边**，始终都有」—— 贴着圆外缘内侧
/// 一圈暗弧，顶部最明显。
///
/// 成因：标准档的折射位移 `u_refract = 8` dp，而着色器在圆的**外缘**把采样点
/// **朝外**推最多这个量（`push` 在贴边处取峰值）。也就是说圆最外那 `band = 7` dp
/// 的一圈里，读到的根本不是圆背后的像素，而是**圆外约 8dp 处的内容**；圆钮顶到
/// 带顶只有 4dp，所以顶上那圈取到的是带子最上沿（含状态栏条）的内容，那里比圆
/// 背后明显更深 —— 读成一圈暗弧。
///
/// 用户口径（2026-09-21）：「让他这个按钮**外边缘不要采样**」。那就把位移压到 0：
/// 圆内每个像素都只取**正下方那一个像素**（`sampleScreen = screenPx`），暗弧从
/// 结构上不可能出现，也不必再去猜「圆外那 8dp 到底是什么内容」。
///
/// 代价：边缘那圈**透镜感**（折射）随之消失，圆钮读作「一块干净的磨砂圆盘 +
/// 一圈边光」，而不再是一颗折射玻璃球。这是用户拍板的取舍（先保证没有暗弧）；
/// 想留一点透镜感就把这个值抬到 2~3，别回到 8。
///
/// 顺带记一笔**被真机否掉的两条路**，别再走：
/// * **换采样源**（子页页壳挂全尺寸 `UndimmedBackdropCapture` + `grouped: true`，
///   2026-09-21 第一版）。最强理由：仓库里首页玻璃带那条黑线就是靠它治好的
///   （`.agents/handoff/2026-09-20-weekday-bar-black-line.md` §8）。真机验收
///   **暗弧仍在** —— 它治的是「位移踩进模糊扩出来的空环」，与这处暗弧不是同一个
///   因；而且它顺手改掉了「圆钮背后取什么」（改成取未压暗的原始内容），是白带的
///   副作用。已整体回退。
/// * **只压一点点**（例如 `narrowSurfaceMaxRefraction(44) = 12.32`）：那个值比标准
///   档的 8 还大，压不到；要压就得显式给比 8 更小的数。
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
///
/// ## 外浮影跟着圆底走（2026-09-23）
///
/// 圆底在显影时垫一圈**小而淡**的外浮影；停在页顶的光箭头不带。原先实底兜底
/// 自己带阴影而玻璃分支没有，两支不同源 —— 现在浮影上提到按钮层，玻璃 / 兜底
/// 两支共用一份。
///
/// **为什么不用 [HyperosGlassShadow.shadow]**（弹窗 / 首页球那份数值，2026-09-23
/// 真机否掉）：那颗是给弹窗衬在页面上的，blur 20 外扩太远，而这颗按钮贴着带边 ——
/// 顶栏磨砂带整体在 [ClipRect] 里（左右与上沿就是带框，下沿只让
/// `bottomOverhang`），外扩的阴影被带框切出**直边**（用户看到的"边界是正方形"），
/// 还压在带的渐变模糊上把背景搅浑。这里的几何余量（折叠大标题条：条高 52、
/// 按钮 44 居中）：按钮下沿距带底只 4dp、左右各 16dp，所以收成 blur 4 / 偏移
/// 1.5dp —— 越过带底的那截强度已衰减到不可见（约峰值的 2%），切不出直边，也
/// 基本不碰渐变模糊区。**这颗按钮若挪去更小的容器，先重算这段余量。**
///
/// 垫影的 [Stack] 必须 `Clip.none`：阴影画在 44×44 之外，默认裁剪会整圈切掉
/// （上游 `MiuixGlassIconButton` 自己那层阴影同样因此开 `Clip.none`）。
class HyperosBackButton extends StatelessWidget {
  const HyperosBackButton({super.key, required this.onPressed});

  /// 本按钮专属的浮影：小而淡（见类注释「为什么不用 [HyperosGlassShadow.shadow]」）。
  static const BoxShadow _shadow = BoxShadow(
    color: Color(0x1A000000),
    offset: Offset(0, 1.5),
    blurRadius: 4,
  );

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    // 只有"内容已经压到顶栏带下面"时才长出圆底；停在页顶就是一根光箭头。
    // 判据走 InheritedWidget 依赖，翻面时本元素自己重建，不需要
    // [HyperosSubpage]（StatelessWidget）跟着重建。
    final contentUnder = HyperosBlurredHeaderScope.contentUnderHeaderOf(context);
    return Stack(
      // 外浮影越出按钮自身的 44×44，默认裁剪会把整圈阴影切没，见类注释。
      clipBehavior: Clip.none,
      children: [
        if (contentUnder) ...[
          // 外浮影垫在玻璃之下：玻璃 / 实底兜底两支共用（见类注释）。
          // key 供测试精确钉这一份 —— 实底兜底在测试环境里会渲染，谓词类
          // 匹配分不清"兜底自带的"与"按钮层垫的"。
          const Positioned.fill(
            child: DecoratedBox(
              key: ValueKey('hyperos-back-button-shadow'),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [_shadow],
              ),
            ),
          ),
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) => LiquidGlassSurface(
                // 正圆：半径取**实际边长**的一半（上游那颗按钮 44×44；它的默认值
                // 将来若变，这里跟着走，不会变成圆角方块）。
                borderRadius: constraints.maxWidth / 2,
                role: LiquidGlassRole.pinnedChrome,
                // 不外推采样：圆内每个像素只取正下方那一个，见类注释
                // 「边缘不外推采样」。标准档的位移（8dp）会让最外 7dp 那一圈读到
                // 圆外约 8dp 处的内容，顶部那圈因此读成暗弧。
                maxRefraction: 0,
                fallbackBuilder: (fallbackContext) => DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: HyperosColors.surfaceContainer(fallbackContext),
                    // 浮影不再在这里画：按钮层统一垫（见 [HyperosGlassShadow]），
                    // 两支各画一份会叠成双层影。
                  ),
                  child: const SizedBox.expand(),
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ],
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
