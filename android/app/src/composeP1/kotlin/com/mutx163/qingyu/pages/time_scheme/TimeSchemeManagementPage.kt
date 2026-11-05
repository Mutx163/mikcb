package com.mutx163.qingyu.pages.time_scheme

import androidx.compose.animation.Crossfade
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuCardDefaults
import com.mutx163.qingyu.components.QingyuPageCardMargin
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.components.QingyuPageScaffold
import com.mutx163.qingyu.components.QingyuSectionGap
import com.mutx163.qingyu.components.QingyuSectionTitle
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.shiftWeight
import com.mutx163.qingyu.theme.QingyuIconColors
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.ButtonDefaults
import top.yukonga.miuix.kmp.basic.CircularProgressIndicator
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.IconButton
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Add
import top.yukonga.miuix.kmp.icon.extended.Location
import top.yukonga.miuix.kmp.icon.extended.Months
import top.yukonga.miuix.kmp.icon.extended.More
import top.yukonga.miuix.kmp.icon.extended.Timer
import top.yukonga.miuix.kmp.preference.ArrowPreference
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 时间模板管理页（列表页）的渲染层。
 *
 * 视觉与行为的唯一基准是 Flutter `lib/screens/time_scheme_management_screen.dart`：
 * 骨架对 `build`（:120-176），条目顺序对 `_buildTimeSchemeListItem`（:370-448），
 * 单张模板卡对 `_buildSchemeCard`（:450-560）。本层是**纯渲染**：所有取值来自
 * [TimeSchemeManagementModel]，所有点击只**上报**（`onCreate` / `onOpenMenu` /
 * `onApply` / `onEditSections` / 两个入口回调），写盘与弹层显隐在宿主
 * （`app/TimeSchemeHost.kt`）。
 *
 * ## 条目顺序为什么照抄 Dart 的下标拼装
 *
 * Dart 那一页不是「随便排几张卡」，而是按下标固定拼出来的一串：
 *
 * ```
 * 0  两个入口行（地点作息匹配 / 日期作息规则）   HyperosListGroup
 * 1  分段间距                                    HyperosSectionGap（12dp）
 * 2  分区标题「时间模板」                         HyperosSectionLabel
 * 3+ 空态：一行禁用提示；有模板：卡片 / 12dp 间距交替
 * ```
 *
 * 这里照同一顺序落成 `QingyuPageList` 的 item，间距交给
 * `verticalArrangement = spacedBy(QingyuSectionGap)`——Dart 的 `HyperosSectionGap`
 * 本身就是 `HyperosTokens.sectionGap = 12dp`，所以**一个 item 一张卡**就等价于
 * 「卡片 / 间距 / 卡片」的交替，不需要再塞 `Spacer`（塞了会变成 20dp，旧版就是这么错的）。
 *
 * ## 与 Dart 的已知差异（诚实清单）
 *
 * - **卡片图标**：Dart 两态用 `Icons.schedule_rounded` / `Icons.access_time_rounded`
 *   两个几乎同形的时钟字；miuix 0.9.4 的官方扩展图标里只有一个时钟位（`Timer`），
 *   所以两态靠颜色区分（使用中 teal / 未使用 blue，与 Dart 的 `HyperosIconColors` 同值），
 *   字形共用 `Timer`。不新造字形。
 * - **入口行图标**：地点用官方 `Location`（= Dart `place_outlined`）；日期规则用官方
 *   `Months`（月历），因为 miuix 没有 `event_available`（带勾选的日历）那一款。
 * - **空态行**：Dart 是 `HyperosNavTile(enabled: false, showChevron: false)`。这里刻意
 *   **不套** `ArrowPreference`——它会画尾部箭头，与 `showChevron: false` 相反——而是
 *   在 `QingyuCard` 里摆一行禁用墨色的文字，视觉结果一致。
 * - **图标与标题的间距**：官方 `ArrowPreference` 的 `startAction` 与文字固定 8dp，
 *   Dart 的 `settingsIconGap` 是 12dp，所以入口行徽标外包了 4dp 的 `padding(end)` 补足。
 */

/**
 * @param model 已算好的页面模型（空态判据、入口行行尾、卡片行、使用中判据）
 * @param onBack 返回
 * @param onCreate 顶栏「新建模板」
 * @param onOpenMenu 卡片右上「更多」→ 宿主弹菜单
 * @param onApply 卡片底部「应用到当前课表」
 * @param onEditSections 卡片底部「编辑节次」
 * @param onOpenLocationEntry 进「地点作息匹配」
 * @param onOpenDateRules 进「日期作息规则」
 */
@Composable
fun TimeSchemeManagementPage(
    model: TimeSchemeManagementModel,
    onBack: () -> Unit,
    onCreate: () -> Unit,
    onOpenMenu: (schemeId: String) -> Unit,
    onApply: (schemeId: String) -> Unit,
    onEditSections: (schemeId: String) -> Unit,
    onOpenLocationEntry: () -> Unit,
    onOpenDateRules: () -> Unit,
    /**
     * 数据首装载中（宿主在后台线程读仓储快照 + 算引用索引）。
     * 为 true 时页面先画一帧**转圈**，别让用户对着空页等（旧实现同步算在主线程上，
     * 首帧被阻塞数秒、数据回来才一次性渲染）。
     */
    isLoading: Boolean = false,
) {
    val dark = isSystemInDarkTheme()

    QingyuPageScaffold(
        title = model.title,
        onBack = onBack,
        actions = {
            // Dart `FHeaderAction(icon: Icons.add_rounded, semanticsLabel: newSchemeTooltip)`
            IconButton(onClick = onCreate) {
                Icon(
                    imageVector = MiuixIcons.Add,
                    contentDescription = model.newSchemeTooltip,
                    tint = Color(QingyuTheme.actionIcon(dark)),
                )
            }
        },
    ) {
        // 加载态 → 内容用 180ms 交叉淡入：不再「空页停几秒、内容猛一下弹出来」。
        Crossfade(
            targetState = isLoading,
            animationSpec = tween(durationMillis = 180),
            label = "timeSchemeLoading",
        ) { loading ->
            QingyuPageList(
                innerPadding = innerPadding,
                scrollBehavior = scrollBehavior,
                horizontalPadding = QingyuPageCardMargin,
                verticalArrangement = Arrangement.spacedBy(QingyuSectionGap),
            ) {
                if (loading) {
                    item(key = "timeSchemeLoading") {
                        TimeSchemeLoadingState()
                    }
                } else {
                    // ── index 0：两个入口行（同一张卡） ──
                    item(key = "timeSchemeEntries") {
                        EntryCard(
                            model = model,
                            onOpenLocationEntry = onOpenLocationEntry,
                            onOpenDateRules = onOpenDateRules,
                        )
                    }

                    // ── index 1 + 2：分段间距（由 spacedBy 承担）+ 分区标题 ──
                    item(key = "timeSchemeSectionTitle") {
                        // 「时间模板」小灰字：与 Flutter v2.1.4.1 `HyperosSectionLabel` 同口径——
                        // 左右 16dp 对齐 28dp 文字轴，纵向不再叠 SmallTitle 默认的 8dp（列表 spacedBy 已给 12dp），
                        // 否则上下各 ~20dp 一大片空白。
                        QingyuSectionTitle(
                            text = TimeSchemeManagementStrings.timeSchemeEntryTitle.zh,
                            insideMargin = PaddingValues(start = 16.dp, end = 16.dp, top = 0.dp, bottom = 0.dp),
                        )
                    }

                    // ── index 3+：空态一行 / 模板卡 ──
                    if (model.isEmpty) {
                        item(key = "timeSchemeEmptyState") {
                            EmptyStateRow()
                        }
                    } else {
                        items(items = model.rows, key = { row -> row.scheme.id }) { row ->
                            SchemeCard(
                                row = row,
                                onOpenMenu = { onOpenMenu(row.scheme.id) },
                                onApply = { onApply(row.scheme.id) },
                                onEditSections = { onEditSections(row.scheme.id) },
                            )
                        }
                    }
                }
            }
        }
    }
}

/** 首装载转圈：与 App 其它异步列表页同形态（居中官方 `CircularProgressIndicator`）。 */
@Composable
private fun TimeSchemeLoadingState() {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 120.dp),
        contentAlignment = Alignment.Center,
    ) {
        CircularProgressIndicator()
    }
}

/** 两个入口行：地点作息匹配 / 日期作息规则（Dart `_buildTimeSchemeListItem` index 0）。 */
@Composable
private fun EntryCard(
    model: TimeSchemeManagementModel,
    onOpenLocationEntry: () -> Unit,
    onOpenDateRules: () -> Unit,
) {
    // 行尾 details：null = 不显示（Dart 里 `details: 空 ? null : '…'`）。
    val locationDetails = model.locationEntryDetails
    val dateRuleDetails = model.dateRuleEntryDetails

    QingyuCard(
        modifier = Modifier.fillMaxWidth(),
        // 与 Flutter `HyperosListGroup` / `HyperosAdaptiveCard` 一致：设置组卡片圆角 24dp。
        cornerRadius = QingyuCardDefaults.SettingsGroupCorner,
    ) {
        ArrowPreference(
            title = TimeSchemeManagementStrings.locationTimeMatchEntryTitle.zh,
            startAction = {
                Box(modifier = Modifier.padding(end = 4.dp)) {
                    LeadingIconBadge(icon = MiuixIcons.Location, accent = Color(QingyuIconColors.ORANGE))
                }
            },
            // 官方的 endActions 是**非空**槽位（`@Composable RowScope.() -> Unit`），
            // 传 null 编译不过；没行尾时给一个什么都不画的槽位即可（与「不显示」等价）。
            endActions = {
                if (locationDetails != null) TrailingDetailText(locationDetails)
            },
            onClick = onOpenLocationEntry,
        )
        // 官方 ArrowSection.kt:44-95：多个 Preference 同卡、中间不加分割线。
        ArrowPreference(
            title = TimeSchemeManagementStrings.scheduleDateRuleSectionTitle.zh,
            startAction = {
                Box(modifier = Modifier.padding(end = 4.dp)) {
                    LeadingIconBadge(icon = MiuixIcons.Months, accent = Color(QingyuIconColors.TEAL))
                }
            },
            endActions = {
                if (dateRuleDetails != null) TrailingDetailText(dateRuleDetails)
            },
            onClick = onOpenDateRules,
        )
    }
}

/**
 * 空态：一行禁用、无箭头的提示行（Dart `HyperosNavTile(enabled: false, showChevron: false)`）。
 *
 * 文案取 ARB 里已有的 `locationTimeMatchNeedTimeScheme`（「请先创建一套时间模板」），
 * 不是新造的空态句。
 */
@Composable
private fun EmptyStateRow() {
    val dark = isSystemInDarkTheme()
    QingyuCard(
        modifier = Modifier.fillMaxWidth(),
        cornerRadius = QingyuCardDefaults.SettingsGroupCorner,
        insideMargin = QingyuCardDefaults.ContentInsideMargin,
    ) {
        Text(
            text = TimeSchemeManagementStrings.locationTimeMatchNeedTimeScheme.zh,
            style = MiuixTheme.textStyles.body1,
            color = Color(QingyuTheme.secondaryText(dark)),
        )
    }
}

/**
 * 一张模板卡（Dart `_buildSchemeCard`，:450-560）。
 *
 * 自上而下：图标徽标 + 名称 + 概要 + 右上「更多」→ 首节起止 →（使用中才有的）
 * 「正在使用」→ 底部一行两个按钮。
 */
@Composable
private fun SchemeCard(
    row: TimeSchemeRow,
    onOpenMenu: () -> Unit,
    onApply: () -> Unit,
    onEditSections: () -> Unit,
) {
    val dark = isSystemInDarkTheme()
    val primaryText = Color(QingyuTheme.primaryText(dark))
    val secondaryText = Color(QingyuTheme.secondaryText(dark))
    // Dart：使用中 teal / 否则 blue（HyperosIconColors 同值 token）。
    val badgeAccent = if (row.isActive) Color(QingyuIconColors.TEAL) else Color(QingyuIconColors.BLUE)

    // 首节起止（Dart :516-522）：
    //   0 节 → '-'（占位符，坏数据也能渲染）
    //   1 节 → 该节 displayText
    //   多节 → 「{首节 displayText} 起」
    val firstSection = row.firstSectionText
    val sectionLine = when {
        row.hasNoSections -> NO_SECTION_PLACEHOLDER
        firstSection == null -> NO_SECTION_PLACEHOLDER
        row.sectionCount <= 1 -> firstSection
        else -> TimeSchemeManagementStrings.timeSchemeStartsAt.filled("start", firstSection)
    }

    QingyuCard(
        modifier = Modifier.fillMaxWidth(),
        // 与 Flutter `HyperosControlCard` 一致：设置组圆角 24dp + headerlessBodyPadding(16,16,16,12)。
        cornerRadius = QingyuCardDefaults.SettingsGroupCorner,
        insideMargin = PaddingValues(start = 16.dp, top = 16.dp, end = 16.dp, bottom = 12.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            LeadingIconBadge(icon = MiuixIcons.Timer, accent = badgeAccent)
            Spacer(modifier = Modifier.width(12.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = row.title,
                    style = MiuixTheme.textStyles.body1.shiftWeight(QingyuWeightDelta.MEDIUM),
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    color = primaryText,
                )
                Spacer(modifier = Modifier.height(2.dp))
                // 概要：Dart 只有一行（`maxLines: 1` + ellipsis）
                Text(
                    text = row.summary,
                    style = MiuixTheme.textStyles.footnote1,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    color = secondaryText,
                )
            }
            IconButton(onClick = onOpenMenu) {
                Icon(
                    imageVector = MiuixIcons.More,
                    contentDescription = TimeSchemeManagementStrings.moreActionsTooltip.zh,
                    tint = Color(QingyuTheme.actionIcon(dark)),
                    modifier = Modifier.size(20.dp),
                )
            }
        }

        Spacer(modifier = Modifier.height(8.dp))
        Text(
            text = sectionLine,
            style = MiuixTheme.textStyles.footnote1,
            color = secondaryText,
        )

        if (row.isActive) {
            Spacer(modifier = Modifier.height(8.dp))
            Text(
                text = TimeSchemeManagementStrings.usingNow.zh,
                style = MiuixTheme.textStyles.footnote1,
                color = Color(QingyuTheme.primary(dark = dark)),
            )
        }

        Spacer(modifier = Modifier.height(12.dp))
        Row(verticalAlignment = Alignment.CenterVertically) {
            // 左：使用中显示「正在使用」且禁用；否则「应用到当前课表」可点。
            SecondaryButton(
                label = if (row.isActive) {
                    TimeSchemeManagementStrings.usingNow.zh
                } else {
                    TimeSchemeManagementStrings.applyToCurrentTimetable.zh
                },
                enabled = !row.isActive,
                onClick = onApply,
                modifier = Modifier.weight(1f),
            )
            Spacer(modifier = Modifier.width(8.dp))
            SecondaryButton(
                label = TimeSchemeManagementStrings.editSectionsAction.zh,
                onClick = onEditSections,
            )
        }
    }
}

/**
 * Dart `HyperosIconBadge`（`indicators.dart:143-166`）的对应物：
 * 26dp 实色圆角方块（圆角 7dp）+ 14dp 白色字形。
 */
@Composable
private fun LeadingIconBadge(icon: ImageVector, accent: Color) {
    Box(
        modifier = Modifier
            .size(26.dp)
            .clip(RoundedCornerShape(7.dp))
            .background(accent),
        contentAlignment = Alignment.Center,
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = Color.White,
            modifier = Modifier.size(14.dp),
        )
    }
}

/** 行尾 details：官方 `ArrowPreference` 的 endActions 槽位里的一段次要墨色文字。 */
@Composable
private fun TrailingDetailText(text: String) {
    Text(
        text = text,
        style = MiuixTheme.textStyles.body2,
        color = MiuixTheme.colorScheme.onSurfaceVariantActions,
    )
}

/**
 * Dart `HyperosButtonVariant.secondary` 的对应物：浅底 + 主色文字（与导入页同款取法）。
 * 禁用态由官方 `Button(enabled = false)` 自己压暗，不手改颜色。
 */
@Composable
private fun SecondaryButton(
    label: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
) {
    Button(
        onClick = onClick,
        modifier = modifier,
        enabled = enabled,
        // 对齐 Flutter `HyperosButtonVariant.secondary`（非磨砂面板）：底色 `secondary`、
        // 字色 `onSecondaryVariant`、禁用用各自的 disabled 档。原来自定义的
        // surfaceVariant 底与卡片底太接近，读起来像纯文字、不像按钮。
        colors = ButtonDefaults.buttonColors(
            color = MiuixTheme.colorScheme.secondary,
            disabledColor = MiuixTheme.colorScheme.disabledSecondary,
            contentColor = MiuixTheme.colorScheme.onSecondaryVariant,
            disabledContentColor = MiuixTheme.colorScheme.disabledOnSecondaryVariant,
        ),
    ) {
        Text(
            text = label,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
    }
}

/**
 * 「这套模板没有任何节次」时的占位符。
 *
 * 与 Dart 逐字一致的是 `'-'`（`_buildSchemeCard` 的 `switch (scheme.sectionCount) 0 => '-'`）：
 * 它是占位符而不是句子，ARB 里也没有对应键，所以不做本地化。
 */
private const val NO_SECTION_PLACEHOLDER = "-"
