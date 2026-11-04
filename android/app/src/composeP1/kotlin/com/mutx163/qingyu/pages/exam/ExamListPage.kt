package com.mutx163.qingyu.pages.exam

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
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
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.components.QingyuPageScaffold
import com.mutx163.qingyu.components.QingyuSectionTitle
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.shiftWeight
import com.mutx163.qingyu.core.Exam
import com.mutx163.qingyu.theme.QingyuIconColors
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.ButtonDefaults
import top.yukonga.miuix.kmp.basic.HorizontalDivider
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.IconButton
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Add
import top.yukonga.miuix.kmp.icon.extended.Alarm
import top.yukonga.miuix.kmp.icon.extended.ChevronForward
import top.yukonga.miuix.kmp.icon.extended.Delete
import top.yukonga.miuix.kmp.icon.extended.Location
import top.yukonga.miuix.kmp.icon.extended.Months
import top.yukonga.miuix.kmp.icon.extended.Notes
import top.yukonga.miuix.kmp.icon.extended.Timer
import top.yukonga.miuix.kmp.overlay.OverlayDialog
import top.yukonga.miuix.kmp.theme.MiuixTheme

/** 进行中徽标用的橙色（取应用层彩豆 token，对齐 Dart `HyperosIconColors.orange`）。 */
private val kLiveOrange = Color(QingyuIconColors.ORANGE)

/** 无关联课程时的默认课程色（取应用层彩豆 token，对齐 Dart `HyperosIconColors.blue`）。 */
private val kDefaultAccent = Color(QingyuIconColors.BLUE)

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

    // 共享骨架：官方 TopAppBar + 标准返回键 + 顶栏毛玻璃 + actions 槽；大标题可折叠
    // （Dart `exam_list_screen.dart:30-32` 走 HyperosSubpage 默认参数）。
    QingyuPageScaffold(
        title = ExamStrings.examListTitle.zh,
        onBack = onBack,
        actions = {
            IconButton(onClick = onAddExam) {
                Icon(
                    imageVector = MiuixIcons.Add,
                    contentDescription = ExamStrings.addExam.zh,
                    tint = Color(QingyuTheme.actionIcon(dark)),
                )
            }
        },
    ) {
        // 官方页面骨架：末端轻震 + 过度滚动 + 顶栏联动 + 滚动条（QingyuPageList 内置）。
        QingyuPageList(
            innerPadding = innerPadding,
            scrollBehavior = scrollBehavior,
            horizontalPadding = 16.dp,
            contentPadding = PaddingValues(top = 8.dp, bottom = 28.dp),
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
                            QingyuSectionTitle(ExamStrings.examPassed.zh)
                        }
                        item {
                            QingyuCard(
                                modifier = Modifier.fillMaxWidth(),
                                insideMargin = PaddingValues(vertical = 2.dp),
                            ) {
                                viewState.past.forEachIndexed { index, row ->
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

    // 删除确认（Dart 用 showHyperosConfirmDialog，文案逐字一致）
    // 常驻组合（2026-11-04 弹层债收口）：显隐只由 show 驱动，关闭不再整棵摘出组合，
    // 官方退场动画才能播完；正文用 rememberLastNonNull 钉住最后一份快照。
    val deleteTarget = rememberLastNonNull(pendingDelete)
    OverlayDialog(
        insideMargin = DpSize(16.dp, 16.dp),
        show = pendingDelete != null,
        title = ExamStrings.deleteExam.zh,
        summary = ExamStrings.deleteExamConfirm.filled("name", deleteTarget?.name.orEmpty()),
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
                    deleteTarget?.let { onDeleteExam(it) }
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

/**
 * 空态：与 App 其它页（`TaskEmptyState` / `CourseOverviewEmptyState`）统一——
 * 居中 图标(48) + 主标题(headline1) + 主操作按钮，不再套一张大卡片（Flutter v2.1.4.1
 * `exam_list_screen.dart:102-115` 是 `Center(HyperosEmptyState(icon,title,action))`）。
 */
@Composable
private fun ExamEmptyState(dark: Boolean, onAddExam: () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 32.dp, vertical = 48.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Icon(
            imageVector = MiuixIcons.Notes,
            contentDescription = null,
            tint = Color(QingyuTheme.secondaryText(dark)),
            modifier = Modifier.size(48.dp),
        )
        Spacer(modifier = Modifier.height(16.dp))
        Text(
            text = ExamStrings.noExams.zh,
            style = MiuixTheme.textStyles.headline1,
            color = Color(QingyuTheme.primaryText(dark)),
            textAlign = TextAlign.Center,
        )
        Spacer(modifier = Modifier.height(20.dp))
        Button(
            onClick = onAddExam,
            colors = ButtonDefaults.buttonColorsPrimary(),
        ) {
            Text(text = ExamStrings.addExam.zh)
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
                    style = MiuixTheme.textStyles.footnote1.shiftWeight(QingyuWeightDelta.SEMIBOLD),
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
                style = MiuixTheme.textStyles.title3.shiftWeight(QingyuWeightDelta.SEMIBOLD),
                color = primaryText,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )

            Spacer(modifier = Modifier.height(8.dp))
            Text(
                text = overview.bigTimeText,
                style = MiuixTheme.textStyles.title1.shiftWeight(QingyuWeightDelta.LIGHT),
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
                            style = MiuixTheme.textStyles.title4.shiftWeight(QingyuWeightDelta.SEMIBOLD),
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
            // 整行可点：点已有考试进编辑（对齐发布版 `exam_list_screen.dart` 的
            // `HyperosPressableRow(onTap = _navigateToEditExam)`）。原先 onClick 参数没接到
            // Row 上，导致点行体无反应；行尾删除按钮在内部自行消费点击，不受影响。
            .clickable(onClick = onClick)
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
                    style = MiuixTheme.textStyles.body1.shiftWeight(QingyuWeightDelta.MEDIUM),
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
                            style = MiuixTheme.textStyles.footnote2.shiftWeight(QingyuWeightDelta.SEMIBOLD),
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
            style = (if (emphasis) MiuixTheme.textStyles.body2 else MiuixTheme.textStyles.footnote1)
                .shiftWeight(if (emphasis) QingyuWeightDelta.SEMIBOLD else 0),
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
    val parsed = normalized.toIntOrNull(16) ?: return fallback
    // 逐通道取字节：等价于原来的「0xFF000000 或 RGB」掩码，强制不透明。
    return Color(
        red = (parsed shr 16) and 0xFF,
        green = (parsed shr 8) and 0xFF,
        blue = parsed and 0xFF,
    )
}

/**
 * 钉住最后一份非空入参（弹层常驻组合：关闭时宿主置空，退场动画期间仍要原对象渲染）。
 */
@Composable
private fun <T : Any> rememberLastNonNull(current: T?): T? {
    var shown by remember { mutableStateOf(current) }
    if (current != null) shown = current
    return shown
}