package com.mutx163.qingyu.pages.exam

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
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.core.Exam
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.HorizontalDivider
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.IconButton
import top.yukonga.miuix.kmp.basic.MiuixScrollBehavior
import top.yukonga.miuix.kmp.basic.Scaffold
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TopAppBar
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Add
import top.yukonga.miuix.kmp.icon.extended.Alarm
import top.yukonga.miuix.kmp.icon.extended.Back
import top.yukonga.miuix.kmp.icon.extended.ChevronForward
import top.yukonga.miuix.kmp.icon.extended.Delete
import top.yukonga.miuix.kmp.icon.extended.Location
import top.yukonga.miuix.kmp.icon.extended.Months
import top.yukonga.miuix.kmp.icon.extended.Notes
import top.yukonga.miuix.kmp.icon.extended.Timer
import top.yukonga.miuix.kmp.overlay.OverlayDialog
import top.yukonga.miuix.kmp.theme.MiuixTheme

/** 进行中徽标用的琥珀色（对齐 Dart `HyperosIconColors.orange`）。 */
private val kLiveOrange = Color(0xFFF59E0B)

/** 无关联课程时的默认课程色（对齐 Dart `HyperosIconColors.blue`）。 */
private val kDefaultAccent = Color(0xFF2196F3)

/**
 * 考试安排页 · Compose 渲染层（Phase 3）。
 *
 * 对应 Flutter `lib/screens/exam_list_screen.dart`（718 行）：
 * - 顶栏：返回 + 「考试安排」+ 添加考试
 * - 最近一场考试概览卡（状态圆点 / 名称 / 大号时间 / 日期·考场·座位 / 提醒 / 倒计时）
 * - 未结束考试列表（按开始时刻正序）
 * - 已结束段（「已结束」标签 + 倒序、整体压暗的行）
 * - 空态：暂无考试安排 + 添加考试
 *
 * **不做任何业务计算**：排序、文案、倒计时全部来自 [ExamListViewState]（见 [ExamListLogic]）。
 *
 * 与 Dart 的行为差异（已在认领文件与汇报里登记）：原页用 `Dismissible` 侧滑删除，
 * miuix 0.9.4 没有侧滑组件，这里改成行尾删除按钮，确认弹窗与文案保持一致。
 */
@Composable
fun ExamListPage(
    viewState: ExamListViewState,
    onBack: () -> Unit,
    onAddExam: () -> Unit,
    onOpenExam: (Exam) -> Unit,
    onDeleteExam: (Exam) -> Unit,
) {
    val dark = isSystemInDarkTheme()
    var pendingDelete by remember { mutableStateOf<Exam?>(null) }
    // 顶栏折叠行为：Dart `exam_list_screen.dart:30-32` 走 HyperosSubpage 默认参数
    // （`collapsibleLargeTitle` 默认 true，见 `hyperos_page.dart:170`），标题是纯 Text ⇒ 有大标题。
    // 一个页面实例一个：返回重新进入应从展开态开始。
    val scrollBehavior = MiuixScrollBehavior()

    Scaffold(
        containerColor = Color(QingyuTheme.scaffoldBackground(dark)),
        // 顶栏进槽位：官方 TopAppBar 自带系统栏顶部内边距，放进槽位后 Scaffold 不再重复给一份。
        topBar = {
            TopAppBar(
                title = ExamStrings.examListTitle.zh,
                largeTitle = ExamStrings.examListTitle.zh,
                scrollBehavior = scrollBehavior,
                color = Color(QingyuTheme.scaffoldBackground(dark)),
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(
                            imageVector = MiuixIcons.Back,
                            contentDescription = ExamStrings.cancelAction.zh,
                            tint = Color(QingyuTheme.actionIcon(dark)),
                        )
                    }
                },
                actions = {
                    IconButton(onClick = onAddExam) {
                        Icon(
                            imageVector = MiuixIcons.Add,
                            contentDescription = ExamStrings.addExam.zh,
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
            LazyColumn(
                modifier = Modifier
                    .fillMaxSize()
                    .nestedScroll(scrollBehavior.nestedScrollConnection),
                contentPadding = PaddingValues(
                    start = 16.dp,
                    end = 16.dp,
                    top = 8.dp,
                    // 底部把系统手势条那段算进去，否则最后一行钻到小白条底下。
                    bottom = innerPadding.calculateBottomPadding() + 28.dp,
                ),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                if (viewState.isEmpty) {
                    item {
                        ExamEmptyState(dark = dark, onAddExam = onAddExam)
                    }
                } else {
                    val overview = viewState.overview
                    if (overview != null) {
                        item {
                            ExamOverviewCard(
                                overview = overview,
                                dark = dark,
                                onClick = { onOpenExam(overview.exam) },
                            )
                        }
                    }

                    if (viewState.upcoming.isNotEmpty()) {
                        item {
                            QingyuCard(
                                modifier = Modifier.fillMaxWidth(),
                                insideMargin = PaddingValues(vertical = 2.dp),
                            ) {
                                viewState.upcoming.forEachIndexed { index, row ->
                                    if (index > 0) {
                                        HorizontalDivider(
                                            modifier = Modifier.padding(horizontal = 14.dp),
                                            color = Color(QingyuTheme.dividerLine(dark)),
                                        )
                                    }
                                    ExamRow(
                                        row = row,
                                        dark = dark,
                                        onClick = { onOpenExam(row.exam) },
                                        onDelete = { pendingDelete = row.exam },
                                    )
                                }
                            }
                        }
                    }

                    if (viewState.past.isNotEmpty()) {
                        item {
                            Text(
                                text = ExamStrings.examPassed.zh,
                                style = MiuixTheme.textStyles.footnote1,
                                color = Color(QingyuTheme.sectionLabel(dark)),
                                modifier = Modifier.padding(start = 4.dp, top = 6.dp, bottom = 2.dp),
                            )
                        }
                        item {
                            QingyuCard(
                                modifier = Modifier.fillMaxWidth(),
                                insideMargin = PaddingValues(vertical = 2.dp),
                            ) {
                                viewState.past.forEachIndexed { index, row ->
                                    if (index > 0) {
                                        HorizontalDivider(
                                            modifier = Modifier.padding(horizontal = 14.dp),
                                            color = Color(QingyuTheme.dividerLine(dark)),
                                        )
                                    }
                                    ExamRow(
                                        row = row,
                                        dark = dark,
                                        onClick = { onOpenExam(row.exam) },
                                        onDelete = { pendingDelete = row.exam },
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // 删除确认（Dart 用 showHyperosConfirmDialog，文案逐字一致）
    val target = pendingDelete
    if (target != null) {
        OverlayDialog(
            show = true,
            title = ExamStrings.deleteExam.zh,
            summary = ExamStrings.deleteExamConfirm.filled("name", target.name),
            onDismissRequest = { pendingDelete = null },
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                Button(
                    onClick = { pendingDelete = null },
                    modifier = Modifier.weight(1f),
                ) {
                    Text(text = ExamStrings.cancelAction.zh)
                }
                Button(
                    onClick = {
                        pendingDelete = null
                        onDeleteExam(target)
                    },
                    modifier = Modifier.weight(1f),
                    colors = top.yukonga.miuix.kmp.basic.ButtonDefaults.buttonColors(
                        color = Color(QingyuTheme.error(dark)),
                        contentColor = Color(QingyuTheme.onError(dark)),
                    ),
                ) {
                    Text(text = ExamStrings.deleteAction.zh)
                }
            }
        }
    }
}

/** 空态：图标 + 「暂无考试安排」+ 添加按钮。 */
@Composable
private fun ExamEmptyState(dark: Boolean, onAddExam: () -> Unit) {
    QingyuCard(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 48.dp),
        insideMargin = PaddingValues(horizontal = 24.dp, vertical = 32.dp),
    ) {
        Column(
            modifier = Modifier.fillMaxWidth(),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Icon(
                imageVector = MiuixIcons.Notes,
                contentDescription = null,
                tint = Color(QingyuTheme.secondaryText(dark)),
                modifier = Modifier.size(44.dp),
            )
            Text(
                text = ExamStrings.noExams.zh,
                style = MiuixTheme.textStyles.body1,
                color = Color(QingyuTheme.secondaryText(dark)),
                textAlign = TextAlign.Center,
            )
            Button(onClick = onAddExam) {
                Text(text = ExamStrings.addExam.zh)
            }
        }
    }
}

/** 最近一场未结束考试的概览卡。 */
@Composable
private fun ExamOverviewCard(overview: ExamOverviewView, dark: Boolean, onClick: () -> Unit) {
    val primaryText = Color(QingyuTheme.primaryText(dark))
    val secondaryText = Color(QingyuTheme.secondaryText(dark))
    val statusAccent = if (overview.isEmphasized) {
        Color(QingyuTheme.primary(dark = dark))
    } else {
        secondaryText
    }

    QingyuCard(
        modifier = Modifier.fillMaxWidth(),
        insideMargin = PaddingValues(0.dp),
        onClick = onClick,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(start = 18.dp, end = 18.dp, top = 18.dp, bottom = 16.dp),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(
                    modifier = Modifier
                        .size(6.dp)
                        .clip(RoundedCornerShape(3.dp))
                        .background(statusAccent),
                )
                Spacer(modifier = Modifier.width(8.dp))
                Text(
                    text = overview.statusLabel,
                    style = MiuixTheme.textStyles.footnote1,
                    fontWeight = FontWeight.SemiBold,
                    color = statusAccent,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.weight(1f),
                )
                val trailing = overview.trailingCountText
                if (trailing != null) {
                    Text(
                        text = trailing,
                        style = MiuixTheme.textStyles.footnote1,
                        color = secondaryText,
                    )
                }
            }

            Spacer(modifier = Modifier.height(14.dp))
            Text(
                text = overview.name,
                style = MiuixTheme.textStyles.title3,
                fontWeight = FontWeight.SemiBold,
                color = primaryText,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )

            Spacer(modifier = Modifier.height(8.dp))
            Text(
                text = overview.bigTimeText,
                style = MiuixTheme.textStyles.title1,
                fontWeight = FontWeight.Light,
                color = primaryText,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            if (overview.isLive) {
                Spacer(modifier = Modifier.height(4.dp))
                Text(
                    text = overview.timeRangeText,
                    style = MiuixTheme.textStyles.footnote1,
                    color = secondaryText,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }

            val meta = overview.metaText
            if (!meta.isNullOrEmpty()) {
                Spacer(modifier = Modifier.height(12.dp))
                Text(
                    text = meta,
                    style = MiuixTheme.textStyles.footnote1,
                    color = secondaryText,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )
            }

            Spacer(modifier = Modifier.height(14.dp))
            HorizontalDivider(color = Color(QingyuTheme.dividerLine(dark)))
            Spacer(modifier = Modifier.height(12.dp))

            Row(verticalAlignment = Alignment.Top) {
                Icon(
                    imageVector = MiuixIcons.Alarm,
                    contentDescription = null,
                    tint = secondaryText,
                    modifier = Modifier.size(16.dp),
                )
                Spacer(modifier = Modifier.width(8.dp))
                Text(
                    text = overview.reminderText,
                    style = MiuixTheme.textStyles.footnote1,
                    color = secondaryText,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.weight(1f),
                )
                val countdown = overview.countdownDays
                if (countdown != null) {
                    Spacer(modifier = Modifier.width(10.dp))
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(
                            text = countdown.toString(),
                            style = MiuixTheme.textStyles.title4,
                            fontWeight = FontWeight.SemiBold,
                            color = primaryText,
                        )
                        Spacer(modifier = Modifier.width(3.dp))
                        Text(
                            text = ExamStrings.examOverviewCountdownUnit.zh,
                            style = MiuixTheme.textStyles.footnote1,
                            color = secondaryText,
                        )
                    }
                }
            }
        }
    }
}

/** 单条考试行。 */
@Composable
private fun ExamRow(
    row: ExamRowView,
    dark: Boolean,
    onClick: () -> Unit,
    onDelete: () -> Unit,
) {
    val primaryText = Color(QingyuTheme.primaryText(dark))
    val secondaryText = Color(QingyuTheme.secondaryText(dark))
    // 已结束的行整体压暗（Dart: 0.45 / 0.55）
    val mutedPrimary = primaryText.copy(alpha = if (row.isPast) 0.45f else 1f)
    val mutedSecondary = secondaryText.copy(alpha = if (row.isPast) 0.55f else 1f)
    val accent = parseHexColor(row.accentColorHex, fallback = kDefaultAccent)
        .copy(alpha = if (row.isPast) 0.45f else 1f)

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(start = 14.dp, end = 6.dp, top = 12.dp, bottom = 12.dp),
        verticalAlignment = Alignment.Top,
    ) {
        Box(
            modifier = Modifier
                .padding(top = 2.dp)
                .size(36.dp)
                .clip(RoundedCornerShape(12.dp))
                .background(accent.copy(alpha = 0.14f)),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                imageVector = MiuixIcons.Notes,
                contentDescription = null,
                tint = accent,
                modifier = Modifier.size(19.dp),
            )
        }
        Spacer(modifier = Modifier.width(12.dp))

        Column(modifier = Modifier.weight(1f)) {
            Row(verticalAlignment = Alignment.Top) {
                Text(
                    text = row.exam.name,
                    style = MiuixTheme.textStyles.body1,
                    fontWeight = FontWeight.Medium,
                    color = mutedPrimary,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.weight(1f),
                )
                val badge = row.countdownBadge
                if (badge != null) {
                    Spacer(modifier = Modifier.width(8.dp))
                    Box(
                        modifier = Modifier
                            .clip(RoundedCornerShape(6.dp))
                            .background(if (row.isLive) kLiveOrange.copy(alpha = 0.14f) else Color.Transparent)
                            .padding(horizontal = 6.dp, vertical = 2.dp),
                    ) {
                        Text(
                            text = badge,
                            style = MiuixTheme.textStyles.footnote2,
                            fontWeight = FontWeight.SemiBold,
                            color = if (row.isLive) kLiveOrange else mutedSecondary,
                        )
                    }
                }
            }

            val courseName = row.courseName
            if (courseName != null) {
                Text(
                    text = courseName,
                    style = MiuixTheme.textStyles.footnote1,
                    color = mutedSecondary,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.padding(top = 2.dp),
                )
            }

            Spacer(modifier = Modifier.height(8.dp))
            ExamMetaLine(
                icon = MiuixIcons.Months,
                text = row.dateLabel,
                color = mutedSecondary,
                emphasis = false,
            )
            Spacer(modifier = Modifier.height(4.dp))
            ExamMetaLine(
                icon = MiuixIcons.Timer,
                text = row.timeRangeText,
                color = mutedPrimary,
                emphasis = !row.isPast,
            )

            val meta = row.metaText
            if (!meta.isNullOrEmpty()) {
                Spacer(modifier = Modifier.height(4.dp))
                ExamMetaLine(
                    icon = MiuixIcons.Location,
                    text = meta,
                    color = mutedSecondary,
                    emphasis = false,
                )
            }

            val reminder = row.reminderText
            if (!reminder.isNullOrEmpty()) {
                Spacer(modifier = Modifier.height(4.dp))
                ExamMetaLine(
                    icon = MiuixIcons.Alarm,
                    text = reminder,
                    color = mutedSecondary,
                    emphasis = false,
                )
            }
        }

        IconButton(onClick = onDelete, modifier = Modifier.size(36.dp)) {
            Icon(
                imageVector = MiuixIcons.Delete,
                contentDescription = ExamStrings.deleteExam.zh,
                tint = if (row.isPast) mutedSecondary else Color(QingyuTheme.actionIcon(dark)),
                modifier = Modifier.size(17.dp),
            )
        }
        Icon(
            imageVector = MiuixIcons.ChevronForward,
            contentDescription = null,
            tint = mutedSecondary.copy(alpha = if (row.isPast) 0.45f else 0.6f),
            modifier = Modifier
                .padding(top = 10.dp)
                .size(16.dp),
        )
    }
}

/** 小图标 + 一行元信息（Dart `_ExamMetaLine`）。 */
@Composable
private fun ExamMetaLine(
    icon: ImageVector,
    text: String,
    color: Color,
    emphasis: Boolean,
) {
    Row(verticalAlignment = Alignment.Top) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = color.copy(alpha = 0.85f),
            modifier = Modifier
                .padding(top = 1.dp)
                .size(14.dp),
        )
        Spacer(modifier = Modifier.width(6.dp))
        Text(
            text = text,
            style = if (emphasis) MiuixTheme.textStyles.body2 else MiuixTheme.textStyles.footnote1,
            fontWeight = if (emphasis) FontWeight.SemiBold else FontWeight.Normal,
            color = color,
            maxLines = 2,
            overflow = TextOverflow.Ellipsis,
        )
    }
}

/** `lib/utils/hex_color.dart:parseHexColorOrFallback` 的 Compose 侧等价实现。 */
private fun parseHexColor(hex: String?, fallback: Color = kDefaultAccent): Color {
    val value = hex?.trim()?.removePrefix("#") ?: return fallback
    val normalized = when (value.length) {
        6 -> value
        8 -> value.substring(2) // AARRGGBB → RRGGBB
        3 -> value.map { "$it$it" }.joinToString("")
        else -> return fallback
    }
    val parsed = normalized.toLongOrNull(16) ?: return fallback
    return Color(0xFF000000L or parsed)
}
