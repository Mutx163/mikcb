import 'package:flutter/material.dart';

import 'hyperos_theme.dart';
import 'hyperos_tokens.dart';
import 'widgets/adaptive_card.dart';
import 'widgets/indicators.dart';
import 'widgets/tiles.dart';

class HyperosAccordionItem {
  const HyperosAccordionItem({
    required this.title,
    required this.child,
    this.insetChild = true,
  });

  final Widget title;
  final Widget child;

  /// 展开内容是否套 [HyperosControlCardScope.defaultHorizontalPadding] 内边距。
  ///
  /// 默认 true，适配文本 / 输入框等内容块；放边到边的交互行
  /// （[HyperosListTile] 等自带行内边距与首尾行圆角的行）时传 false，
  /// 行组包 [HyperosControlCardRows] 让首尾行按压高亮跟随卡片圆角。
  final bool insetChild;
}

/// Expandable sections inside a control card (replaces Forui [FAccordion]).
///
/// 组头是「分组标签」不是行：标题应传小节标签语音的文字（如
/// [HyperosTypography.sectionLabel]，灰字无徽章），尾部展开指示用
/// 组件库细 chevron 旋转（收起向下 / 展开向上），与导航行静态
/// chevron 同形不同态；展开内容放交互行时传 [HyperosAccordionItem.insetChild]
/// 为 false。
class HyperosAccordion extends StatelessWidget {
  const HyperosAccordion({super.key, required this.items});

  final List<HyperosAccordionItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0)
            Divider(
              height: 1,
              thickness: 1,
              color: HyperosColors.actionIcon(context).withValues(alpha: 0.25),
            ),
          _HyperosAccordionTile(item: items[i]),
        ],
      ],
    );
  }
}

class _HyperosAccordionTile extends StatefulWidget {
  const _HyperosAccordionTile({required this.item});

  final HyperosAccordionItem item;

  @override
  State<_HyperosAccordionTile> createState() => _HyperosAccordionTileState();
}

class _HyperosAccordionTileState extends State<_HyperosAccordionTile> {
  var _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 组头按压与全 app 行一致：HyperosPressableRow 的延迟灰色填充
        // （滚动开始即取消、松手即清除，边到边填充由卡片圆角裁剪），
        // 替代裸 InkWell 的 Material 水波纹高亮。
        HyperosPressableRow(
          onTap: () => setState(() => _expanded = !_expanded),
          backgroundColor: HyperosColors.card(context),
          highlightColor: HyperosColors.rowHighlight(context),
          child: Padding(
            padding: HyperosTokens.rowPaddingUniform,
            child: Row(
              children: [
                Expanded(child: widget.item.title),
                // 展开指示与全库行尾 chevron 同语音：细线灰 chevron，
                // 收起转 90° 指向下、展开转回指向上（同形不同态）。
                RotatedBox(
                  quarterTurns: _expanded ? -1 : 1,
                  child: const HyperosChevron(),
                ),
              ],
            ),
          ),
        ),
        if (_expanded)
          Padding(
            padding: widget.item.insetChild
                ? const EdgeInsets.fromLTRB(16, 0, 16, 16)
                : EdgeInsets.zero,
            child: widget.item.child,
          ),
      ],
    );
  }
}

/// Info hint row with optional leading icon (replaces Forui [FAlert]).
class HyperosHintBanner extends StatelessWidget {
  const HyperosHintBanner({super.key, required this.title, this.icon});

  final Widget title;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    return HyperosAdaptiveCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[icon!, const SizedBox(width: 10)],
          Expanded(
            child: DefaultTextStyle(
              style: HyperosTypography.listDetail(context),
              child: title,
            ),
          ),
        ],
      ),
    );
  }
}
