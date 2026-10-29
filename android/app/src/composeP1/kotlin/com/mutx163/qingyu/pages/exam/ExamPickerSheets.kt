package com.mutx163.qingyu.pages.exam

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
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
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
import java.time.LocalDate
import java.time.LocalDateTime

/**
 * 加考试页的四个子弹层（批次 F10）。
 *
 * `AddExamPage` 只暴露回调、不假装自己有选择器（见该文件 KDoc）；本文件补上
 * 「点日期 / 点时间 / 点关联课程 / 加自定义提醒」四处真正的落点。
 *
 * ## 与 Dart 的对照
 *
 * | 弹层 | Dart 出处 | Dart 长什么样 | 这里怎么实现 |
 * |---|---|---|---|
 * | 考试日期 | `add_exam_screen.dart:655-800` | `HyperosSheet`：**周次列表**（行「第 N 周」+「本周」副标题）+ 一行 7 个星期按钮；另有一个次要按钮「使用日历选择」打开 `showMiuixDatePickerSheet` 月历 | 同一结构的前半段：周次列表 + 7 个星期按钮（判据全走模型层 `AddExamLogic.initialWeekForPicker` / `isCurrentWeek` / `dateForWeekAndDay`）。**月历那一层没有搬**：Kotlin 侧 miuix 0.9.4 没有 `DatePicker`，自绘月历属 MIUIX-FIRST 例外（要用户拍板 + 登记），所以当学期开始日缺失（无法按周算）时退回年 / 月 / 日三列滚轮，而不是装一个月历 |
 * | 开始 / 结束时间 | `add_exam_screen.dart:820+` → `showMiuixTimePickerSheet` | 时 / 分双列滚轮 + 确认 | 同款：`basic.NumberPicker` 双列（同族先例 `SettingsHost.kt:352`、`TimeSchemeHost.kt:519`） |
 * | 关联课程 | `add_exam_screen.dart:283-303` → `showCourseTemplatePickerSheet` | 底部弹层，按课名分组、名称升序，选中行尾有勾 | 同款：`OverlayBottomSheet` + `LazyColumn(heightIn(max = 屏高×0.64))`，选项由 `AddExamFormReducer.coursePickerOptions` 生成 |
 * | 自定义提醒 | `showExamReminderOffsetPickerSheet`（`lib/widgets/exam_reminder_offset_picker_sheet.dart`） | 天 / 小时 / 分钟三列滚轮，上限 30 天 23 小时 59 分 | 同款：三列滚轮，初值与合成走模型层 `decomposeReminderTotal` / `reminderTotalMinutes` |
 *
 * 一律不在这里做业务计算：初值、越界钳制、日期换算全部来自 [AddExamLogic] / [AddExamFormReducer]。
 */

/**
 * 选考试日期（周次列表 + 星期）。
 *
 * @param semesterStart 学期开始日；为 `null` 时无法按周换算，退回年/月/日三列滚轮
 *   （Dart 里「没设学期开始日」时走的就是日历那条路，见 `add_exam_screen.dart:657-676`）。
 * @param totalWeeks 学期总周数（快照 `settings.semesterWeekCount`）。
 * @param selectedDate 当前已选日期；为 `null` 表示还没选过（不预选星期，与 Dart `:700-703` 一致）。
 */
@Composable
fun ExamDatePickerSheet(
    show: Boolean,
    semesterStart: LocalDateTime?,
    totalWeeks: Int,
    selectedDate: LocalDateTime?,
    onPick: (LocalDateTime) -> Unit,
    onDismiss: () -> Unit,
) {
    if (semesterStart == null) {
        ExamCalendarWheelSheet(
            show = show,
            initial = selectedDate,
            onPick = onPick,
            onDismiss = onDismiss,
        )
        return
    }

    val dark = isSystemInDarkTheme()
    val weeks = (1..totalWeeks.coerceAtLeast(1)).toList()
    val initialWeek = remember(show, semesterStart, totalWeeks, selectedDate) {
        AddExamLogic.initialWeekForPicker(
            anchor = selectedDate,
            semesterStart = semesterStart,
            totalWeeks = totalWeeks,
        )
    }
    var week by remember(show, initialWeek) { mutableIntStateOf(initialWeek) }
    // Dart 只在「已经选过日期」时预选星期，否则一个都不选（`:700-703`）。
    var dayOfWeek by remember(show, selectedDate) {
        mutableStateOf(selectedDate?.dayOfWeek?.value)
    }

    val listState = rememberLazyListState()
    LaunchedEffect(show) {
        // 初值滚动到已选周（Dart `:706-708` 的 initialScrollOffset，行高 56dp）。
        val target = weeks.indexOf(week).coerceAtLeast(0)
        if (target > 0) listState.scrollToItem(target)
    }

    val weekLabel = ExamStrings.weekLabel.zh
    val thisWeek = ExamStrings.thisWeekLabel.zh

    OverlayBottomSheet(
        show = show,
        title = ExamStrings.examDateWeekPickerTitle.zh,
        onDismissRequest = onDismiss,
    ) {
        Column(modifier = Modifier.fillMaxWidth()) {
            Text(
                text = selectedDateLabelText(week, dayOfWeek, semesterStart),
                style = MiuixTheme.textStyles.footnote1,
                color = Color(QingyuTheme.secondaryText(dark)),
                modifier = Modifier.padding(start = 16.dp, end = 16.dp, bottom = 8.dp),
            )
            // 弹层内的短列表不承载页面级滚动，所以不用 `QingyuPageList`（它带页面级滚动条、
            // 还要求 Scaffold 的 innerPadding）；但手感要对齐官方：末端轻震 + 过度滚动两件照官方配方接上
            // （同族先例 `TaskPickerSheets.kt:99-108`）。守卫 R2 认的正是这两个修饰符。
            LazyColumn(
                state = listState,
                modifier = Modifier
                    .fillMaxWidth()
                    // Dart 弹层选项区上限是屏高的 0.64（`add_exam_screen.dart:301-304` 同口径）。
                    .heightIn(max = (LocalScreenHeight() * 0.64f).dp)
                    .scrollEndHaptic()
                    .overScrollVertical(),
            ) {
                items(weeks) { item ->
                    val isSelected = item == week
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { week = item }
                            .padding(horizontal = 16.dp, vertical = 13.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Column(modifier = Modifier.weight(1f)) {
                            Text(
                                text = weekLabel.replace("{week}", item.toString()),
                                style = MiuixTheme.textStyles.body1,
                                color = Color(QingyuTheme.primaryText(dark)),
                            )
                            if (AddExamLogic.isCurrentWeek(item, semesterStart, LocalDateTime.now())) {
                                Text(
                                    text = thisWeek,
                                    style = MiuixTheme.textStyles.footnote1,
                                    color = Color(QingyuTheme.secondaryText(dark)),
                                )
                            }
                        }
                        if (isSelected) {
                            Icon(
                                imageVector = MiuixIcons.Ok,
                                contentDescription = null,
                                tint = Color(QingyuTheme.primary(dark = dark)),
                                modifier = Modifier.size(18.dp),
                            )
                        }
                    }
                    HorizontalDivider(
                        modifier = Modifier.padding(start = 16.dp),
                        color = Color(QingyuTheme.dividerLine(dark)),
                    )
                }
            }
            Spacer(modifier = Modifier.height(12.dp))
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp),
                horizontalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                for (candidate in 1..7) {
                    val isSelected = candidate == dayOfWeek
                    TextButton(
                        modifier = Modifier.weight(1f),
                        text = weekdayShort(candidate),
                        onClick = { dayOfWeek = candidate },
                        // miuix 的 `textButtonColors(color = …)` 是**底色**、`textColor` 是字色
                        // （见 `CourseActionSheet.kt:725` 那张对照表）：选中 = 主色底 + onPrimary 字。
                        colors = top.yukonga.miuix.kmp.basic.ButtonDefaults.textButtonColors(
                            color = if (isSelected) {
                                Color(QingyuTheme.primary(dark = dark))
                            } else {
                                Color(QingyuTheme.surfaceContainerHighest(dark))
                            },
                            textColor = if (isSelected) {
                                // on-primary 走 miuix 主题令牌（本仓先例 `CourseOverviewPage.kt:576`），
                                // 不写死白色：换主题色后字色才跟着变。
                                MiuixTheme.colorScheme.onPrimary
                            } else {
                                Color(QingyuTheme.primaryText(dark))
                            },
                        ),
                    )
                }
            }
            Spacer(modifier = Modifier.height(16.dp))
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                TextButton(
                    modifier = Modifier.weight(1f),
                    text = ExamStrings.cancelAction.zh,
                    onClick = onDismiss,
                )
                Button(
                    modifier = Modifier.weight(1f),
                    onClick = {
                        val picked = dayOfWeek
                        if (picked != null) {
                            onPick(AddExamLogic.dateForWeekAndDay(semesterStart, week, picked))
                        }
                    },
                ) {
                    Text(text = ExamStrings.confirmAction.zh)
                }
            }
            Spacer(modifier = Modifier.height(8.dp))
        }
    }
}

/** 未选星期时的说明行（Dart `:735-742`：没选星期就只显示「第 N 周」）。 */
private fun selectedDateLabelText(
    week: Int,
    dayOfWeek: Int?,
    semesterStart: LocalDateTime,
): String {
    val weekText = ExamStrings.weekLabel.zh.replace("{week}", week.toString())
    if (dayOfWeek == null) return weekText
    val date = AddExamLogic.dateForWeekAndDay(semesterStart, week, dayOfWeek)
    return "$weekText · %d-%02d-%02d".format(date.year, date.monthValue, date.dayOfMonth)
}

/**
 * 年 / 月 / 日三列滚轮（学期开始日缺失时的退路）。
 *
 * 范围照 Dart 月历弹层：`[今天-365 天, 今天+2 年]`（`add_exam_screen.dart:761-771`）。
 */
@Composable
private fun ExamCalendarWheelSheet(
    show: Boolean,
    initial: LocalDateTime?,
    onPick: (LocalDateTime) -> Unit,
    onDismiss: () -> Unit,
) {
    val base = (initial ?: LocalDateTime.now()).toLocalDate()
    val minYear = LocalDateTime.now().minusDays(365).year
    val maxYear = LocalDateTime.now().plusYears(2).year
    var year by remember(show, base) { mutableIntStateOf(base.year.coerceIn(minYear, maxYear)) }
    var month by remember(show, base) { mutableIntStateOf(base.monthValue) }
    var day by remember(show, base) { mutableIntStateOf(base.dayOfMonth) }
    val maxDay = LocalDate.of(year, month, 1).lengthOfMonth()
    val safeDay = day.coerceAtMost(maxDay)

    OverlayBottomSheet(
        show = show,
        title = ExamStrings.examDateWeekPickerTitle.zh,
        onDismissRequest = onDismiss,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp),
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(180.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                NumberPicker(
                    value = year,
                    onValueChange = { picked ->
                        year = picked
                        day = day.coerceAtMost(
                            LocalDate.of(picked, month, 1).lengthOfMonth(),
                        )
                    },
                    range = minYear..maxYear,
                    label = { "$it 年" },
                    textStyle = MiuixTheme.textStyles.title3,
                    modifier = Modifier.weight(1.2f),
                )
                NumberPicker(
                    value = month,
                    onValueChange = { picked ->
                        month = picked
                        day = day.coerceAtMost(
                            LocalDate.of(year, picked, 1).lengthOfMonth(),
                        )
                    },
                    range = 1..12,
                    wrapAround = true,
                    label = { "$it 月" },
                    textStyle = MiuixTheme.textStyles.title3,
                    modifier = Modifier.weight(1f),
                )
                NumberPicker(
                    value = safeDay,
                    onValueChange = { day = it },
                    range = 1..maxDay,
                    wrapAround = true,
                    label = { "$it 日" },
                    textStyle = MiuixTheme.textStyles.title3,
                    modifier = Modifier.weight(1f),
                )
            }
            Spacer(modifier = Modifier.height(12.dp))
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                TextButton(
                    modifier = Modifier.weight(1f),
                    text = ExamStrings.cancelAction.zh,
                    onClick = onDismiss,
                )
                Button(
                    modifier = Modifier.weight(1f),
                    onClick = { onPick(LocalDateTime.of(year, month, safeDay, 0, 0)) },
                ) {
                    Text(text = ExamStrings.confirmAction.zh)
                }
            }
            Spacer(modifier = Modifier.height(8.dp))
        }
    }
}

/**
 * 时 / 分双列滚轮。
 *
 * 照 Dart `showMiuixTimePickerSheet`：小时 `0..23`、分钟 `0..59`（分钟步进 1，Dart 同款），
 * 初值由调用方传 `HH:mm`，非法值先过 `AddExamLogic.normalizeTimeOrFallback`。
 */
@Composable
fun ExamTimePickerSheet(
    show: Boolean,
    title: String,
    initial: String,
    onPick: (String) -> Unit,
    onDismiss: () -> Unit,
) {
    val normalized = AddExamLogic.normalizeTimeOrFallback(initial)
    val parts = normalized.split(":")
    val baseHour = parts[0].toIntOrNull() ?: 8
    val baseMinute = parts[1].toIntOrNull() ?: 0
    var hour by remember(show, normalized) { mutableIntStateOf(baseHour) }
    var minute by remember(show, normalized) { mutableIntStateOf(baseMinute) }

    OverlayBottomSheet(
        show = show,
        title = title,
        onDismissRequest = onDismiss,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp),
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(180.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                NumberPicker(
                    value = hour,
                    onValueChange = { hour = it },
                    range = 0..23,
                    wrapAround = true,
                    label = { "%02d".format(it) },
                    textStyle = MiuixTheme.textStyles.title3,
                    modifier = Modifier.weight(1f),
                )
                Text(
                    text = ":",
                    style = MiuixTheme.textStyles.title3,
                    color = Color(QingyuTheme.primaryText(isSystemInDarkTheme())),
                )
                NumberPicker(
                    value = minute,
                    onValueChange = { minute = it },
                    range = 0..59,
                    wrapAround = true,
                    label = { "%02d".format(it) },
                    textStyle = MiuixTheme.textStyles.title3,
                    modifier = Modifier.weight(1f),
                )
            }
            Spacer(modifier = Modifier.height(12.dp))
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                TextButton(
                    modifier = Modifier.weight(1f),
                    text = ExamStrings.cancelAction.zh,
                    onClick = onDismiss,
                )
                Button(
                    modifier = Modifier.weight(1f),
                    onClick = { onPick("%02d:%02d".format(hour, minute)) },
                ) {
                    Text(text = ExamStrings.confirmAction.zh)
                }
            }
            Spacer(modifier = Modifier.height(8.dp))
        }
    }
}

/** 选关联课程（按课名分组、名称升序、选中行尾打勾）。 */
@Composable
fun ExamCoursePickerSheet(
    show: Boolean,
    options: List<AddExamFormReducer.ExamCourseOption>,
    onPick: (String) -> Unit,
    onDismiss: () -> Unit,
) {
    val dark = isSystemInDarkTheme()
    OverlayBottomSheet(
        show = show,
        title = ExamStrings.linkCourse.zh,
        onDismissRequest = onDismiss,
    ) {
        // 同上：弹层内短列表不用 `QingyuPageList`，但滚动三件套（末端轻震 + 过度滚动）照官方配方。
        LazyColumn(
            modifier = Modifier
                .fillMaxWidth()
                // 与 Dart 选项区同高（屏高 × 0.64）。
                .heightIn(max = (LocalScreenHeight() * 0.64f).dp)
                .scrollEndHaptic()
                .overScrollVertical(),
        ) {
            items(options) { option ->
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { onPick(option.courseId) }
                        .padding(horizontal = 16.dp, vertical = 13.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            text = option.title,
                            style = MiuixTheme.textStyles.body1,
                            color = Color(QingyuTheme.primaryText(dark)),
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                        )
                        if (option.details.isNotEmpty()) {
                            Text(
                                text = option.details,
                                style = MiuixTheme.textStyles.footnote1,
                                color = Color(QingyuTheme.secondaryText(dark)),
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis,
                            )
                        }
                    }
                    if (option.selected) {
                        Icon(
                            imageVector = MiuixIcons.Ok,
                            contentDescription = null,
                            tint = Color(QingyuTheme.primary(dark = dark)),
                            modifier = Modifier.size(18.dp),
                        )
                    }
                }
                HorizontalDivider(
                    modifier = Modifier.padding(start = 16.dp),
                    color = Color(QingyuTheme.dividerLine(dark)),
                )
            }
        }
        Spacer(modifier = Modifier.height(8.dp))
    }
}

/**
 * 自定义提醒：天 / 小时 / 分钟三列滚轮。
 *
 * 上限 30 天（`AddExamLogic.MAX_REMINDER_MINUTES` 的同一条口径：
 * 30 天 23 小时 59 分），初值走 `AddExamFormReducer.reminderPickerInitial`。
 */
@Composable
fun ExamReminderPickerSheet(
    show: Boolean,
    initialMinutes: Int?,
    onPick: (Int) -> Unit,
    onDismiss: () -> Unit,
) {
    val parts = AddExamFormReducer.reminderPickerInitial(initialMinutes)
    var days by remember(show, initialMinutes) { mutableIntStateOf(parts.days) }
    var hours by remember(show, initialMinutes) { mutableIntStateOf(parts.hours) }
    var minutes by remember(show, initialMinutes) { mutableIntStateOf(parts.minutes) }

    OverlayBottomSheet(
        show = show,
        title = ExamStrings.examReminderAddCustomTitle.zh,
        onDismissRequest = onDismiss,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp),
        ) {
            Text(
                text = ExamStrings.examReminderAddCustomHint.zh,
                style = MiuixTheme.textStyles.footnote1,
                color = Color(QingyuTheme.secondaryText(isSystemInDarkTheme())),
                modifier = Modifier.padding(bottom = 8.dp),
            )
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(180.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                NumberPicker(
                    value = days,
                    onValueChange = { days = it },
                    range = 0..30,
                    label = { "$it${ExamStrings.examReminderPickerDays.zh}" },
                    textStyle = MiuixTheme.textStyles.title3,
                    modifier = Modifier.weight(1f),
                )
                NumberPicker(
                    value = hours,
                    onValueChange = { hours = it },
                    range = 0..23,
                    wrapAround = true,
                    label = { "$it${ExamStrings.examReminderPickerHours.zh}" },
                    textStyle = MiuixTheme.textStyles.title3,
                    modifier = Modifier.weight(1f),
                )
                NumberPicker(
                    value = minutes,
                    onValueChange = { minutes = it },
                    range = 0..59,
                    wrapAround = true,
                    label = { "$it${ExamStrings.examReminderPickerMinutes.zh}" },
                    textStyle = MiuixTheme.textStyles.title3,
                    modifier = Modifier.weight(1f),
                )
            }
            Spacer(modifier = Modifier.height(12.dp))
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                TextButton(
                    modifier = Modifier.weight(1f),
                    text = ExamStrings.cancelAction.zh,
                    onClick = onDismiss,
                )
                Button(
                    modifier = Modifier.weight(1f),
                    onClick = {
                        onPick(
                            AddExamFormReducer.reminderTotal(
                                ReminderPickerParts(days = days, hours = hours, minutes = minutes),
                            ),
                        )
                    },
                ) {
                    Text(text = ExamStrings.confirmAction.zh)
                }
            }
            Spacer(modifier = Modifier.height(8.dp))
        }
    }
}

/** 当前屏高（dp），给弹层选项区算上限用。 */
@Composable
private fun LocalScreenHeight(): Float {
    val configuration = LocalConfiguration.current
    return configuration.screenHeightDp.toFloat()
}

/** 星期按钮的文字（Dart `l10n.weekdayMon` 是「周一」，按钮上只放「一」）。 */
private fun weekdayShort(dayOfWeek: Int): String =
    ExamStrings.weekdayLabel(dayOfWeek).removePrefix("周")
