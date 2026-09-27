import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

import '../../utils/theme_seed_accent.dart';
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
/// 交互底座用 [MiuixPressable]（Miuix 的按压遮罩 + 无障碍），盒子自己画 —— **不要**改回
/// `MiuixButton`：那个控件会用 `DefaultTextStyle.merge` 注入自己的墨色与行高，胶囊里
/// 只要再带一个带 `color`/`height` 的文字样式就会把它盖掉（黑底黑字就是那么来的）。
class HyperosChipRow extends StatelessWidget {
  const HyperosChipRow({
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
    this.equalWidth = true,
    this.height = 40,
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

  /// 胶囊高度（默认 40，与本仓按钮同高）。
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
    // 选中 = **实心主题色**（这一条就是它与药丸分段的分野）；未选中 = 与分段轨道同一档中性
    // 底，于是「一排浅底 + 一颗填色」的整体观感与 MIUI 录音机那个一致。
    final fill = selected
        ? HyperosColors.primarySurface(context)
        : HyperosColors.rowHighlight(context);
    // 墨色**由底色本身**算黑白，不是 `onAccentInk(primary)`。
    //
    // ⚠️ 这条是 2026-09-27 修的一个真 bug：用户的中性灰主题下，黑底上出现了**深色字**。
    // 两个原因叠加 ——① `primary` 与 `primarySurface` 是**两套解析**：深色模式下近黑
    // seed（中性灰/锌灰/石板灰）`primary` 回落墨色、`primarySurface` 却向白提亮，两者
    // 不是同一个色，拿 `primary` 算出来的墨色对不上真正的底色。② 更直接的是我把
    // `HyperosTypography.listTitle`（自带 `primaryText` 墨色）整个塞进了按钮里，**盖掉了**
    // 按钮注入的墨色。改成从 `fill` 算、并在文字样式上**显式写死 color**，两条路都堵死。
    final ink = selected
        ? onAccentInk(fill)
        : HyperosColors.secondaryText(context);

    // 胶囊**全圆**（`height / 2`）。
    //
    // ⚠️ 别用 `HyperosRadius.clampCornerRadius` 那套留 6px 直边的收口：那条规矩是给
    // **卡片 / 面板**那类大面子的（弧线不许并成一条），胶囊本来就该是圆的 —— 本仓
    // `_MaterialChoiceChips`（液态预设那排）也是全圆。2026-09-27 用户报「按钮也不圆」就是
    // 被我按大面子的规矩收窄了。
    final radius = BorderRadius.circular(height / 2);

    return Semantics(
      // 只带「互斥组 + 选中」两个标记，按钮 / 无障碍标签交给内层 `MiuixPressable`
      // （它自己发 `button` + `onTap` + label），免得两个 Semantics 节点各念一遍。
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: MiuixPressable(
        onPressed: onTap,
        borderRadius: radius,
        semanticLabel: label,
        child: DecoratedBox(
          decoration: BoxDecoration(color: fill, borderRadius: radius),
          child: SizedBox(
            height: height,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: HyperosTypography.listTitle(context).copyWith(
                    fontSize: 15,
                    // 行高**显式写死**：不写就继承 `listTitle` 的 1.25（那是给列表行排的），
                    // 字号一改行高与字形对不上，视觉上就是「字没上下居中」（2026-09-27 用户报）。
                    height: 1.2,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: ink,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
