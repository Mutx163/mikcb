import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

import '../../utils/theme_seed_accent.dart';
import 'hyperos_radius.dart';
import 'hyperos_theme.dart';

/// 筛选胶囊一排（MIUI/HyperOS 那种「全部 / 录音机 / 通话 / 应用」）。
///
/// ## 它和本仓另外两种控件的分工
///
/// 面板里同时存在三种「选一个」的动作，长得必须不一样，否则用户读不出点下去会发生什么：
///
/// * **药丸分段**（`HyperosTabRow`）→ 从 2~3 个**取值**里选一个（默认材质、模糊强度…）。
///   形状：一条灰轨道 + 一块白色浮块。
/// * **筛选胶囊**（本控件）→ 在**若干类**里挑一类看（类别/来源/筛选项）。形状：一排
///   独立胶囊，**选中那颗填主题色**、未选中是浅底。
/// * **下划线标签**（`HyperosUnderlineTabs`）→ **翻页**。形状：一行文字 + 一道短横线。
///
/// 胶囊与分段最关键的区别是**选中态**：分段是「灰轨道里浮一块白」，胶囊是「一颗实心填色」。
/// 隔着两米也能一眼分清「这是改一个值」还是「这是换一类看」。
///
/// 交互底座直接用 [MiuixButton]（带 MiuixPressable 的按压回弹），不是自己拼
/// `GestureDetector` —— 按压手感与全 App 按钮一致。
class HyperosChipRow extends StatelessWidget {
  const HyperosChipRow({
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
    this.equalWidth = true,
    this.height = MiuixButtonDefaults.minHeight,
    this.gap = 8,
    super.key,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  /// 胶囊是否**等宽铺满**整行。
  ///
  /// 默认真：两三颗时铺满看起来整齐、也与下面的设置行同宽。给 false 则按文字宽度排、并
  /// 支持横向滚动（项多时用，末项会露出一半提示还能滑）—— 那一支就是 MIUI 录音机列表
  /// 顶上的那种。
  final bool equalWidth;

  /// 胶囊高度（默认 [MiuixButtonDefaults.minHeight]）。
  final double height;

  /// 不等宽时的胶囊间距。
  final double gap;

  @override
  Widget build(BuildContext context) {
    assert(labels.isNotEmpty, 'HyperosChipRow requires at least one label');
    assert(
      selectedIndex >= 0 && selectedIndex < labels.length,
      'selectedIndex out of range',
    );

    final chips = <Widget>[
      for (var i = 0; i < labels.length; i++)
        _Chip(
          label: labels[i],
          selected: i == selectedIndex,
          height: height,
          onTap: () => onChanged(i),
        ),
    ];

    if (equalWidth) {
      return Row(
        children: <Widget>[
          for (var i = 0; i < chips.length; i++) ...[
            if (i > 0) SizedBox(width: gap),
            Expanded(child: chips[i]),
          ],
        ],
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const ClampingScrollPhysics(),
      child: Row(
        children: <Widget>[
          for (var i = 0; i < chips.length; i++) ...[
            if (i > 0) SizedBox(width: gap),
            chips[i],
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.height,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // 圆角按本仓圆角规矩收口：胶囊不塌成全圆，留 6px 直边（`HyperosRadius` 的
    // `minStraightEdge`），所以是 `height / 2 - 6` 而不是 `height / 2`。
    final radius = HyperosRadius.clampCornerRadius(height / 2, height);

    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: label,
      child: MiuixButton(
        onPressed: onTap,
        cornerRadius: radius,
        minWidth: 0,
        minHeight: height,
        insideMargin: const EdgeInsets.symmetric(horizontal: 20),
        colors: MiuixButtonColors(
          // 选中 = **实心主题色**（这一条就是它与药丸分段的分野）；未选中 = 与分段轨道
          // 同一档中性底，于是「一排浅底 + 一颗填色」的整体观感与 MIUI 录音机那个一致。
          color: selected
              ? HyperosColors.primarySurface(context)
              : HyperosColors.rowHighlight(context),
          // 主题色底上的墨色按亮度取黑白（用户把主题色调成浅黄时也不会白字白底）。
          contentColor: selected
              ? onAccentInk(HyperosColors.primary(context))
              : HyperosColors.secondaryText(context),
          disabledColor: HyperosColors.rowHighlight(context),
          disabledContentColor: HyperosColors.secondaryText(context),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: HyperosTypography.listTitle(context).copyWith(
            fontSize: 15,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
