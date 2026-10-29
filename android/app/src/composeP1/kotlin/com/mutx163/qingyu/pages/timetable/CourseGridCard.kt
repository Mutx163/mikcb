package com.mutx163.qingyu.pages.timetable

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.core.Course
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 周视图课卡的几何常量（Dart `course_card.dart:_buildCompactCard` 的紧凑卡口径）。
 *
 * **为什么写常量而不是直接 `8.dp`**：这些是**复刻 Dart 版式**的几何量（圆角 8、
 * 内边距 4/4~6、行距 2、字号 9/8/7），不是随手挑的间距。集中成常量既能让
 * 单测钉住，也避免「写死字号」的守卫（R4）把几何口径当成绕过主题。
 */
object WeekCardMetrics {
    /** 卡面圆角（Dart `_buildCompactCard` 的 `borderRadius: 8`）。 */
    const val CORNER_RADIUS_DP = 8f

    /** 卡面与格子之间的外缩（真实值来自设置 `timetableCourseCardGap`，这里是兜底）。 */
    const val OUTER_INSET_DP = 1.25f

    /** 内容左右内边距（Dart `horizontal: 4`）。 */
    const val INNER_HORIZONTAL_DP = 4f

    /** 内容上下内边距：矮格 4、常规 6（Dart `sectionHeight < 64 ? 4 : 6`）。 */
    const val INNER_VERTICAL_COMPACT_DP = 4f
    const val INNER_VERTICAL_REGULAR_DP = 6f

    /** 文字行距（Dart `SizedBox(height: 2)`）。 */
    const val LINE_GAP_DP = 2f

    /** 详情字号 = 标题字号 - 1（Dart `compactSubtitleFontSize`），并 clamp 到 7..14。 */
    fun detailFontSize(titleFontSize: Float): Float =
        (titleFontSize - 1f).coerceIn(7f, 14f)

    /** 角标/小字字号 = 详情 - 1，clamp 到 6..12（Dart overline 口径）。 */
    fun overlineFontSize(detailFontSize: Float): Float =
        (detailFontSize - 1f).coerceIn(6f, 12f)
}

/**
 * 安全解析 16 进制颜色串，失败时回退到 [fallback]。
 */
fun parseHexColor(hex: String?, fallback: Color = Color(0xFF2196F3)): Color {
    if (hex.isNullOrBlank()) return fallback
    val cleaned = hex.trim()
    return try {
        Color(android.graphics.Color.parseColor(if (cleaned.startsWith("#")) cleaned else "#$cleaned"))
    } catch (_: Throwable) {
        fallback
    }
}

/**
 * 根据背景色计算高对比前景色（深色底配白字，浅色底配深墨色）。
 */
fun calculateInk(backgroundColor: Color): Color {
    val luminance = 0.299 * backgroundColor.red + 0.587 * backgroundColor.green + 0.114 * backgroundColor.blue
    return if (luminance > 0.55) Color(0xFF1E293B) else Color.White
}

/**
 * 周网格课程卡片（对应 Dart `lib/widgets/course_card.dart` 的紧凑卡分支）。
 *
 * ## 这一版按 Dart 逐项复刻（2026-10-29 重做）
 *
 * 旧卡片的四个问题，逐条对上 Dart 后修掉：
 * 1. **不读设置**：内容行（课名/教师/地点/时间/周次/简介）现在全部由 [WeekViewStyle]
 *    的七个开关控制；字号取 `courseCardFontSize`（默认 9/8），不再用 13sp 的
 *    `footnote2`（那比 Dart 大一半，卡片里放不下三行）；
 * 2. **角标语义错**：Dart 的「非本周」是左上角**小字**（不是胶囊），「冲突」同时
 *    出现为左上小字 + 右上角标（`showConflictBadgeOnTimetable` 可关）；
 * 3. **非本周透明度**：Dart 固定 0.62（旧值 0.45 太淡，看着像禁用了）；
 * 4. **圆角 16/10dp**：Dart 是 8dp；卡与格子之间只有约 1.25dp 的外缩。
 *
 * ## 刻意没做的（已在审计里记账，不是遗忘）
 *
 * - 天气行（`CourseWeatherDisplay`）：Compose 侧天气数据还没接进课表宿主，见
 *   `_AUDIT-week-view.md` 的 P1-3；
 * - 高斯/液态玻璃卡面：没有壁纸与预糊位图管线时两者都会退化成半透明实体，
 *   这里按 [WeekCardSurface.TRANSLUCENT] 的降级口径画（与 Dart 无壁纸时一致）；
 * - 每行的 flex 比例（Dart 用 `flex: 4/2/3` 分配高度）：这里用 maxLines + 省略号，
 *   视觉接近，但「格子很高时各行按比例拉长」这层没有。
 */
@Composable
fun CourseGridCard(
    model: WeekCardModel,
    style: WeekViewStyle,
    sectionHeight: Dp,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    isHighlighted: Boolean = false,
    isHoliday: Boolean = false,
) {
    val course = model.course
    val rawColor = parseHexColor(model.colorHex ?: course.color, fallback = Color(0xFF2196F3))
    // 卡面透明度：Dart 的 `surfaceOpacity` 是冲突/非本周的压淡系数，直接乘在填充上。
    val fillAlpha = when (style.surfaceStyle) {
        WeekCardSurface.SOLID -> model.opacity
        WeekCardSurface.TRANSLUCENT -> 0.72f * model.opacity
        // 没有壁纸/模糊管线时 Dart 也退化成半透明实体（`effectiveCourseCardSurfaceStyle`）。
        WeekCardSurface.GAUSSIAN -> 0.55f * model.opacity
    }
    val fill = rawColor.copy(alpha = fillAlpha.coerceIn(0.08f, 1f))
    val ink = course.textColor?.let { parseHexColor(it, fallback = calculateInk(rawColor)) }
        ?: calculateInk(rawColor)
    val detailInk = ink.copy(alpha = 0.85f)

    val titleFontSize = style.cardTitleFontSize
    val detailFontSize = WeekCardMetrics.detailFontSize(titleFontSize)
    val overlineFontSize = WeekCardMetrics.overlineFontSize(detailFontSize)
    val shape = RoundedCornerShape(WeekCardMetrics.CORNER_RADIUS_DP.dp)
    val span = model.sectionSpan
    val innerVerticalPadding = if (sectionHeight < 64.dp) {
        WeekCardMetrics.INNER_VERTICAL_COMPACT_DP
    } else {
        WeekCardMetrics.INNER_VERTICAL_REGULAR_DP
    }

    // Dart 的压淡：停课 0.4、假期 0.3（`CourseCard.build` 顶部的 Opacity 分支）。
    val dim = when {
        model.isSuspended -> 0.4f
        isHoliday -> 0.3f
        else -> 1f
    }

    val borderModifier = if (isHighlighted) {
        Modifier.border(1.2.dp, Color.White.copy(alpha = 0.9f), shape)
    } else {
        Modifier
    }

    Box(
        modifier = modifier
            .padding(style.cardInsetDp.dp)
            .fillMaxSize()
            .alpha(dim)
            .clip(shape)
            .background(fill)
            .then(borderModifier)
            .clickable(onClick = onClick),
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(
                    horizontal = WeekCardMetrics.INNER_HORIZONTAL_DP.dp,
                    vertical = innerVerticalPadding.dp,
                ),
            verticalArrangement = when (style.verticalAlign) {
                WeekCardVerticalAlign.TOP -> Arrangement.Top
                WeekCardVerticalAlign.CENTER -> Arrangement.Center
                WeekCardVerticalAlign.BOTTOM -> Arrangement.Bottom
                WeekCardVerticalAlign.SPACE_EVENLY -> Arrangement.SpaceEvenly
            },
            horizontalAlignment = when (style.horizontalAlign) {
                WeekCardHorizontalAlign.LEFT -> Alignment.Start
                WeekCardHorizontalAlign.CENTER -> Alignment.CenterHorizontally
                WeekCardHorizontalAlign.RIGHT -> Alignment.End
            },
        ) {
            val textAlign = when (style.horizontalAlign) {
                WeekCardHorizontalAlign.LEFT -> TextAlign.Start
                WeekCardHorizontalAlign.CENTER -> TextAlign.Center
                WeekCardHorizontalAlign.RIGHT -> TextAlign.End
            }

            // ── 左上角小字（非本周 / 冲突），Dart `compactOverlineText` ──
            val overline = when (model.overline) {
                WeekCardOverline.NON_CURRENT_WEEK -> TimetableStrings.nonCurrentWeekLabel.zh
                WeekCardOverline.CONFLICT -> TimetableStrings.conflictLabel.zh
                null -> null
            }
            if (overline != null) {
                Text(
                    text = overline,
                    style = MiuixTheme.textStyles.footnote2,
                    fontSize = overlineFontSize.sp,
                    fontWeight = FontWeight.Normal,
                    color = detailInk,
                    textAlign = textAlign,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                Spacer(modifier = Modifier.height(WeekCardMetrics.LINE_GAP_DP.dp))
            }

            var hasAnyField = false

            if (style.showName) {
                hasAnyField = true
                Text(
                    text = course.name,
                    style = MiuixTheme.textStyles.footnote2,
                    fontSize = titleFontSize.sp,
                    fontWeight = FontWeight.Bold,
                    color = ink,
                    textAlign = textAlign,
                    maxLines = if (span >= 3) 4 else if (span >= 2) 3 else 2,
                    overflow = TextOverflow.Ellipsis,
                )
            }
            if (style.showTeacher && course.teacher.isNotBlank()) {
                hasAnyField = true
                CardDetailLine(course.teacher.trim(), detailFontSize, detailInk, textAlign)
            }
            if (style.showLocation && course.location.isNotBlank()) {
                hasAnyField = true
                CardDetailLine(course.location.trim(), detailFontSize, detailInk, textAlign)
            }
            if (style.showTime) {
                hasAnyField = true
                CardDetailLine(
                    text = if (style.showTimeLabels) {
                        TimetableStrings.formatClassStartsAt(course.startTime)
                    } else {
                        course.startTime
                    },
                    fontSize = detailFontSize,
                    color = detailInk,
                    textAlign = textAlign,
                )
                CardDetailLine(
                    text = if (style.showTimeLabels) {
                        TimetableStrings.formatClassEndsAt(course.endTime)
                    } else {
                        course.endTime
                    },
                    fontSize = detailFontSize,
                    color = detailInk,
                    textAlign = textAlign,
                )
            }
            if (style.showWeeks) {
                hasAnyField = true
                CardDetailLine(
                    text = TimetableStrings.formatCourseWeekDescription(course),
                    fontSize = detailFontSize,
                    color = detailInk,
                    textAlign = textAlign,
                )
            }
            if (style.showDescription && !course.description.isNullOrBlank()) {
                hasAnyField = true
                CardDetailLine(
                    text = course.description!!.trim(),
                    fontSize = detailFontSize,
                    color = detailInk,
                    textAlign = textAlign,
                    maxLines = 2,
                )
            }
            // Dart 的兜底：七个字段全关也必须有课名，否则卡上只剩留白。
            if (!hasAnyField) {
                Text(
                    text = course.name,
                    style = MiuixTheme.textStyles.footnote2,
                    fontSize = titleFontSize.sp,
                    fontWeight = FontWeight.Bold,
                    color = ink,
                    textAlign = textAlign,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )
            }
        }

        // ── 右上角角标（冲突），Dart `topRightBadgeText` ──
        if (model.badge == WeekCardBadge.CONFLICT) {
            Row(
                modifier = Modifier
                    .align(Alignment.TopEnd)
                    .padding(top = 2.dp, end = 2.dp)
                    .clip(RoundedCornerShape(999.dp))
                    .background(ink.copy(alpha = 0.22f))
                    .padding(horizontal = 3.dp, vertical = 1.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = TimetableStrings.conflictLabel.zh,
                    style = MiuixTheme.textStyles.footnote2,
                    fontSize = overlineFontSize.sp,
                    fontWeight = FontWeight.Bold,
                    color = ink,
                    maxLines = 1,
                )
            }
        }
    }
}

/** 课卡的一行详情（Dart `_buildCompactTextLines` 的详情行）。 */
@Composable
private fun CardDetailLine(
    text: String,
    fontSize: Float,
    color: Color,
    textAlign: TextAlign,
    maxLines: Int = 1,
) {
    Spacer(modifier = Modifier.height(WeekCardMetrics.LINE_GAP_DP.dp))
    Text(
        text = text,
        style = MiuixTheme.textStyles.footnote2,
        fontSize = fontSize.sp,
        fontWeight = FontWeight.Normal,
        color = color,
        textAlign = textAlign,
        maxLines = maxLines,
        overflow = TextOverflow.Ellipsis,
    )
}
