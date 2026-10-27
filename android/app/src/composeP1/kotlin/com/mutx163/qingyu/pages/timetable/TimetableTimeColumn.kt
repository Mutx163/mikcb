package com.mutx163.qingyu.pages.timetable

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.core.SectionTime
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Text

/**
 * 课表左侧时间轴列（Timetable Time Column · Compose Phase 3）。
 *
 * 对应 Flutter `lib/widgets/timetable/timetable_time_column.dart`：
 * - 每行展示：节次序号数字（大字） + 紧凑起止时间（如 08:00 / 08:45）；
 * - 高度与右侧网格对应节次精确对齐（[sectionHeight]）；
 * - 支持根据 [currentSection] 高亮当前进行中的节次序号。
 */
@Composable
fun TimetableTimeColumn(
    sectionCount: Int = 12,
    sectionTimes: List<SectionTime> = emptyList(),
    sectionHeight: Dp = 64.dp,
    timeColumnWidth: Dp = 34.dp,
    currentSection: Int? = null,
    modifier: Modifier = Modifier,
) {
    val dark = isSystemInDarkTheme()
    val accentColor = Color(QingyuTheme.primary(dark = dark))
    val textColor = Color(QingyuTheme.primaryText(dark))
    val subTextColor = Color(QingyuTheme.secondaryText(dark)).copy(alpha = 0.85f)

    Column(
        modifier = modifier.width(timeColumnWidth),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        for (sectionIndex in 1..sectionCount) {
            val isCurrent = currentSection == sectionIndex
            val sectionTime = sectionTimes.getOrNull(sectionIndex - 1)

            val startTime = sectionTime?.startTime.orEmpty()
            val endTime = sectionTime?.endTime.orEmpty()

            Box(
                modifier = Modifier
                    .width(timeColumnWidth)
                    .height(sectionHeight)
                    .padding(vertical = 2.dp),
                contentAlignment = Alignment.Center,
            ) {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.Center,
                ) {
                    Text(
                        text = "$sectionIndex",
                        fontSize = 12.sp,
                        fontWeight = if (isCurrent) FontWeight.Bold else FontWeight.SemiBold,
                        color = if (isCurrent) accentColor else textColor,
                        textAlign = TextAlign.Center,
                    )
                    if (startTime.isNotBlank()) {
                        Spacer(modifier = Modifier.height(2.dp))
                        Text(
                            text = startTime,
                            fontSize = 8.5.sp,
                            lineHeight = 10.sp,
                            color = if (isCurrent) accentColor.copy(alpha = 0.9f) else subTextColor,
                            textAlign = TextAlign.Center,
                            maxLines = 1,
                        )
                    }
                    if (endTime.isNotBlank()) {
                        Text(
                            text = endTime,
                            fontSize = 8.5.sp,
                            lineHeight = 10.sp,
                            color = if (isCurrent) accentColor.copy(alpha = 0.9f) else subTextColor,
                            textAlign = TextAlign.Center,
                            maxLines = 1,
                        )
                    }
                }
            }
        }
    }
}
