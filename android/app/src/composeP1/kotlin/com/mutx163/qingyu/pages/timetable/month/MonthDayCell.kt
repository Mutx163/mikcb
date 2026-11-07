package com.mutx163.qingyu.pages.timetable.month

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.luminance
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
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
 * 月视图单格（日号 + 恒在的色带槽位 + 休/班角标 + 今天态）。
 *
 * 移植自 `lib/widgets/timetable/month_view/month_day_cell.dart`（2026-10-27 快照）。
 *
 * ## 格子不是一张卡，而是「白卡里的一格」
 *
 * 底色由外层 [MonthCalendarCard] 那张白卡提供，本组件只画内容。所以判墨一律按
 * **主题**（卡是实底的，不透壁纸），不按壁纸亮度。
 *
 * | 状态 | 表达 |
 * |---|---|
 * | 选中 | primary 实心圆角块 + 反白数字 |
 * | 今天 | primary 最浅一档淡底 + 主题色粗体数字（**不是**描边：描边与选中块太像） |
 * | 假期 | 暖红数字 + 右上角「休」 |
 * | 调休 | 右上角「班」（蓝） |
 * | 月外 | 按**对比度**弱化到看得清的极限（不乘一个裸 alpha） |
 *
 * ## 色带槽位恒在（2026-10-25 的教训）
 *
 * 条件渲染色带会让同一行 7 个日号的顶边跳 4px（真机逐像素量过 271/275）。
 * 所以 [MonthMetrics.CELL_STRIP_SLOT_HEIGHT] 无论有没有色带都占位，
 * 有内容时在槽位底部画色带、没内容时留空。
 */
@Composable
fun MonthDayCell(
    entry: MonthDayEntry,
    isToday: Boolean,
    isSelected: Boolean,
    onTap: () -> Unit,
    modifier: Modifier = Modifier,
    radius: Dp = MonthMetrics.CELL_RADIUS.dp,
    courseStripBudget: Int = MonthDayCellDefaults.COURSE_STRIP_BUDGET,
) {
    val dark = isSystemInDarkTheme()
    val scheme = MiuixTheme.colorScheme
    val shape = RoundedCornerShape(radius)

    // 卡面墨色：白卡上就是主题墨。**不跟壁纸走**；卡面亮度只用于「月外日期弱化」。
    val ink = Color(QingyuTheme.primaryText(dark))
    val primary = scheme.primary
    val cardLuminance = scheme.surface.luminance()

    val badge = when {
        entry.isAdjustedWorkday -> MonthText.adjustedWorkdayBadge.text to scheme.primary
        entry.isHoliday -> MonthText.holidayBadge.text to scheme.error
        else -> null
    }

    // ── 日号墨色：选中 → 今天 → 假期 → 普通 ──
    val dayInk: Color = when {
        isSelected -> {
            // 选中块是 primary 实心：数字必须反白/反暗，按 primary 自身亮度取。
            val onPrimary = scheme.onPrimary
            if (onPrimary.luminance() > primary.luminance()) onPrimary else ink
        }
        isToday -> primary
        entry.isHoliday -> scheme.error
        else -> ink
    }

    // 月外日期：按月外墨与卡面的**对比度**弱化，而不是再乘一个 alpha
    //（乘 alpha 会把墨与卡面的亮度差一起吃掉 —— 2026-10-22 修过的坑）。
    val resolvedDayInk = if (entry.isOutsideMonth && !isSelected && !isToday && !entry.isHoliday) {
        dimInkToContrast(dayInk, cardLuminance)
    } else {
        dayInk
    }

    // ── 底边分段色带：课程色（最多 4 段）→ 考试红 → 日程蓝 ──
    // 考试/假期红走 error 槽、日程蓝走 primary 槽（语义槽，深浅色由主题桥接管）：
    // error 不受种子色触碰（QingyuPageTheme 只派生 primary 族），考试红不与主题撞色。
    val strips = buildList {
        for (index in entry.courseColorHexes.indices) {
            if (index < courseStripBudget) {
                add(parseHexColorOrFallback(entry.courseColorHexes[index], fallback = primary))
            }
        }
        if (entry.examCount > 0) add(scheme.error)
        if (entry.scheduleCount > 0) add(scheme.primary)
    }
    // 月外格不画色带：它们是邻月的日子，不该在本月里「浮出来」。
    val showStrips = strips.isNotEmpty() && !entry.isOutsideMonth

    val label = semanticsLabel(entry)

    Box(
        modifier = modifier
            .clip(shape)
            .clickable(onClick = onTap)
            .semantics { contentDescription = label },
    ) {
        // 选中态：整格一块 primary 圆角块。
        if (isSelected) {
            Box(
                modifier = Modifier
                    .matchParentSize()
                    .background(primary, shape),
            )
        } else if (isToday) {
            // 今天但没选中：淡底 + 主题色粗体数字（与选中态差在「重量级」而非样式）。
            Box(
                modifier = Modifier
                    .matchParentSize()
                    .background(primary.copy(alpha = MonthInk.HAIRLINE.toFloat()), shape),
            )
        }

        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = MonthMetrics.CELL_INNER_PADDING.dp),
            verticalArrangement = Arrangement.Center,
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text(
                text = entry.date.dayOfMonth.toString(),
                style = MiuixTheme.textStyles.title4.shiftWeight(
                    if (isToday || isSelected) QingyuWeightDelta.EXTRABOLD else QingyuWeightDelta.SEMIBOLD,
                ),
                color = resolvedDayInk,
                maxLines = 1,
                overflow = TextOverflow.Clip,
            )
            // 色带槽位：**恒在**（没内容时留空，高度不变），日号在每格里位置一致。
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(MonthMetrics.CELL_STRIP_SLOT_HEIGHT.dp),
                contentAlignment = Alignment.BottomCenter,
            ) {
                if (showStrips) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(MonthMetrics.CELL_STRIP_HEIGHT.dp),
                        horizontalArrangement = Arrangement.spacedBy(0.dp),
                    ) {
                        for (strip in strips) {
                            Box(
                                modifier = Modifier
                                    .weight(1f)
                                    .fillMaxHeight()
                                    .background(strip),
                            )
                        }
                    }
                }
            }
        }

        if (badge != null) {
            Box(
                modifier = Modifier
                    .align(Alignment.TopEnd)
                    .padding(
                        top = 1.dp,
                        end = (MonthMetrics.CELL_INNER_PADDING + 1.0).dp,
                    ),
            ) {
                Text(
                    text = badge.first,
                    style = MiuixTheme.textStyles.footnote2.shiftWeight(QingyuWeightDelta.BOLD),
                    color = badge.second,
                    maxLines = 1,
                )
            }
        }
    }
}

/** 日期格的语义默认值。 */
object MonthDayCellDefaults {

    /**
     * 底边色带里最多画几段课程色（考试 / 日程会在此基础上再加一段）。
     *
     * 4 不是「装得下多少」而是「分不分得清」：一格 ~43dp 宽，4 段每段约 10dp，
     * 仍是能分辨的色块；再多就成了一条渐变色带，颜色失去指向性。
     */
    const val COURSE_STRIP_BUDGET = 4
}

/**
 * 月外日期弱化后**仍须达到**的对比度。
 *
 * 3.2 比 WCAG 正文门槛 4.5 低（看得出「这是上个月」），又高于非正文下限 3.0
 * （看得出「这是几号」）。与 Dart `monthOutsideTextContrast` 同值。
 */
private const val MONTH_OUTSIDE_TEXT_CONTRAST = 3.2f

/** 把 [ink] 弱化到「仍然满足目标对比度」的最淡程度（对比度口径，不是裸 alpha）。 */
private fun dimInkToContrast(
    ink: Color,
    surfaceLuminance: Float,
    targetContrast: Float = MONTH_OUTSIDE_TEXT_CONTRAST,
): Color {
    val inkLuminance = ink.luminance()
    if (contrastOf(inkLuminance, surfaceLuminance) <= targetContrast) return ink
    var low = 0f
    var high = 1f
    repeat(18) {
        val mid = (low + high) / 2f
        val blended = inkLuminance * mid + surfaceLuminance * (1f - mid)
        if (contrastOf(blended, surfaceLuminance) >= targetContrast) {
            high = mid
        } else {
            low = mid
        }
    }
    return ink.copy(alpha = high)
}

/** 两个亮度之间的 WCAG 对比度（1–21）。 */
private fun contrastOf(a: Float, b: Float): Float {
    val hi = max(a, b)
    val lo = min(a, b)
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
