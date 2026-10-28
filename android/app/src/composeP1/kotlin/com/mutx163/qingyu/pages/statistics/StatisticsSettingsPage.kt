package com.mutx163.qingyu.pages.statistics

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuPageCardMargin
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.components.QingyuPageScaffold
import com.mutx163.qingyu.components.QingyuSectionGap
import com.mutx163.qingyu.components.QingyuSectionTitle
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Alarm
import top.yukonga.miuix.kmp.preference.SwitchPreference

/**
 * 统计设置页 · Compose 渲染层（Phase 3）。
 *
 * 对应 Flutter `lib/screens/statistics_settings_screen.dart`：
 * - 顶栏：返回 + "统计设置"
 * - 一块设置分组（块头 "本周课程小结"），组内一行开关：
 *   标题 "本周课程小结"，副标题按开关态取「下次推送 {日期} {时间}」或「已关闭每周周报推送」
 *
 * 不持业务状态、不做业务计算：下次推送时刻与副标题都在
 * [StatisticsSettingsLogic.buildViewState] 里算好，这里只画。
 *
 * ## 版式（2026-10-28 按页面样式规则 R1..R6 重排）
 *
 * 原先自己 `Scaffold + TopAppBar + Column + verticalScroll + Card + 手拼块头`，
 * 六条规则里中了四条（R2 非惰性滚动、R3 裸卡片无按压反馈、R4 写死字号、R6 手拼分组标题）。
 * 现在整页照 `docs/reference/compose-page-style-rules.md` §三 的标准配方搭：
 * [QingyuPageScaffold]（顶栏 / 返回键 / 折叠行为）→ [QingyuPageList]（惰性列表 + 滚动条 + 末端触感）
 * → [QingyuSectionTitle]（官方 `SmallTitle`，自带 28dp 左缘）→ [QingyuCard]（按压反馈 + 语义圆角）。
 *
 * 注：块头与开关行标题在 Dart 原文里是同一个 ARB 键（`weeklyReportTitle`），
 * 屏上念两遍是既有行为，本次迁移不改文案。
 */
@Composable
fun StatisticsSettingsPage(
    viewState: StatisticsSettingsViewState,
    onBack: () -> Unit,
    onWeeklyReportToggle: (Boolean) -> Unit,
) {
    val dark = isSystemInDarkTheme()

    // 大标题折叠行为由骨架统一持有（Dart lib/screens/statistics_settings_screen.dart:23
    // 走 HyperosSubpage，collapsibleLargeTitle 默认 true ⇒ 用骨架默认的可折叠大标题变体）。
    QingyuPageScaffold(title = viewState.title, onBack = onBack) {
        QingyuPageList(
            innerPadding = innerPadding,
            scrollBehavior = scrollBehavior,
            // 横向留白 12dp + Preference 自带 16dp = 文字左缘 28dp，与 SmallTitle 的 28 轴线对齐。
            horizontalPadding = QingyuPageCardMargin,
            contentPadding = PaddingValues(top = 8.dp, bottom = 24.dp),
        ) {
            item(key = "weeklyReport") {
                QingyuSectionTitle(text = viewState.sectionTitle)
                QingyuCard(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(bottom = QingyuSectionGap),
                    // 里面是 Preference 行（自带 16dp 内边距），只留一点上下呼吸位。
                    insideMargin = PaddingValues(vertical = 2.dp),
                ) {
                    SwitchPreference(
                        checked = viewState.isEnabled,
                        onCheckedChange = onWeeklyReportToggle,
                        title = viewState.tileTitle,
                        summary = viewState.subtitle,
                        startAction = {
                            Icon(
                                imageVector = MiuixIcons.Alarm,
                                contentDescription = null,
                                tint = Color(QingyuTheme.primary(dark = dark)),
                                modifier = Modifier
                                    .padding(horizontal = 4.dp)
                                    .size(20.dp),
                            )
                        },
                    )
                }
            }
        }
    }
}
