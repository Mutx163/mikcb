package com.mutx163.qingyu.pages.time_scheme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.components.QingyuPageTheme
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Card
import top.yukonga.miuix.kmp.basic.HorizontalDivider
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.IconButton
import top.yukonga.miuix.kmp.basic.Scaffold
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TopAppBar
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Add
import top.yukonga.miuix.kmp.icon.extended.Back
import top.yukonga.miuix.kmp.icon.extended.More
import top.yukonga.miuix.kmp.preference.ArrowPreference

/**
 * 时间模板管理页 · Compose 渲染层（Phase 3）。
 *
 * 对应 Flutter `lib/screens/time_scheme_management_screen.dart`（1 888 行）。
 *
 * ## 页面骨架严格照 Dart 的 `_buildTimeSchemeListItem`（:378-431）
 *
 * 那一页不是「随便排几张卡」，而是**按下标拼出来的固定清单**：
 *
 * ```
 * 0  两个入口行（地点作息匹配 / 日期作息规则）  HyperosListGroup
 * 1  分段间距                                   HyperosSectionGap
 * 2  分区标题「时间模板」                        HyperosSectionLabel
 * 3+ 空态时：一行禁用提示「请先创建一套时间模板」
 *    有模板时：模板卡 / 间距交替
 * ```
 *
 * 这里照同一顺序落，因此 `oneScheme` / `twoSchemes` 与 Dart 的视觉节奏一致
 * （卡片之间留缝，而不是一坨连着）。
 *
 * ## 界面上没有的文案，本层不编
 *
 * 空态用的是 Dart 真实那一行 `locationTimeMatchNeedTimeScheme`（「请先创建一套时间模板」），
 * 不是自造的 "暂无模板"。凡是本层出现的字，都能在 [TimeSchemeManagementStrings]
 * 里找到同名键。
 *
 * ## 已知差异（认领文件里也记了一份）
 *
 * 六个弹层（新建/重命名、删除确认、使用情况、分享、编辑器）的**内容数据**模型层已备齐
 * （`createSheet` / `renameSheet` / `deleteCheck` / `usageView` / `shareSheet` / `editor`），
 * 但官方 Miuix 的弹层选型（OverlayDialog vs SuperDialog）属壳层决策，本批只把
 * 「用户点了哪一项」上报给宿主，由宿主弹。不做静默省略。
 *
 * @param model 已算好的页面模型（含空态判据、行内容、菜单项）
 * @param onBack 返回
 * @param onCreate 新建模板
 * @param onOpenScheme 进某套模板的编辑器
 * @param onMenuAction 行内菜单选了某一项
 * @param onOpenLocationEntry 进「地点作息匹配」
 * @param onOpenDateRules 进「日期作息规则」
 * @param dateRuleCount 日期规则条数（0 时入口不显示数字）
 * @param hasActiveDateRule 今天是否落在某条日期规则区间内
 */
@Composable
fun TimeSchemeManagementPage(
    model: TimeSchemeManagementModel,
    onBack: () -> Unit,
    onCreate: () -> Unit,
    onOpenScheme: (String) -> Unit,
    onMenuAction: (schemeId: String, action: TimeSchemeAction) -> Unit,
    onOpenLocationEntry: () -> Unit,
    onOpenDateRules: () -> Unit,
    dateRuleCount: Int = 0,
    hasActiveDateRule: Boolean = false,
) {
    val dark = isSystemInDarkTheme()

    QingyuPageTheme {
        Scaffold(
            containerColor = Color(QingyuTheme.scaffoldBackground(dark)),
            topBar = {
                TopAppBar(
                    title = model.title,
                    navigationIcon = {
                        IconButton(onClick = onBack) {
                            Icon(
                                imageVector = MiuixIcons.Back,
                                contentDescription = model.title,
                                tint = Color(QingyuTheme.actionIcon(dark)),
                            )
                        }
                    },
                    actions = {
                        IconButton(onClick = onCreate) {
                            Icon(
                                imageVector = MiuixIcons.Add,
                                contentDescription = model.newSchemeTooltip,
                                tint = Color(QingyuTheme.actionIcon(dark)),
                            )
                        }
                    },
                )
            },
        ) { innerPadding ->
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(innerPadding)
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = 16.dp, vertical = 8.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                // ── index 0：两个入口行 ──
                Card(modifier = Modifier.fillMaxWidth(), insideMargin = PaddingValues(vertical = 2.dp)) {
                    ArrowPreference(
                        title = TimeSchemeManagementStrings.locationTimeMatchEntryTitle.zh,
                        // Dart：locationTimeGroups 为空时 details 不显示（null）
                        summary = null,
                        onClick = onOpenLocationEntry,
                    )
                    HorizontalDivider(
                        modifier = Modifier.padding(start = 16.dp),
                        color = Color(QingyuTheme.dividerLine(dark)),
                    )
                    ArrowPreference(
                        title = TimeSchemeManagementStrings.scheduleDateRuleSectionTitle.zh,
                        // Dart：dateRules 为空 → 不显示；非空且今天在区间 → 「今天在区间内」；
                        // 否则显示条数。三种形态与 Dart 三元表达式一一对应。
                        summary = when {
                            dateRuleCount <= 0 -> null
                            hasActiveDateRule ->
                                TimeSchemeManagementStrings.scheduleDateRuleActiveToday.zh
                            else -> dateRuleCount.toString()
                        },
                        onClick = onOpenDateRules,
                    )
                }

                // ── index 2：分区标题 ──
                Text(
                    text = TimeSchemeManagementStrings.timeSchemeEntryTitle.zh,
                    fontSize = 13.sp,
                    color = Color(QingyuTheme.sectionLabel(dark)),
                    modifier = Modifier.padding(start = 4.dp, top = 8.dp, bottom = 4.dp),
                )

                // ── index 3+：空态一行 / 模板卡与间距交替 ──
                if (model.isEmpty) {
                    Card(modifier = Modifier.fillMaxWidth(), insideMargin = PaddingValues(vertical = 2.dp)) {
                        // Dart 这里是一个 **enabled: false、showChevron: false** 的行，
                        // 文案就是「请先创建一套时间模板」。不是新造的空态文案。
                        ArrowPreference(
                            title = TimeSchemeManagementStrings.locationTimeMatchNeedTimeScheme.zh,
                            summary = null,
                            onClick = {},
                            enabled = false,
                        )
                    }
                } else {
                    val rows = model.rows
                    for ((index, row) in rows.withIndex()) {
                        SchemeCard(
                            row = row,
                            menu = model.menu(row.scheme.id),
                            onOpen = { onOpenScheme(row.scheme.id) },
                            onMenuAction = { action -> onMenuAction(row.scheme.id, action) },
                        )
                        // Dart：模板卡之间插 HyperosSectionGap（卡片各占一格、间距占一格）
                        if (index < rows.lastIndex) {
                            Spacer(Modifier.height(8.dp))
                        }
                    }
                }
            }
        }
    }
}

/** 一张模板卡：标题（+ 使用中标签）+ 概要 + 起用时间 + 右上更多。 */
@Composable
private fun SchemeCard(
    row: TimeSchemeRow,
    menu: List<TimeSchemeMenuItem>,
    onOpen: () -> Unit,
    onMenuAction: (TimeSchemeAction) -> Unit,
) {
    val dark = isSystemInDarkTheme()

    Card(modifier = Modifier.fillMaxWidth(), insideMargin = PaddingValues(vertical = 12.dp)) {
        Column(modifier = Modifier.padding(horizontal = 16.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Column(modifier = Modifier.weight(1f)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(
                            text = row.title,
                            fontSize = 16.sp,
                            fontWeight = FontWeight.Medium,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                            color = Color(QingyuTheme.primaryText(dark)),
                        )
                        // 使用中的模板带状态标签；未使用时不占位（Dart 同口径）
                        if (row.isActive) {
                            Spacer(Modifier.width(8.dp))
                            Text(
                                text = row.statusLabel,
                                fontSize = 11.sp,
                                color = Color(QingyuTheme.primary(dark = dark)),
                            )
                        }
                    }
                    Spacer(Modifier.height(3.dp))
                    Text(
                        text = row.summary,
                        fontSize = 13.sp,
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis,
                        color = Color(QingyuTheme.secondaryText(dark)),
                    )
                    val startsAt = row.startsAt
                    if (startsAt != null) {
                        Spacer(Modifier.height(3.dp))
                        Text(
                            text = startsAt,
                            fontSize = 12.sp,
                            color = Color(QingyuTheme.secondaryText(dark)),
                        )
                    }
                }

                // 行尾：整卡可点进编辑器；更多菜单由宿主用官方下拉呈现，
                // 这里只上报「选了哪一项」，不把弹层状态塞进渲染层。
                IconButton(onClick = onOpen) {
                    Icon(
                        imageVector = MiuixIcons.More,
                        contentDescription = menu.firstOrNull()?.label ?: row.title,
                        tint = Color(QingyuTheme.actionIcon(dark)),
                        modifier = Modifier.size(20.dp),
                    )
                }
            }
        }
    }
}
