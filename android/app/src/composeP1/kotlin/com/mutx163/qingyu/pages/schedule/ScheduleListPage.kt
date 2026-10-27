package com.mutx163.qingyu.pages.schedule

import androidx.compose.foundation.background
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
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
import androidx.compose.foundation.lazy.LazyColumn
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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.Card
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.IconButton
import top.yukonga.miuix.kmp.basic.Scaffold
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Back
import top.yukonga.miuix.kmp.icon.extended.ChevronForward
import top.yukonga.miuix.kmp.theme.MiuixTheme
import androidx.compose.ui.input.nestedscroll.nestedScroll
import com.mutx163.qingyu.components.QingyuPageTheme
import top.yukonga.miuix.kmp.basic.MiuixScrollBehavior
import top.yukonga.miuix.kmp.basic.TopAppBar
import top.yukonga.miuix.kmp.icon.extended.Add

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
    val colors = MiuixTheme.colorScheme
    var deleteCandidate by remember { mutableStateOf<ScheduleItemData?>(null) }

    // 顶栏折叠行为：Dart 侧 schedule_list_screen.dart:38 走 HyperosSubpage，
    // overlayHeader / collapsibleLargeTitle 均为默认 true（可折叠大标题）。
    val scrollBehavior = MiuixScrollBehavior()

    QingyuPageTheme {
        Scaffold(
            containerColor = Color(QingyuTheme.scaffoldBackground(dark)),
            // 顶栏进槽位：官方 TopAppBar 自带系统栏顶部内边距，放进槽位后
            // Scaffold 不再重复给一份（第一版手搓 Row 时状态栏被算了两遍）。
            topBar = {
                TopAppBar(
                    title = ScheduleStrings.scheduleListTitle.zh,
                    largeTitle = ScheduleStrings.scheduleListTitle.zh,
                    scrollBehavior = scrollBehavior,
                    navigationIcon = {
                        IconButton(onClick = onBack) {
                            Icon(
                                imageVector = MiuixIcons.Back,
                                contentDescription = ScheduleStrings.cancelAction.zh,
                                tint = Color(QingyuTheme.actionIcon(dark)),
                            )
                        }
                    },
                    // Dart 侧顶栏右侧是 FHeaderAction(Icons.add_rounded) 图标按钮，
                    // 第一版用了文字按钮「添加」，与现版本形态不一致。
                    actions = {
                        IconButton(onClick = onAddSchedule) {
                            Icon(
                                imageVector = MiuixIcons.Add,
                                contentDescription = ScheduleStrings.addScheduleAction.zh,
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
                    .padding(innerPadding),
            ) {
                if (groups.isEmpty) {
                    // ── 空态展示 ──
                    Box(
                        modifier = Modifier
                            .fillMaxSize()
                            .padding(24.dp),
                        contentAlignment = Alignment.Center,
                    ) {
                        Card(
                            modifier = Modifier.fillMaxWidth(),
                            insideMargin = PaddingValues(24.dp),
                        ) {
                            Column(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalAlignment = Alignment.CenterHorizontally,
                                verticalArrangement = Arrangement.spacedBy(16.dp),
                            ) {
                                Text(
                                    text = ScheduleStrings.scheduleListEmptyTitle.zh,
                                    fontSize = 16.sp,
                                    color = Color(QingyuTheme.secondaryText(dark)),
                                )
                                MiuixActionButton(
                                    text = ScheduleStrings.addScheduleAction.zh,
                                    onClick = onAddSchedule,
                                )
                            }
                        }
                    }
            } else {
                // ── 分组列表 ──
                LazyColumn(
                    modifier = Modifier.fillMaxSize().nestedScroll(scrollBehavior.nestedScrollConnection),
                    contentPadding = PaddingValues(
                        start = 16.dp,
                        end = 16.dp,
                        top = 8.dp,
                        // 底部把系统手势条那段算进去，否则最后一行钻到小白条底下。
                        bottom = innerPadding.calculateBottomPadding() + 24.dp,
                    ),
                    verticalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    if (groups.upcoming.isNotEmpty()) {
                        item(key = "header_upcoming") {
                            ScheduleSectionHeader(ScheduleStrings.scheduleUpcomingSection.zh, dark)
                        }
                        items(groups.upcoming, key = { "upcoming_${it.item.id}" }) { entry ->
                            ScheduleListCard(
                                entry = entry,
                                dimmed = false,
                                dark = dark,
                                onEdit = { onEditSchedule(entry.item) },
                                onDelete = { deleteCandidate = entry.item },
                            )
                        }
                    }

                    if (groups.past.isNotEmpty()) {
                        item(key = "header_past") {
                            ScheduleSectionHeader(ScheduleStrings.schedulePastSection.zh, dark)
                        }
                        items(groups.past, key = { "past_${it.item.id}" }) { entry ->
                            ScheduleListCard(
                                entry = entry,
                                dimmed = true,
                                dark = dark,
                                onEdit = { onEditSchedule(entry.item) },
                                onDelete = { deleteCandidate = entry.item },
                            )
                        }
                    }

                    if (groups.paused.isNotEmpty()) {
                        item(key = "header_paused") {
                            ScheduleSectionHeader(ScheduleStrings.schedulePausedSection.zh, dark)
                        }
                        items(groups.paused, key = { "paused_${it.item.id}" }) { entry ->
                            ScheduleListCard(
                                entry = entry,
                                dimmed = true,
                                dark = dark,
                                onEdit = { onEditSchedule(entry.item) },
                                onDelete = { deleteCandidate = entry.item },
                            )
                        }
                    }
                }
                }
            }
        }
    }

    // 删除确认弹框
    deleteCandidate?.let { candidate ->
        ConfirmDeleteDialog(
            title = ScheduleStrings.deleteScheduleTitle.zh,
            message = ScheduleStrings.deleteScheduleMessage.filled("title", candidate.title),
            onDismiss = { deleteCandidate = null },
            onConfirm = {
                onDeleteSchedule(candidate)
                deleteCandidate = null
            },
        )
    }
}

@Composable
private fun ScheduleSectionHeader(title: String, dark: Boolean) {
    Text(
        text = title,
        fontSize = 13.sp,
        fontWeight = FontWeight.Medium,
        color = Color(QingyuTheme.sectionLabel(dark)),
        modifier = Modifier.padding(start = 4.dp, top = 8.dp, bottom = 2.dp),
    )
}

@Composable
private fun ScheduleListCard(
    entry: ScheduleListEntry,
    dimmed: Boolean,
    dark: Boolean,
    onEdit: () -> Unit,
    onDelete: () -> Unit,
) {
    val item = entry.item
    val accentColor = parseHexColor(item.color, fallback = Color(0xFF5B9CF6))
    val primaryAlpha = if (dimmed) 0.45f else 1.0f
    val secondaryAlpha = if (dimmed) 0.55f else 0.85f

    Card(
        modifier = Modifier.fillMaxWidth(),
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
                        text = item.title.ifEmpty { ScheduleStrings.scheduleBadgeLabel.zh },
                        fontSize = 16.sp,
                        fontWeight = FontWeight.SemiBold,
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
                            fontSize = 11.sp,
                            fontWeight = FontWeight.Medium,
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
                                    Color(0xFF22C55E).copy(alpha = 0.14f),
                                    RoundedCornerShape(999.dp),
                                )
                                .padding(horizontal = 8.dp, vertical = 2.dp),
                        ) {
                            Box(
                                modifier = Modifier
                                    .size(6.dp)
                                    .clip(CircleShape)
                                    .background(Color(0xFF22C55E)),
                            )
                            Spacer(modifier = Modifier.width(4.dp))
                            Text(
                                text = ScheduleStrings.scheduleOngoingLabel.zh,
                                fontSize = 11.sp,
                                fontWeight = FontWeight.SemiBold,
                                color = Color(0xFF22C55E),
                            )
                        }
                    }
                }

                Spacer(modifier = Modifier.height(4.dp))

                // 时间与日期描述
                val metaText = formatScheduleMeta(entry)
                Text(
                    text = metaText,
                    fontSize = 12.sp,
                    color = Color(QingyuTheme.secondaryText(dark)).copy(alpha = secondaryAlpha),
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )

                // 地点展示
                item.location?.takeIf { it.isNotBlank() }?.let { loc ->
                    Spacer(modifier = Modifier.height(2.dp))
                    Text(
                        text = loc,
                        fontSize = 12.sp,
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
                        fontSize = 11.sp,
                        color = Color(QingyuTheme.secondaryText(dark)).copy(alpha = secondaryAlpha),
                    )
                }
            }

            // 尾部删除与编辑箭头
            Row(verticalAlignment = Alignment.CenterVertically) {
                MiuixActionButton(
                    text = ScheduleStrings.deleteAction.zh,
                    onClick = onDelete,
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

@Composable
private fun ConfirmDeleteDialog(
    title: String,
    message: String,
    onDismiss: () -> Unit,
    onConfirm: () -> Unit,
) {
    val dark = isSystemInDarkTheme()
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .padding(24.dp),
        insideMargin = PaddingValues(16.dp),
    ) {
        Column(
            modifier = Modifier.fillMaxWidth(),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text(
                text = title,
                fontSize = 18.sp,
                fontWeight = FontWeight.Bold,
                color = Color(QingyuTheme.primaryText(dark)),
            )
            Text(
                text = message,
                fontSize = 14.sp,
                color = Color(QingyuTheme.secondaryText(dark)),
            )
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.End,
            ) {
                MiuixActionButton(
                    text = ScheduleStrings.cancelAction.zh,
                    onClick = onDismiss,
                )
                Spacer(modifier = Modifier.width(8.dp))
                MiuixActionButton(
                    text = ScheduleStrings.deleteAction.zh,
                    onClick = onConfirm,
                )
            }
        }
    }
}

private fun recurrenceBadgeLabel(item: ScheduleItemData): String? {
    return when (item.recurrence) {
        ScheduleRecurrence.DAILY -> ScheduleStrings.scheduleRepeatDaily.zh
        ScheduleRecurrence.WEEKLY -> {
            val day = ScheduleStrings.weekdayLabel(ScheduleDateUtils.dayOfWeek(item.startDate))
            ScheduleStrings.scheduleWeeklyWithDay.filled("day", day)
        }
        ScheduleRecurrence.NONE -> null
    }
}

private fun formatScheduleMeta(entry: ScheduleListEntry): String {
    val item = entry.item
    val timeSpan = ScheduleStrings.scheduleTimeRange
        .filled("start" to item.startTime, "end" to item.endTime)

    if (ScheduleDateUtils.isCrossDayRange(item)) {
        return ScheduleStrings.scheduleCrossDaySpanHint
            .filled("start" to "${item.startDate} ${item.startTime}", "end" to "${item.endDate} ${item.endTime}")
    }

    val date = entry.nextDate ?: item.endDate
    val weekday = ScheduleStrings.weekdayLabel(ScheduleDateUtils.dayOfWeek(date))
    return "$date $weekday · $timeSpan"
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


/**
 * miuix 0.9.4 对齐补丁：0.9.4 的 `Button` 只有 `content: @Composable RowScope.() -> Unit`，
 * 不再有 `text` 参数（0.8.8 才有）。这里包一层，保持既有调用点的 `text = …` 形状，
 * 避免把每处按钮正文都重写一遍。
 */
@Composable
private fun MiuixActionButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
) {
    Button(onClick = onClick, modifier = modifier, enabled = enabled) {
        Text(
            text = text,
            fontSize = 16.sp,
            fontWeight = FontWeight.Medium,
            color = MiuixTheme.colorScheme.onPrimary,
        )
    }
}
