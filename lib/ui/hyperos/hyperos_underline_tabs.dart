import 'package:flutter/material.dart';

import 'dart:math' as math;

import 'package:university_timetable/l10n/app_localizations.dart';

import 'hyperos_miuix_spec.dart';
import 'hyperos_theme.dart';

/// 下划线标签栏：表示**翻页**（在几页之间切换），不表示**选值**。
///
/// ## 为什么要有它（不能直接用药丸分段）
///
/// 药丸分段（[HyperosTabRow]）是「从几个值里选一个」的语言：它在设置里到处都是「这一项
/// 取哪个值」。而**翻页**是另一件事 —— 页面内容整体换了，不是某一项的值变了。两者长成一
/// 样、又混在同一个面板里，用户就会把翻页控件当成又一个设置项去读（2026-09-27 用户报
/// 「和下面的按钮一模一样，导致用户有可能以为这个是功能切换的东西」）。
///
/// 所以这里把两类控件按语义分家，各用各的形状：
///
/// * **药丸分段** → 选值（默认材质、首页顶栏玻璃…）
/// * **下划线标签** → 翻页（本控件）
///
/// 下划线是这条分界线：面板里出现的每一道短横线都在说「这里是导航」，药丸都在说「这里
/// 是取值」。用户不需要读文案就知道自己点下去会发生什么。
///
/// ## 形状
///
/// * 标签**等宽铺满**整行（与下面的设置行同宽同重）。
/// * 选中标签用主墨 + 加粗，未选中用次级墨 —— 和药丸分段同一套墨色纪律，只是**没有轨道、
///   没有浮块**。
/// * 指示器是一道**短横线**（宽度取标签宽的 40%、上限 28），随选中项连续滑动。
/// * 底部**不画通栏分隔线**：这个控件常驻在玻璃面板顶部，再加一道横线就是用户最不想要的
///   那种「凭空一条线」。
class HyperosUnderlineTabs extends StatelessWidget {
  const HyperosUnderlineTabs({
    required this.tabs,
    required this.selectedIndex,
    required this.onChanged,
    this.height = HyperosMiuixTopAppBar.collapsedHeight,
    super.key,
  });

  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  /// 整条标签栏高度。默认取折叠顶栏那一行的高度（44）—— 它现在**就是**一行顶栏，不再是
  /// 一个内联分段控件。
  final double height;

  /// 指示器宽度占标签宽的比例与上限（短横线，不是通栏）。
  static const double _indicatorWidthFactor = 0.4;
  static const double _indicatorMaxWidth = 28;
  static const double _indicatorHeight = 3;
  static const double _indicatorRadius = 1.5;

  /// 指示器换页的时长与曲线（与本仓其他滑动指示器同口径）。
  static const Duration _slideDuration = Duration(milliseconds: 220);
  static const Curve _slideCurve = Curves.easeOutCubic;

  @override
  Widget build(BuildContext context) {
    assert(tabs.isNotEmpty, 'HyperosUnderlineTabs requires at least one tab');
    assert(
      selectedIndex >= 0 && selectedIndex < tabs.length,
      'selectedIndex out of range',
    );

    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tabWidth = constraints.maxWidth / tabs.length;
          final indicatorWidth = math.min(
            tabWidth * _indicatorWidthFactor,
            _indicatorMaxWidth,
          );

          // `TweenAnimationBuilder` 自己保留上一次的值再往新的 end 走，所以这里只需要给
          // 「目标下标」—— 换页时指示器就是连续滑过去的，不需要另写 AnimationController。
          return TweenAnimationBuilder<double>(
            tween: Tween<double>(end: selectedIndex.toDouble()),
            duration: _slideDuration,
            curve: _slideCurve,
            builder: (context, position, _) {
              // 位置以「标签宽」为单位，换算成像素；标签数变化时也不会越界。
              final left = (position * tabWidth) + (tabWidth - indicatorWidth) / 2;
              return Stack(
                children: <Widget>[
                  for (var i = 0; i < tabs.length; i++)
                    Positioned.fill(
                      child: _TabLabel(
                        text: tabs[i],
                        selected: i == selectedIndex,
                        onTap: () => onChanged(i),
                      ),
                    ),
                  Positioned(
                    left: left.clamp(0.0, constraints.maxWidth - indicatorWidth),
                    bottom: 0,
                    width: indicatorWidth,
                    height: _indicatorHeight,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: HyperosColors.primary(context),
                        borderRadius: BorderRadius.circular(_indicatorRadius),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _TabLabel extends StatelessWidget {
  const _TabLabel({
    required this.text,
    required this.selected,
    required this.onTap,
  });

  final String text;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      // 读屏标签带「标签」身份后缀；l10n 不在树上（裸宿主测试）时退化为纯文字，
      // 角色（button/selected/inMutuallyExclusiveGroup）语义不受影响。
      label: l10n == null ? text : l10n.underlineTabSemanticsLabel(text),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: HyperosTypography.listTitle(context).copyWith(
              color: selected
                  ? HyperosColors.primaryText(context)
                  : HyperosColors.secondaryText(context),
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}
