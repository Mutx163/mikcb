package com.mutx163.qingyu.pages.schedule

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
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuPageCardMargin
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.components.QingyuSectionTitle
import com.mutx163.qingyu.theme.QingyuIconColors
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.IconButton
import top.yukonga.miuix.kmp.basic.Scaffold
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Back
import top.yukonga.miuix.kmp.icon.extended.ChevronForward
import top.yukonga.miuix.kmp.theme.MiuixTheme
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
                            QingyuCard(
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
                                        style = MiuixTheme.textStyles.body1,
                                        color = Color(QingyuTheme.secondaryText(dark)),
                                    )
                                    MiuixActionButton(
                                        text = ScheduleStrings.addScheduleAction.zh,
                                        onClick = onAddSchedule,
                                    )
                                }
                            }
                        }
                    }
                } else {
                    // ── 分组列表：横向留白按配方由每个块自己带 12dp ──
                    if (groups.upcoming.isNotEmpty()) {
                        item(key = "header_upcoming") {
                            QingyuSectionTitle(ScheduleStrings.scheduleUpcomingSection.zh)
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
                            QingyuSectionTitle(ScheduleStrings.schedulePastSection.zh)
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
                            QingyuSectionTitle(ScheduleStrings.schedulePausedSection.zh)
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
                        text = item.title.ifEmpty { ScheduleStrings.scheduleBadgeLabel.zh },
                        style = MiuixTheme.textStyles.body1,
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
                            style = MiuixTheme.textStyles.footnote2,
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
                                text = ScheduleStrings.scheduleOngoingLabel.zh,
                                style = MiuixTheme.textStyles.footnote2,
                                fontWeight = FontWeight.SemiBold,
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
    QingyuCard(
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
                style = MiuixTheme.textStyles.title4,
                fontWeight = FontWeight.Bold,
                color = Color(QingyuTheme.primaryText(dark)),
            )
            Text(
                text = message,
                style = MiuixTheme.textStyles.body2,
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
            style = MiuixTheme.textStyles.body1,
            fontWeight = FontWeight.Medium,
            color = MiuixTheme.colorScheme.onPrimary,
        )
    }
}
