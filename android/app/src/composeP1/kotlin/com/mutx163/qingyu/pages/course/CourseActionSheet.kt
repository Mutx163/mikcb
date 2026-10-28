package com.mutx163.qingyu.pages.course

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.app.CourseAction
import com.mutx163.qingyu.app.CourseActionDispatcher
import com.mutx163.qingyu.app.CourseActionStrings
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.ButtonDefaults
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TextButton
import top.yukonga.miuix.kmp.overlay.OverlayBottomSheet
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 课程操作弹层（Phase 3.5 · 主派工大表 T1）。
 *
 * 对应 Dart `lib/widgets/course_action_sheet.dart` 的 `CourseActionSheetBody`：
 * 上方是这节课的信息（时间 / 教师 / 地点），中间是说明句，下方是动作区。
 *
 * ## 容器为什么是 `OverlayBottomSheet`
 *
 * Dart 用 `showHyperosFrostedSheet`（**底部弹层**，磨砂材质）。miuix 0.9.4 的官方对位件是
 * `overlay.OverlayBottomSheet`（`OverlayDialog` 是对话框语义，不是底栏）——按 Dart 口径取前者。
 *
 * ## 本层只做两件事
 *
 * 1. 把 `Course` 摆上屏（**不**做任何业务判断）；
 * 2. 把点击转成 [CourseAction] 交给宿主。
 *
 * 「点了之后写不写得进去、带哪门课去编辑页」全在
 * [CourseActionDispatcher]（纯 Kotlin，JVM 可测）。
 *
 * ## 调课为什么在这一个文件里做「两步」
 *
 * Dart 点「调课」会再弹一个选择弹层（`showTimetableCourseRescheduleSheet`，
 * `timetable_course_sheet_actions.dart:99` 起）让用户选目标周 / 星期 / 节次。
 * 本批没有第二个弹层，所以**在同一次弹层里换一步**：点「调课」→ 面板切到目标选择
 * →「确定」把目标交给 [onReschedule]（宿主据此调 `CourseActionDispatcher.rescheduleOccurrence`）。
 * 这样这个按钮**点得动、且真的能改课**，而不是一个点了没反应的入口。
 *
 * ## 与 Dart 的**已知差异**（诚实清单）
 *
 * - Dart 弹层里还有「冲突课 / 情侣课」预览与切换（`course_action_sheet.dart:210-500`）——
 *   那需要冲突计算与情侣课数据，本批不做，只显示当前这一门；
 * - Dart 的「备注」行、天气行、关联作业行各自进子弹层，本批只保留动作区（点课程卡片
 *   的主要诉求是操作，备注/天气属各自批次）；
 * - 调课面板**不改地点**（Dart 的调课弹层可以）：本批保留原地点，只挪周次/星期/节次；
 * - **单节课提醒**行只在 [CourseActionDispatcher.isClassAlarmAvailable] 为真时显示；
 *   本批它恒为 false（Compose 侧没有 class-alarm 调度器），所以这一行**不出现**，
 *   而不是出现一个点了没反应的入口。
 *
 * @param course 要操作的课程；`null` 表示关闭弹层。
 * @param week 当前浏览周次（occurrence 级操作与说明句都要）。
 * @param onDismiss 关闭（点空白 / 返回键 / 动作执行后）。
 * @param onAction 动作回调；宿主据此导航或调 [CourseActionDispatcher]。
 * @param onReschedule 调课面板「确定」的回调：目标周 / 星期 / 起止节次。
 */
@Composable
fun CourseActionSheet(
    course: Course?,
    week: Int,
    onDismiss: () -> Unit,
    onAction: (CourseAction) -> Unit,
    onReschedule: (targetWeek: Int, dayOfWeek: Int, startSection: Int, endSection: Int) -> Unit = { _, _, _, _ -> },
) {
    val dark = androidx.compose.foundation.isSystemInDarkTheme()
    val colors = MiuixTheme.colorScheme
    val primaryText = Color(QingyuTheme.primaryText(dark))
    val secondaryText = Color(QingyuTheme.secondaryText(dark))
    var pickingReschedule by remember(course?.id) { mutableStateOf(false) }

    OverlayBottomSheet(
        show = course != null,
        title = course?.name,
        onDismissRequest = onDismiss,
    ) {
        if (course == null) return@OverlayBottomSheet
        Column(modifier = Modifier.fillMaxWidth().padding(horizontal = 4.dp)) {
            if (pickingReschedule) {
                ReschedulePicker(
                    course = course,
                    sourceWeek = week,
                    primaryText = primaryText,
                    secondaryText = secondaryText,
                    onCancel = { pickingReschedule = false },
                    onConfirm = { targetWeek, day, start, end ->
                        pickingReschedule = false
                        onReschedule(targetWeek, day, start, end)
                    },
                )
                return@Column
            }

            // ── 这节课的信息 ──
            InfoRow(
                label = "${course.startTime}-${course.endTime}",
                detail = CourseActionStrings.sectionRange(course.startSection, course.endSection),
                primaryText = primaryText,
                secondaryText = secondaryText,
            )
            InfoRow(
                label = CourseActionStrings.teacherOrUnknown(course.teacher),
                detail = null,
                primaryText = primaryText,
                secondaryText = secondaryText,
            )
            InfoRow(
                label = CourseActionStrings.locationOrUnknown(course.location),
                detail = null,
                primaryText = primaryText,
                secondaryText = secondaryText,
            )

            Spacer(modifier = Modifier.height(12.dp))
            Text(
                text = CourseActionStrings.notice(week),
                // 说明句用官方字阶（13sp footnote1）：写死 12sp 会绕过主题，
                // 用户字重 / 系统粗体 / 字阶调整全部失效（R4）。
                style = MiuixTheme.textStyles.footnote1,
                color = secondaryText,
            )
            Spacer(modifier = Modifier.height(14.dp))

            // ── 动作区 ──
            // 编辑：主按钮（Dart `course_action_sheet.dart:876-879`）
            Button(
                onClick = { onAction(CourseAction.EDIT) },
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text(text = CourseActionStrings.courseActionEditPrimary.zh)
            }
            Spacer(modifier = Modifier.height(10.dp))

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                // 调课（Dart `:887-891`）：进同弹层的目标选择步；那周没课则置灰
                TextButton(
                    modifier = Modifier.weight(1f),
                    text = CourseActionStrings.courseActionRescheduleSecondary.zh,
                    enabled = CourseActionDispatcher.canReschedule(course, week),
                    onClick = { pickingReschedule = true },
                )
                // 停课 / 恢复（Dart `:898-900`：已停课显示「恢复」）
                TextButton(
                    modifier = Modifier.weight(1f),
                    text = CourseActionStrings.suspendButtonLabel(course.isSuspendedInWeek(week)),
                    onClick = { onAction(CourseAction.SUSPEND) },
                )
                // 删除（Dart `:909`，destructive 变体）
                TextButton(
                    modifier = Modifier.weight(1f),
                    text = CourseActionStrings.courseActionDeleteSecondary.zh,
                    colors = ButtonDefaults.textButtonColors(
                        color = Color(QingyuTheme.error(dark)),
                    ),
                    onClick = { onAction(CourseAction.DELETE) },
                )
            }

            Spacer(modifier = Modifier.height(6.dp))

            // 加作业（Dart `:833-839`）；单节课提醒按可用性显示（本批恒不可用）
            TextButton(
                modifier = Modifier.fillMaxWidth(),
                text = CourseActionStrings.courseTaskAction.zh,
                onClick = { onAction(CourseAction.ADD_TASK) },
            )
            if (CourseActionDispatcher.isClassAlarmAvailable()) {
                TextButton(
                    modifier = Modifier.fillMaxWidth(),
                    text = CourseActionStrings.classAlarmActionLabel.zh,
                    onClick = { onAction(CourseAction.SET_ALARM) },
                )
            }
            Spacer(modifier = Modifier.height(8.dp))
        }
    }
}

/**
 * 调课的目标选择步（Dart `showTimetableCourseRescheduleSheet` 的简化对位件）。
 *
 * 只选**目标周 / 星期 / 起止节次**：这三样就是「把这一次课挪到哪儿」的全部信息；
 * 地点沿用原值（见上方诚实清单）。默认值取「原位置」，用户只改需要改的那一项。
 */
@Composable
private fun ReschedulePicker(
    course: Course,
    sourceWeek: Int,
    primaryText: Color,
    secondaryText: Color,
    onCancel: () -> Unit,
    onConfirm: (Int, Int, Int, Int) -> Unit,
) {
    var targetWeek by remember(course.id) { mutableIntStateOf(sourceWeek) }
    var day by remember(course.id) { mutableIntStateOf(course.dayOfWeek) }
    var start by remember(course.id) { mutableIntStateOf(course.startSection) }
    var end by remember(course.id) { mutableIntStateOf(course.endSection) }

    Text(
        text = CourseActionStrings.courseActionRescheduleSecondary.zh,
        style = MiuixTheme.textStyles.body1,
        fontWeight = FontWeight.Medium,
        color = primaryText,
    )
    Spacer(modifier = Modifier.height(10.dp))

    // 目标周
    StepperRow(
        label = CourseActionStrings.targetWeekLabel,
        value = targetWeek,
        canDecrease = targetWeek > 1,
        canIncrease = true,
        primaryText = primaryText,
        secondaryText = secondaryText,
        onChange = { targetWeek = it.coerceAtLeast(1) },
    )
    // 星期
    StepperRow(
        label = CourseActionStrings.weekdayLabel.zh,
        value = day,
        canDecrease = day > 1,
        canIncrease = day < 7,
        primaryText = primaryText,
        secondaryText = secondaryText,
        onChange = { day = it.coerceIn(1, 7) },
    )
    // 起止节次
    StepperRow(
        label = CourseActionStrings.startSectionLabel.zh,
        value = start,
        canDecrease = start > 1,
        canIncrease = start < end,
        primaryText = primaryText,
        secondaryText = secondaryText,
        onChange = { start = it.coerceIn(1, end) },
    )
    StepperRow(
        label = CourseActionStrings.endSectionLabel.zh,
        value = end,
        canDecrease = end > start,
        canIncrease = end < 30,
        primaryText = primaryText,
        secondaryText = secondaryText,
        onChange = { end = it.coerceIn(start, 30) },
    )

    Spacer(modifier = Modifier.height(14.dp))
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        TextButton(
            modifier = Modifier.weight(1f),
            text = CourseActionStrings.cancelAction.zh,
            onClick = onCancel,
        )
        Button(
            modifier = Modifier.weight(1f),
            onClick = { onConfirm(targetWeek, day, start, end) },
        ) {
            Text(text = CourseActionStrings.confirmAction.zh)
        }
    }
    Spacer(modifier = Modifier.height(8.dp))
}

/** 一行「标签 + 减 / 值 / 加」的步进控件。 */
@Composable
private fun StepperRow(
    label: String,
    value: Int,
    canDecrease: Boolean,
    canIncrease: Boolean,
    primaryText: Color,
    secondaryText: Color,
    onChange: (Int) -> Unit,
) {
    Row(
        modifier = Modifier.fillMaxWidth().padding(vertical = 2.dp),
        verticalAlignment = androidx.compose.ui.Alignment.CenterVertically,
    ) {
        Text(text = label, style = MiuixTheme.textStyles.body2, color = primaryText, modifier = Modifier.weight(1f))
        TextButton(text = "−", enabled = canDecrease, onClick = { onChange(value - 1) })
        Text(
            text = value.toString(),
            style = MiuixTheme.textStyles.body1,
            fontWeight = FontWeight.Medium,
            color = primaryText,
            modifier = Modifier.width(36.dp),
            textAlign = androidx.compose.ui.text.style.TextAlign.Center,
        )
        TextButton(text = "+", enabled = canIncrease, onClick = { onChange(value + 1) })
    }
}

/** 弹层里的一行课程信息（Dart `_CourseDetailTile` 的简化对位件）。 */
@Composable
private fun InfoRow(
    label: String,
    detail: String?,
    primaryText: Color,
    secondaryText: Color,
) {
    QingyuCard(modifier = Modifier.fillMaxWidth().padding(vertical = 2.dp)) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 10.dp),
            verticalAlignment = androidx.compose.ui.Alignment.CenterVertically,
        ) {
            Text(
                text = label,
                style = MiuixTheme.textStyles.body2,
                fontWeight = FontWeight.Medium,
                color = primaryText,
            )
            if (detail != null) {
                Spacer(modifier = Modifier.width(8.dp))
                Text(text = detail, style = MiuixTheme.textStyles.footnote1, color = secondaryText)
            }
        }
    }
}
