package com.mutx163.qingyu.pages.task

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.HorizontalDivider
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TextButton
import top.yukonga.miuix.kmp.overlay.OverlayBottomSheet
import top.yukonga.miuix.kmp.theme.MiuixTheme
import top.yukonga.miuix.kmp.utils.overScrollVertical
import top.yukonga.miuix.kmp.utils.scrollEndHaptic
import java.time.LocalDateTime

/**
 * 作业表单的两个子弹层（Phase 3.5 · T1 收尾 task-18）。
 *
 * 补的是 `AddTaskPage` 里两处**点不动**的行：来源课程、截止日期。
 * 判据全在 [com.mutx163.qingyu.app.AddTaskFormReducer]（纯 Kotlin、JVM 可测），
 * 本文件只负责「摆出来 + 把选择转达出去」。
 *
 * ## 与 Dart 的对照
 *
 * | 弹层 | Dart 出处 | 容器 |
 * |---|---|---|
 * | 选课程 | `add_task_screen.dart:282-347`（`showHyperosSheet` + `HyperosChoiceGroup`，按课名分组、首项「无关联课程」） | `OverlayBottomSheet` |
 * | 选日期 | `:349-365` + `lib/widgets/miuix_date_picker_sheet.dart`（**年 / 月 / 日**三个数字选择器 + 取消/确认，initialDate = 当前值 ?: 今天，范围 2020-01-01 ~ 2035-12-31） | `OverlayBottomSheet` |
 *
 * **日期弹层的结构是照 Dart 来的**：Dart 那份 `miuix_date_picker_sheet.dart:325-365` 就是
 * 年/月/日三个 picker（`'$value年'` / `'$value月'` / `'$value日'`）+ `cancelAction` / `confirmAction`
 * 两个按钮，**不是日历**（本文件初稿写成「Dart 是日历、这里只能退化成步进」，那是错的，
 * 已更正）。差异只剩实现形式：Dart 用 `MiuixFlingNumberPicker`（惯性滚轮），
 * 本文件用 ± 步进（miuix 0.9.4 的 Kotlin 侧没有滚轮选择器）。
 *
 * ⚠️ **本文件多给了一个入口**：「无到期日」行。Dart 的清空入口是上面那个开关
 * （`add_task_screen.dart:250-252`），弹层里没有；task-18 明确要求弹层里也能清空，
 * 所以这里多一行。语义与开关关闭**完全一致**（都走
 * `AddTaskFormReducer.withHasDueDate(false)`），不是第二份判据。
 */

/**
 * 选课程弹层。
 *
 * @param options 候选项（由 `AddTaskFormReducer.coursePickerOptions` 生成：首项「无关联课程」+ 按名分组升序）。
 * @param onPick 选中项 id；`null` 表示用户关掉了弹层（不改状态）。
 */
@Composable
fun TaskCoursePickerSheet(
    show: Boolean,
    options: List<TaskCourseOption>,
    onPick: (String?) -> Unit,
    /** 弹层标题：表单里是「来源课程」；清单页筛选复用同一弹层时传「课程筛选」。 */
    title: String = TaskStrings.taskCourseLabel,
) {
    val dark = androidx.compose.foundation.isSystemInDarkTheme()
    val colors = MiuixTheme.colorScheme
    val primaryText = Color(QingyuTheme.primaryText(dark))
    val secondaryText = Color(QingyuTheme.secondaryText(dark))

    OverlayBottomSheet(
        show = show,
        title = title,
        onDismissRequest = { onPick(null) },
    ) {
        // 弹层内部的短列表不承载页面级滚动，所以不用 `QingyuPageList`
        //（它带页面级滚动条，且要求 Scaffold 的 innerPadding）；
        // 但手感要对齐官方：末端轻震 + 过度滚动这两件照官方配方接上。
        LazyColumn(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 4.dp)
                .scrollEndHaptic()
                .overScrollVertical(),
        ) {
            items(options) { option ->
                val selected = option.isSelected
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { onPick(option.id) }
                        .padding(horizontal = 12.dp, vertical = 14.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        text = option.label,
                        // Dart 侧选项行是 HyperosChoiceTile → HyperosTypography.listTitle，
                        // 映射到官方字阶是 main（见 docs/reference/miuix-api-mapping.md §2）。
                        style = MiuixTheme.textStyles.main,
                        fontWeight = if (selected) FontWeight.Medium else FontWeight.Normal,
                        color = if (selected) colors.primary else primaryText,
                        modifier = Modifier.weight(1f),
                    )
                    if (selected) {
                        Text(
                            text = "✓",
                            style = MiuixTheme.textStyles.main,
                            color = colors.primary,
                        )
                    }
                }
                HorizontalDivider(color = secondaryText.copy(alpha = 0.15f))
            }
            item { Spacer(modifier = Modifier.height(8.dp)) }
        }
    }
}

/**
 * 选日期弹层（到期日）。
 *
 * 三个出口语义**互不混淆**（这是本文件初版的一个设计错误，已改）：
 * - [onDismiss] 取消 / 点空白 ⇒ **不改状态**；
 * - [onClear] 「无到期日」⇒ 清空（与上面那个开关关闭同语义）；
 * - [onPick] 确认 ⇒ 写入所选日期并**打开开关**（Dart `:361-364`）。
 *
 * @param initial 当前到期日；`null` 时用今天（Dart `:354` `initialDate: _dueDate ?? DateTime.now()`）。
 */
@Composable
fun TaskDueDatePickerSheet(
    show: Boolean,
    initial: LocalDateTime?,
    onPick: (LocalDateTime) -> Unit,
    onClear: () -> Unit,
    onDismiss: () -> Unit,
) {
    val dark = androidx.compose.foundation.isSystemInDarkTheme()
    val primaryText = Color(QingyuTheme.primaryText(dark))
    val colors = MiuixTheme.colorScheme

    // 初值：当前到期日 ?: 今天，并夹进 Dart 给的范围（2020-01-01 ~ 2035-12-31）
    val base = (initial ?: LocalDateTime.now()).toLocalDate().let {
        when {
            it.year < MIN_YEAR -> it.withYear(MIN_YEAR).withMonth(1).withDayOfMonth(1)
            it.year > MAX_YEAR -> it.withYear(MAX_YEAR).withMonth(12).withDayOfMonth(31)
            else -> it
        }
    }
    var year by remember(show, base) { mutableIntStateOf(base.year) }
    var month by remember(show, base) { mutableIntStateOf(base.monthValue) }
    var day by remember(show, base) { mutableIntStateOf(base.dayOfMonth) }

    OverlayBottomSheet(
        show = show,
        title = TaskStrings.taskDueDateLabel,
        onDismissRequest = onDismiss,
    ) {
        Column(modifier = Modifier.fillMaxWidth().padding(horizontal = 4.dp)) {
            StepperRow(TaskStrings.datePickerYear, year, MIN_YEAR, MAX_YEAR, primaryText) { year = it }
            StepperRow(TaskStrings.datePickerMonth, month, 1, 12, primaryText) { month = it }
            StepperRow(TaskStrings.datePickerDay, day, 1, daysInMonth(year, month), primaryText) { day = it }

            Spacer(modifier = Modifier.height(12.dp))
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                TextButton(
                    modifier = Modifier.weight(1f),
                    text = PICKER_CANCEL_LABEL,
                    onClick = onDismiss,
                )
                Button(
                    modifier = Modifier.weight(1f),
                    onClick = {
                        val safeDay = day.coerceAtMost(daysInMonth(year, month))
                        onPick(LocalDateTime.of(year, month, safeDay, 0, 0))
                    },
                ) {
                    Text(text = PICKER_CONFIRM_LABEL)
                }
            }
            Spacer(modifier = Modifier.height(6.dp))
            TextButton(
                modifier = Modifier.fillMaxWidth(),
                text = TaskStrings.taskNoDueDate,
                colors = top.yukonga.miuix.kmp.basic.ButtonDefaults.textButtonColors(
                    color = colors.primary,
                ),
                onClick = onClear,
            )
            Spacer(modifier = Modifier.height(8.dp))
        }
    }
}

/** 一行「标签 + 减 / 值 / 加」。 */
@Composable
private fun StepperRow(
    label: String,
    value: Int,
    min: Int,
    max: Int,
    primaryText: Color,
    onChange: (Int) -> Unit,
) {
    Row(
        modifier = Modifier.fillMaxWidth().padding(vertical = 2.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = label,
            style = MiuixTheme.textStyles.body2,
            color = primaryText,
            modifier = Modifier.weight(1f),
        )
        TextButton(text = "−", enabled = value > min, onClick = { onChange(value - 1) })
        Text(
            text = value.toString(),
            style = MiuixTheme.textStyles.main,
            fontWeight = FontWeight.Medium,
            color = primaryText,
            modifier = Modifier.width(48.dp),
            textAlign = androidx.compose.ui.text.style.TextAlign.Center,
        )
        TextButton(text = "+", enabled = value < max, onClick = { onChange(value + 1) })
    }
}

/** Dart 的日期范围下界（`:355` `firstDate: DateTime(2020)`）。 */
private const val MIN_YEAR = 2020

/** Dart 的日期范围上界（`:356` `lastDate: DateTime(2035, 12, 31)`）。 */
private const val MAX_YEAR = 2035

/**
 * 弹层两个通用按钮的文案，逐字取 ARB `cancelAction` / `confirmAction`
 * （Dart `miuix_date_picker_sheet.dart:186,196` 用的就是这两个键）。
 *
 * 2026-10-28：原先就地写成 private const（当时 task-18 写作用域不含 `TaskStrings`）。
 * `CjkLiteralGateTest` 判为「渲染层新增中文字面量」，故改为引用 `TaskStrings`
 * 中同值常量（`main/` 里，不在门禁扫描范围，且是文案的既定归属处）。
 */
private val PICKER_CANCEL_LABEL = TaskStrings.cancelAction
private val PICKER_CONFIRM_LABEL = TaskStrings.confirmAction

private fun daysInMonth(year: Int, month: Int): Int =
    java.time.YearMonth.of(year, month).lengthOfMonth()
