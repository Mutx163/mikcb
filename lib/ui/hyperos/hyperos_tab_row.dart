import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

import 'hyperos_theme.dart';

/// HyperOS segmented control layout variant — selects the Miuix tab row style.
enum HyperosTabRowStyle {
  /// Gray track + white sliding pill (Miuix `TabRowWithContour`).
  contour,

  /// Blue filled selected segment with bordered unselected tabs.
  bordered,
}

/// HyperOS segmented tab row — delegates to [MiuixTabRow] / [MiuixTabRowWithContour].
///
/// 几何、动效、无障碍全部走上游（超椭圆轨道 + 一整块连续滑动的指示器 + 每格的
/// 「第几个 / 共几个、是否选中」语义）。本类只负责把 HyperOS 的**墨色**接进去，
/// 以及把每格的宽度区间放宽 —— 上游默认每格 62~84 定宽，格数少的时候右边会空一
/// 大块，设置里那种「通栏分段」必须显式放宽（见 [fillWidth]）。
class HyperosTabRow extends StatelessWidget {
  const HyperosTabRow({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onChanged,
    this.enabled = true,
    this.style = HyperosTabRowStyle.contour,
    this.colors,
    this.minWidth,
    this.maxWidth,
    this.height,
  });

  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final bool enabled;
  final HyperosTabRowStyle style;

  /// 墨色。留空走上游默认（轨道 `surface` / 选中块 `surfaceContainer`）——
  /// 深色模式下那个 `surfaceContainer` 正好等于页面底色，选中与否几乎看不出来，
  /// 所以设置里凡是分段都显式传 [surfaceColors]。
  final MiuixTabRowColors? colors;

  final double? minWidth;
  final double? maxWidth;
  final double? height;

  /// 让分段**铺满给它的整行**。
  ///
  /// 上游按固定区间（62~84）算每格宽度再从左往右排，格数少时右侧会剩一块空地。
  /// 设置页的分段与内容同宽才好看，把上限放到无穷即可均分整行；标签放不下时
  /// 上游自己截断加省略号。
  static const double fillWidth = double.infinity;

  /// HyperOS 表面墨色：轨道 = 行高亮底、选中块 = 卡片面、选中/未选中取主/次级墨。
  ///
  /// 就是分段该有的那三档面，别拿 Miuix 原始色板：它在深色下把选中块画成页面底色
  /// （见 [colors]）。
  static MiuixTabRowColors surfaceColors(BuildContext context) =>
      MiuixTabRowColors(
        backgroundColor: HyperosColors.rowHighlight(context),
        contentColor: HyperosColors.secondaryText(context),
        selectedBackgroundColor: HyperosColors.card(context),
        selectedContentColor: HyperosColors.primaryText(context),
      );

  @override
  Widget build(BuildContext context) {
    assert(tabs.isNotEmpty, 'HyperosTabRow requires at least one tab');
    assert(
      selectedIndex >= 0 && selectedIndex < tabs.length,
      'selectedIndex out of range',
    );

    final onTabSelected = enabled ? onChanged : (_) {};
    switch (style) {
      case HyperosTabRowStyle.bordered:
        return MiuixTabRow(
          tabs: tabs,
          selectedTabIndex: selectedIndex,
          onTabSelected: onTabSelected,
          colors: colors,
          minWidth: minWidth ?? MiuixTabRowDefaults.tabRowMinWidth,
          maxWidth: maxWidth ?? MiuixTabRowDefaults.tabRowMaxWidth,
          height: height ?? MiuixTabRowDefaults.tabRowHeight,
        );
      case HyperosTabRowStyle.contour:
        return MiuixTabRowWithContour(
          tabs: tabs,
          selectedTabIndex: selectedIndex,
          onTabSelected: onTabSelected,
          colors: colors,
          minWidth: minWidth ?? MiuixTabRowDefaults.tabRowWithContourMinWidth,
          maxWidth: maxWidth ?? MiuixTabRowDefaults.tabRowWithContourMaxWidth,
          height: height ?? MiuixTabRowDefaults.tabRowWithContourHeight,
        );
    }
  }
}

/// Alias for [HyperosTabRow] — common naming in settings screens.
typedef HyperosSegmentedControl = HyperosTabRow;
