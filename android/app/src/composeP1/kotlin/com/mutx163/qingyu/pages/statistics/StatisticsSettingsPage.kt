package com.mutx163.qingyu.pages.statistics

import android.widget.Toast
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuPageCardMargin
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.components.QingyuPageScaffold
import com.mutx163.qingyu.components.QingyuPageTheme
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

    // 开关的显示值必须在本页落地：壳（ShellPageIndex.kt 的 `e.statisticsSettings`）
    // 只在进入页面时读一次偏好，点击回调写完调度器就返回，没有任何 Compose 状态
    // 会触发重组。若直接绑 `viewState.isEnabled`，用户点一下开关会弹回原位、
    // 看起来像「按了没反应」。副标题也用同一个本地值重算，避免「开着却写已关闭」。
    var enabled by remember(viewState.isEnabled) { mutableStateOf(viewState.isEnabled) }
    val subtitle = remember(enabled, viewState.nextFireAt) {
        StatisticsSettingsLogic.subtitle(enabled, viewState.nextFireAt)
    }
    // 结果提示走本页（2026-11-05 审核修复）：对齐 Dart `_setWeeklyReportEnabled` 的
    // 两条反馈——成功 `weeklyReportEnabledHint` / `weeklyReportDisabledHint`、失败
    // `saveFailed`（statistics_settings_screen.dart:88-111）。此前 Compose 版
    // 成败都无提示。宿主回调同步执行，落盘/调度抛错时**回滚开关**再提示，
    // 不让「界面开着、实际没排上」。文案取模型层现成的
    // [StatisticsSettingsLogic.toggleResultMessage] / `SAVE_FAILED_MESSAGE`。
    val context = LocalContext.current

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
                        checked = enabled,
                        onCheckedChange = { want ->
                            val previous = enabled
                            enabled = want
                            try {
                                onWeeklyReportToggle(want)
                                Toast.makeText(
                                    context,
                                    StatisticsSettingsLogic.toggleResultMessage(want),
                                    Toast.LENGTH_SHORT,
                                ).show()
                            } catch (error: Throwable) {
                                // 落盘/调度失败：开关回滚 + 诚实提示（Dart 同语义，
                                // `_setWeeklyReportEnabled` 的 catch 分支）。
                                // 文案按异常**类型**选（`StatisticsSettingsLogic.failureMessage`）：
                                // 通知不可达 → 「去开通知」；其余 → 「保存失败」。
                                // 不在这里认 message 字符串——那是两处各解析一次的老毛病。
                                enabled = previous
                                Toast.makeText(
                                    context,
                                    StatisticsSettingsLogic.failureMessage(error),
                                    Toast.LENGTH_SHORT,
                                ).show()
                            }
                        },
                        title = viewState.tileTitle,
                        summary = subtitle,
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

// ── 预览 ──────────────────────────────────────────────────────────────────────
//
// 副标题里的「下次推送 M月d日 HH:mm」是模型层算的（`WeeklyReportSchedule.nextFireAt`），
// 所以预览也走真装配函数 `StatisticsSettingsLogic.buildViewState(...)`，不手写一份假日期。
//
// `LocalDateTime` 用全限定名：本文件的 import 块按预览约定只允许动三行
// （`Preview` / `QingyuPageTheme` / 总览布局件），不为预览扩大 import 面。

/** 预览基准时刻：2026-11-08 10:00（周日），下次推送落在下周一。 */
private val previewSettingsNow: java.time.LocalDateTime = java.time.LocalDateTime.of(2026, 11, 8, 10, 0)

private fun previewSettingsState(enabled: Boolean): StatisticsSettingsViewState =
    StatisticsSettingsLogic.buildViewState(weeklyReportEnabled = enabled, now = previewSettingsNow)

/** 一档预览的公共身体：视图状态 + 外观档位。 */
@Composable
private fun PreviewSettingsBody(
    state: StatisticsSettingsViewState,
    dark: Boolean = false,
    textScale: Float = 1f,
) {
    QingyuPageTheme(isDark = dark, textScale = textScale) {
        StatisticsSettingsPage(
            viewState = state,
            onBack = {},
            onWeeklyReportToggle = {},
        )
    }
}

// ── 单档：开关两态 × 亮色 ───────────────────────────────────────────────────

@Suppress("unused")
@Preview(name = "1 周报已开启", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun PreviewSettingsEnabled() {
    PreviewSettingsBody(previewSettingsState(enabled = true))
}

@Suppress("unused")
@Preview(name = "2 周报已关闭", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun PreviewSettingsDisabled() {
    PreviewSettingsBody(previewSettingsState(enabled = false))
}

// ── 单档：外观两档（以「已开启」为基准）────────────────────────────────────

@Suppress("unused")
@Preview(name = "3 暗色", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun PreviewSettingsDark() {
    PreviewSettingsBody(previewSettingsState(enabled = true), dark = true)
}

@Suppress("unused")
@Preview(name = "4 大字号 1.3", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun PreviewSettingsLargeText() {
    PreviewSettingsBody(previewSettingsState(enabled = true), textScale = 1.3f)
}
