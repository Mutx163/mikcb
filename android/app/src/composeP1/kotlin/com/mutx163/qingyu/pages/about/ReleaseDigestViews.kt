package com.mutx163.qingyu.pages.about

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.shiftWeight
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.ExpandLess
import top.yukonga.miuix.kmp.icon.extended.ExpandMore
import top.yukonga.miuix.kmp.theme.Colors
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 发布说明摘要的**共享渲染件**（2026-11-03 版面收口）。
 *
 * 「更新日志页」（[ChangelogPage]）与「版本更新页」（[AboutUpdatePage]）此前各写一套
 * 几乎相同的私有实现（HighlightRow / GroupedEntries / ExpandToggle / kindColor）——
 * 行距、圆点、分类色、展开文案各自漂移。本文件收成唯一一套，两页共用：
 *
 * - [ReleaseNotesHighlightRow]：一条「更新重点」（分类色点 + 分类标签 + 短标题）；
 * - [ReleaseNotesGroupedEntries]：展开区按分类分组的完整条目；
 * - [ReleaseNotesExpandToggle]：展开/收起入口（文案复用 [ChangelogStrings] 既有 ARB 键，零新增）；
 * - [releaseNotesKindColor]：分类色语义（新增=主题色 / 移除=错误色 / 其余次级墨色）。
 *
 * 字号一律走 [MiuixTheme.textStyles]（[shiftWeight] 只做增量），颜色全部来自主题
 * ——本文件不出现写死字号与裸色值。
 */

/** 条目分组的固定顺序（与挑选重点的优先级一致，Dart `_groupOrder`）。 */
internal val releaseNotesGroupOrder = listOf(
    ReleaseChangeKind.ADDED,
    ReleaseChangeKind.IMPROVED,
    ReleaseChangeKind.REMOVED,
    ReleaseChangeKind.FIXED,
    ReleaseChangeKind.OTHER,
)

/** 分类色：新增用主题色（一版里最希望被看到的就是它），移除用错误色，其余次级墨色。 */
internal fun releaseNotesKindColor(kind: ReleaseChangeKind, colors: Colors): Color = when (kind) {
    ReleaseChangeKind.ADDED -> colors.primary
    ReleaseChangeKind.REMOVED -> colors.error
    ReleaseChangeKind.IMPROVED, ReleaseChangeKind.FIXED -> colors.onSurfaceSecondary
    ReleaseChangeKind.OTHER -> colors.onSurfaceVariantSummary
}

/** 一条「更新重点」：分类色点 + 分类标签（可选）+ 短标题（最多两行）。 */
@Composable
internal fun ReleaseNotesHighlightRow(entry: ReleaseChangeEntry) {
    val colors = MiuixTheme.colorScheme
    val accent = releaseNotesKindColor(entry.kind, colors)
    Row(
        modifier = Modifier.fillMaxWidth().padding(bottom = 8.dp),
        verticalAlignment = Alignment.Top,
    ) {
        Spacer(
            modifier = Modifier
                .padding(top = 7.dp)
                .size(5.dp)
                .background(accent, CircleShape),
        )
        Spacer(Modifier.width(8.dp))
        if (entry.label.isNotEmpty()) {
            Text(
                text = entry.label,
                style = MiuixTheme.textStyles.footnote1.shiftWeight(QingyuWeightDelta.SEMIBOLD),
                color = accent,
            )
            Spacer(Modifier.width(8.dp))
        }
        Text(
            text = entry.headline,
            style = MiuixTheme.textStyles.body2,
            color = colors.onBackground,
            lineHeight = 19.sp,
            maxLines = 2,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.weight(1f),
        )
    }
}

/** 展开区按分类分组：标题形如「新增 · 12」，条目本身不再重复分类词。 */
@Composable
internal fun ReleaseNotesGroupedEntries(digest: ReleaseNotesDigest) {
    val colors = MiuixTheme.colorScheme
    var isFirstGroup = true

    for (kind in releaseNotesGroupOrder) {
        val group = digest.entries.filter { it.kind == kind }
        if (group.isEmpty()) continue
        if (!isFirstGroup) Spacer(Modifier.height(12.dp))
        isFirstGroup = false

        val label = group.firstOrNull { it.label.isNotEmpty() }?.label
        if (label != null) {
            Text(
                text = "$label · ${group.size}",
                style = MiuixTheme.textStyles.footnote1.shiftWeight(QingyuWeightDelta.SEMIBOLD),
                color = releaseNotesKindColor(kind, colors),
            )
            Spacer(Modifier.height(6.dp))
        }
        for (entry in group) {
            ReleaseNotesEntryRow(entry)
        }
    }
}

/** 展开后的一条完整条目（说明文字弱色、完整折行）。 */
@Composable
internal fun ReleaseNotesEntryRow(entry: ReleaseChangeEntry) {
    val colors = MiuixTheme.colorScheme
    Text(
        text = entry.text,
        style = MiuixTheme.textStyles.footnote1,
        color = colors.onSurfaceSecondary,
        lineHeight = 20.sp,
        modifier = Modifier.padding(bottom = 10.dp),
    )
}

/**
 * 展开/收起入口：纯文字动作 + 箭头。文案复用更新日志页同一组 ARB 键——
 * 「收起 / 查看全部 N 项 / 查看完整说明」的判据两页必须一字不差。
 */
@Composable
internal fun ReleaseNotesExpandToggle(
    expanded: Boolean,
    revealsHiddenEntries: Boolean,
    total: Int,
    onToggle: () -> Unit,
) {
    val colors = MiuixTheme.colorScheme
    val label = when {
        expanded -> ChangelogStrings.collapseAction
        revealsHiddenEntries -> ChangelogStrings.viewAllAction(total)
        else -> ChangelogStrings.viewFullAction
    }

    Row(
        modifier = Modifier.clickable { onToggle() }.padding(vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = label,
            style = MiuixTheme.textStyles.footnote1.shiftWeight(QingyuWeightDelta.SEMIBOLD),
            color = colors.primary,
        )
        Spacer(Modifier.width(2.dp))
        Icon(
            imageVector = if (expanded) MiuixIcons.ExpandLess else MiuixIcons.ExpandMore,
            contentDescription = null,
            tint = colors.primary,
            modifier = Modifier.size(16.dp),
        )
    }
}

/**
 * 长文摘要的统一形态：重点 + 计数常显，完整条目**默认收起**、点开才铺开
 * （「别一坨灰字堆着」）。分隔线用主题 secondaryContainer 的 1dp 淡线，
 * 与更新日志页同款；是否展开由调用方持有状态。
 */
@Composable
internal fun ReleaseNotesExpandableBody(digest: ReleaseNotesDigest) {
    val colors = MiuixTheme.colorScheme
    var expanded by remember(digest) { mutableStateOf(false) }
    val hasHiddenEntries = digest.total > digest.highlights.size

    if (digest.entries.isNotEmpty()) {
        Spacer(Modifier.height(4.dp))
        ReleaseNotesExpandToggle(
            expanded = expanded,
            revealsHiddenEntries = hasHiddenEntries,
            total = digest.total,
            onToggle = { expanded = !expanded },
        )
    }

    if (expanded) {
        Spacer(Modifier.height(10.dp))
        Spacer(
            modifier = Modifier
                .fillMaxWidth()
                .height(1.dp)
                .background(colors.secondaryContainer),
        )
        Spacer(Modifier.height(10.dp))
        ReleaseNotesGroupedEntries(digest)
    }
}
