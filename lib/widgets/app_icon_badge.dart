import 'package:flutter/material.dart';

import '../services/bundled_assets.dart';
import 'bundled_asset_image.dart';

/// App 图标方块：圆角裁切 + 发丝描边 + 同色系极轻投影。
///
/// ## 为什么不用「彩色光晕」也不用「中性灰投影」
///
/// 图标资源是**不透明**的整块方块（717×717、四角不透明），自带底色
/// `#F3F8F6`（很淡的薄荷绿），画面主色是低饱和青绿（约 `#7EBCC6`）。
/// 它所在的卡片是纯白 `#FFFFFF`，页面底是 `#F2F2F2`——三者亮度只差 3% 左右，
/// 色相却各不同（薄荷 / 纯白 / 中性灰），所以：
///
/// - **中性灰投影**（2026-10-19 第一版）压在这三种近白上，读起来是「脏」；
/// - **主题色光晕**（更早的实现，`colorScheme.primary` 18%）默认是蓝
///   `#3482FF`，青绿图标下压一层蓝，是撞色。
///
/// 现在的做法把「边界」和「浮起」拆开：边界交给一圈 0.75dp 的描边（把图标
/// 「扣」在白卡上），浮起交给取自图标自己青绿的极轻投影（不引入新色相）。
/// 图标资源若换色，[_artTint] 要跟着重取。
class AppIconBadge extends StatelessWidget {
  const AppIconBadge({super.key, this.size = 72, this.radius});

  final double size;

  /// 默认按 84dp 设计稿的比例换算（24/84），与启动图标在桌面上的观感一致。
  final double? radius;

  /// 取自 `assets/branding/launcher_icon.png` 的青绿水系。
  static const Color _artTint = Color(0xFF7EBCC6);

  /// 描边：中性 8% 墨。不用主题色——描边只负责「边界」，不参与配色。
  static const Color _ringColor = Color(0x14000000);

  @override
  Widget build(BuildContext context) {
    final cornerRadius = radius ?? size * 24 / 84;
    final borderRadius = BorderRadius.circular(cornerRadius);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: _artTint.withValues(alpha: 0.22),
            blurRadius: size * 0.13,
            offset: Offset(0, size * 0.04),
          ),
        ],
      ),
      // 用 foregroundDecoration 而不是 decoration 的 border：decoration 画在
      // 子级**下面**，会被不透明的图标整块盖掉，描边根本看不见。
      foregroundDecoration: BoxDecoration(
        borderRadius: borderRadius,
        border: Border.all(color: _ringColor, width: 0.75),
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BundledAssetImage(
          assetPath: BundledAssets.launcherIcon,
          fit: BoxFit.cover,
          cacheWidth: (size * 2).round(),
          cacheHeight: (size * 2).round(),
        ),
      ),
    );
  }
}
