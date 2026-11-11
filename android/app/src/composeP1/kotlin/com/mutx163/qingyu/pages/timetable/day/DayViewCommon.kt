package com.mutx163.qingyu.pages.timetable.day

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.shiftWeight
import com.mutx163.qingyu.pages.timetable.CourseCardInk
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Notes
import top.yukonga.miuix.kmp.icon.extended.Tasks
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 安全解析 16 进制颜色串，失败时回退到 [fallback]。
 */
fun parseHexColorOrFallback(hex: String?, fallback: Color = Color(0xFF2196F3)): Color {
    if (hex.isNullOrBlank()) return fallback
    val cleaned = hex.trim()
    return try {
        Color(android.graphics.Color.parseColor(if (cleaned.startsWith("#")) cleaned else "#$cleaned"))
    } catch (_: Throwable) {
        fallback
    }
}

/**
 * 对应 Dart dayAgendaInkWash：
 * 根据墨色 (ink) 计算出带有指定透明度的洗色 (wash)。
 */
fun dayAgendaInkWash(ink: Color, alpha: Float = 0.16f): Color {
    return ink.copy(alpha = alpha)
}

/**
 * 根据背景色彩挑高对比前景色：**白 / 近黑里与底色 WCAG 对比度更高的一档**。
 *
 * 2026-11-07 之前这里是 `0.299R + 0.587G + 0.114B > 0.55` 的 gamma 加权阈值，
 * 它对中灰判断是错的：`#808080` 的 gamma 加权是 0.502（判白字，对比度 3.95:1），
 * 而它的真实 WCAG 亮度是 0.216（近黑字 4.41:1）——实心卡上黑字更清楚。
 * 现在与壁纸墨色共用 `CourseCardInk` 那套判据，不再有第二套阈值。
 */
fun calculateCardInk(backgroundColor: Color): Color =
    Color(CourseCardInk.bestContrastInk(backgroundColor.toArgb()))

/**
 * 日视图通用状态胶囊徽标。
 *
 * 对应 `DayAgendaStatusBadge`：圆角 999dp、字号 10.5sp、单行文本。
 */
@Composable
fun DayAgendaBadge(
    text: String,
    textColor: Color,
    backgroundColor: Color,
    modifier: Modifier = Modifier,
    weightDelta: Int = 0,
) {
    Box(
        modifier = modifier
            .background(backgroundColor, RoundedCornerShape(999.dp))
            .padding(horizontal = 8.dp, vertical = 3.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = text,
            style = MiuixTheme.textStyles.footnote2.shiftWeight(weightDelta),
            lineHeight = 12.sp,
            color = textColor,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
    }
}

/**
 * 任务来源课程小圆点。
 */
@Composable
fun DayCourseDot(
    color: Color,
    modifier: Modifier = Modifier,
    size: Dp = 6.dp,
) {
    Box(
        modifier = modifier
            .size(size)
            .background(color, CircleShape),
    )
}

/**
 * 课程卡作业红点指示器。
 *
 * 对应 `DayAgendaHomeworkDot`：18dp 纯白圆底 + 1.2dp 描边 + 破坏红图标。
 */
@Composable
fun DayAgendaHomeworkDot(
    modifier: Modifier = Modifier,
    iconColor: Color = Color(QingyuTheme.destructive()),
) {
    Box(
        modifier = modifier
            .size(18.dp)
            .background(Color.White.copy(alpha = 0.95f), CircleShape)
            .border(1.2.dp, Color.White, CircleShape),
        contentAlignment = Alignment.Center,
    ) {
        Icon(
            imageVector = MiuixIcons.Tasks,
            // ARB `courseTaskAction` =「作业」，不再写死字面量（CJK 门禁账）
            contentDescription = DayViewStrings.courseTaskAction.text,
            modifier = Modifier.size(11.dp),
            tint = iconColor,
        )
    }
}

/**
 * 课程卡右上角「备注」胶囊按钮。
 */
@Composable
fun DayAgendaNoteAction(
    ink: Color,
    onPressed: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val bg = dayAgendaInkWash(ink, 0.16f)
    val border = dayAgendaInkWash(ink, 0.22f)
    Box(
        modifier = modifier
            .clip(CircleShape)
            .background(bg)
            .border(1.dp, border, CircleShape)
            .clickable(onClick = onPressed)
            .padding(horizontal = 9.dp, vertical = 5.dp),
        contentAlignment = Alignment.Center,
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.Center,
        ) {
            Icon(
                imageVector = MiuixIcons.Notes,
                contentDescription = null,
                modifier = Modifier.size(13.dp),
                tint = ink,
            )
            Spacer(modifier = Modifier.width(4.dp))
            Text(
                text = DayViewStrings.courseNoteAction.text,
                style = MiuixTheme.textStyles.footnote2,
                color = ink,
            )
        }
    }
}

/**
 * 课程卡右上角「记作业」胶囊按钮。
 */
@Composable
fun DayAgendaTaskAction(
    ink: Color,
    onPressed: () -> Unit,
    hasTask: Boolean = false,
    modifier: Modifier = Modifier,
) {
    val bg = dayAgendaInkWash(ink, 0.16f)
    val border = dayAgendaInkWash(ink, 0.22f)
    Box(
        modifier = modifier
            .clip(CircleShape)
            .background(bg)
            .border(1.dp, border, CircleShape)
            .clickable(onClick = onPressed)
            .padding(horizontal = 9.dp, vertical = 5.dp),
        contentAlignment = Alignment.Center,
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.Center,
        ) {
            Icon(
                imageVector = MiuixIcons.Tasks,
                contentDescription = null,
                modifier = Modifier.size(13.dp),
                tint = ink,
            )
            Spacer(modifier = Modifier.width(4.dp))
            Text(
                text = DayViewStrings.courseTaskAction.text,
                style = MiuixTheme.textStyles.footnote2.shiftWeight(if (hasTask) QingyuWeightDelta.SEMIBOLD else 0),
                color = ink,
            )
        }
    }
}

/**
 * 议程卡信息行（教师、地点、天气、单周备注等）。
 */
@Composable
fun DayAgendaInfoRow(
    icon: ImageVector,
    text: String,
    ink: Color,
    modifier: Modifier = Modifier,
    textModifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            modifier = Modifier.size(13.dp),
            tint = ink.copy(alpha = 0.85f),
        )
        Spacer(modifier = Modifier.width(6.dp))
        Text(
            text = text,
            style = MiuixTheme.textStyles.footnote1,
            color = ink.copy(alpha = 0.85f),
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = textModifier,
        )
    }
}
