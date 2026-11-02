package com.mutx163.qingyu.pages.timetable.day

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
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.state.ToggleableState
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuCardDefaults
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.shiftWeight
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.CourseTask
import com.mutx163.qingyu.pages.settings.HomeMaterialRenderSpec
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.CardDefaults
import top.yukonga.miuix.kmp.basic.Checkbox
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.blur.Backdrop
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.ChevronForward
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 日视图待办折叠带 · Compose 渲染层。
 *
 * 对应 Flutter `lib/widgets/timetable/day_view/day_view_task_band.dart`：
 * - 独立全天待办带（作业只有日期无时刻，不塞进时间线）；
 * - 中性卡片承载面（作业独立于课程底色，采用系统卡片质感）；
 * - 三档折叠展示：
 *   1. 已逾期列表（红高亮，超过 3 项自动折叠，展示「还有 N 项逾期」入口）；
 *   2. 今日到期列表；
 *   3. 今日已完成列表（删除线、次级文字颜色，留在原地便于撤回）；
 * - 交互热区分离：左侧复选框勾选切换完成态，整行点击进入作业编辑页。
 */
@Composable
fun DayViewTaskBandCard(
    data: DayTaskBandData,
    // 能力型：null ⇒ 对应交互不渲染
    onToggleTask: ((CourseTask) -> Unit)? = null,
    onEditTask: ((CourseTask) -> Unit)? = null,
    onViewAllOverdue: (() -> Unit)? = null,
    courseResolver: (CourseTask) -> Course? = { null },
    /** 材质快照（`SettingsMaterialModel.renderSpecOf`）。null = 老行为（主题实底卡）。 */
    material: HomeMaterialRenderSpec? = null,
    /** 液态档的整页共享背景采样源（见 [dayAgendaSurface]）。 */
    glassBackdrop: Backdrop? = null,
    modifier: Modifier = Modifier,
) {
    if (data.isEmpty) {
        return
    }

    val dark = isSystemInDarkTheme()
    val primaryTextColor = Color(QingyuTheme.primaryText(dark))
    val secondaryTextColor = Color(QingyuTheme.secondaryText(dark))
    val actionIconColor = Color(QingyuTheme.actionIcon(dark))
    val destructiveColor = Color(QingyuTheme.destructive())

    // 待办带与摘要卡 / 议程卡同材质（Dart `day_view_task_band.dart:43`：材质与其余内容卡同源）。
    val shape = RoundedCornerShape(QingyuCardDefaults.Corner)
    val glass = dayAgendaGlassBackdrop(material, glassBackdrop)
    val fillAlpha = dayAgendaSurfaceAlpha(material, 1f).coerceIn(0.08f, 1f)
    val translucent = glass != null || fillAlpha < 1f

    QingyuCard(
        modifier = modifier
            .fillMaxWidth()
            .then(
                if (translucent) {
                    Modifier.dayAgendaSurface(
                        glassBackdrop = glass,
                        shape = shape,
                        fill = MiuixTheme.colorScheme.surface.copy(alpha = fillAlpha),
                    )
                } else {
                    Modifier
                },
            ),
        colors = if (translucent) {
            CardDefaults.defaultColors(color = Color.Transparent)
        } else {
            CardDefaults.defaultColors()
        },
        insideMargin = PaddingValues(horizontal = 14.dp, vertical = 12.dp),
    ) {
        Column(modifier = Modifier.fillMaxWidth()) {
            var hasPrecedingSection = false

            // 1. 已逾期小节
            if (data.overdue.isNotEmpty()) {
                Text(
                    text = DayViewStrings.taskOverdueSection.zh,
                    style = MiuixTheme.textStyles.footnote2.shiftWeight(QingyuWeightDelta.SEMIBOLD),
                    color = destructiveColor,
                )
                Spacer(modifier = Modifier.height(4.dp))

                for (row in data.overdue) {
                    val course = courseResolver(row.task)
                    TaskBandItemRow(
                        row = row,
                        course = course,
                        isOverdue = true,
                        primaryColor = destructiveColor,
                        secondaryColor = secondaryTextColor,
                        actionColor = actionIconColor,
                        onToggle = taskRowAction(onToggleTask, row.task),
                        onEdit = taskRowAction(onEditTask, row.task),
                    )
                }

                // 逾期超过上限时的折叠入口
                if (data.hiddenOverdueCount > 0) {
                    Spacer(modifier = Modifier.height(2.dp))
                    Row(
                        modifier = Modifier
                            .clip(RoundedCornerShape(6.dp))
                            .then(if (onViewAllOverdue != null) Modifier.clickable(onClick = onViewAllOverdue) else Modifier)
                            .padding(horizontal = 4.dp, vertical = 4.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text(
                            text = DayViewStrings.dayTaskBandOverdueMore(data.hiddenOverdueCount),
                            style = MiuixTheme.textStyles.footnote1.shiftWeight(QingyuWeightDelta.MEDIUM),
                            color = secondaryTextColor,
                        )
                        Spacer(modifier = Modifier.width(2.dp))
                        Icon(
                            imageVector = MiuixIcons.ChevronForward,
                            contentDescription = null,
                            modifier = Modifier.size(14.dp),
                            tint = secondaryTextColor,
                        )
                    }
                }

                hasPrecedingSection = true
            }

            // 2. 今日到期小节
            if (data.today.isNotEmpty()) {
                if (hasPrecedingSection) {
                    Spacer(modifier = Modifier.height(10.dp))
                }

                for (row in data.today) {
                    val course = courseResolver(row.task)
                    TaskBandItemRow(
                        row = row,
                        course = course,
                        isOverdue = false,
                        primaryColor = primaryTextColor,
                        secondaryColor = secondaryTextColor,
                        actionColor = actionIconColor,
                        onToggle = taskRowAction(onToggleTask, row.task),
                        onEdit = taskRowAction(onEditTask, row.task),
                    )
                }

                hasPrecedingSection = true
            }

            // 3. 今日已完成小节
            if (data.completed.isNotEmpty()) {
                if (hasPrecedingSection) {
                    Spacer(modifier = Modifier.height(10.dp))
                }

                Text(
                    text = DayViewStrings.taskCompletedSection.zh,
                    style = MiuixTheme.textStyles.footnote2.shiftWeight(QingyuWeightDelta.SEMIBOLD),
                    color = secondaryTextColor,
                )
                Spacer(modifier = Modifier.height(4.dp))

                for (row in data.completed) {
                    val course = courseResolver(row.task)
                    TaskBandItemRow(
                        row = row,
                        course = course,
                        isOverdue = false,
                        primaryColor = secondaryTextColor,
                        secondaryColor = secondaryTextColor.copy(alpha = 0.7f),
                        actionColor = actionIconColor.copy(alpha = 0.5f),
                        onToggle = taskRowAction(onToggleTask, row.task),
                        onEdit = taskRowAction(onEditTask, row.task),
                    )
                }
            }
        }
    }
}

/**
 * 待办带的一行条目：复选框 + 任务标题 + 关联课程与逾期天数 + 尾部编辑箭头。
 */
@Composable
private fun TaskBandItemRow(
    row: DayTaskBandRow,
    course: Course?,
    isOverdue: Boolean,
    primaryColor: Color,
    secondaryColor: Color,
    actionColor: Color,
    // 能力型：null ⇒ 该交互不渲染（不画点了没反应的复选框 / 箭头）
    onToggle: (() -> Unit)?,
    onEdit: (() -> Unit)?,
    modifier: Modifier = Modifier,
) {
    val isCompleted = row.kind == DayTaskBandKind.COMPLETED
    val title = DayTaskBandLogic.resolveDisplayTitle(row.task)
    val textDecoration = if (isCompleted) TextDecoration.LineThrough else null

    Row(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(8.dp))
            .then(if (onEdit != null) Modifier.clickable(onClick = onEdit) else Modifier)
            .padding(vertical = 5.dp, horizontal = 2.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        // 复选框：没有落点就不画（画出来只会变成点了不动的假控件）
        if (onToggle != null) {
            Checkbox(
                state = if (isCompleted) ToggleableState.On else ToggleableState.Off,
                onClick = onToggle,
            )
        }

        // 标题与来源课程描述
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = title,
                style = MiuixTheme.textStyles.body2.shiftWeight(
                    if (isCompleted) 0 else QingyuWeightDelta.SEMIBOLD,
                ),
                color = primaryColor,
                textDecoration = textDecoration,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )

            val courseName = course?.name.orEmpty().trim()
            if (courseName.isNotEmpty() || isOverdue) {
                Spacer(modifier = Modifier.height(3.dp))
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    if (courseName.isNotEmpty()) {
                        // 课程色是数据色；缺省时退回主题 primary（不写死字面量，R5）。
                        val dotColor = parseHexColorOrFallback(course?.color, fallback = MiuixTheme.colorScheme.primary)
                        DayCourseDot(color = dotColor)
                        Text(
                            text = courseName,
                            style = MiuixTheme.textStyles.footnote1,
                            color = secondaryColor,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                            modifier = Modifier.weight(1f, fill = false),
                        )
                    }

                    if (isOverdue && row.overdueDays > 0) {
                        Text(
                            text = DayViewStrings.dayTaskBandOverdueBadge(row.overdueDays),
                            style = MiuixTheme.textStyles.footnote2.shiftWeight(QingyuWeightDelta.SEMIBOLD),
                            color = Color(QingyuTheme.destructive()),
                        )
                    }
                }
            }
        }

        // 尾部箭头指示器：只在「点得动」时才画
        if (onEdit != null) {
            Icon(
                imageVector = MiuixIcons.ChevronForward,
                contentDescription = null,
                modifier = Modifier.size(16.dp),
                tint = actionColor,
            )
        }
    }
}

/**
 * 把「(CourseTask) -> Unit 的可空能力」绑到某一行任务上。
 *
 * 返回 null 表示这项交互没接线 ⇒ 调用方不渲染对应控件（不画点了没反应的勾选框/箭头）。
 * 单独抽成函数是为了让 `?.let { }` 的类型推断有明确目标，避免 `() -> Unit?` 歧义。
 */
private fun taskRowAction(
    action: ((com.mutx163.qingyu.core.CourseTask) -> Unit)?,
    task: com.mutx163.qingyu.core.CourseTask,
): (() -> Unit)? = action?.let { invoke -> { invoke(task) } }
