import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

import '../../l10n/app_localizations.dart';
import '../../models/timetable_settings.dart';
import '../../ui/hyperos/hyperos.dart';
import 'timetable_home_header.dart';
import 'timetable_profile_switcher_trigger.dart';

/// 「软件名字那一行」——首页与所有独立页面**共用的唯一实现**（2026-10-21 立）。
///
/// ## 为什么必须抽出来
///
/// 用户口径：「顶部的软件名字位置，为什么显示和其他页面的高度是不完全一样的，
/// 看起来有变动，而且右边那个菜单按钮，也是不完全一样的，那个东西能不能提取成
/// 通用组件，就是软件名字那一行东西」。
///
/// 在此之前首页（`TimetableHomeStack`）与独立页面（`TimetablePageChromeShell`）
/// **各写了一份**同一行的拼装，两处漂了两处：
///
/// | 差异点 | 首页 | 独立页面（旧） | 后果 |
/// |---|---|---|---|
/// | 底部内边距 | 玻璃态 **0** | 恒为 **2**（用了默认值） | 标题与按钮整体**下移 1px** |
/// | 右侧按钮 | 按 `hasPartnerBinding` 决定 1~2 颗 | 只取 `.last` 一颗 | 间距与形态不同 |
///
/// `HyperosRootHeader` 的 `padding.bottom` 从 2 变 0，标题顶边会从 9.0 移到
/// 10.0（实测）—— 1px 的差肉眼能看出「跳一下」，这正是用户说的"看起来有变动"。
///
/// 抽成一个组件后，这类差异**只能改一处**，两边再也不会有第二种说法。
///
/// ## 谁负责什么
///
/// * 本组件只管**这一行长什么样**：返回箭头（可关）、软件名字 / 档案切换、
///   右侧图标；
/// * 背景、玻璃带、墨色作用域、菜单弹层仍由调用方的页面外壳负责 —— 首页那条栈
///   与独立页外壳的玻璃管线本来就不同（首页有自己的滚动/下拉语义），
///   把那些也塞进来会把两套生命周期混成一个。
class TimetableTitleBar extends StatelessWidget {
  const TimetableTitleBar({
    required this.settings,
    required this.activeProfileName,
    required this.onProfileTap,
    required this.foreground,
    required this.mutedForeground,
    required this.heartLink,
    required this.moreLink,
    required this.menuAnchor,
    required this.moreButtonKey,
    required this.onPrewarmGlass,
    required this.onReleaseGlass,
    required this.onShowTopActions,
    this.hasPartnerBinding = false,
    this.coupleOverlayActive = false,
    this.onToggleCoupleOverlay,
    this.showBackButton = false,
    required this.headerUsesFrostedChrome,
    super.key,
  });

  final TimetableSettings settings;

  /// 当前档案名（null = 未命名，触发区内不显示副标题）。
  final String? activeProfileName;

  final VoidCallback onProfileTap;

  /// 标题墨色（外壳按壁纸亮度判好的极性）。
  final Color foreground;
  final Color mutedForeground;

  /// 爱心 / 更多两颗玻璃球的锚点（可见图标画在外壳的常驻球上）。
  final LayerLink heartLink;
  final LayerLink moreLink;
  final MiuixGlassPopupAnchor menuAnchor;
  final GlobalKey moreButtonKey;

  final VoidCallback onPrewarmGlass;
  final VoidCallback onReleaseGlass;
  final VoidCallback onShowTopActions;

  /// 是否有情侣绑定：决定爱心那颗按钮出不出现。
  final bool hasPartnerBinding;
  final bool coupleOverlayActive;
  final ValueChanged<bool>? onToggleCoupleOverlay;

  /// 顶栏此刻是否真的走玻璃（`HomeChromeSpec.headerUsesFrostedChrome`）。
  ///
  /// ⚠️ **必须由调用方从 `HomeChromeSpec` 取**，不能用
  /// `settings.homePageHeaderBlurEnabled` 顶替：后者只是玻璃判据的**一个输入**，
  /// 还要看有没有壁纸、顶栏是否透壁纸、模糊管线是否在。用错会让底部内边距
  /// 在"有设置但没壁纸"时判成玻璃态 —— 那 1px 位移就又回来了。
  final bool headerUsesFrostedChrome;

  /// 是否显示返回箭头。
  ///
  /// 由调用方判定而不是本组件猜：独立页面在「坞内嵌页」这条路上没有「上一页」
  /// 语义（切换走底栏、系统返回直接退应用），那时不该出现返回键；
  /// 首页则永远不显示。
  final bool showBackButton;

  /// 标题文字的左侧微调（与首页 `_homeTitleHorizontalNudge` 同一个值）。
  ///
  /// 4 不是随手取的：软件名字默认贴着返回箭头 / 屏幕左缘，直接顶格读起来偏挤。
  static const double titleHorizontalNudge = 4;

  /// **玻璃态下底部内边距为 0**，非玻璃态留 2。
  ///
  /// 这是本轮修的那 1px 位移的来源：旧实现两处不一致（一处 0、一处用默认 2）。
  /// 判据跟 `HyperosRootHeader` 自己的默认值对齐（2），但玻璃态要压成 0 ——
  /// 玻璃带本身已经把底部那 2px 盖住了，再留就是双重留白。
  static double bottomPaddingFor({required bool frosted}) => frosted ? 0 : 2;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return HyperosRootHeader(
      title: Row(
        children: [
          if (showBackButton)
            HyperosBackButton(
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          Expanded(
            child: TimetableProfileSwitcherTrigger(
              style: settings.homeTitleStyle,
              activeProfileName: activeProfileName,
              onTap: onProfileTap,
              foreground: foreground,
              mutedForeground: mutedForeground,
              leftPadding: titleHorizontalNudge,
            ),
          ),
        ],
      ),
      suffixes: buildTimetableHomeHeaderActions(
        l10n: l10n,
        hasPartnerBinding: hasPartnerBinding,
        coupleOverlayActive: coupleOverlayActive,
        heartLink: heartLink,
        moreLink: moreLink,
        homeMenuAnchor: menuAnchor,
        topMenuButtonKey: moreButtonKey,
        onToggleCoupleOverlay: () =>
            onToggleCoupleOverlay?.call(!coupleOverlayActive),
        onPrewarmGlass: onPrewarmGlass,
        onReleaseGlass: onReleaseGlass,
        onShowTopActions: onShowTopActions,
      ),
      // padding 必须显式给：默认值（底部 2）与玻璃态需要的 0 不同，
      // 靠"不传"就会和另一边漂开（本轮就是这个问题）。
      padding: EdgeInsets.fromLTRB(
        8,
        0,
        8,
        bottomPaddingFor(frosted: headerUsesFrostedChrome),
      ),
    );
  }
}
