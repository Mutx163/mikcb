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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.core.Course
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.ContactsCircle
import top.yukonga.miuix.kmp.icon.extended.Location

/**
 * 周视图课程卡片展示模型。
 *
 * 封装单门课程在周视图网格内的激活状态、冲突标记以及多列并排时的列索引与总列数。
 */
data class WeekCourseCardModel(
    val course: Course,
    val isCurrentWeek: Boolean = true,
    val isConflicting: Boolean = false,
    val colIndex: Int = 0,
    val totalCols: Int = 1,
)

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
 * 根据背景色彩计算高对比前景色（深色底配白字，浅色底配深墨色）。
 */
fun calculateInk(backgroundColor: Color): Color {
    val luminance = 0.299 * backgroundColor.red + 0.587 * backgroundColor.green + 0.114 * backgroundColor.blue
    return if (luminance > 0.55) Color(0xFF1E293B) else Color.White
}

/**
 * 课表周网格内课程卡片组件（Course Grid Card · Compose Phase 3）。
 *
 * 对应 Flutter `lib/widgets/course_card.dart` 周视图表现：
 * - 视觉呈现：Miuix 风格 10dp 圆角、柔和背景调色、课程名截断、地点与教师信息；
 * - 状态呈现：本周课程高亮显示；非本周课程半透明（alpha 0.45）并带有「非本周」微标签；
 * - 冲突呈现：当同节次存在多门冲突课程时，展示醒目的「冲突」角标，并支持分列宽度缩放；
 * - 点击事件：触发 [onClick]。
 */
@Composable
fun CourseGridCard(
    model: WeekCourseCardModel,
    onClick: (Course) -> Unit,
    modifier: Modifier = Modifier,
) {
    val course = model.course
    val isCurrentWeek = model.isCurrentWeek
    val isConflicting = model.isConflicting

    val rawColor = parseHexColor(course.color, fallback = Color(0xFF2196F3))
    val baseCardColor = if (!isCurrentWeek) Color(0xFF94A3B8) else rawColor
    val cardAlpha = if (!isCurrentWeek) 0.45f else 0.92f
    val cardBg = baseCardColor.copy(alpha = cardAlpha)

    val ink = if (isCurrentWeek) calculateInk(baseCardColor) else Color(0xFF334155)
    val subInk = ink.copy(alpha = 0.85f)

    val shape = RoundedCornerShape(10.dp)
    val span = (course.endSection - course.startSection + 1).coerceAtLeast(1)

    val borderModifier = if (isConflicting) {
        Modifier.border(1.dp, Color(0xFFEF4444).copy(alpha = 0.8f), shape)
    } else {
        Modifier
    }

    Box(
        modifier = modifier
            .padding(horizontal = 1.dp, vertical = 1.5.dp)
            .fillMaxSize()
            .clip(shape)
            .background(cardBg)
            .then(borderModifier)
            .clickable { onClick(course) }
            .padding(horizontal = 5.dp, vertical = 4.dp),
    ) {
        Column(
            modifier = Modifier.fillMaxSize(),
            verticalArrangement = Arrangement.SpaceBetween,
        ) {
            // ── 顶部：课程名与状态角标 ──
            Column {
                // 状态指示条（非本周 / 冲突）
                if (!isCurrentWeek || isConflicting) {
                    Row(
                        modifier = Modifier.padding(bottom = 2.dp),
                        horizontalArrangement = Arrangement.spacedBy(2.dp),
                    ) {
                        if (!isCurrentWeek) {
                            Box(
                                modifier = Modifier
                                    .clip(RoundedCornerShape(3.dp))
                                    .background(ink.copy(alpha = 0.15f))
                                    .padding(horizontal = 3.dp, vertical = 1.dp),
                            ) {
                                Text(
                                    text = "非本周",
                                    fontSize = 7.5.sp,
                                    lineHeight = 9.sp,
                                    fontWeight = FontWeight.Medium,
                                    color = ink,
                                )
                            }
                        }
                        if (isConflicting) {
                            Box(
                                modifier = Modifier
                                    .clip(RoundedCornerShape(3.dp))
                                    .background(Color(0xFFEF4444))
                                    .padding(horizontal = 3.dp, vertical = 1.dp),
                            ) {
                                Text(
                                    text = "冲突",
                                    fontSize = 7.5.sp,
                                    lineHeight = 9.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = Color.White,
                                )
                            }
                        }
                    }
                }

                // 课程名称
                Text(
                    text = course.name,
                    fontSize = if (model.totalCols > 1) 9.5.sp else 10.5.sp,
                    lineHeight = 12.sp,
                    fontWeight = FontWeight.Bold,
                    color = ink,
                    maxLines = if (span >= 3) 4 else if (span >= 2) 3 else 2,
                    overflow = TextOverflow.Ellipsis,
                )
            }

            // ── 底部：教室与教师 ──
            Column {
                if (course.location.isNotBlank()) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier.padding(top = 1.dp),
                    ) {
                        if (model.totalCols == 1) {
                            Icon(
                                imageVector = MiuixIcons.Location,
                                contentDescription = null,
                                modifier = Modifier.size(9.dp),
                                tint = subInk,
                            )
                            Spacer(modifier = Modifier.width(1.5.dp))
                        }
                        Text(
                            text = course.location,
                            fontSize = if (model.totalCols > 1) 8.5.sp else 9.sp,
                            lineHeight = 11.sp,
                            fontWeight = FontWeight.Medium,
                            color = subInk,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                        )
                    }
                }

                if (span >= 2 && course.teacher.isNotBlank() && model.totalCols == 1) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier.padding(top = 1.dp),
                    ) {
                        Icon(
                            imageVector = MiuixIcons.ContactsCircle,
                            contentDescription = null,
                            modifier = Modifier.size(8.5.dp),
                            tint = subInk.copy(alpha = 0.7f),
                        )
                        Spacer(modifier = Modifier.width(1.5.dp))
                        Text(
                            text = course.teacher,
                            fontSize = 8.5.sp,
                            lineHeight = 10.sp,
                            fontWeight = FontWeight.Normal,
                            color = subInk.copy(alpha = 0.85f),
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                        )
                    }
                }
            }
        }
    }
}
