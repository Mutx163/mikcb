package com.mutx163.qingyu.pages.schedule

import androidx.compose.foundation.background
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.app.AppLocaleRuntime
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuGlassIconButton
import com.mutx163.qingyu.components.QingyuPageCardMargin
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.components.QingyuPageScaffold
import com.mutx163.qingyu.components.QingyuPageTheme
import com.mutx163.qingyu.components.QingyuSectionTitle
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.shiftWeight
import com.mutx163.qingyu.pages.task.TaskStrings
import com.mutx163.qingyu.theme.QingyuIconColors
import com.mutx163.qingyu.theme.QingyuTheme
import java.time.format.DateTimeFormatter
import java.util.Locale
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TextButton
import top.yukonga.miuix.kmp.overlay.OverlayDialog
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.ChevronForward
import top.yukonga.miuix.kmp.theme.MiuixTheme
import top.yukonga.miuix.kmp.icon.extended.Add
import top.yukonga.miuix.kmp.icon.extended.Months

/**
 * 日程列表页 · Compose 渲染层（Phase 3）。
 *
 * 对应 Flutter `lib/screens/schedule_list_screen.dart`：
 * 三组列表（即将到来 / 已过期 / 已暂停）+ 空态 + 增删改入口。
 */
@Composable
fun ScheduleListPage(
    groups: ScheduleListGroups,
    onBack: () -> Unit,
    onAddSchedule: () -> Unit,
    onEditSchedule: (ScheduleItemData) -> Unit,
    onDeleteSchedule: (ScheduleItemData) -> Unit,
) {
    val dark = isSystemInDarkTheme()
    var deleteCandidate by remember { mutableStateOf<ScheduleItemData?>(null) }

    // 共享骨架（2026-11-05 B 组迁移）：官方顶栏 + 标准返回键 + 顶栏毛玻璃 + actions 槽。
    // 返回键的显隐（根页不画）与玻璃圆底的出没门控都由骨架注入；大标题仍可折叠
    //（Dart `schedule_list_screen.dart:38` 走 HyperosSubpage 默认参数）。
    QingyuPageScaffold(
        title = ScheduleStrings.scheduleListTitle.text,
        onBack = onBack,
        // Dart 侧顶栏右侧是 FHeaderAction(Icons.add_rounded) 图标按钮，
        // 第一版用了文字按钮「添加」，与现版本形态不一致。
        // 右上动作键与左上返回键同一套外观：共享玻璃圆底 + 细边 + 小外浮影。
        actions = {
            QingyuGlassIconButton(
                onClick = onAddSchedule,
                contentDescription = ScheduleStrings.addScheduleAction.text,
                icon = MiuixIcons.Add,
                tint = Color(QingyuTheme.actionIcon(dark)),
            )
        },
    ) {
        // 主滚动统一走共享套件（R2）：内含官方三件套（末端轻震 + 过度滚动 + 顶栏联动）
        // 与右侧滚动条。底部手势条由本页**显式**算一次放进 contentPadding，所以喂给套件的
        // innerPadding 只取顶部——套件内部还会再加一次 innerPadding 的 bottom，
        // 两份都给就会把小白条算两遍（原版正是「Column padding(innerPadding) +
        // contentPadding 里再来一次」，本来就重复）。
        QingyuPageList(
            innerPadding = PaddingValues(top = innerPadding.calculateTopPadding()),
            scrollBehavior = scrollBehavior,
            contentPadding = PaddingValues(
                top = 8.dp,
                // 底部把系统手势条那段算进去，否则最后一行钻到小白条底下。
                bottom = innerPadding.calculateBottomPadding() + 24.dp,
            ),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            if (groups.isEmpty) {
                // ── 空态展示 ──
                item(key = "empty") {
                    Box(
                        modifier = Modifier
                            .fillParentMaxSize()
                            .padding(24.dp),
                        contentAlignment = Alignment.Center,
                    ) {
                        // 口径 = 发布版 `schedule_list_screen.dart:85-98` 的
                        // `HyperosEmptyState(icon: event_available_outlined, title, action)`：
                        // 居中图标(48) + 16dp + 标题 + 20dp + 主操作按钮，**不套卡片**
                        // （考试页 `ExamEmptyState`、待办页 `TaskEmptyState` 同版式）。
                        // 图标语义取官方 `Months`（月历=「有日期/有安排」），与
                        // `event_available_outlined` 最近；miuix 0.9.4 无「带勾日历」字形。
                        Column(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalAlignment = Alignment.CenterHorizontally,
                        ) {
                            Icon(
                                imageVector = MiuixIcons.Months,
                                contentDescription = null,
                                tint = Color(QingyuTheme.secondaryText(dark)),
                                modifier = Modifier.size(48.dp),
                            )
                            Spacer(modifier = Modifier.height(16.dp))
                            Text(
                                text = ScheduleStrings.scheduleListEmptyTitle.text,
                                style = MiuixTheme.textStyles.headline1,
                                color = Color(QingyuTheme.primaryText(dark)),
                            )
                            Spacer(modifier = Modifier.height(20.dp))
                            ScheduleActionButton(
                                text = ScheduleStrings.addScheduleAction.text,
                                onClick = onAddSchedule,
                                primary = true,
                            )
                        }
                    }
                }
            } else {
                // ── 分组列表：横向留白按配方由每个块自己带 12dp ──
                if (groups.upcoming.isNotEmpty()) {
                    item(key = "header_upcoming") {
                        QingyuSectionTitle(ScheduleStrings.scheduleUpcomingSection.text)
                    }
                    items(groups.upcoming, key = { "upcoming_${it.item.id}" }) { entry ->
                        ScheduleListCard(
                            entry = entry,
                            dimmed = false,
                            dark = dark,
                            modifier = Modifier.padding(horizontal = QingyuPageCardMargin),
                            onEdit = { onEditSchedule(entry.item) },
                            onDelete = { deleteCandidate = entry.item },
                        )
                    }
                }

                if (groups.past.isNotEmpty()) {
                    item(key = "header_past") {
                        QingyuSectionTitle(ScheduleStrings.schedulePastSection.text)
                    }
                    items(groups.past, key = { "past_${it.item.id}" }) { entry ->
                        ScheduleListCard(
                            entry = entry,
                            dimmed = true,
                            dark = dark,
                            modifier = Modifier.padding(horizontal = QingyuPageCardMargin),
                            onEdit = { onEditSchedule(entry.item) },
                            onDelete = { deleteCandidate = entry.item },
                        )
                    }
                }

                if (groups.paused.isNotEmpty()) {
                    item(key = "header_paused") {
                        QingyuSectionTitle(ScheduleStrings.schedulePausedSection.text)
                    }
                    items(groups.paused, key = { "paused_${it.item.id}" }) { entry ->
                        ScheduleListCard(
                            entry = entry,
                            dimmed = true,
                            dark = dark,
                            modifier = Modifier.padding(horizontal = QingyuPageCardMargin),
                            onEdit = { onEditSchedule(entry.item) },
                            onDelete = { deleteCandidate = entry.item },
                        )
                    }
                }
            }
        }
    }

    // 删除确认框：官方 OverlayDialog（遮罩 + 点外部 / 返回键关闭 + 居中）。
    // 原来是一张裸 QingyuCard 直接画在页面里，既不遮罩也不居中，返回键会退掉整页。
    val candidate = deleteCandidate
    OverlayDialog(
        show = candidate != null,
        title = ScheduleStrings.deleteScheduleTitle.text,
        summary = candidate?.let { ScheduleStrings.deleteScheduleMessage.filled("title", it.title) },
        onDismissRequest = { deleteCandidate = null },
        insideMargin = DpSize(16.dp, 16.dp),
    ) {
        if (candidate != null) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                TextButton(
                    modifier = Modifier.weight(1f),
                    text = ScheduleStrings.cancelAction.text,
                    onClick = { deleteCandidate = null },
                )
                ScheduleActionButton(
                    text = ScheduleStrings.deleteAction.text,
                    onClick = {
                        onDeleteSchedule(candidate)
                        deleteCandidate = null
                    },
                    modifier = Modifier.weight(1f),
                    destructive = true,
                )
            }
        }
    }
}

@Composable
private fun ScheduleListCard(
    entry: ScheduleListEntry,
    dimmed: Boolean,
    dark: Boolean,
    modifier: Modifier = Modifier,
    onEdit: () -> Unit,
    onDelete: () -> Unit,
) {
    val item = entry.item
    // Dart：parseHexColorOrFallback(item.color, fallback: HyperosIconColors.blue)。
    val accentColor = parseHexColor(item.color, fallback = Color(QingyuIconColors.BLUE))
    val primaryAlpha = if (dimmed) 0.45f else 1.0f
    val secondaryAlpha = if (dimmed) 0.55f else 0.85f

    QingyuCard(
        modifier = modifier.fillMaxWidth(),
        insideMargin = PaddingValues(horizontal = 14.dp, vertical = 12.dp),
        onClick = onEdit,
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            // 色彩条指示器
            Box(
                modifier = Modifier
                    .width(4.dp)
                    .height(36.dp)
                    .clip(RoundedCornerShape(2.dp))
                    .background(accentColor.copy(alpha = primaryAlpha)),
            )

            // 信息列
            Column(modifier = Modifier.weight(1f)) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    Text(
                        text = item.title.ifEmpty { ScheduleStrings.scheduleBadgeLabel.text },
                        style = MiuixTheme.textStyles.body1.shiftWeight(QingyuWeightDelta.SEMIBOLD),
                        color = Color(QingyuTheme.primaryText(dark)).copy(alpha = primaryAlpha),
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        modifier = Modifier.weight(1f, fill = false),
                    )

                    // 重复徽标
                    val recurrenceBadge = recurrenceBadgeLabel(item)
                    if (recurrenceBadge != null) {
                        Text(
                            text = recurrenceBadge,
                            style = MiuixTheme.textStyles.footnote2.shiftWeight(QingyuWeightDelta.MEDIUM),
                            color = Color(QingyuTheme.primary(dark = dark)).copy(alpha = primaryAlpha),
                            modifier = Modifier
                                .background(
                                    Color(QingyuTheme.primary(dark = dark)).copy(alpha = 0.12f),
                                    RoundedCornerShape(4.dp),
                                )
                                .padding(horizontal = 6.dp, vertical = 2.dp),
                        )
                    }

                    // 进行中徽标
                    if (entry.ongoing) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            modifier = Modifier
                                .background(
                                    Color(QingyuIconColors.GREEN).copy(alpha = 0.14f),
                                    RoundedCornerShape(999.dp),
                                )
                                .padding(horizontal = 8.dp, vertical = 2.dp),
                        ) {
                            Box(
                                modifier = Modifier
                                    .size(6.dp)
                                    .clip(CircleShape)
                                    .background(Color(QingyuIconColors.GREEN)),
                            )
                            Spacer(modifier = Modifier.width(4.dp))
                            Text(
                                text = ScheduleStrings.scheduleOngoingLabel.text,
                                style = MiuixTheme.textStyles.footnote2.shiftWeight(QingyuWeightDelta.SEMIBOLD),
                                color = Color(QingyuIconColors.GREEN),
                            )
                        }
                    }
                }

                Spacer(modifier = Modifier.height(4.dp))

                // 时间与日期描述
                val metaText = formatScheduleMeta(entry)
                Text(
                    text = metaText,
                    style = MiuixTheme.textStyles.footnote1,
                    color = Color(QingyuTheme.secondaryText(dark)).copy(alpha = secondaryAlpha),
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )

                // 地点展示
                item.location?.takeIf { it.isNotBlank() }?.let { loc ->
                    Spacer(modifier = Modifier.height(2.dp))
                    Text(
                        text = loc,
                        style = MiuixTheme.textStyles.footnote1,
                        color = Color(QingyuTheme.secondaryText(dark)).copy(alpha = secondaryAlpha),
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                }

                // 提醒提示
                if (!dimmed && item.reminderMinutesBefore != null) {
                    Spacer(modifier = Modifier.height(2.dp))
                    Text(
                        text = ScheduleStrings.scheduleReminderMinutes
                            .filled("minutes", item.reminderMinutesBefore.toString()),
                        style = MiuixTheme.textStyles.footnote2,
                        color = Color(QingyuTheme.secondaryText(dark)).copy(alpha = secondaryAlpha),
                    )
                }
            }

            // 尾部删除与编辑箭头
            Row(verticalAlignment = Alignment.CenterVertically) {
                ScheduleActionButton(
                    text = ScheduleStrings.deleteAction.text,
                    onClick = onDelete,
                    destructive = true,
                )
                Spacer(modifier = Modifier.width(4.dp))
                Icon(
                    imageVector = MiuixIcons.ChevronForward,
                    contentDescription = null,
                    tint = Color(QingyuTheme.actionIcon(dark)).copy(alpha = primaryAlpha),
                )
            }
        }
    }
}

private fun recurrenceBadgeLabel(item: ScheduleItemData): String? {
    return when (item.recurrence) {
        ScheduleRecurrence.DAILY -> ScheduleStrings.scheduleRepeatDaily.text
        ScheduleRecurrence.WEEKLY -> {
            val day = ScheduleStrings.weekdayLabel(ScheduleDateUtils.dayOfWeek(item.startDate))
            ScheduleStrings.scheduleWeeklyWithDay.filled("day", day)
        }
        ScheduleRecurrence.NONE -> null
    }
}

private fun formatScheduleMeta(entry: ScheduleListEntry): String {
    val item = entry.item

    // 跨天单次日程：发布版 `schedule_list_screen.dart:317-322` 的 `_timeLabel`
    // 会退到 `scheduleTimeRange`，两端各写成「M月d日 + 时刻」（`:396-405`）。
    // Kotlin 这一支原先借用了编辑表单的 `scheduleCrossDaySpanHint`（「从 … 持续到 …」）
    // 且直接拼 ISO 日期，列表行与发布版对不上；这里改回区间模板。
    if (ScheduleDateUtils.isCrossDayRange(item)) {
        return ScheduleStrings.scheduleTimeRange.filled(
            "start" to "${formatMonthDay(item.startDate)} ${item.startTime}",
            "end" to "${formatMonthDay(item.endDate)} ${item.endTime}",
        )
    }

    val date = entry.nextDate ?: item.endDate
    val weekday = ScheduleStrings.weekdayLabel(ScheduleDateUtils.dayOfWeek(date))
    val timeSpan = ScheduleStrings.scheduleTimeRange
        .filled("start" to item.startTime, "end" to item.endTime)
    // 发布版同日口径（`:407-421`）：日期「M月d日」+ 星期，再接「· 时刻区间」。
    return "${formatMonthDay(date)} $weekday · $timeSpan"
}

/**
 * 「M月d日」日期显示（对齐发布版 `schedule_list_screen.dart:400/409` 的 `DateFormat.MMMd`）。
 *
 * 单位词取 ARB 既有键（`datePickerMonth` / `datePickerDay`），与日程表单
 * `AddScheduleItemPage.formatScheduleDateDisplay`（`:1105-1113`）同一口径——
 * 不新造中文字面量（`CjkLiteralGateTest` 对 composeP1 是棘轮门禁）。
 * 解析不出 ISO 日期时原样回显，不吞掉行。
 */
private fun formatMonthDay(iso: String): String {
    val date = ScheduleDateUtils.parseDate(iso) ?: return iso
    // 与发布版 `DateFormat.MMMd(l10n.localeName)` 同口径：受支持的中日韩语言
    // 「M月d日」口径由 ARB 已有的 `datePickerMonth`/`datePickerDay` 拼出
    // （en 的这两个键是单词 Month/Day，不能当后缀用）；英文按默认 Locale 的短月名 + 日。
    // `AppLocaleRuntime.set` 会把 `Locale.setDefault` 一并改成当前 App 语言，
    // 所以读默认 Locale 就是界面语言；未初始化（纯 JVM / 首帧前）按简体中文出字。
    val language = AppLocaleRuntime.language ?: "zh"
    if (language == "en") {
        return date.format(DateTimeFormatter.ofPattern("MMMd", Locale.getDefault()))
    }
    return "${date.monthValue}${TaskStrings.datePickerMonth}" +
        "${date.dayOfMonth}${TaskStrings.datePickerDay}"
}

private fun parseHexColor(hex: String?, fallback: Color): Color {
    if (hex == null) return fallback
    val trimmed = hex.trim().removePrefix("#")
    return try {
        when (trimmed.length) {
            6 -> Color(trimmed.toLong(16) or 0xFF000000)
            8 -> Color(trimmed.toLong(16))
            else -> fallback
        }
    } catch (_: Exception) {
        fallback
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// IDE 预览（2026-11-08，照 about/ContributorsPage.kt 样板铺）
//
// 只给实现阶段看效果，不进业务路径。覆盖两个维度：
//
//   数据状态 3 档：三组都有数据 / 空态 / 跨天日程；
//   外观 3 档：亮色、暗色、大字号 1.3。
//
// 为什么偏偏是这几档：
//   · 暗色 —— 历史上出现过「白字落在白卡片上」（壳用无参 MiuixTheme，页面取色却走
//     isSystemInDarkTheme()）；这一档就是防它复发；
//   · 大字号 —— 行内「11月09日 周一 · 19:00 - 21:00」这类元信息最先折行；
//   · 空态 —— 一张卡片居中，与列表两套布局，最容易只改了一条；
//   · 跨天 —— 同一行要换成「跨天」提示文案，是另一条分支。
//
// 数据由真实的 ScheduleListGrouper 分组（今天固定 2026-11-08），不手写分组结果，
// 否则预览好看而真机仍可能分错组。
//
// 固定写法：主题一律包 QingyuPageTheme(isDark = …)，不要直接 MiuixTheme { }；
// 字号用 QingyuPageTheme(textScale = …)，不用 @Preview(fontScale = …)；
// 宽度按 400dp（本仓折行实测口径），高度给一屏多。
// ─────────────────────────────────────────────────────────────────────────────

/** 预览用的「今天」：固定值，避开跑预览当天的日期漂移。 */
private const val PREVIEW_SCHEDULE_TODAY = "2026-11-08"

/** 预览用假数据：一条日程条目。 */
private fun previewScheduleItem(
    id: String,
    title: String,
    startDate: String,
    startTime: String,
    endTime: String,
    location: String,
    endDate: String = startDate,
    note: String? = null,
    recurrence: ScheduleRecurrence = ScheduleRecurrence.NONE,
    enabled: Boolean = true,
): ScheduleItemData = ScheduleItemData(
    id = id,
    title = title,
    location = location,
    note = note,
    startDate = startDate,
    endDate = endDate,
    startTime = startTime,
    endTime = endTime,
    color = "#5B9CF6",
    recurrence = recurrence,
    reminderMinutesBefore = 15,
    enabled = enabled,
)

/** 三组都有数据：即将到来（含重复日程）/ 已过期 / 已暂停。 */
private fun previewScheduleGroups(): ScheduleListGroups = ScheduleListGrouper.group(
    items = listOf(
        previewScheduleItem(
            id = "schedule_preview_1",
            title = "高等数学辅导",
            startDate = "2026-11-09",
            startTime = "19:00",
            endTime = "21:00",
            location = "示例大学 · 三教 204",
            note = "带习题册，讲第 5 章",
            recurrence = ScheduleRecurrence.WEEKLY,
        ),
        previewScheduleItem(
            id = "schedule_preview_2",
            title = "英语四级报名截止",
            startDate = "2026-11-20",
            startTime = "09:00",
            endTime = "17:00",
            location = "线上 · 教务处",
        ),
        previewScheduleItem(
            id = "schedule_preview_3",
            title = "小组项目答辩",
            startDate = "2026-10-30",
            startTime = "14:00",
            endTime = "16:00",
            location = "示例大学 · 实验楼 501",
        ),
        previewScheduleItem(
            id = "schedule_preview_4",
            title = "晨跑打卡",
            startDate = "2026-11-10",
            startTime = "06:30",
            endTime = "07:10",
            location = "东区操场",
            recurrence = ScheduleRecurrence.DAILY,
            enabled = false,
        ),
    ),
    todayIso = PREVIEW_SCHEDULE_TODAY,
)

/** 单条跨天日程：元信息行走「跨天」文案分支。 */
private fun previewScheduleGroupsCrossDay(): ScheduleListGroups = ScheduleListGrouper.group(
    items = listOf(
        previewScheduleItem(
            id = "schedule_preview_cross_day",
            title = "通宵备考自习室",
            startDate = "2026-11-09",
            endDate = "2026-11-10",
            startTime = "22:00",
            endTime = "01:00",
            location = "示例大学 · 图书馆 24h 自修区",
        ),
    ),
    todayIso = PREVIEW_SCHEDULE_TODAY,
)

/** 一档预览的公共身体：分组数据 + 外观档位。 */
@Composable
private fun PreviewScheduleListPage(
    groups: ScheduleListGroups,
    dark: Boolean = false,
    textScale: Float = 1f,
) {
    QingyuPageTheme(isDark = dark, textScale = textScale) {
        ScheduleListPage(
            groups = groups,
            onBack = {},
            onAddSchedule = {},
            onEditSchedule = {},
            onDeleteSchedule = {},
        )
    }
}

// ── 单档：数据三态 × 亮色 ──────────────────────────────────────────────────

@Suppress("unused")
@Preview(name = "1 三组有数据", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun ScheduleListPagePreviewData() {
    PreviewScheduleListPage(previewScheduleGroups())
}

@Suppress("unused")
@Preview(name = "2 空态", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun ScheduleListPagePreviewEmpty() {
    PreviewScheduleListPage(
        groups = ScheduleListGroups(
            upcoming = emptyList(),
            past = emptyList(),
            paused = emptyList(),
        ),
    )
}

@Suppress("unused")
@Preview(name = "3 跨天日程", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun ScheduleListPagePreviewCrossDay() {
    PreviewScheduleListPage(previewScheduleGroupsCrossDay())
}

// ── 单档：外观两档（以「三组有数据」为基准）─────────────────────────────────

@Suppress("unused")
@Preview(name = "4 暗色", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun ScheduleListPagePreviewDark() {
    PreviewScheduleListPage(previewScheduleGroups(), dark = true)
}

@Suppress("unused")
@Preview(name = "5 大字号 1.3", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun ScheduleListPagePreviewLargeText() {
    PreviewScheduleListPage(previewScheduleGroups(), textScale = 1.3f)
}

// ── 总览：三态并排，一屏看完 ─────────────────────────────────────────────────

/**
 * 一屏总览：三组有数据 / 空态 / 暗色 横向并排，用来一眼比结构差异。
 *
 * 3 × 400dp + 2 × 16dp 间距 = 1232dp，所以画布给 1280dp。Studio 会等比缩小显示，
 * **缩放后字看不清是正常的**——要看细节点上面 1~5 的单档标签。
 */
@Suppress("unused")
@Preview(name = "0 总览·三态并排", showBackground = true, widthDp = 1280, heightDp = 900)
@Composable
private fun ScheduleListPagePreviewOverview() {
    Row(
        modifier = Modifier.fillMaxSize(),
        horizontalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Box(Modifier.width(400.dp).fillMaxHeight()) {
            PreviewScheduleListPage(previewScheduleGroups())
        }
        Box(Modifier.width(400.dp).fillMaxHeight()) {
            PreviewScheduleListPage(
                groups = ScheduleListGroups(
                    upcoming = emptyList(),
                    past = emptyList(),
                    paused = emptyList(),
                ),
            )
        }
        Box(Modifier.width(400.dp).fillMaxHeight()) {
            PreviewScheduleListPage(previewScheduleGroups(), dark = true)
        }
    }
}
