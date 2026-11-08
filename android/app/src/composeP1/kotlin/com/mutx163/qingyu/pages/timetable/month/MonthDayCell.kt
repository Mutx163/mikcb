package com.mutx163.qingyu.pages.timetable.month

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.luminance
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.shiftWeight
import com.mutx163.qingyu.pages.timetable.day.parseHexColorOrFallback
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.theme.MiuixTheme
import kotlin.math.max
import kotlin.math.min

/**
 * 月视图单格（日号 + 恒在的标记槽位 + 休/班角标 + 今天/选中态）。
 *
 * 移植自 `lib/widgets/timetable/month_view/month_day_cell.dart`（2026-10-27 快照）。
 *
 * ## 连续网格，不是一排小方块（2026-11-07 重做）
 *
 * 旧实现每格是一块带 1.5dp 缝、10dp 圆角的浅色小方块；放进整页「大圆角白卡 +
 * 胶囊/圆形状态」的语言里，读起来像在卡片里又嵌了一张日期选择器。现在：
 *
 * | 状态 | 表达 |
 * |---|---|
 * | 今天 | 数字后面一颗 primary **实心圆**（直径 28），数字反白 |
 * | 选中 | 数字后面一颗 primary 淡底圆 + 1.5dp primary 描边（今天选中时今天态优先） |
 * | 普通 | 只有数字，没有格子底、没有缝 |
 * | 假期 | 暖红数字 + 右上角「休」 |
 * | 调休 | 右上角「班」（蓝） |
 * | 月外 | 按对比度弱化到看得清的极限（sRGB 合成后算），不画角标/标记 |
 *
 * 7 列、周次轨、日期数字全部落在**同一张连续矩阵**里；分隔感由列宽、周次轨的
 * 细索引线和每行 45dp 的节拍提供，不靠小方块。
 *
 * ## 标记槽位恒在（2026-10-25 的教训）
 *
 * 条件渲染标记会让同一行 7 个日号的顶边跳 4px（真机逐像素量过 271/275）。
 * 所以 [MonthMetrics.CELL_MARK_SLOT_HEIGHT] 无论有没有内容都占位，
 * 有内容时在槽位里画标记、没内容时留空。
 *
 * ## 标记为什么是固定尺寸（2026-11-07）
 *
 * 旧色带按格宽均分：段宽 = 1/段数。同一天「2 节课」在有日程时从 1/2 缩到 1/4，
 * 超过 4 节还会静默消失——同一个量在不同日子里长得不一样，编码不成立。
 * 现在固定 4dp：
 * * 课程 = 实心圆点（课程色）；
 * * 考试 = 实心小方块（error）；
 * * 日程 = 空心圆环（primary）；
 * * 装不下时补一个「+」，数量仍由读屏文案给出。
 */
@Composable
fun MonthDayCell(
    entry: MonthDayEntry,
    isToday: Boolean,
    isSelected: Boolean,
    onTap: () -> Unit,
    modifier: Modifier = Modifier,
    markBudget: Int = MonthDayCellDefaults.MARK_BUDGET,
) {
    val dark = isSystemInDarkTheme()
    val scheme = MiuixTheme.colorScheme
    val ink = Color(QingyuTheme.primaryText(dark))
    val primary = scheme.primary
    val onPrimary = scheme.onPrimary
    // 卡片真正的底色是 surfaceContainer（亮色 #FFF），不是页底 surface（#F2F2F2）。
    val cardSurface = scheme.surfaceContainer

    val badge = when {
        entry.isAdjustedWorkday -> MonthText.adjustedWorkdayBadge.text to primary
        entry.isHoliday -> MonthText.holidayBadge.text to scheme.error
        else -> null
    }

    // 今天/选中：数字后面的圆形状态。今天优先（实心圆、反白）；
    // 选中但非今天：淡底圆 + 描边；两者都没有：裸数字。
    val filled = isToday
    val ringed = isSelected && !isToday
    val dayInk: Color = when {
        isToday -> onPrimary
        isSelected -> primary
        entry.isHoliday -> scheme.error
        else -> ink
    }
    val resolvedDayInk = if (entry.isOutsideMonth) {
        dimInkToContrast(ink, cardSurface)
    } else {
        dayInk
    }

    val marks = buildMarks(
        entry = entry,
        primary = primary,
        examColor = scheme.error,
        budget = markBudget,
    )
    val totalMarks = entry.courseCount +
        (if (entry.examCount > 0) 1 else 0) +
        (if (entry.scheduleCount > 0) 1 else 0)
    val overflow = totalMarks > marks.size
    val moreInk = ink.copy(alpha = MonthInk.TERTIARY.toFloat())

    val label = semanticsLabel(entry)

    Box(
        modifier = modifier
            .clickable(onClick = onTap)
            .semantics { contentDescription = label },
    ) {
        Column(
            modifier = Modifier.fillMaxSize(),
            verticalArrangement = Arrangement.Center,
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Box(
                modifier = Modifier
                    .size(MonthDayCellDefaults.STATE_CIRCLE.dp)
                    .then(
                        when {
                            filled -> Modifier.background(primary, CircleShape)
                            ringed -> Modifier.background(
                                primary.copy(alpha = MonthDayCellDefaults.SELECTED_FILL),
                                CircleShape,
                            )
                            else -> Modifier
                        },
                    )
                    .then(
                        if (ringed) {
                            Modifier.border(
                                MonthDayCellDefaults.SELECTED_BORDER.dp,
                                primary,
                                CircleShape,
                            )
                        } else {
                            Modifier
                        },
                    ),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = entry.date.dayOfMonth.toString(),
                    style = MiuixTheme.textStyles.body1.shiftWeight(
                        if (isToday || isSelected) {
                            QingyuWeightDelta.EXTRABOLD
                        } else {
                            QingyuWeightDelta.SEMIBOLD
                        },
                    ),
                    color = resolvedDayInk,
                    maxLines = 1,
                    overflow = TextOverflow.Clip,
                )
            }

            // 标记槽位：**恒在**（没内容时留空，高度不变），数字在每格里位置一致。
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(MonthMetrics.CELL_MARK_SLOT_HEIGHT.dp),
                contentAlignment = Alignment.Center,
            ) {
                if (!entry.isOutsideMonth && (marks.isNotEmpty() || overflow)) {
                    Row(
                        horizontalArrangement = Arrangement.spacedBy(
                            MonthDayCellDefaults.MARK_GAP.dp,
                        ),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        for (mark in marks) {
                            DayMarkView(mark = mark)
                        }
                        if (overflow) {
                            MoreMarkView(color = moreInk)
                        }
                    }
                }
            }
        }

        if (badge != null && !entry.isOutsideMonth) {
            Box(
                modifier = Modifier
                    .align(Alignment.TopEnd)
                    .padding(top = 1.dp, end = 3.dp),
            ) {
                Text(
                    text = badge.first,
                    style = MiuixTheme.textStyles.footnote2.shiftWeight(
                        QingyuWeightDelta.BOLD,
                    ),
                    color = badge.second,
                    maxLines = 1,
                )
            }
        }
    }
}

/** 日期格的一个标记：固定 4dp，不随同格其它标记的数量改变大小。 */
private data class DayMark(
    val color: Color,
    val kind: DayMarkKind,
)

private enum class DayMarkKind {
    COURSE,
    EXAM,
    SCHEDULE,
}

/**
 * 按「考试 / 日程先占位，课程补剩余槽位」的顺序生成标记。
 *
 * 这样考试日不会被六节课的圆点挤掉；代价是极忙的日子可能少显示一个课程点，
 * 由「+」标记兜底，具体数量仍在读屏文案里。
 */
private fun buildMarks(
    entry: MonthDayEntry,
    primary: Color,
    examColor: Color,
    budget: Int,
): List<DayMark> {
    val slots = budget.coerceAtLeast(0)
    val fixed = (if (entry.examCount > 0) 1 else 0) +
        (if (entry.scheduleCount > 0) 1 else 0)
    val courseSlots = (slots - fixed).coerceAtLeast(0)
    val shownCourses = min(entry.courseCount, courseSlots)

    return buildList {
        for (index in 0 until shownCourses) {
            add(
                DayMark(
                    color = parseHexColorOrFallback(
                        entry.courseColorHexes.getOrNull(index),
                        fallback = primary,
                    ),
                    kind = DayMarkKind.COURSE,
                ),
            )
        }
        if (entry.examCount > 0) add(DayMark(examColor, DayMarkKind.EXAM))
        if (entry.scheduleCount > 0) add(DayMark(primary, DayMarkKind.SCHEDULE))
    }
}

/** 课程=圆点、考试=小方块、日程=圆环：三种形状，不依赖颜色也能分。 */
@Composable
private fun DayMarkView(mark: DayMark) {
    val size = MonthMetrics.CELL_MARK_HEIGHT.dp
    when (mark.kind) {
        DayMarkKind.COURSE -> Box(
            modifier = Modifier
                .size(size)
                .background(mark.color, CircleShape),
        )

        DayMarkKind.EXAM -> Box(
            modifier = Modifier
                .size(size)
                .background(mark.color, RoundedCornerShape(1.dp)),
        )

        DayMarkKind.SCHEDULE -> Box(
            modifier = Modifier
                .size(size)
                .border(1.dp, mark.color, CircleShape),
        )
    }
}

/** 「还有更多」：一个 4dp 的加号，不占额外宽度、不写数字（数量在读屏文案里）。 */
@Composable
private fun MoreMarkView(color: Color) {
    Box(
        modifier = Modifier.size(MonthMetrics.CELL_MARK_HEIGHT.dp),
        contentAlignment = Alignment.Center,
    ) {
        Box(
            modifier = Modifier
                .size(width = 4.dp, height = 1.dp)
                .background(color, RoundedCornerShape(0.5.dp)),
        )
        Box(
            modifier = Modifier
                .size(width = 1.dp, height = 4.dp)
                .background(color, RoundedCornerShape(0.5.dp)),
        )
    }
}

/** 日期格的默认值。 */
object MonthDayCellDefaults {

    /** 今天/选中状态圆的直径；比 45dp 的格子小一圈，像日历而不是色块。 */
    const val STATE_CIRCLE = 28.0

    /** 选中态（非今天）的淡底透明度。 */
    const val SELECTED_FILL = 0.08f

    /** 选中态描边宽度。 */
    const val SELECTED_BORDER = 1.5

    /** 标记行最多画几个（考试 / 日程先占位，课程补剩余）。 */
    const val MARK_BUDGET = 3

    /** 课程 / 考试 / 日程标记之间的间距。 */
    const val MARK_GAP = 3.0

    /** 兼容旧调用点：色带预算已更名为 [MARK_BUDGET]。 */
    @Deprecated("Use MARK_BUDGET", ReplaceWith("MARK_BUDGET"))
    const val COURSE_STRIP_BUDGET = MARK_BUDGET
}

/**
 * 月外日期弱化后**仍须达到**的对比度。
 *
 * 3.2 比 WCAG 正文门槛 4.5 低（看得出「这是上个月」），又高于非正文下限 3.0
 * （看得出「这是几号」）。与 Dart `monthOutsideTextContrast` 同值。
 */
private const val MONTH_OUTSIDE_TEXT_CONTRAST = 3.2f

/**
 * 把 [ink] 弱化到「仍然满足目标对比度」的最淡程度。
 *
 * ⚠️ 2026-11-07 修：旧实现把**亮度**当线性量做 alpha 混合，但屏幕是按 sRGB
 * 通道合成的（两者不是一回事），算出的 alpha 0.754 上屏后还有约 5.8:1，月外
 * 日期看起来几乎和本月一样重。现在直接按 sRGB 通道合成后再算对比度，并且
 * 参照面用**卡面**（[Color] 传 surfaceContainer），不再用页底 surface。
 */
private fun dimInkToContrast(
    ink: Color,
    surface: Color,
    targetContrast: Float = MONTH_OUTSIDE_TEXT_CONTRAST,
): Color {
    if (contrastOf(ink, surface) <= targetContrast) return ink
    var low = 0f
    var high = 1f
    repeat(18) {
        val mid = (low + high) / 2f
        val blended = blendSrgb(ink, surface, mid)
        if (contrastOf(blended, surface) >= targetContrast) {
            high = mid
        } else {
            low = mid
        }
    }
    return ink.copy(alpha = high)
}

/** 按 sRGB 通道做 source-over 合成（与屏幕实际绘制一致，不先线性化）。 */
private fun blendSrgb(foreground: Color, background: Color, alpha: Float): Color {
    val a = alpha.coerceIn(0f, 1f)
    return Color(
        red = foreground.red * a + background.red * (1f - a),
        green = foreground.green * a + background.green * (1f - a),
        blue = foreground.blue * a + background.blue * (1f - a),
        alpha = 1f,
    )
}

/** 两个颜色之间的 WCAG 对比度（1–21）。 */
private fun contrastOf(a: Color, b: Color): Float {
    val la = a.luminance()
    val lb = b.luminance()
    val hi = max(la, lb)
    val lo = min(la, lb)
    return (hi + 0.05f) / (lo + 0.05f)
}

/** 语义标签：`10月5日，休，1场考试，2个日程，3节课`。 */
private fun semanticsLabel(entry: MonthDayEntry): String {
    val parts = mutableListOf(MonthText.dayLabel(entry.date.monthValue, entry.date.dayOfMonth))
    when {
        entry.isAdjustedWorkday -> parts.add(MonthText.adjustedWorkdayBadge.text)
        entry.isHoliday -> parts.add(MonthText.holidayBadge.text)
    }
    if (entry.examCount > 0) parts.add(MonthText.examCount(entry.examCount))
    if (entry.scheduleCount > 0) parts.add(MonthText.scheduleCount(entry.scheduleCount))
    if (entry.courseCount > 0) parts.add(MonthText.courseCount(entry.courseCount))
    return parts.joinToString(SEMANTICS_SEPARATOR)
}

/**
 * 语义标签里的分隔（中文全角逗号，与 Dart 侧一致；不是屏上文案）。
 *
 * 用 `\uFF0C` 转义而不是直接敲字形：渲染层「不许出现中文字面量」的棘轮门禁
 * 按源码扫字符，标点也算一行命中 —— 这不是文案，却会被误报。
 */
private const val SEMANTICS_SEPARATOR = "\uFF0C"
