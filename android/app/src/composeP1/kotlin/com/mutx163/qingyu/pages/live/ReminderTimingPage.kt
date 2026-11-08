package com.mutx163.qingyu.pages.live

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.ui.tooling.preview.Preview
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuCardDefaults
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.components.QingyuPageScaffold
import com.mutx163.qingyu.components.QingyuPageTheme
import com.mutx163.qingyu.components.QingyuSectionTitle
import com.mutx163.qingyu.theme.QingyuShapes
import top.yukonga.miuix.kmp.preference.OverlayDropdownPreference
import top.yukonga.miuix.kmp.preference.SwitchPreference

/**
 * 「提醒时间」子屏 · Compose 渲染层（P35-live-reminder）。
 *
 * 对应 Flutter `lib/screens/live_settings_subpages.dart:72-289` 的
 * `LiveReminderTimingScreen`（State `:80-289`）：
 *
 * - 3 组共 12 个控件：
 *   1) 提醒开关组：上课前提醒开关 / 课中与下课提醒开关 / 重点提醒切入时机下拉（仅课中提醒开启时出现）；
 *   2) 展示方式组：课中状态栏通知开关 / 展示超级岛开关；
 *   3) 时间阈值组：上课前弹出时间下拉 / 下课前秒级阈值下拉 / 课中时间样式下拉。
 * - 控件形态照抄 Dart：`HyperosSwitchTile` → 官方 `SwitchPreference`；
 *   `HyperosSelectTile` → 官方 `OverlayDropdownPreference`（标题 + 副标题 + 下拉）。
 * - 所有文案取 [ReminderTimingStrings]（与 `lib/l10n/app_zh.arb` 逐字一致）；
 *   联动/摘要/边界口径全部走 [ReminderTimingLogic]，本层不写业务判断。
 *
 * 本层不持业务状态、不落库：状态由宿主传入，改动通过 [onStateChange] 抛回。
 */
@Composable
fun LiveReminderTimingPage(
    state: ReminderTimingState,
    onStateChange: (ReminderTimingState) -> Unit,
    onBack: () -> Unit,
) {
    val duringClassEnabled = ReminderTimingLogic.isDuringClassReminderEnabled(state)
    val leadSummary = ReminderTimingLogic.resolveLeadSummary(state)
    val statusHint = ReminderTimingLogic.resolveDuringClassStatusHint(state)

    // 骨架照 `docs/reference/compose-page-style-rules.md` §三：顶栏与滚动容器都走共享套件。
    // Dart 侧是 HyperosSubpage（`collapsibleLargeTitle` 默认 true）+ HyperosListView，
    // 大标题可折叠；官方 demo 侧滚动一律是 LazyColumn + 滚动三件套 ⇒ 样式从 demo。
    QingyuPageScaffold(
        title = ReminderTimingStrings.liveReminderTimingTitle.text,
        onBack = onBack,
    ) {
        QingyuPageList(
            innerPadding = innerPadding,
            scrollBehavior = scrollBehavior,
            contentPadding = PaddingValues(top = 8.dp, bottom = 24.dp),
            verticalArrangement = Arrangement.spacedBy(QingyuShapes.SECTION_GAP.dp),
        ) {
            // ── 组 1：提醒开关 ──
            item(key = "reminder-switches") {
                ReminderGroup(
                    label = ReminderTimingStrings.liveReminderSwitchesTitle.text,
                ) {
                    SwitchPreference(
                        checked = state.liveEnableBeforeClass,
                        onCheckedChange = {
                            onStateChange(state.copy(liveEnableBeforeClass = it))
                        },
                        title = ReminderTimingStrings.beforeClassReminderTitle.text,
                        summary = ReminderTimingStrings.formatBeforeClassReminderSubtitle(
                            state.liveShowBeforeClassMinutes,
                        ),
                    )

                    SwitchPreference(
                        // 显示值与写回值都走 OR 判据：拨一下把两个字段一起写。
                        checked = duringClassEnabled,
                        onCheckedChange = {
                            onStateChange(
                                ReminderTimingLogic.withDuringClassReminderEnabled(state, it),
                            )
                        },
                        title = ReminderTimingStrings.duringClassReminderTitle.text,
                    )

                    if (duringClassEnabled) {
                        val leadOptions = ReminderTimingLogic.CLASS_REMINDER_START_MINUTES
                        val leadLabels = leadOptions.map { minutes ->
                            ReminderTimingStrings.leadOptionText(minutes)
                        }
                        val leadIndex = leadOptions
                            .indexOf(state.liveClassReminderStartMinutes)
                            .coerceAtLeast(0)
                        OverlayDropdownPreference(
                            items = leadLabels,
                            selectedIndex = leadIndex,
                            title = ReminderTimingStrings.liveClassReminderLeadTitle.text,
                            summary = ReminderTimingStrings.leadSummaryText(leadSummary),
                            onSelectedIndexChange = { index ->
                                leadOptions.getOrNull(index)?.let { minutes ->
                                    onStateChange(
                                        state.copy(liveClassReminderStartMinutes = minutes),
                                    )
                                }
                            },
                        )
                    }
                }
            }

            // ── 组 2：展示方式 ──
            item(key = "display-mode") {
                ReminderGroup(
                    label = ReminderTimingStrings.liveDisplayModeTitle.text,
                ) {
                    SwitchPreference(
                        checked = state.liveShowDuringClassNotification,
                        onCheckedChange = {
                            onStateChange(state.copy(liveShowDuringClassNotification = it))
                        },
                        title = ReminderTimingStrings.duringClassStatusNotificationTitle.text,
                        summary = ReminderTimingStrings.duringClassStatusHintText(statusHint),
                    )

                    SwitchPreference(
                        checked = state.livePromoteDuringClass,
                        onCheckedChange = {
                            onStateChange(state.copy(livePromoteDuringClass = it))
                        },
                        title = ReminderTimingStrings.enableIslandDisplayTitle.text,
                    )
                }
            }

            // ── 组 3：时间阈值 ──
            item(key = "time-threshold") {
                ReminderGroup(
                    label = ReminderTimingStrings.liveTimeThresholdTitle.text,
                ) {
                    val beforeClassOptions = ReminderTimingLogic.BEFORE_CLASS_MINUTES_OPTIONS
                    val beforeClassIndex = beforeClassOptions
                        .indexOf(state.liveShowBeforeClassMinutes)
                        .coerceAtLeast(0)
                    OverlayDropdownPreference(
                        items = beforeClassOptions.map { minutes ->
                            ReminderTimingStrings.formatBeforeClassMinutesOption(minutes)
                        },
                        selectedIndex = beforeClassIndex,
                        title = ReminderTimingStrings.beforeClassPopupLabel.text,
                        onSelectedIndexChange = { index ->
                            beforeClassOptions.getOrNull(index)?.let { minutes ->
                                onStateChange(
                                    state.copy(liveShowBeforeClassMinutes = minutes),
                                )
                            }
                        },
                    )

                    val endSecondsOptions = ReminderTimingLogic.END_SECONDS_OPTIONS
                    val endSecondsIndex = endSecondsOptions
                        .indexOf(state.liveEndSecondsCountdownThreshold)
                        .coerceAtLeast(0)
                    OverlayDropdownPreference(
                        items = endSecondsOptions.map { seconds ->
                            ReminderTimingStrings.formatBeforeEndSecondsOption(seconds)
                        },
                        selectedIndex = endSecondsIndex,
                        title = ReminderTimingStrings.beforeEndSecondsLabel.text,
                        onSelectedIndexChange = { index ->
                            endSecondsOptions.getOrNull(index)?.let { seconds ->
                                onStateChange(
                                    state.copy(liveEndSecondsCountdownThreshold = seconds),
                                )
                            }
                        },
                    )

                    val displayModes = LiveDuringClassTimeDisplayMode.entries
                    val displayModeIndex = displayModes
                        .indexOf(state.liveDuringEndTimeDisplayMode)
                        .coerceAtLeast(0)
                    OverlayDropdownPreference(
                        items = displayModes.map { mode ->
                            ReminderTimingStrings.displayModeText(mode)
                        },
                        selectedIndex = displayModeIndex,
                        title = ReminderTimingStrings.duringEndTimeDisplayLabel.text,
                        onSelectedIndexChange = { index ->
                            displayModes.getOrNull(index)?.let { mode ->
                                onStateChange(
                                    state.copy(liveDuringEndTimeDisplayMode = mode),
                                )
                            }
                        },
                    )
                }
            }
        }
    }
}

/**
 * 宿主接线用的状态化重载：内部持有 [ReminderTimingState]，每次改动清洗后回调 [onPersist]。
 *
 * - [initialState]：进入页面时的草稿；先过一遍 [ReminderTimingLogic.sanitize]，
 *   保证三个下拉的当前值一定命中合法选项（外部老数据可能越界）。
 * - [onPersist]：每次改动后的完整草稿快照交给宿主落库（Dart `_enqueuePersist` 的口径在宿主层，
 *   失败提示与串行保存也归宿主）。
 */
@Composable
fun LiveReminderTimingPage(
    onBack: () -> Unit,
    initialState: ReminderTimingState = ReminderTimingState(),
    onPersist: (ReminderTimingState) -> Unit = {},
) {
    var state by remember { mutableStateOf(ReminderTimingLogic.sanitize(initialState)) }

    LiveReminderTimingPage(
        state = state,
        onStateChange = { next ->
            val sanitized = ReminderTimingLogic.sanitize(next)
            state = sanitized
            onPersist(sanitized)
        },
        onBack = onBack,
    )
}

/**
 * 一组 = 分组标签 + 一张设置组白卡（Dart `HyperosSectionLabel` + `HyperosListGroup`）。
 *
 * 分组标签走 [QingyuSectionTitle]（官方 `SmallTitle`）：自带 28dp 左缘，
 * 正好对上「页面 0 → Card 外边距 12 → Preference 自带 16」那条轴线；
 * 手写 `13.sp + padding(start = 20.dp)` 会对不齐。
 *
 * 卡片内边距传 0：官方 `*Preference` 组件自带 16dp，再给会变 32dp（见 [QingyuCard] 注释）。
 */
@Composable
private fun ReminderGroup(
    label: String,
    content: @Composable ColumnScope.() -> Unit,
) {
    QingyuSectionTitle(text = label)
    QingyuCard(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = QingyuShapes.ROW_PADDING_HORIZONTAL.dp),
        cornerRadius = QingyuCardDefaults.SettingsGroupCorner,
        insideMargin = PaddingValues(0.dp),
        content = content,
    )
}

// ─────────────────────────────────────────────────────────────────────────────
// IDE 预览（2026-11-08）
//
// 只给实现阶段看效果，不进业务路径。覆盖两个维度：
//
//   数据状态 2 档：默认（课中提醒开 ⇒ 三个下拉都在）/ 课中提醒关（少一个切入时机下拉）；
//   外观 3 档：亮色、暗色、大字号 1.3。
//
// 为什么偏偏是这两档数据：「重点提醒切入时机」这一行只在课中提醒开着时才渲染，
// 关掉后整页少一行——模型层的 OR 判据（两个字段任一为真即算开）最容易在这里改错。
//
// 固定写法：主题一律 QingyuPageTheme(isDark = …)、字号走 textScale 参数
//（@Preview(fontScale = …) 绕过了应用的 appTextScale 口径）；宽度按 400dp。
// 这里刻意用**无状态重载**（`state = …`）：状态化重载会额外清洗 + 回调落库，预览里不需要。
// ─────────────────────────────────────────────────────────────────────────────

/** 默认草稿：课中提醒开着，三个下拉与两侧摘要全部可见。 */
private val previewReminderTimingDefault: ReminderTimingState = ReminderTimingState(
    liveEnableBeforeClass = true,
    liveEnableDuringClass = true,
    liveEnableBeforeEnd = true,
    liveClassReminderStartMinutes = 10,
    liveShowDuringClassNotification = true,
    livePromoteDuringClass = true,
    liveShowBeforeClassMinutes = 20,
    liveEndSecondsCountdownThreshold = 60,
    liveDuringEndTimeDisplayMode = LiveDuringClassTimeDisplayMode.NEAREST,
)

/** 课中与下课提醒关掉（两个字段一起为 false）：整页少一行，状态栏通知那行的副句也换口径。 */
private val previewReminderTimingDuringClassOff: ReminderTimingState =
    previewReminderTimingDefault.copy(
        liveEnableDuringClass = false,
        liveEnableBeforeEnd = false,
    )

/** 一档预览的公共身体：草稿状态 + 外观档位。 */
@Composable
private fun PreviewLiveReminderTimingPage(
    state: ReminderTimingState,
    dark: Boolean = false,
    textScale: Float = 1f,
) {
    QingyuPageTheme(isDark = dark, textScale = textScale) {
        LiveReminderTimingPage(
            state = state,
            onStateChange = {},
            onBack = {},
        )
    }
}

// ── 单档：两态 × 亮色 ──────────────────────────────────────────────────────

@Suppress("unused")
@Preview(name = "1 默认", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun LiveReminderTimingPagePreviewDefault() {
    PreviewLiveReminderTimingPage(previewReminderTimingDefault)
}

@Suppress("unused")
@Preview(name = "2 课中提醒关闭", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun LiveReminderTimingPagePreviewDuringClassOff() {
    PreviewLiveReminderTimingPage(previewReminderTimingDuringClassOff)
}

// ── 单档：外观两档（以「默认」为基准）───────────────────────────────────────

@Suppress("unused")
@Preview(name = "3 暗色", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun LiveReminderTimingPagePreviewDark() {
    PreviewLiveReminderTimingPage(previewReminderTimingDefault, dark = true)
}

@Suppress("unused")
@Preview(name = "4 大字号 1.3", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun LiveReminderTimingPagePreviewLargeText() {
    PreviewLiveReminderTimingPage(previewReminderTimingDefault, textScale = 1.3f)
}
