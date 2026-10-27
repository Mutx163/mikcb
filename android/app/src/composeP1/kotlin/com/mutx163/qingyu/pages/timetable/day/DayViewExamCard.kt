package com.mutx163.qingyu.pages.timetable.day

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
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
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Alarm
import top.yukonga.miuix.kmp.icon.extended.File
import top.yukonga.miuix.kmp.icon.extended.Location

/**
 * 日视图考试预警卡 · Compose 渲染层。
 *
 * 对应 Flutter `lib/widgets/timetable/day_view/day_view_exam_agenda_card.dart`：
 * - 警示调色板：红调高亮背景，警示临近考试；
 * - 顶栏：考试徽标 + 倒计时天数徽标（「今天」或「N 天后」）；
 * - 详情：考试名称、考试时间段、考场位置与座位号、关联课程名。
 */
@Composable
fun DayViewExamCard(
    entry: DayAgendaEntry.ExamEntry,
    onTap: () -> Unit,
    radius: Dp = 16.dp,
    modifier: Modifier = Modifier,
) {
    val dark = isSystemInDarkTheme()
    val errorColor = Color(QingyuTheme.error(dark))
    val cardColor = errorColor.copy(alpha = 0.95f)
    val ink = Color.White
    val shape = RoundedCornerShape(radius)

    val countdownText = if (entry.daysUntil == 0) {
        DayViewStrings.examCountdownToday.zh
    } else {
        DayViewStrings.examCountdownDays(entry.daysUntil)
    }

    Box(
        modifier = modifier
            .fillMaxWidth()
            .clip(shape)
            .background(cardColor)
            .clickable(onClick = onTap),
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(start = 14.dp, top = 12.dp, end = 14.dp, bottom = 12.dp),
        ) {
            // 顶栏：考试徽标与倒计时徽标
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                // 考试徽标
                Box(
                    modifier = Modifier
                        .background(dayAgendaInkWash(ink, 0.18f), RoundedCornerShape(8.dp))
                        .padding(horizontal = 8.dp, vertical = 4.dp),
                    contentAlignment = Alignment.Center,
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(
                            imageVector = MiuixIcons.File,
                            contentDescription = null,
                            modifier = Modifier.size(12.dp),
                            tint = ink,
                        )
                        Spacer(modifier = Modifier.width(4.dp))
                        Text(
                            text = DayViewStrings.examBadgeLabel.zh,
                            fontSize = 11.sp,
                            fontWeight = FontWeight.Bold,
                            color = ink,
                        )
                    }
                }

                // 倒计时徽标
                DayAgendaBadge(
                    text = countdownText,
                    textColor = ink,
                    backgroundColor = dayAgendaInkWash(ink, 0.18f),
                    fontWeight = FontWeight.SemiBold,
                )
            }

            Spacer(modifier = Modifier.height(10.dp))

            // 考试科目名称
            Text(
                text = entry.exam.name,
                fontSize = 17.sp,
                fontWeight = FontWeight.Bold,
                color = ink,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
                lineHeight = 22.sp,
            )

            // 考试时间段
            if (entry.exam.startTime.isNotBlank() && entry.exam.endTime.isNotBlank()) {
                Spacer(modifier = Modifier.height(6.dp))
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(
                        imageVector = MiuixIcons.Alarm,
                        contentDescription = null,
                        modifier = Modifier.size(13.dp),
                        tint = ink.copy(alpha = 0.9f),
                    )
                    Spacer(modifier = Modifier.width(6.dp))
                    Text(
                        text = "${entry.exam.startTime} - ${entry.exam.endTime}",
                        fontSize = 12.5.sp,
                        fontWeight = FontWeight.Medium,
                        color = ink.copy(alpha = 0.9f),
                    )
                }
            }

            // 考场与座位号
            val location = entry.exam.location?.trim().orEmpty()
            val seat = entry.exam.seatNumber?.trim().orEmpty()
            val locationAndSeat = buildString {
                if (location.isNotEmpty()) append(location)
                if (seat.isNotEmpty()) {
                    if (isNotEmpty()) append(" · ")
                    append("座位: $seat")
                }
            }
            if (locationAndSeat.isNotEmpty()) {
                Spacer(modifier = Modifier.height(4.dp))
                DayAgendaInfoRow(
                    icon = MiuixIcons.Location,
                    text = locationAndSeat,
                    ink = ink,
                )
            }

            // 关联课程名称
            entry.linkedCourse?.let { course ->
                Spacer(modifier = Modifier.height(3.dp))
                Text(
                    text = course.name,
                    fontSize = 12.sp,
                    color = ink.copy(alpha = 0.75f),
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
        }
    }
}
