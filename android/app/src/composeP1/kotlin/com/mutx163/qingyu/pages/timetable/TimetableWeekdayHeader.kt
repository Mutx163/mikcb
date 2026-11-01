package com.mutx163.qingyu.pages.timetable

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.luminance
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.shiftWeight
import com.mutx163.qingyu.pages.shell.HomeBackgroundModel
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.theme.MiuixTheme
import java.time.LocalDate
import java.util.Locale

/**
 * 星期栏的几何与字阶刻度（逐条对齐 Dart `timetable_weekday_header.dart`）。
 *
 * **字阶的已知例外**：这里刻意写死 10 / 10 / 8.5sp，不跟 `MiuixTheme.textStyles` 走。
 * 与 `HeatmapSpec.WEEKDAY_LABEL_SP` 同一判定——这是**复刻 Dart 的几何口径**，不是绕开主题：
 * - 周次格 `:184`、星期标签 `:298` 都是 `fontSize: 10`；
 * - 日期 `:311` 是 `fontSize: 8.5`（官方字阶没有 8.5 这一档）。
 * 抬到最近一档 `footnote2`（11sp）会让「周一 + 10/26」两行在 40dp 的栏里挤不下，
 * 7 列在窄屏上也会横向溢出。常量集中在这里，是为了让守卫（R4）能分清
 * 「几何口径」与「随手写死」。
 */
object WeekdayHeaderMetrics {
    /** 整条栏高（Dart `TimetableWeekdayHeader.height = 40`，`:55`）。 */
    const val HEIGHT_DP = 40f

    /** 左端「{week} 周」字号（Dart `:184`）。 */
    const val WEEK_LABEL_SP = 10f

    /** 星期标签字号（Dart `:298`）。 */
    const val WEEKDAY_LABEL_SP = 10f

    /** 日期 `MM/DD` 字号（Dart `:311`）。 */
    const val DATE_LABEL_SP = 8.5f

    /** 星期与日期之间的固定间距（Dart `:305` `SizedBox(height: 2)`）。 */
    const val LABEL_GAP_DP = 2f

    /** 每格左右外边距（Dart `:267` `margin: horizontal 1`）。 */
    const val CELL_MARGIN_HORIZONTAL_DP = 1f

    /** 每格上下内边距（Dart `:270` `padding: vertical 3`）。 */
    const val CELL_PADDING_VERTICAL_DP = 3f

    /** 左端周次格的内边距：左 8 / 右 2（Dart `:179`，略向右让周次与节次数字对齐）。 */
    const val WEEK_LABEL_PADDING_START_DP = 8f
    const val WEEK_LABEL_PADDING_END_DP = 2f

    /** 表格底部细分隔线（Dart `:125`：无壁纸档 `dividerWidth = 0.5`）。 */
    const val DIVIDER_DP = 0.5f

    /** 今天格的底部下划线（Dart `:278` `width: showsTodayMarker ? 2 : 0`）。 */
    const val TODAY_UNDERLINE_DP = 2f

    /** 下划线透明度（Dart `:276` `accentColor.withValues(alpha: 0.35)`）。 */
    const val TODAY_UNDERLINE_ALPHA = 0.35f

    /** 选中日 / 今天的日期透明度（Dart `:243`：选中 0.9、今天 0.78）。 */
    const val SELECTED_DATE_ALPHA = 0.9f
    const val TODAY_DATE_ALPHA = 0.78f

    /** 考试 / 日程圆点直径（Dart `:330` / `:347` `width: 4, height: 4`）。 */
    const val DOT_SIZE_DP = 4f

    /** 两枚圆点之间（Dart `:340` `SizedBox(width: 2)`）。 */
    const val DOT_GAP_DP = 2f

    /** 次要墨色的透明度：浅墨 0.72 / 深墨 0.70（Dart `homePageOverWallpaperMutedInk`）。 */
    const val MUTED_INK_LIGHT_ALPHA = 0.72f
    const val MUTED_INK_DARK_ALPHA = 0.70f

    /**
     * `MM/DD` 两位补零（Dart `:309` `padLeft(2, '0')`）。
     *
     * 固定用 [Locale.ROOT]：Dart 的 `padLeft` 产出的是 ASCII 数字，
     * 跟随默认 Locale 会在阿拉伯语等区域产出本地化数字，与 Dart 对不上。
     */
    fun dateText(date: LocalDate): String =
        String.format(Locale.ROOT, "%02d/%02d", date.monthValue, date.dayOfMonth)

    /**
     * 某一周某一天对应的日历日期（Dart `_dateForWeekDay`，`:57-75`）。
     *
     * 学期起始日先**归一化到周一**（`start - (start.dayOfWeek.value - 1)`），
     * 再按「第几周 / 星期几」偏移；没有学期起始日 ⇒ `null`（Dart 同样返回 null，
     * 此时日期文本为空、`isToday` 恒 false）。
     */
    fun dateForWeekDay(
        semesterStartDate: LocalDate?,
        week: Int,
        dayOfWeek: Int,
    ): LocalDate? {
        val start = semesterStartDate ?: return null
        val monday = start.minusDays((start.dayOfWeek.value - 1).toLong())
        return monday.plusDays(((week - 1) * 7 + (dayOfWeek - 1)).toLong())
    }
}

/**
 * 课表周视图的星期信息栏（对应 Flutter `lib/widgets/timetable/timetable_weekday_header.dart`）。
 *
 * ## 这一版按 Dart 逐条复刻（2026-10-29 重做）
 *
 * 旧版「看着像」的六处，逐条对上 Dart 后修掉：
 * 1. **星期标签**：旧版写 `一/二/…`，Dart 用 ARB 的 `周一..周日`（`_weekdayLabel`，`:83-98`）；
 * 2. **日期**：旧版只画日号，Dart 画两位补零的 `MM/DD`（`:309`）；
 * 3. **今天**：旧版是蓝胶囊 + 白字，Dart 是**底部 2dp 强调色下划线**（alpha 0.35，`:272-281`），
 *    而且选中日与今天互斥（`showsTodayMarker = isToday && !isSelected`，`:246`）；
 * 4. **左端**：旧版显示「10月」，Dart 显示 `{week} 周`（`currentWeekCompact`，`:181`）；
 * 5. **圆点**：旧版没有考试红点 / 日程圆点；Dart 在格子底部居中横排两枚 4dp 圆点
 *    （考试用 `colorScheme.error`、日程用星期强调色，`:317-361`）；
 * 6. **颜色来源**：旧版直接用 `QingyuTheme.primary`，Dart 读用户设置的星期栏字色与强调色
 *    （`:210-237`）；这里改读 [WeekViewStyle.weekdayFontColorLight] /
 *    [WeekViewStyle.weekdayAccentColorLight] 等键。
 *
 * ## 刻意没做的
 *
 * - **壁纸明暗自适应**（Dart 的 `homePageOverWallpaperInk` / `Accent` 的对比度推明度分支）：
 *   Compose 侧周视图还没有壁纸与预糊管线，走 Dart「无壁纸」那一条分支即可 ——
 *   `configured ?? themeFallback`（`lib/utils/home_page_background.dart:774-776`）。
 * - **日视图的三周叠放 / 跟手平移**（`:400-463`）：那是日视图的 pager 联动，
 *   由日视图页面自己组合，不在本组件职责内。
 * - **选中指示条的滑动形变**（`timetable_weekday_selection_indicator.dart`）：
 *   它需要 `PageController` 逐帧位置，属日视图 pager 的接线，另开一条线。
 *
 * @param week 这一行展示的是第几周（决定日期与左端周次文本）。
 * @param currentWeek 当前真实周次。**Dart 的星期栏不标「本周」**，此参数只为调用方语义保留。
 * @param todayDate 判定「今天」用的日期，默认取系统今天（可注入固定值便于自测）。
 * @param semesterStartDate 学期起始日；为 null 时日期文本为空、不算今天。
 * @param visibleDays 可见的星期序号（1=周一），隐藏周末时传 1..5。
 * @param style 周视图渲染风格（读星期栏字色 / 强调色 / 字体口径）。
 * @param selectedDayOfWeek 选中的星期（日视图用），用强调色但不画下划线。
 * @param hasExamOnDate 该日期是否有考试（画红点）。
 * @param hasScheduleOnDate 该日期是否有日程（画强调色圆点）。
 * @param timeColumnWidth 左侧周次格的宽度，与时间列对齐。
 * @param height 整条栏高（Dart 固定 40dp）。
 * @param onDayClick 点某一天的回调（带 1..7 的星期序号）。
 * @param onWeekTitleClick 点左端周次文本（打开周次选择器）。
 */
@Suppress("UNUSED_PARAMETER")
@Composable
fun TimetableWeekdayHeader(
    week: Int,
    currentWeek: Int? = null,
    todayDate: LocalDate = LocalDate.now(),
    semesterStartDate: LocalDate? = null,
    visibleDays: List<Int> = (1..7).toList(),
    style: WeekViewStyle = WeekViewStyle(),
    selectedDayOfWeek: Int? = null,
    hasExamOnDate: (LocalDate) -> Boolean = { false },
    hasScheduleOnDate: (LocalDate) -> Boolean = { false },
    /**
     * 星期栏背后壁纸的平均亮度（Dart `homePageOverWallpaperInk` 的输入，
     * `home_page_background.dart:763-799`）。**null = 没壁纸 / 亮度未知 ⇒ 用设置/主题原色**。
     *
     * 非 null 时：用户挑的字色对比度够（≥3:1）就保留；不够就保色相推到够；
     * 没有配置色（= 用的是主题默认）才按亮度直接翻黑/白。深壁纸上的星期栏/日期
     * 以前沿用深色主题字 ⇒ 黑字压黑底看不见（2026-11-01 用户报）。
     */
    wallpaperLuminance: Double? = null,
    timeColumnWidth: Dp = 34.dp,
    height: Dp = WeekdayHeaderMetrics.HEIGHT_DP.dp,
    onDayClick: (dayOfWeek: Int) -> Unit = {},
    onWeekTitleClick: () -> Unit = {},
    modifier: Modifier = Modifier,
) {
    val dark = isSystemInDarkTheme()
    // 墨色来源：用户设置的星期栏字色 / 强调色（Dart `:210-237` 读的两个 hex 键）。
    // 解析失败时回落主题语义槽（Dart `themeFallback`），不写死任何色值。
    // 压在壁纸上时再经 [HomeBackgroundModel.inkOverWallpaperArgb] 做对比度适配。
    val weekdayInk = Color(
        HomeBackgroundModel.inkOverWallpaperArgb(
            configuredArgb = HomeBackgroundModel.parseHexArgb(
                if (dark) style.weekdayFontColorDark else style.weekdayFontColorLight,
            ),
            fallbackArgb = MiuixTheme.colorScheme.onSurface.toArgb(),
            wallpaperLuminance = wallpaperLuminance,
        ),
    )
    val accentInk = Color(
        HomeBackgroundModel.inkOverWallpaperArgb(
            configuredArgb = HomeBackgroundModel.parseHexArgb(
                if (dark) style.weekdayAccentColorDark else style.weekdayAccentColorLight,
            ),
            fallbackArgb = MiuixTheme.colorScheme.primary.toArgb(),
            wallpaperLuminance = wallpaperLuminance,
        ),
    )
    // 分隔线：无壁纸档 Dart 用 `HyperosColors.dividerLine` + 0.5dp（`:122-125`）。
    val dividerColor = Color(QingyuTheme.dividerLine(dark))
    // 考试红点用主题的 error 语义色（Dart `colorScheme.error`，`:334`）。
    val examDotColor = MiuixTheme.colorScheme.error

    Column(modifier = modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .height(height),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            // ── 左端：周次格（点开周次选择器） ──
            Box(
                modifier = Modifier
                    .width(timeColumnWidth)
                    .fillMaxHeight()
                    .clickable(onClick = onWeekTitleClick),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = TimetableStrings.formatCurrentWeekCompact(week),
                    style = MiuixTheme.textStyles.footnote2.shiftWeight(QingyuWeightDelta.EXTRABOLD),
                    fontSize = WeekdayHeaderMetrics.WEEK_LABEL_SP.sp,
                    color = weekdayInk,
                    textAlign = TextAlign.Center,
                    maxLines = 1,
                    modifier = Modifier.padding(
                        start = WeekdayHeaderMetrics.WEEK_LABEL_PADDING_START_DP.dp,
                        end = WeekdayHeaderMetrics.WEEK_LABEL_PADDING_END_DP.dp,
                    ),
                )
            }

            // ── 右侧：每一天一格 ──
            Row(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxHeight(),
            ) {
                for (dayOfWeek in visibleDays) {
                    val date = WeekdayHeaderMetrics.dateForWeekDay(
                        semesterStartDate = semesterStartDate,
                        week = week,
                        dayOfWeek = dayOfWeek,
                    )
                    val isToday = date != null && date == todayDate
                    val isSelected = selectedDayOfWeek == dayOfWeek
                    // Dart `:246`：选中日不画今天下划线，两者互斥。
                    val showsTodayMarker = isToday && !isSelected

                    WeekdayCell(
                        dayOfWeek = dayOfWeek,
                        date = date,
                        isToday = isToday,
                        isSelected = isSelected,
                        showsTodayMarker = showsTodayMarker,
                        weekdayInk = weekdayInk,
                        accentInk = accentInk,
                        examDotColor = examDotColor,
                        hasExam = date != null && hasExamOnDate(date),
                        hasSchedule = date != null && hasScheduleOnDate(date),
                        onClick = { onDayClick(dayOfWeek) },
                        modifier = Modifier
                            .weight(1f)
                            .fillMaxHeight(),
                    )
                }
            }
        }

        // 底部细分隔线
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(WeekdayHeaderMetrics.DIVIDER_DP.dp)
                .background(dividerColor),
        )
    }
}

/**
 * 星期栏里的一天（Dart `:252-367` 的 `Expanded > Material > InkWell > AnimatedContainer`）。
 *
 * 结构对齐：外层点击区 = 整格；内层 `margin: horizontal 1` + `padding: vertical 3`；
 * 今天下划线画在**内层容器的底边**（Dart 的 `Border.bottom`），圆点用悬浮层贴在底部，
 * 不占内容高度（Dart `:285-289` 的注释说明过为什么必须悬浮）。
 */
@Composable
private fun WeekdayCell(
    dayOfWeek: Int,
    date: LocalDate?,
    isToday: Boolean,
    isSelected: Boolean,
    showsTodayMarker: Boolean,
    weekdayInk: Color,
    accentInk: Color,
    examDotColor: Color,
    hasExam: Boolean,
    hasSchedule: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    // Dart `:238-245`：今天 / 选中日整格换成强调色，日期再用更淡的同色。
    val labelColor = if (isSelected || isToday) accentInk else weekdayInk
    val dateColor = when {
        isSelected -> accentInk.copy(alpha = WeekdayHeaderMetrics.SELECTED_DATE_ALPHA)
        isToday -> accentInk.copy(alpha = WeekdayHeaderMetrics.TODAY_DATE_ALPHA)
        else -> weekdayInk.mutedInk()
    }
    val underlineColor = accentInk.copy(alpha = WeekdayHeaderMetrics.TODAY_UNDERLINE_ALPHA)
    val dateText = date?.let { WeekdayHeaderMetrics.dateText(it) }.orEmpty()

    Box(modifier = modifier.clickable(onClick = onClick)) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = WeekdayHeaderMetrics.CELL_MARGIN_HORIZONTAL_DP.dp)
                .drawBehind {
                    if (!showsTodayMarker) return@drawBehind
                    val thickness = WeekdayHeaderMetrics.TODAY_UNDERLINE_DP.dp.toPx()
                    drawRect(
                        color = underlineColor,
                        topLeft = Offset(0f, size.height - thickness),
                        size = Size(size.width, thickness),
                    )
                }
                .padding(vertical = WeekdayHeaderMetrics.CELL_PADDING_VERTICAL_DP.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
        ) {
            Text(
                text = TimetableStrings.formatWeekday(dayOfWeek),
                style = MiuixTheme.textStyles.footnote2.shiftWeight(
                    if (isSelected || isToday) QingyuWeightDelta.EXTRABOLD else QingyuWeightDelta.SEMIBOLD,
                ),
                fontSize = WeekdayHeaderMetrics.WEEKDAY_LABEL_SP.sp,
                color = labelColor,
                textAlign = TextAlign.Center,
                maxLines = 1,
            )
            Spacer(modifier = Modifier.height(WeekdayHeaderMetrics.LABEL_GAP_DP.dp))
            Text(
                text = dateText,
                style = MiuixTheme.textStyles.footnote2,
                fontSize = WeekdayHeaderMetrics.DATE_LABEL_SP.sp,
                color = dateColor,
                textAlign = TextAlign.Center,
                maxLines = 1,
            )
        }

        // 考试 / 日程圆点：悬浮在格子底部居中，不参与内容高度分配。
        if (hasExam || hasSchedule) {
            Row(
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .padding(vertical = WeekdayHeaderMetrics.CELL_PADDING_VERTICAL_DP.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                if (hasExam) {
                    Box(
                        modifier = Modifier
                            .size(WeekdayHeaderMetrics.DOT_SIZE_DP.dp)
                            .background(examDotColor, CircleShape),
                    )
                }
                if (hasExam && hasSchedule) {
                    Spacer(modifier = Modifier.width(WeekdayHeaderMetrics.DOT_GAP_DP.dp))
                }
                if (hasSchedule) {
                    Box(
                        modifier = Modifier
                            .size(WeekdayHeaderMetrics.DOT_SIZE_DP.dp)
                            .background(accentInk, CircleShape),
                    )
                }
            }
        }
    }
}

/**
 * 由主墨色派生的次要墨色（Dart `homePageOverWallpaperMutedInk`，`home_page_background.dart:999-1010`）。
 *
 * 浅墨（亮度 > 0.55）压到 0.72、深墨压到 0.70 —— 这两档是 Dart 的实测值，
 * 不是随手取的 85%。
 */
private fun Color.mutedInk(): Color =
    copy(
        alpha = if (luminance() > 0.55f) {
            WeekdayHeaderMetrics.MUTED_INK_LIGHT_ALPHA
        } else {
            WeekdayHeaderMetrics.MUTED_INK_DARK_ALPHA
        },
    )
