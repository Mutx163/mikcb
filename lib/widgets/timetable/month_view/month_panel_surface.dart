import 'package:flutter/material.dart';

import '../../../models/timetable_settings.dart';
import '../../../ui/hyperos/hyperos.dart';
import '../../../utils/card_surface_ink.dart';
import '../../../utils/home_page_background.dart';
import '../../course_surface.dart';

/// 月视图**信息区**卡片的填充色 —— 唯一来源（2026-10-23 改口径）。
///
/// ## 为什么是「白卡」而不是「面板里的灰卡」
///
/// 用户口径：「下面的信息区域也改成这样，单独的卡片，而不是一个整体大卡片」，
/// 并给了小米日历的截图 —— 那边信息区的卡是**白卡浮在壁纸上**，卡与卡之间
/// 露出壁纸。
///
/// 旧版本这里返回 `surfaceContainerHighest`，那是因为当时卡片躺在**一整块
/// 白色面板里面**：卡片若也用 `surface`，与面板底逐位相同、卡就不存在了
/// （2026-10-22 实测深色下对比 **1.00:1**）。现在面板没了，卡片直接浮在
/// 壁纸上，所以：
///
/// * 填充取回 `surface`（白），与上半那张日历卡**同一个颜色** —— 上下两种卡
///   于是读作同一套；
/// * 区分靠圆角 + 卡与卡之间的缝隙（露出壁纸），不靠灰白差。
///
/// ## 为什么不再按 brightness 分叉
///
/// `surface` 在深浅两套主题下本来就是对的值（白 / 近黑），分叉就是漏改一半的
/// 成因（2026-10-22 那次深色分支还写着 `surface`，与面板底同色，整块板上的
/// 卡片全部消失）。
Color monthInfoCardFill(BuildContext context) {
  return Theme.of(context).colorScheme.surface;
}

/// 信息卡里的墨色：**按卡面实际亮度**判（卡浮在壁纸上，玻璃档会透壁纸）。
///
/// ## 为什么不能直接给 `onSurface`
///
/// 旧版式里信息区是不透明白板，卡里一律用主题墨色（`onSurface`）—— 那是对的，
/// 因为壁纸在板下面看不见。现在卡直接躺在壁纸上：
///
/// * 实体档：卡面就是 `surface`，用主题墨色仍然对；
/// * 玻璃档（用户可能把课程卡材质调成玻璃）：卡面是「自身底色 × 染色比例 +
///   壁纸 × 余量」，暗壁纸上的玻璃卡是深色的，此时主题墨色（通常近黑）
///   就是黑字压深卡 —— 直接不可读。
///
/// 所以这里按 [cardSurfaceInk] 的同一套判据算（它已经处理了 washAlpha、壁纸
/// 亮度未知时的回落），与周视图 / 日视图卡片同源。
Color monthInfoCardInk({
  required BuildContext context,
  required TimetableSettings settings,
  required Color cardFill,
  double? wallpaperLuminance,
}) {
  final blurOn = HyperosBlurredHeader.backdropBlurEnabled(context);
  final style = dayViewContentCardSurfaceStyle(
    settings,
    backdropBlurOn: blurOn,
  );
  return cardSurfaceInk(
    fill: cardFill,
    washAlpha: CourseSurface.washAlpha(context, style),
    wallpaperLuminance: wallpaperLuminance,
    fallback: Theme.of(context).colorScheme.onSurface,
  );
}
