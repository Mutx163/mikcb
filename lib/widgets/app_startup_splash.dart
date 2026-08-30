import 'package:flutter/material.dart';

import '../ui/hyperos/hyperos_radius.dart';

/// 自绘启动画面最短展示时长：保证品牌画面可感知。对齐 2114 时代系统启动
/// 画面的自然可见时长（引擎启动 + 初始化期）；初始化更慢时按实际时长
/// 展示，不加额外等待。
const Duration kMinSplashDuration = Duration(milliseconds: 650);

/// 距最短展示时长还差的滞留时间；已超过则为 0。
Duration splashHoldRemaining(Duration elapsed) {
  final remaining = kMinSplashDuration - elapsed;
  return remaining.isNegative ? Duration.zero : remaining;
}

/// 应用自绘启动画面：2114 发布版同款全出血 launcher 图标 + 常规字重品牌字。
///
/// Android 12+ 的系统启动画面窗口本身无法删除，原生侧已剥到纯色底
/// （values-v31 styles：图标 transparent、无品牌图），品牌呈现完全由本页
/// 接管——图标清晰度、圆角、字号、字色、排版都走应用自己的体系，不再
/// 经过系统图标遮罩/缩放/羽化链路（此前三轮真机翻车均源于该链路）。
class AppStartupSplash extends StatelessWidget {
  const AppStartupSplash({super.key});

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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: iconSize,
              height: iconSize,
              child: ClipRRect(
                // 圆角走应用自己的图标徽章比例（HyperosRadius.chipRadius），
                // 不再依赖系统遮罩形状。
                borderRadius:
                    BorderRadius.circular(HyperosRadius.chipRadius(iconSize)),
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
    );
  }
}
