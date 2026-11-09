package com.mutx163.qingyu.pages.timetable

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
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
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.luminance
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.shiftWeight
import com.mutx163.qingyu.pages.shell.HomeBackgroundModel
import com.mutx163.qingyu.pages.timetable.day.WeekdayHeaderSlideResolver
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
     * 选中指示蓝条（简化自 Dart `timetable_weekday_selection_indicator.dart`，动效保持简单）：
     * 高度 3dp、最大宽 22dp、宽占格比 0.34、滑动时长 220ms。
     */
    const val SELECTION_BAR_HEIGHT_DP = 3f
    const val SELECTION_BAR_MAX_WIDTH_DP = 22f
    const val SELECTION_BAR_WIDTH_RATIO = 0.34f
    const val SELECTION_BAR_ANIM_MS = 220

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
 * 日视图 → 星期栏的实时桥：选中日 + **连续页号**。
 *
 * 只驱动**显示**（选中高亮、蓝条跟手、跨周整条平移），**不落盘**：落盘仍走
 * `DayViewPage` 停稳后的 `onPageChanged`（避免快速连续切日时每页重写整份设置 JSON）。
 *
 * 由 `TimetableWeekPage` 用 `CompositionLocalProvider` 注入给 dayContent；独立日页
 * 自己建一份（见 `DayViewPage`）；周视图 / 预览为 null。
 */
class DaySelectionBridge {
    var week by mutableIntStateOf(1)
    var dayOfWeek by mutableIntStateOf(1)

    /**
     * 分页器的**连续**页号（`currentPage + currentPageOffsetFraction`）。
     *
     * `NaN` = 还没量到（周视图 / 预览 / 日页首帧之前）⇒ 星期栏退回离散的
     * [week] / [dayOfWeek]，行为与旧版一致。
     */
    var pagePosition by mutableFloatStateOf(Float.NaN)

    fun update(week: Int, dayOfWeek: Int) {
        this.week = week
        this.dayOfWeek = dayOfWeek
    }

    fun updatePagePosition(pagePosition: Float) {
        this.pagePosition = pagePosition
    }

    /**
     * 日视图「横向拖星期栏换日」的出口（Dart `timetable_screen.dart:3996-4004`
     * `day-view-weekday-bar-swipe-area`：整条栏盖一块刮擦层，位移按可见天数放大后
     * 注入日分页器，一根栏宽 = 一整周）。
     *
     * 由真正持有分页器的日页写入（`DayViewPage`）；`null` = 周视图 / 预览 / 没有
     * 分页器 ⇒ 星期栏不装刮擦手势、只保留点选。必须是 Compose 状态：日页在星期栏
     * **之后**组合，普通 var 改了不会让已经画出来的栏重新装手势。
     *
     * 参数单位是「天」，正数 = 往后一天。
     */
    var onScrubShift: ((deltaDays: Int) -> Unit)? by mutableStateOf(null)
}

/** `null` = 不是首页嵌入的日视图（周视图 / 独立日页 / 预览），星期栏用传入的参数值。 */
val LocalDaySelectionBridge = compositionLocalOf<DaySelectionBridge?> { null }

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
 * - ~~壁纸明暗自适应~~ **2026-11-01 已补**：`wallpaperLuminance` 非空时，字色 / 强调色走
 *   `HomeBackgroundModel.inkOverWallpaperArgb`（Dart `homePageOverWallpaperInk` 同口径）；
 *   无壁纸 / 亮度未知时仍是 `configured ?? themeFallback`（`:774-776`）。
 * - ~~日视图的三周叠放 / 跟手平移~~ **2026-11-08 已补**：日视图把分页器的连续页号经
 *   [DaySelectionBridge.pagePosition] 送进来后，跨周段由 `WeekdayRow` 两行错位平移复刻
 *   Dart `:400-463`（几何换算在 `WeekdayHeaderSlideResolver`）。同一周内整条不动，
 *   只有选中指示条跟着页号小数走。
 * - **选中指示条的滑动形变**（`timetable_weekday_selection_indicator.dart`）：
 *   Dart 在格位之间会拉宽 / 边缘回拉；这里仍只做整体平移，形变未复刻。
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
    /**
     * 学期总周数：跨周平移时把页号夹在学期内（`null` = 不夹，按页号原样画）。
     * 只影响末周边界的防呆，不影响常态滚动。
     */
    totalWeeks: Int? = null,
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
    /** 月视图：只画月份 + 星期列，日期/今天/考试点都不画；列几何与周/日完全一致。 */
    monthMode: Boolean = false,
    /** 月视图左端显示的月份（如“11月”）；非月视图忽略。 */
    monthLabel: String? = null,
    timeColumnWidth: Dp = 34.dp,
    height: Dp = WeekdayHeaderMetrics.HEIGHT_DP.dp,
    onDayClick: (dayOfWeek: Int) -> Unit = {},
    onWeekTitleClick: () -> Unit = {},
    /**
     * 首页嵌入日视图时的**实时选中桥**（`null` = 周视图 / 独立日页 / 预览，用 [week]/[selectedDayOfWeek] 参数）。
     * 非 null 时星期栏改读桥里的实时值：切换日时选中高亮即时跟手、蓝条平滑滑动，不受外层「停稳才回写」影响。
     */
    selectionBridge: DaySelectionBridge? = null,
    modifier: Modifier = Modifier,
) {
    val dark = isSystemInDarkTheme()
    // 生效的周次 / 选中日：嵌日视图时用实时桥（每翻一页即更新），否则用传入参数。
    val effectiveWeek = selectionBridge?.week ?: week
    val effectiveSelectedDayOfWeek = selectionBridge?.dayOfWeek ?: selectedDayOfWeek
    val selectionIndex = effectiveSelectedDayOfWeek?.let { visibleDays.indexOf(it) } ?: -1
    // 蓝条位置：以「有/无选中」为 key 重建 Animatable —— 首次出现（周视图→日视图首帧）直接
    // 定位到目标格、**不做滑动**；同一选中态内的真实切日才 animateTo 平滑滑过去（跟手）。
    val barAnim = remember(selectionIndex >= 0) {
        Animatable(if (selectionIndex >= 0) selectionIndex.toFloat() else 0f)
    }
    LaunchedEffect(selectionIndex) {
        if (selectionIndex >= 0) {
            barAnim.animateTo(
                targetValue = selectionIndex.toFloat(),
                animationSpec = tween(durationMillis = WeekdayHeaderMetrics.SELECTION_BAR_ANIM_MS),
            )
        }
    }
    // 墨色来源：用户设置的星期栏字色 / 强调色（Dart `:210-237` 读的两个 hex 键）。
    // 解析失败时回落主题语义槽（Dart `themeFallback`），不写死任何色值。
    // 压在壁纸上时再经 [HomeBackgroundModel.inkOverWallpaperArgb] 做对比度适配。
    val weekdayInk = Color(
        HomeBackgroundModel.inkOverWallpaperArgb(
            configuredArgb = HomeBackgroundModel.parseInkArgb(
                if (dark) style.weekdayFontColorDark else style.weekdayFontColorLight,
            ),
            fallbackArgb = MiuixTheme.colorScheme.onSurface.toArgb(),
            wallpaperLuminance = wallpaperLuminance,
            // 设置里的出厂值（浅色 #000000 / 深色 #FFFFFF）与「没改过」等价：
            // 压在壁纸上时按亮度**直接翻黑/白**，不是把黑字推成中灰（Dart `:740-750`）。
            builtInDefaultArgb = if (dark) 0xFFFFFFFF.toInt() else 0xFF000000.toInt(),
        ),
    )
    val accentInk = Color(
        HomeBackgroundModel.inkOverWallpaperArgb(
            // 强调色是有色相的，不做「默认翻黑白」：对比度不够时保色相推亮度（Dart 同口径）。
            configuredArgb = HomeBackgroundModel.parseInkArgb(
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

    // ── 连续页号 → 跨周滑动几何（Dart `timetable_weekday_header.dart:400-463`）──
    // 只有日视图的桥会带连续页号；NaN（周视图 / 预览 / 日页首帧之前）走旧的离散口径。
    val continuousPage = selectionBridge?.pagePosition?.takeIf { it.isFinite() }
    val slide = continuousPage?.let {
        WeekdayHeaderSlideResolver.resolve(
            pagePosition = it,
            visibleDayCount = visibleDays.size,
            totalWeeks = totalWeeks ?: Int.MAX_VALUE,
        )
    }
    // 选中格只标在「这一行就是当前周」上：跨周过半后桥里的周次已翻到下一周，
    // 高亮与选中条在同一刻交接到滑入行（分页器换页也在中点）。
    fun selectedOnRow(rowWeek: Int): Int? =
        effectiveSelectedDayOfWeek?.takeIf { rowWeek == effectiveWeek }

    // ── 日视图：横向拖星期栏 = 跟手换日（Dart `timetable_screen.dart:3996-4004`）──
    // 只有日页把回调写进桥时才装手势（周视图 / 预览没有分页器 ⇒ 不装，点选不受影响）。
    // 换算口径与 Dart 的放大一致：一根栏宽 = 一整周，滑过一格宽就换一天。
    val scrubShift = selectionBridge?.onScrubShift
    val haptic = LocalHapticFeedback.current
    val scrubModifier = if (scrubShift == null) {
        Modifier
    } else {
        Modifier.pointerInput(scrubShift, visibleDays) {
            var accumulated = 0f
            detectHorizontalDragGestures(
                onDragStart = { accumulated = 0f },
                onHorizontalDrag = { change, dragAmount ->
                    change.consume()
                    accumulated += dragAmount
                    val dayCount = visibleDays.size.coerceAtLeast(1)
                    val stepWidth = size.width / dayCount.toFloat()
                    if (stepWidth > 0f) {
                        // 往右拖 = 上一天；往左拖 = 下一天（内容跟手）。
                        // 一次手势跨多格就连翻多天，每翻一天保留一次「切日」触感
                        //（Dart：整段拖动只保留日切换点击震感）。
                        while (accumulated <= -stepWidth) {
                            accumulated += stepWidth
                            scrubShift(1)
                            haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                        }
                        while (accumulated >= stepWidth) {
                            accumulated -= stepWidth
                            scrubShift(-1)
                            haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                        }
                    }
                },
            )
        }
    }

    Column(
        modifier = modifier
            .fillMaxWidth()
            .then(scrubModifier),
    ) {
        if (slide != null && slide.crossing) {
            // ── 跨周：整条（周次 + 七天 + 选中条）跟着分页器平移 ──
            // 同一周内整条不动，只有选中条跟手；只有这一格过渡段才把上一周整行滑出、
            // 下一周整行滑入，接缝处不留空档。
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(height)
                    .clipToBounds(),
            ) {
                WeekdayRow(
                    rowWeek = slide.outgoingWeek,
                    selectedDayOfWeek = selectedOnRow(slide.outgoingWeek),
                    showSelection = slide.showSelectionOnOutgoing,
                    selectionPosition = { slide.outgoingSelection },
                    translationFraction = -slide.progress,
                    todayDate = todayDate,
                    semesterStartDate = semesterStartDate,
                    visibleDays = visibleDays,
                    weekdayInk = weekdayInk,
                    accentInk = accentInk,
                    examDotColor = examDotColor,
                    hasExamOnDate = hasExamOnDate,
                    hasScheduleOnDate = hasScheduleOnDate,
                    timeColumnWidth = timeColumnWidth,
                    height = height,
                    monthMode = monthMode,
                    monthLabel = monthLabel,
                    onDayClick = onDayClick,
                    onWeekTitleClick = onWeekTitleClick,
                )
                WeekdayRow(
                    rowWeek = slide.incomingWeek,
                    selectedDayOfWeek = selectedOnRow(slide.incomingWeek),
                    showSelection = !slide.showSelectionOnOutgoing,
                    selectionPosition = { slide.incomingSelection },
                    translationFraction = 1f - slide.progress,
                    todayDate = todayDate,
                    semesterStartDate = semesterStartDate,
                    visibleDays = visibleDays,
                    weekdayInk = weekdayInk,
                    accentInk = accentInk,
                    examDotColor = examDotColor,
                    hasExamOnDate = hasExamOnDate,
                    hasScheduleOnDate = hasScheduleOnDate,
                    timeColumnWidth = timeColumnWidth,
                    height = height,
                    monthMode = monthMode,
                    monthLabel = monthLabel,
                    onDayClick = onDayClick,
                    onWeekTitleClick = onWeekTitleClick,
                )
            }
        } else {
            // 静止 / 同一周内换日：只有一行。有连续页号时选中条按小数格位直接跟手
            // （拖到哪儿条就在哪儿）；没有时退回 220ms 的 Animatable（旧行为）。
            val rowWeek = slide?.outgoingWeek ?: effectiveWeek
            WeekdayRow(
                rowWeek = rowWeek,
                selectedDayOfWeek = selectedOnRow(rowWeek),
                showSelection = true,
                selectionPosition = {
                    if (slide != null) {
                        slide.outgoingSelection
                    } else if (selectionIndex >= 0) {
                        barAnim.value
                    } else {
                        null
                    }
                },
                translationFraction = 0f,
                todayDate = todayDate,
                semesterStartDate = semesterStartDate,
                visibleDays = visibleDays,
                weekdayInk = weekdayInk,
                accentInk = accentInk,
                examDotColor = examDotColor,
                hasExamOnDate = hasExamOnDate,
                hasScheduleOnDate = hasScheduleOnDate,
                timeColumnWidth = timeColumnWidth,
                height = height,
                monthMode = monthMode,
                monthLabel = monthLabel,
                onDayClick = onDayClick,
                onWeekTitleClick = onWeekTitleClick,
            )
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
 * 星期栏的一整行（Dart `fullWeekRowFor`，`timetable_weekday_header.dart:150-390`）：
 * 左端周次格 + 七天格 + 选中指示条。跨周时同一帧里画两行，按 [translationFraction]
 * 错位平移（0 = 正常位置，-1 = 整行滑出左侧，1 = 整行停在右侧待入）。
 *
 * @param translationFraction 相对整条栏宽度的平移比例（绘制期生效，不触发重新测量）。
 * @param selectionPosition 该行选中指示的**小数格位**（0 .. 可见天数-1）；`null` = 不画。
 *   以 lambda 传入，让 Animatable 在绘制期读取，避免每帧重组。
 * @param showSelection 跨周过渡时选中条只画在一行上（Dart `extrasOnOutgoing`）。
 */
@Composable
private fun WeekdayRow(
    rowWeek: Int,
    selectedDayOfWeek: Int?,
    showSelection: Boolean,
    selectionPosition: () -> Float?,
    translationFraction: Float,
    todayDate: LocalDate,
    semesterStartDate: LocalDate?,
    visibleDays: List<Int>,
    weekdayInk: Color,
    accentInk: Color,
    examDotColor: Color,
    hasExamOnDate: (LocalDate) -> Boolean,
    hasScheduleOnDate: (LocalDate) -> Boolean,
    timeColumnWidth: Dp,
    height: Dp,
    monthMode: Boolean,
    monthLabel: String?,
    onDayClick: (dayOfWeek: Int) -> Unit,
    onWeekTitleClick: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(height)
            .graphicsLayer { translationX = translationFraction * size.width },
        verticalAlignment = Alignment.CenterVertically,
    ) {
        // ── 左端：周次格（点开周次选择器） ──
        Box(
            modifier = Modifier
                .width(timeColumnWidth)
                .fillMaxHeight()
                .clickable(enabled = !monthMode, onClick = onWeekTitleClick),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = if (monthMode) {
                    monthLabel.orEmpty()
                } else {
                    TimetableStrings.formatCurrentWeekCompact(rowWeek)
                },
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
                .fillMaxHeight()
                // 选中指示蓝条（简化版 Dart selection indicator）：画在本行底边，
                // 位置取选中格的小数下标；日视图里由分页器逐帧驱动，周视图不画。
                .drawBehind {
                    if (!showSelection || visibleDays.isEmpty()) return@drawBehind
                    val position = selectionPosition() ?: return@drawBehind
                    val slot = size.width / visibleDays.size
                    val barW = minOf(
                        WeekdayHeaderMetrics.SELECTION_BAR_MAX_WIDTH_DP.dp.toPx(),
                        slot * WeekdayHeaderMetrics.SELECTION_BAR_WIDTH_RATIO,
                    )
                    val barH = WeekdayHeaderMetrics.SELECTION_BAR_HEIGHT_DP.dp.toPx()
                    val maxLeft = (size.width - barW).coerceAtLeast(0f)
                    val left = (slot * position + (slot - barW) / 2f).coerceIn(0f, maxLeft)
                    drawRoundRect(
                        color = accentInk,
                        topLeft = Offset(left, size.height - barH),
                        size = Size(barW, barH),
                        cornerRadius = CornerRadius(barH / 2f),
                    )
                },
        ) {
            for (dayOfWeek in visibleDays) {
                val date = WeekdayHeaderMetrics.dateForWeekDay(
                    semesterStartDate = semesterStartDate,
                    week = rowWeek,
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
                    enabled = !monthMode,
                    onClick = { onDayClick(dayOfWeek) },
                    modifier = Modifier
                        .weight(1f)
                        .fillMaxHeight(),
                )
            }
        }
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
    /** 月视图：日期行用空格占位，保持星期文字与周/日同一 y。 */
    reserveDateLine: Boolean = false,
    enabled: Boolean = true,
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
    val dateText = date?.let { WeekdayHeaderMetrics.dateText(it) }
        ?: if (reserveDateLine) " " else ""

    Box(modifier = modifier.clickable(enabled = enabled, onClick = onClick)) {
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
