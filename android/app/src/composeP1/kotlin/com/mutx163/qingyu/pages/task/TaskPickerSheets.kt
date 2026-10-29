package com.mutx163.qingyu.pages.task

import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.HorizontalDivider
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.NumberPicker
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TextButton
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Ok
import top.yukonga.miuix.kmp.overlay.OverlayBottomSheet
import top.yukonga.miuix.kmp.theme.MiuixTheme
import top.yukonga.miuix.kmp.utils.overScrollVertical
import top.yukonga.miuix.kmp.utils.scrollEndHaptic
import java.time.LocalDateTime

/**
 * 作业族的两个子弹层（Phase 3.5 · T1 收尾 task-18；2026-10-29 按 Dart 原版重新对齐）。
 *
 * 补的是 `AddTaskPage` 里两处**点不动**的行：来源课程、截止日期。
 * 判据全在 [com.mutx163.qingyu.app.AddTaskFormReducer]（纯 Kotlin、JVM 可测），
 * 本文件只负责「摆出来 + 把选择转达出去」。
 *
 * ## 与 Dart 的对照
 *
 * | 弹层 | Dart 出处 | Dart 长什么样 | 这里怎么实现 |
 * |---|---|---|---|
 * | 选课程 | `add_task_screen.dart:282-347`（`showHyperosSheet` + `HyperosSheet(title:)` + `HyperosChoiceGroup`，首项「无关联课程」、按课名分组升序） | 选项行 `HyperosChoiceTile`：`variant: dialog`，行高 ≥ 56、内边距 `(16,13,16,13)`、**选中 = 行尾 22dp 勾**（`tiles.dart:656-661` → `indicators.dart:168-176`），行间分隔线左缩进 16（`tiles.dart:687-690`）；选项区最高 **屏高 × 0.64**（`:301-304`） | `OverlayBottomSheet` + `LazyColumn(heightIn(max = 屏高×0.64))` + 同款行距 / 勾图标 / 分隔线 |
 * | 选日期 | `add_task_screen.dart:349-365` → `showMiuixDatePickerSheet`（`lib/widgets/miuix_date_picker_sheet.dart`） | **月历** `MiuixDatePicker`（`:166-180`），点月历标题才弹**年 / 月 / 日三列滚轮**（`_YearMonthWheelDialog` `:325-367`，行文案 `'$value年' '/月' '/日'`）；范围 2020-01-01 ~ 2035-12-31、初值 `当前值 ?: 今天`（`:354-356`） | `OverlayBottomSheet` + 官方 `basic.NumberPicker` 三列滚轮（同族先例 `SettingsHolidayHost.kt:575-599`、`SettingsSemesterHost.kt:249-274`） |
 *
 * ⚠️ **月历那一层没有搬**：Kotlin 侧 miuix 0.9.4 没有 `DatePicker`，自绘月历属于 MIUIX-FIRST
 * 标准里的例外（要用户拍板 + 登记），所以这里只保留 Dart 里同样由滚轮承担的那一半 ——
 * 年 / 月 / 日三列 + 取消 / 确认。**这是本文件与 Dart 唯一的结构性差异。**
 *
 * 📌 更正（2026-10-29）：旧注释写「Dart 用 `MiuixFlingNumberPicker` 惯性滚轮、**不是日历**」，
 * 那是错的。Dart `:351` 调的是 `showMiuixDatePickerSheet`，主视图就是月历；`MiuixFlingNumberPicker`
 * 只是「点标题弹出来的那层」。已按实情改写。
 *
 * ⚠️ **本文件多给了一个入口**：「无到期日」按钮。Dart 的清空入口是表单里那个开关
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
    val dark = isSystemInDarkTheme()
    val colors = MiuixTheme.colorScheme
    val primaryText = Color(QingyuTheme.primaryText(dark))
    // Dart `add_task_screen.dart:301-304`：选项区最高 = 屏高 × 0.64，课程多时列表内部滚动。
    // 没有这个上限，课多的课表会把弹层顶满整屏（缺口矩阵 C3）。
    // 同款写法见 `DataTransferPage.CoursePickerSheet`（`LazyColumn(heightIn(max = …))`）。
    val maxListHeight = (LocalConfiguration.current.screenHeightDp * SHEET_MAX_HEIGHT_FRACTION).dp

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
                .heightIn(max = maxListHeight)
                .scrollEndHaptic()
                .overScrollVertical(),
        ) {
            itemsIndexed(options) { index, option ->
                // Dart 选项行：`HyperosChoiceTile(variant: dialog)`（`tiles.dart:630-693`）。
                // 选中态**不是整行变色**，只有行尾一个勾（`highlightSelectedText` 默认 false，
                // `add_task_screen.dart` 也没传）——标题颜色与字重保持常态，只加勾。
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .heightIn(min = CHOICE_ROW_MIN_HEIGHT)
                        .clickable { onPick(option.id) }
                        .padding(
                            horizontal = CHOICE_ROW_HORIZONTAL_PADDING,
                            vertical = CHOICE_ROW_VERTICAL_PADDING,
                        ),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        text = option.label,
                        // Dart 侧选项行是 `HyperosChoiceTile` → `HyperosTypography.listTitle`，
                        // 映射到官方字阶是 main（见 docs/reference/miuix-api-mapping.md §2）。
                        style = MiuixTheme.textStyles.main,
                        color = primaryText,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        modifier = Modifier.weight(1f),
                    )
                    if (option.isSelected) {
                        // `HyperosSelectedCheckmark(size = 22)`（dialog 变体，`tiles.dart:658-660`）。
                        Spacer(modifier = Modifier.width(CHOICE_CHECK_GAP))
                        Icon(
                            imageVector = MiuixIcons.Ok,
                            contentDescription = null,
                            modifier = Modifier.size(CHOICE_CHECK_SIZE),
                            tint = colors.primary,
                        )
                    }
                }
                // `showDivider: index < values.length - 1`，左缩进 = 行内边距 16。
                if (index < options.lastIndex) {
                    HorizontalDivider(
                        modifier = Modifier.padding(start = CHOICE_ROW_HORIZONTAL_PADDING),
                        color = colors.dividerLine,
                    )
                }
            }
            item { Spacer(modifier = Modifier.height(8.dp)) }
        }
    }
}

/**
 * 选日期弹层（到期日）：官方 `NumberPicker` 年 / 月 / 日三列滚轮 + 取消 / 确认。
 *
 * 三个出口语义**互不混淆**：
 * - [onDismiss] 取消 / 点空白 / 返回 ⇒ **不改状态**；
 * - [onClear] 「无到期日」⇒ 清空（与上面那个开关关闭同语义）；
 * - [onPick] 确认 ⇒ 写入所选日期并**打开开关**（Dart `:361-364`）。
 *
 * 「日」列的上界跟年月走：切月后选中值越界要跟着收，否则确认会写进一个不存在的日期
 * （与 `SettingsSemesterHost.SemesterStartDateSheet` 同一处置）。
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

    val maxDay = daysInMonth(year, month)
    val safeDay = day.coerceAtMost(maxDay)

    OverlayBottomSheet(
        show = show,
        title = TaskStrings.taskDueDateLabel,
        onDismissRequest = onDismiss,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = DATE_PICKER_HORIZONTAL_PADDING),
        ) {
            // Dart 三列滚轮（`miuix_date_picker_sheet.dart:326-367`）：
            // 年不循环、月与日 wrapAround，行文案 `N年 / N月 / N日`。
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(DATE_PICKER_ROW_HEIGHT),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                NumberPicker(
                    value = year,
                    // 换年时「日」跟着收（Dart `miuix_date_picker_sheet.dart:217-225`：改年后
                    // `if (_wheelDay > maxDay) _wheelDay = maxDay`），否则 2 月 30 日会被带过去。
                    onValueChange = { picked ->
                        year = picked
                        day = day.coerceAtMost(daysInMonth(picked, month))
                    },
                    range = MIN_YEAR..MAX_YEAR,
                    label = { "$it${TaskStrings.datePickerYear}" },
                    textStyle = MiuixTheme.textStyles.title3,
                    modifier = Modifier.weight(1f),
                )
                NumberPicker(
                    value = month,
                    // 同上（Dart `:226-234` 是同一处置）。
                    onValueChange = { picked ->
                        month = picked
                        day = day.coerceAtMost(daysInMonth(year, picked))
                    },
                    range = 1..12,
                    wrapAround = true,
                    label = { "$it${TaskStrings.datePickerMonth}" },
                    textStyle = MiuixTheme.textStyles.title3,
                    modifier = Modifier.weight(1f),
                )
                NumberPicker(
                    value = safeDay,
                    onValueChange = { day = it },
                    range = 1..maxDay,
                    wrapAround = true,
                    label = { "$it${TaskStrings.datePickerDay}" },
                    textStyle = MiuixTheme.textStyles.title3,
                    modifier = Modifier.weight(1f),
                )
            }
            Spacer(modifier = Modifier.height(16.dp))
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                // 取消 ⇒ 只关弹层、不改状态（Dart `:190` `Navigator.of(context).pop()` 返回 null）。
                TextButton(
                    modifier = Modifier.weight(1f),
                    text = PICKER_CANCEL_LABEL,
                    onClick = onDismiss,
                )
                Button(
                    modifier = Modifier.weight(1f),
                    onClick = {
                        // Dart `:362` `CourseTask.dateOnly(selected)` ⇒ 只取日期、时分归零。
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

/** Dart 的日期范围下界（`:355` `firstDate: DateTime(2020)`）。 */
private const val MIN_YEAR = 2020

/** Dart 的日期范围上界（`:356` `lastDate: DateTime(2035, 12, 31)`）。 */
private const val MAX_YEAR = 2035

/** Dart `add_task_screen.dart:303`：选项区最高 = 屏高 × 0.64。 */
private const val SHEET_MAX_HEIGHT_FRACTION = 0.64f

/** Dart `HyperosMiuixSpec.settingsRowMinHeight`：设置/选项行最小高度。 */
private val CHOICE_ROW_MIN_HEIGHT = 56.dp

/** Dart `HyperosMiuixSpec.settingsRowPadding`（`16,13,16,13`）。 */
private val CHOICE_ROW_HORIZONTAL_PADDING = 16.dp
private val CHOICE_ROW_VERTICAL_PADDING = 13.dp

/** Dart `HyperosSelectedCheckmark(size = 22)`（`variant: dialog`）。 */
private val CHOICE_CHECK_SIZE = 22.dp

/** 勾与标题之间的间隔（Dart `tiles.dart:657` `SizedBox(width: 6)`）。 */
private val CHOICE_CHECK_GAP = 6.dp

/** 日期滚轮行高（与 `SettingsSemesterHost` / `SettingsHolidayHost` 同款 180dp）。 */
private val DATE_PICKER_ROW_HEIGHT = 180.dp

/** 日期弹层左右内边距（同族两个先例都是 16dp）。 */
private val DATE_PICKER_HORIZONTAL_PADDING = 16.dp

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
