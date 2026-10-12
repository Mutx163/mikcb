import 'package:flutter/material.dart';

import '../ui/hyperos/hyperos_miuix_spec.dart';
import '../ui/hyperos/hyperos_motion.dart';
import '../ui/hyperos/hyperos_radius.dart';

/// 自绘启动画面最短展示时长：保证品牌画面可感知。对齐 2114 时代系统启动
/// 画面的自然可见时长（引擎启动 + 初始化期）；初始化更慢时按实际时长
/// 展示，不加额外等待。
///
/// 2026-10-10：650 → 400ms。原先靠「静止画面挂满 650ms」保证品牌可感知，
/// 而静止画面等久了用户读作「卡住了」。现在品牌呈现由入场动效承担
/// （见 [AppStartupSplash]）：淡入 + 上移约 300ms 内完成，观感是「正在
/// 加载」，剩下的时长只是让品牌停一下，不再需要 650ms。
const Duration kMinSplashDuration = Duration(milliseconds: 400);

/// 距最短展示时长还差的滞留时间；已超过则为 0。
Duration splashHoldRemaining(Duration elapsed) {
  final remaining = kMinSplashDuration - elapsed;
  return remaining.isNegative ? Duration.zero : remaining;
}

/// 品牌入场动效的基准时长（毫秒）。
///
/// 取 [HyperosMiuixNavigation.transitionDurationMs] 同族的 300ms：与页面转场
/// 同一量级，淡入这一段读起来像「App 正在进场」，而不是一次额外的等待。
/// 实际时长经 [HyperosMotionPlatform.scaledDuration] 跟随用户的过渡速度设置。
const int kSplashEntranceMs = 300;

/// 应用自绘启动画面：2114 发布版同款全出血 launcher 图标 + 常规字重品牌字。
///
/// Android 12+ 的系统启动画面窗口本身无法删除，原生侧已剥到纯色底
/// （values-v31 styles：图标 transparent、无品牌图），品牌呈现完全由本页
/// 接管——图标清晰度、圆角、字号、字色、排版都走应用自己的体系，不再
/// 经过系统图标遮罩/缩放/羽化链路（此前三轮真机翻车均源于该链路）。
///
/// ## 入场动效
///
/// 2026-10-10 起，图标与品牌字从「下方 12px + 透明」淡入到位，约 300ms。
///
/// 为什么值得加：本页要停 [kMinSplashDuration]，而初始化慢时机型上还会
/// 更久（壁纸解码 + 高斯模糊 + 着色器编译都在这一段里跑）。**一帧不动的
/// 画面挂 1 秒，用户读作「卡死了」；同样时长的淡入动效，用户读作「正在
/// 加载」**。感知差别极大，成本只是启动画面子树里的一次位移动画。
///
/// 为什么是淡入 + 上移、而不是缩放或旋转：这两个只改 transform / opacity，
/// 不触发重排、不重绘位图（图标是 717px 源图），合成层直接算，几乎不占
/// UI 线程。缩放在 RasterCache 未命中时要重新采样那张大图。
class AppStartupSplash extends StatefulWidget {
  const AppStartupSplash({super.key});

  @override
  State<AppStartupSplash> createState() => _AppStartupSplashState();
}

class _AppStartupSplashState extends State<AppStartupSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    // 进场时长走应用自己的动效体系：用户改过「过渡速度」时同步跟着变，
    // 关掉动画（scale=0）时 [scaledDuration] 返回 0，控制器立刻到位。
    duration: HyperosMotionPlatform.scaledDuration(kSplashEntranceMs),
  );

  /// 动效里位移量：从下方 12 个逻辑像素淡入到位。
  static const _slideDistance = 12.0;

  /// 位移曲线：与 HyperOS 页面转场同一族（fast_out_extra_slow_in）——
  /// 起步快、收尾慢，读起来是「到位」而不是「飘过来」。
  late final Animation<double> _entrance = CurvedAnimation(
    parent: _controller,
    curve: HyperosMiuixNavigation.transitionCurve,
  );

  @override
  void initState() {
    super.initState();
    // 首帧（= 本页上屏那一帧）就已经是动画起点：用户看到的第一眼就是
    // 「开始淡入」，不会先完整定格再重新动一次。
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    // 与原生启动井（splash_background：白天 #FFFFFF / 夜间 #121212）同色，
    // 系统纯色底 → 本页无感衔接。
    const iconSize = 112.0;
    return ColoredBox(
      color: isDark ? const Color(0xFF121212) : Colors.white,
      child: Center(
        child: AnimatedBuilder(
          animation: _entrance,
          builder: (context, child) {
            return Opacity(
              opacity: _entrance.value.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, _slideDistance * (1 - _entrance.value)),
                child: child,
              ),
            );
          },
          // child 提出来：子树不随动画重建，只重建外层两个 widget。
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: iconSize,
                height: iconSize,
                child: ClipRRect(
                  // 圆角走应用自己的图标徽章比例（HyperosRadius.chipRadius），
                  // 不再依赖系统遮罩形状。
                  borderRadius: BorderRadius.circular(
                    HyperosRadius.chipRadius(iconSize),
                  ),
                  child: const Image(
                    image: AssetImage('assets/branding/launcher_icon.png'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 36),
              Text(
                '轻屿课表',
                style: TextStyle(
                  fontSize: 30,
                  // 品牌字口径（用户明确要求）：常规字重，勿加粗。
                  fontWeight: FontWeight.w400,
                  letterSpacing: 2,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
