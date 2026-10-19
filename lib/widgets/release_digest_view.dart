import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/utils/release_notes_digest.dart';

/// 「本次更新重点」的统一呈现，弹窗与历史版本页共用。
///
/// 三段式，按「扫一眼 → 知道规模 → 想看细节」排：
///
/// 1. 至多 3 条**短标题**（分类标签取正文自己的「新增 / 优化 …」，见
///    [ReleaseChangeEntry.label]；正文换成英文时标签也跟着变）；
/// 2. 一行**分类计数**交代这一版的规模——40 项里 30 项修复，和「2 项新增」
///    是两种完全不同的更新；
/// 3. 「查看全部 N 项」原地展开完整条目。
///
/// [groupEntries] 为真时展开区按分类分组（标题带条数），适合历史版本页；
/// 弹窗里保持扁平列表，避免把有限的横向空间让给分组标题。
///
/// 滚动由宿主负责：弹窗把本组件放进可滚区域，历史页的卡片在列表里。这里
/// 不自己套 `ListView`，两处滚动会抢手势，弹窗的下拉关闭也会跟着变钝。
class ReleaseDigestView extends StatefulWidget {
  const ReleaseDigestView({
    super.key,
    required this.digest,
    this.initiallyExpanded = false,
    this.groupEntries = false,
    this.alwaysExpandable = false,
    this.showHeading = true,
  });

  final ReleaseNotesDigest digest;

  /// 初始是否展开（历史版本页只让最新一版默认展开）。
  final bool initiallyExpanded;

  /// 展开区按分类分组，标题形如「新增 · 12」。
  final bool groupEntries;

  /// 即使所有条目都已经出现在重点行里，也提供「查看完整句子」的入口。
  final bool alwaysExpandable;

  /// 是否显示「本次更新重点」小标题（历史页的卡片已有版本号，可关掉）。
  final bool showHeading;

  @override
  State<ReleaseDigestView> createState() => _ReleaseDigestViewState();
}

class _ReleaseDigestViewState extends State<ReleaseDigestView> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = MiuixTheme.of(context);
    final colors = theme.colors;
    final textStyles = theme.textStyles;
    final digest = widget.digest;
    final counts = releaseChangeCounts(digest);
    // 还有没露过面的条目时，入口说的是「查看全部 N 项」；如果重点行已经把全部
    // 条目都列出来了（展开只是换成完整句子），改说「查看完整说明」——否则在
    // 「一共 2 条、2 条都看得见」的版本上，用户会读到一句像是撒谎的话。
    final hasHiddenEntries = digest.total > digest.highlights.length;
    final canExpand = widget.alwaysExpandable
        ? digest.total > 0
        : hasHiddenEntries;
    // 分类计数只在它提供重点行之外的信息时才显示：单一分类、且条目已经全部
    // 列在重点行里时，这一行就是把上面 N 行又数了一遍（v2.1.3.4 正是这种）。
    // 一版 54 条、四个分类时它照旧出现——那是这一版的规模，不是重复。
    final showCounts =
        counts.isNotEmpty && (counts.length > 1 || hasHiddenEntries);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showHeading) ...[
          MiuixText(
            l10n.aboutUpdateHighlightsTitle,
            style: textStyles.footnote1,
            color: colors.onSurfaceVariantSummary,
            fontWeight: FontWeight.w600,
          ),
          const SizedBox(height: 8),
        ],
        for (final entry in digest.highlights)
          _HighlightRow(
            entry: entry,
            colors: colors,
            textStyles: textStyles,
          ),
        if (showCounts) ...[
          const SizedBox(height: 2),
          MiuixText(
            _formatCounts(counts),
            style: textStyles.footnote1,
            color: colors.onSurfaceVariantSummary,
          ),
        ],
        if (canExpand) ...[
          const SizedBox(height: 4),
          _buildExpandToggle(
            l10n: l10n,
            colors: colors,
            textStyles: textStyles,
            revealsHiddenEntries: hasHiddenEntries,
          ),
        ],
        if (_expanded) ...[
          const SizedBox(height: 10),
          Container(height: 1, color: colors.secondaryContainer),
          const SizedBox(height: 10),
          if (widget.groupEntries)
            ..._buildGroupedEntries(colors: colors, textStyles: textStyles)
          else
            for (final entry in digest.entries)
              _EntryRow(entry: entry, colors: colors, textStyles: textStyles),
        ],
      ],
    );
  }

  String _formatCounts(List<(String, int)> counts) =>
      counts.map((item) => '${item.$1} ${item.$2}').join(' · ');

  /// 分组展开：分类标题带条数，条目本身不再重复分类词。
  List<Widget> _buildGroupedEntries({
    required MiuixColors colors,
    required MiuixTextStyles textStyles,
  }) {
    final widgets = <Widget>[];
    for (final kind in _groupOrder) {
      final group = widget.digest.entries
          .where((entry) => entry.kind == kind)
          .toList(growable: false);
      if (group.isEmpty) {
        continue;
      }
      final label = group
          .map((entry) => entry.label)
          .firstWhere((value) => value.isNotEmpty, orElse: () => '');
      if (widgets.isNotEmpty) {
        widgets.add(const SizedBox(height: 12));
      }
      if (label.isNotEmpty) {
        widgets.add(
          MiuixText(
            '$label · ${group.length}',
            style: textStyles.footnote1,
            color: _kindColor(kind, colors),
            fontWeight: FontWeight.w600,
          ),
        );
        widgets.add(const SizedBox(height: 6));
      }
      for (final entry in group) {
        widgets.add(
          _EntryRow(
            entry: entry,
            colors: colors,
            textStyles: textStyles,
            showLabel: false,
          ),
        );
      }
    }
    return widgets;
  }

  Widget _buildExpandToggle({
    required AppLocalizations l10n,
    required MiuixColors colors,
    required MiuixTextStyles textStyles,
    required bool revealsHiddenEntries,
  }) {
    // 用 GestureDetector 而不是 InkWell / MiuixTextButton：弹窗面板是玻璃材质
    // （不是 Material），InkWell 的水波找不到可画的平面；这一行是纯文字动作，
    // 也不需要按钮那么大的点击区。
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _expanded = !_expanded),
      child: Semantics(
        button: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              MiuixText(
                _expanded
                    ? l10n.aboutUpdateCollapseAction
                    : revealsHiddenEntries
                    ? l10n.aboutUpdateViewAllAction('${widget.digest.total}')
                    : l10n.aboutUpdateViewFullAction,
                style: textStyles.footnote1,
                color: colors.primary,
                fontWeight: FontWeight.w600,
              ),
              const SizedBox(width: 2),
              Icon(
                _expanded ? Icons.expand_less : Icons.expand_more,
                size: 16,
                color: colors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 条目分组的固定顺序（与挑选重点的优先级一致）。
const List<ReleaseChangeKind> _groupOrder = <ReleaseChangeKind>[
  ReleaseChangeKind.added,
  ReleaseChangeKind.improved,
  ReleaseChangeKind.removed,
  ReleaseChangeKind.fixed,
  ReleaseChangeKind.other,
];

/// 一条重点：分类色点 + 分类标签 + 短标题。
class _HighlightRow extends StatelessWidget {
  const _HighlightRow({
    required this.entry,
    required this.colors,
    required this.textStyles,
  });

  final ReleaseChangeEntry entry;
  final MiuixColors colors;
  final MiuixTextStyles textStyles;

  @override
  Widget build(BuildContext context) {
    final accent = _kindColor(entry.kind, colors);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: 8),
          if (entry.label.isNotEmpty) ...[
            MiuixText(
              entry.label,
              style: textStyles.footnote1,
              color: accent,
              fontWeight: FontWeight.w600,
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: MiuixText(
              entry.headline,
              style: textStyles.body2,
              color: colors.onBackground,
              height: 1.35,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// 展开后的一条完整条目：分类标签（可选）+ 完整说明。
class _EntryRow extends StatelessWidget {
  const _EntryRow({
    required this.entry,
    required this.colors,
    required this.textStyles,
    this.showLabel = true,
  });

  final ReleaseChangeEntry entry;
  final MiuixColors colors;
  final MiuixTextStyles textStyles;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showLabel && entry.label.isNotEmpty) ...[
            MiuixText(
              entry.label,
              style: textStyles.footnote2,
              color: _kindColor(entry.kind, colors),
              fontWeight: FontWeight.w600,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: MiuixText(
              entry.text,
              style: textStyles.footnote1,
              color: colors.onSurfaceSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// 分类色：新增用主题色（一版里最希望被看到的就是它），移除用错误色，
/// 其余用次要墨色——三种颜色足够区分，不会把界面染成调色板。
Color _kindColor(ReleaseChangeKind kind, MiuixColors colors) => switch (kind) {
  ReleaseChangeKind.added => colors.primary,
  ReleaseChangeKind.removed => colors.error,
  ReleaseChangeKind.improved ||
  ReleaseChangeKind.fixed => colors.onSurfaceSecondary,
  ReleaseChangeKind.other => colors.onSurfaceVariantSummary,
};
