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
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.QingyuSheet
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.rememberSheetMaxHeight
import com.mutx163.qingyu.components.shiftWeight
import com.mutx163.qingyu.pages.timetable.day.parseHexColorOrFallback
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.ButtonDefaults
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.NumberPicker
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TextButton
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Ok
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
 * | 关联课程 | `add_exam_screen.dart:283-303` → `showCourseTemplatePickerSheet` | 底部弹层，按课名分组、名称升序，选中行尾有勾 | 同款：`QingyuSheet` + `LazyColumn(heightIn(max = 屏高×0.64))`，选项由 `AddExamFormReducer.coursePickerOptions` 生成 |
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

    val weekLabel = ExamStrings.weekLabel.text
    val thisWeek = ExamStrings.thisWeekLabel.text

    QingyuSheet(
        show = show,
        title = ExamStrings.examDateWeekPickerTitle.text,
        onDismissRequest = onDismiss,
        // 内容每一块（说明字、周次行、星期按钮行、取消/确认行）都自己垫了左右 16，
        // 没有通栏元素 ⇒ 框架侧横向归零，单边仍是 Dart 那个 16
        //（`hyperosMiuixBottomSheetInsideMargin`），不再叠成 32。
        contentPadsHorizontally = true,
        // 正文里有 LazyColumn（周次列表）：套件不能再套一层 verticalScroll（嵌套滚动）。
        // 底部让位因此由本文件落实 —— 见取消/确认行之后那个 `Spacer(bottomInset)`。
        contentScrolls = true,
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
                    // Dart 弹层选项区上限是屏高的 0.64（`add_exam_screen.dart:301-304` 同口径）；
                    // 但本弹层列表之下还有星期按钮行与取消/确认行等固定件，0.64 在矮屏/大字号
                    // 时会把底部按钮挤出面板（2026-11-02 弹窗审核 P2 已知债）——收到 0.55 给
                    // 固定件留出高度。矮屏表现仍需真机复核。
                    .heightIn(max = rememberSheetMaxHeight(0.55f))
                    .scrollEndHaptic()
                    .overScrollVertical(),
            ) {
                itemsIndexed(weeks) { index, item ->
                    val isSelected = item == week
                    val isCurrentWeek = AddExamLogic.isCurrentWeek(item, semesterStart, LocalDateTime.now())
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { week = item }
                            .padding(horizontal = 16.dp, vertical = 13.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        // 2026-11-02 弹窗审核 P3：Dart 行首有 36dp 周数字徽章
                        //（选中=主色实心、本周=次色、其余=浅底），Compose 此前缺失。
                        WeekBadge(
                            week = item,
                            isSelected = isSelected,
                            isCurrentWeek = isCurrentWeek,
                            dark = dark,
                        )
                        Spacer(modifier = Modifier.width(12.dp))
                        Column(modifier = Modifier.weight(1f)) {
                            Text(
                                text = weekLabel.replace("{week}", item.toString()),
                                // 2026-11-02 弹窗审核 P3：Dart 选项行主行是 listTitle(17)=main、
                                // 副行是 listDetail(14)=body2，body1/footnote1 整体小一档。
                                style = MiuixTheme.textStyles.main,
                                color = Color(QingyuTheme.primaryText(dark)),
                            )
                            if (isCurrentWeek) {
                                Text(
                                    text = thisWeek,
                                    style = MiuixTheme.textStyles.body2,
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
                    // 2026-11-02 弹窗审核 P2：Dart 每格是「日名 + 日期」两行，Compose 只剩一个
                    // 星期字。TextButton 只有单文本槽，改用官方 Button 的 content 槽补第二行。
                    Button(
                        onClick = { dayOfWeek = candidate },
                        modifier = Modifier.weight(1f),
                        colors = ButtonDefaults.buttonColors(
                            color = if (isSelected) {
                                Color(QingyuTheme.primary(dark = dark))
                            } else {
                                Color(QingyuTheme.surfaceContainerHighest(dark))
                            },
                            contentColor = if (isSelected) {
                                // on-primary 走 miuix 主题令牌（本仓先例 `CourseOverviewPage.kt:576`），
                                // 不写死白色：换主题色后字色才跟着变。
                                MiuixTheme.colorScheme.onPrimary
                            } else {
                                Color(QingyuTheme.primaryText(dark))
                            },
                        ),
                        insideMargin = PaddingValues(horizontal = 4.dp, vertical = 8.dp),
                    ) {
                        Column(
                            horizontalAlignment = Alignment.CenterHorizontally,
                            verticalArrangement = Arrangement.spacedBy(2.dp),
                        ) {
                            Text(text = weekdayShort(candidate), style = MiuixTheme.textStyles.footnote2)
                            Text(
                                text = weekdayDateLabel(week, candidate, semesterStart),
                                style = MiuixTheme.textStyles.footnote2,
                            )
                        }
                    }
                }
            }
            Spacer(modifier = Modifier.height(16.dp))
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Button(
                    modifier = Modifier.weight(1f),
                    onClick = onDismiss,
                    // 发布版滚轮弹层的「取消」是次要色实心键（`hyperos_controls.dart:657-818`
                    // 的 secondary：#E6E6E6 底 + 主文本字），不是 ghost 文字键。
                    colors = ButtonDefaults.buttonColors(
                        color = Color(QingyuTheme.secondary(dark)),
                        contentColor = Color(QingyuTheme.primaryText(dark)),
                    ),
                ) {
                    Text(text = ExamStrings.cancelAction.text)
                }
                Button(
                    modifier = Modifier.weight(1f),
                    // 未选星期时置灰而不是可点但无声无息（2026-11-02 弹窗审核 P2：
                    // onClick 里判空后什么都不做，用户会以为卡死了）。
                    enabled = dayOfWeek != null,
                    onClick = {
                        val picked = dayOfWeek
                        if (picked != null) {
                            onPick(AddExamLogic.dateForWeekAndDay(semesterStart, week, picked))
                        }
                    },
                    // 「确认」是出口：Dart 那颗主按钮是 primary 变体（强调色），
                    // 默认 `buttonColors()` 是灰的 secondary 口径。
                    colors = ButtonDefaults.buttonColorsPrimary(),
                ) {
                    Text(text = ExamStrings.confirmAction.text)
                }
            }
            // 底部让位（系统手势区 + 16）垫在**最后一块固定件之后**：本弹层滚动的是中间的
            // 周次列表，若塞进列表的 contentPadding 会在按钮行上方留一截空白。
            Spacer(modifier = Modifier.height(bottomInset))
        }
    }
}

/** 未选星期时的说明行（Dart `:735-742`：没选星期就只显示「第 N 周」）。 */
private fun selectedDateLabelText(
    week: Int,
    dayOfWeek: Int?,
    semesterStart: LocalDateTime,
): String {
    val weekText = ExamStrings.weekLabel.text.replace("{week}", week.toString())
    if (dayOfWeek == null) return weekText
    val date = AddExamLogic.dateForWeekAndDay(semesterStart, week, dayOfWeek)
    return "$weekText · %d-%02d-%02d".format(date.year, date.monthValue, date.dayOfMonth)
}

/** 星期按钮第二行的具体日期（月-日，纯数字不需要走 ARB；Dart 每格日名下有这一行）。 */
private fun weekdayDateLabel(
    week: Int,
    dayOfWeek: Int,
    semesterStart: LocalDateTime,
): String {
    val date = AddExamLogic.dateForWeekAndDay(semesterStart, week, dayOfWeek)
    return "%d-%02d".format(date.monthValue, date.dayOfMonth)
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
    val dark = isSystemInDarkTheme()
    val base = (initial ?: LocalDateTime.now()).toLocalDate()
    val minYear = LocalDateTime.now().minusDays(365).year
    val maxYear = LocalDateTime.now().plusYears(2).year
    var year by remember(show, base) { mutableIntStateOf(base.year.coerceIn(minYear, maxYear)) }
    var month by remember(show, base) { mutableIntStateOf(base.monthValue) }
    var day by remember(show, base) { mutableIntStateOf(base.dayOfMonth) }
    val maxDay = LocalDate.of(year, month, 1).lengthOfMonth()
    val safeDay = day.coerceAtMost(maxDay)

    QingyuSheet(
        show = show,
        title = ExamStrings.examDateWeekPickerTitle.text,
        onDismissRequest = onDismiss,
        // 内容根 `Column` 自己给了左右 16（三列滚轮与按钮行都不通栏）⇒ 框架侧横向归零，
        // 单边就是 Dart 那个 16，不再叠成 32。
        contentPadsHorizontally = true,
        // 正文只有 NumberPicker 滚轮（固定高 180dp），没有竖向可滚动容器
        // ⇒ contentScrolls 保持 false，由套件套滚动并自动补底部让位。
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
                    label = { "$it ${ExamStrings.datePickerYear.text}" },
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
                    label = { "$it ${ExamStrings.datePickerMonth.text}" },
                    textStyle = MiuixTheme.textStyles.title3,
                    modifier = Modifier.weight(1f),
                )
                NumberPicker(
                    value = safeDay,
                    onValueChange = { day = it },
                    range = 1..maxDay,
                    wrapAround = true,
                    label = { "$it ${ExamStrings.datePickerDay.text}" },
                    textStyle = MiuixTheme.textStyles.title3,
                    modifier = Modifier.weight(1f),
                )
            }
            Spacer(modifier = Modifier.height(12.dp))
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Button(
                    modifier = Modifier.weight(1f),
                    onClick = onDismiss,
                    // 发布版滚轮弹层的「取消」是次要色实心键（`hyperos_controls.dart:657-818`
                    // 的 secondary：#E6E6E6 底 + 主文本字），不是 ghost 文字键。
                    colors = ButtonDefaults.buttonColors(
                        color = Color(QingyuTheme.secondary(dark)),
                        contentColor = Color(QingyuTheme.primaryText(dark)),
                    ),
                ) {
                    Text(text = ExamStrings.cancelAction.text)
                }
                Button(
                    modifier = Modifier.weight(1f),
                    onClick = { onPick(LocalDateTime.of(year, month, safeDay, 0, 0)) },
                    // 出口按钮走强调色（Dart 主按钮是 primary 变体，默认 `buttonColors()` 是灰的）。
                    colors = ButtonDefaults.buttonColorsPrimary(),
                ) {
                    Text(text = ExamStrings.confirmAction.text)
                }
            }
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
    val dark = isSystemInDarkTheme()
    val normalized = AddExamLogic.normalizeTimeOrFallback(initial)
    val parts = normalized.split(":")
    val baseHour = parts[0].toIntOrNull() ?: 8
    val baseMinute = parts[1].toIntOrNull() ?: 0
    var hour by remember(show, normalized) { mutableIntStateOf(baseHour) }
    var minute by remember(show, normalized) { mutableIntStateOf(baseMinute) }

    QingyuSheet(
        show = show,
        title = title,
        onDismissRequest = onDismiss,
        // 内容根 `Column` 自己给了左右 16（时/分两列与按钮行都不通栏）⇒ 框架侧横向归零。
        contentPadsHorizontally = true,
        // 只有两列 NumberPicker（固定高 180dp），没有竖向可滚动容器
        // ⇒ contentScrolls 保持 false，由套件套滚动并补底部让位。
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
                Button(
                    modifier = Modifier.weight(1f),
                    onClick = onDismiss,
                    // 发布版滚轮弹层的「取消」是次要色实心键（`hyperos_controls.dart:657-818`
                    // 的 secondary：#E6E6E6 底 + 主文本字），不是 ghost 文字键。
                    colors = ButtonDefaults.buttonColors(
                        color = Color(QingyuTheme.secondary(dark)),
                        contentColor = Color(QingyuTheme.primaryText(dark)),
                    ),
                ) {
                    Text(text = ExamStrings.cancelAction.text)
                }
                Button(
                    modifier = Modifier.weight(1f),
                    onClick = { onPick("%02d:%02d".format(hour, minute)) },
                    // 出口按钮走强调色（Dart 主按钮是 primary 变体，默认 `buttonColors()` 是灰的）。
                    colors = ButtonDefaults.buttonColorsPrimary(),
                ) {
                    Text(text = ExamStrings.confirmAction.text)
                }
            }
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
    QingyuSheet(
        show = show,
        title = ExamStrings.linkCourse.text,
        onDismissRequest = onDismiss,
        // 正文根是 LazyColumn、自己没有横向内边距：行的 16 是**列表行的内缩**
        // （触摸区通栏、文字缩进 16），不是内容根的主边距 ⇒ 框架侧照旧给 16dp。
        // Dart 同款行也是 16（`settingsRowPadding`）+ `insideMargin` 16 = 单边 32，
        // 与 `TaskPickerSheets` 的选课程弹层同一口径。
        contentPadsHorizontally = false,
        // 正文是 LazyColumn（自己管滚动）：套件不能再套 verticalScroll（嵌套滚动）。
        // 底部让位因此由本文件落实——垫在固定的取消按钮之后（见下）。
        contentScrolls = true,
    ) {
        // 同上：弹层内短列表不用 `QingyuPageList`，但滚动三件套（末端轻震 + 过度滚动）照官方配方。
        LazyColumn(
            modifier = Modifier
                .fillMaxWidth()
                // 与 Dart 选项区同口径的限高；列表之下还有固定的取消按钮
                //（2026-11-02 弹窗审核 P2 补的），上限收到 0.55 给固定件留出高度，
                // 矮屏/大字号时按钮不再被挤出面板（同 `ExamDatePickerSheet` 的 0.55）。
                .heightIn(max = rememberSheetMaxHeight(0.55f))
                .scrollEndHaptic()
                .overScrollVertical(),
        ) {
            itemsIndexed(options) { index, option ->
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { onPick(option.courseId) }
                        .padding(horizontal = 16.dp, vertical = 13.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    // 2026-11-02 弹窗审核 P2：Dart 选项行首有 36dp 课程颜色徽章，Compose 缺失。
                    Box(
                        modifier = Modifier
                            .size(36.dp)
                            .clip(RoundedCornerShape(10.dp))
                            .background(
                                parseHexColorOrFallback(
                                    option.color,
                                    fallback = Color(QingyuTheme.primary(dark = dark)),
                                ),
                            ),
                    )
                    Spacer(modifier = Modifier.width(12.dp))
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            text = option.title,
                            // 与周次列表同一条口径：主行 main、副行 body2（对齐 Dart listTitle/listDetail）。
                            style = MiuixTheme.textStyles.main,
                            color = Color(QingyuTheme.primaryText(dark)),
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                        )
                        if (option.details.isNotEmpty()) {
                            Text(
                                text = option.details,
                                style = MiuixTheme.textStyles.body2,
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
            }
        }
        Spacer(modifier = Modifier.height(8.dp))
        // 2026-11-02 弹窗审核 P2：Dart 弹层底部有全宽「取消」，Compose 此前只能靠点空白/返回关闭。
        Button(
            modifier = Modifier.fillMaxWidth(),
            onClick = onDismiss,
            // 同上：取消键走次要色实心，不保留 ghost 文字键。
            colors = ButtonDefaults.buttonColors(
                color = Color(QingyuTheme.secondary(dark)),
                contentColor = Color(QingyuTheme.primaryText(dark)),
            ),
        ) {
            Text(text = ExamStrings.cancelAction.text)
        }
        // 列表之下有固定件 ⇒ 底部让位（手势区 + 16）垫在固定件之后，
        // 不再塞进列表 contentPadding（会在按钮上方造一截空白）。
        Spacer(modifier = Modifier.height(bottomInset))
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
    val dark = isSystemInDarkTheme()
    val parts = AddExamFormReducer.reminderPickerInitial(initialMinutes)
    var days by remember(show, initialMinutes) { mutableIntStateOf(parts.days) }
    var hours by remember(show, initialMinutes) { mutableIntStateOf(parts.hours) }
    var minutes by remember(show, initialMinutes) { mutableIntStateOf(parts.minutes) }

    QingyuSheet(
        show = show,
        title = ExamStrings.examReminderAddCustomTitle.text,
        onDismissRequest = onDismiss,
        // 内容根 `Column` 自己给了左右 16（说明句、三列滚轮、按钮行都不通栏）⇒ 框架侧横向归零。
        contentPadsHorizontally = true,
        // 只有三列 NumberPicker（固定高 180dp），没有竖向可滚动容器
        // ⇒ contentScrolls 保持 false，由套件套滚动并补底部让位。
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp),
        ) {
            Text(
                text = ExamStrings.examReminderAddCustomHint.text,
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
                    label = { "$it${ExamStrings.examReminderPickerDays.text}" },
                    textStyle = MiuixTheme.textStyles.title3,
                    modifier = Modifier.weight(1f),
                )
                NumberPicker(
                    value = hours,
                    onValueChange = { hours = it },
                    range = 0..23,
                    wrapAround = true,
                    label = { "$it${ExamStrings.examReminderPickerHours.text}" },
                    textStyle = MiuixTheme.textStyles.title3,
                    modifier = Modifier.weight(1f),
                )
                NumberPicker(
                    value = minutes,
                    onValueChange = { minutes = it },
                    range = 0..59,
                    wrapAround = true,
                    label = { "$it${ExamStrings.examReminderPickerMinutes.text}" },
                    textStyle = MiuixTheme.textStyles.title3,
                    modifier = Modifier.weight(1f),
                )
            }
            Spacer(modifier = Modifier.height(12.dp))
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Button(
                    modifier = Modifier.weight(1f),
                    onClick = onDismiss,
                    // 发布版滚轮弹层的「取消」是次要色实心键（`hyperos_controls.dart:657-818`
                    // 的 secondary：#E6E6E6 底 + 主文本字），不是 ghost 文字键。
                    colors = ButtonDefaults.buttonColors(
                        color = Color(QingyuTheme.secondary(dark)),
                        contentColor = Color(QingyuTheme.primaryText(dark)),
                    ),
                ) {
                    Text(text = ExamStrings.cancelAction.text)
                }
                Button(
                    modifier = Modifier.weight(1f),
                    onClick = {
                        onPick(
                            AddExamFormReducer.reminderTotal(
                                ReminderPickerParts(days = days, hours = hours, minutes = minutes),
                            ),
                        )
                    },
                    // 出口按钮走强调色（Dart 主按钮是 primary 变体，默认 `buttonColors()` 是灰的）。
                    colors = ButtonDefaults.buttonColorsPrimary(),
                ) {
                    Text(text = ExamStrings.confirmAction.text)
                }
            }
        }
    }
}

/**
 * 周次行首的 36dp 周数字徽章（Dart 同款）：选中 = 主色实心 + onPrimary 字、
 * 本周 = 次色底、其余 = 浅底。颜色全走主题令牌，不写死。
 */
@Composable
private fun WeekBadge(
    week: Int,
    isSelected: Boolean,
    isCurrentWeek: Boolean,
    dark: Boolean,
) {
    val bg = when {
        isSelected -> Color(QingyuTheme.primary(dark = dark))
        isCurrentWeek -> MiuixTheme.colorScheme.secondaryContainer
        else -> Color(QingyuTheme.surfaceContainerHighest(dark))
    }
    val fg = if (isSelected) MiuixTheme.colorScheme.onPrimary else Color(QingyuTheme.primaryText(dark))
    Box(
        modifier = Modifier
            .size(36.dp)
            .clip(RoundedCornerShape(10.dp))
            .background(bg),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = week.toString(),
            style = MiuixTheme.textStyles.footnote1.shiftWeight(QingyuWeightDelta.SEMIBOLD),
            color = fg,
        )
    }
}

/**
 * 星期按钮的文字：只放一个字（ARB `weekdayShortMonday..Sunday`）。
 *
 * 2026-10-29 质量审核：原实现是 `weekdayLabel(dayOfWeek).removePrefix("周")`——
 * 从「周一」里用硬编码的「周」去截，等于在渲染层写中文，既过不了 i18n 棘轮，
 * 在非中文语言下也会截错（英文星期名根本没有「周」前缀）。改为直接读 ARB 短名。
 */
private fun weekdayShort(dayOfWeek: Int): String =
    ExamStrings.weekdayShortLabel(dayOfWeek)
