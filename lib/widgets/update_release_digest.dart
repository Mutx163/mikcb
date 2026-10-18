import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/utils/release_notes_digest.dart';

/// 更新弹窗里的「本次更新重点」。
///
/// 旧弹窗只把正文去掉标题后取前 4 行：那既不是重点（只是文件开头的顺序），
/// 一条 60 字的说明又会被截断在第二行。这里换成三段式，按「扫一眼 → 知道规模 →
/// 想看细节」的顺序排：
///
/// 1. 至多 3 条**短标题**（分类标签直接取正文自己的「新增 / 优化 …」，
///    见 [ReleaseChangeEntry.label]；正文换成英文时标签也跟着变，不必再翻译一套）；
/// 2. 一行**分类计数**交代这一版的规模 —— 46 项里 11 项新增，和「只有 2 项修复」
///    是两种完全不同的更新，用户需要先知道这次值不值得点下载；
/// 3. 「查看全部 N 项」在弹窗内原地展开完整条目，不跳浏览器、也不离开下载按钮。
///
/// 滚动由宿主负责（弹窗把本组件放进一个可滚区域），所以这里不自己套
/// `ListView`：两处滚动会抢手势，弹窗的下拉关闭也会跟着变钝。
class UpdateReleaseDigest extends StatefulWidget {
  const UpdateReleaseDigest({super.key, required this.digest});

  final ReleaseNotesDigest digest;

  @override
  State<UpdateReleaseDigest> createState() => _UpdateReleaseDigestState();
}

class _UpdateReleaseDigestState extends State<UpdateReleaseDigest> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = MiuixTheme.of(context);
    final colors = theme.colors;
    final textStyles = theme.textStyles;
    final digest = widget.digest;
    final counts = releaseChangeCounts(digest);
    final canExpand = digest.total > digest.highlights.length;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MiuixText(
          l10n.aboutUpdateHighlightsTitle,
          style: textStyles.footnote1,
          color: colors.onSurfaceVariantSummary,
          fontWeight: FontWeight.w600,
        ),
        const SizedBox(height: 8),
        for (final entry in digest.highlights)
          _HighlightRow(
            entry: entry,
            colors: colors,
            textStyles: textStyles,
          ),
        if (counts.isNotEmpty) ...[
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
          ),
        ],
        if (_expanded) ...[
          const SizedBox(height: 10),
          Container(height: 1, color: colors.secondaryContainer),
          const SizedBox(height: 10),
          for (final entry in digest.entries)
            _EntryRow(entry: entry, colors: colors, textStyles: textStyles),
        ],
      ],
    );
  }

  String _formatCounts(List<(String, int)> counts) =>
      counts.map((item) => '${item.$1} ${item.$2}').join(' · ');

  Widget _buildExpandToggle({
    required AppLocalizations l10n,
    required MiuixColors colors,
    required MiuixTextStyles textStyles,
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
                    : l10n.aboutUpdateViewAllAction('${widget.digest.total}'),
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

/// 展开后的一条完整条目：分类标签 + 完整说明。
class _EntryRow extends StatelessWidget {
  const _EntryRow({
    required this.entry,
    required this.colors,
    required this.textStyles,
  });

  final ReleaseChangeEntry entry;
  final MiuixColors colors;
  final MiuixTextStyles textStyles;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (entry.label.isNotEmpty) ...[
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
/// 其余用次要墨色 —— 三种颜色足够区分，不会把弹窗染成调色板。
Color _kindColor(ReleaseChangeKind kind, MiuixColors colors) => switch (kind) {
  ReleaseChangeKind.added => colors.primary,
  ReleaseChangeKind.removed => colors.error,
  ReleaseChangeKind.improved ||
  ReleaseChangeKind.fixed => colors.onSurfaceSecondary,
  ReleaseChangeKind.other => colors.onSurfaceVariantSummary,
};
