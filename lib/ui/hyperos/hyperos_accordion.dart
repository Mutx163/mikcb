import 'package:flutter/material.dart';

import 'hyperos_theme.dart';
import 'hyperos_tokens.dart';
import 'widgets/adaptive_card.dart';
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
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  color: HyperosColors.actionIcon(context),
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
