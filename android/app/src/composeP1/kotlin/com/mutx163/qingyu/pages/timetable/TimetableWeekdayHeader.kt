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
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Text
import java.time.LocalDate
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 课表周视图表头栏（Timetable Weekday Header · Compose Phase 3）。
 *
 * 对应 Flutter `lib/widgets/timetable/timetable_weekday_header.dart`：
 * - 左侧时间轴对齐区：显示月份（如 "10月"）或周次简写（如 "9周"），点击可触发周次选择器；
 * - 右侧星期与日期栏：按星期一至星期日展示 7 列星期标签与具体日历号数；
 * - 今天高亮（Today Marker）：当前真实今天以 Miuix 胶囊底色与墨色反差醒目呈现；
 * - 交互反馈：点击任意一天回调 [onDayClick]（带出 dayOfWeek 1..7），方便下钻日视图。
 */
@Composable
fun TimetableWeekdayHeader(
    week: Int,
    currentWeek: Int? = null,
    todayDate: LocalDate = LocalDate.now(),
    dates: List<LocalDate>? = null,
    semesterStartDate: LocalDate? = null,
    visibleDays: List<Int> = listOf(1, 2, 3, 4, 5, 6, 7),
    selectedDayOfWeek: Int? = null,
    timeColumnWidth: Dp = 34.dp,
    height: Dp = 44.dp,
    onDayClick: (dayOfWeek: Int) -> Unit = {},
    onWeekTitleClick: () -> Unit = {},
    modifier: Modifier = Modifier,
) {
    val dark = isSystemInDarkTheme()
    val isCurrentBrowsingWeek = currentWeek == null || week == currentWeek

    // 确定本周周一对应的基准日期
    val mondayDate: LocalDate? = dates?.firstOrNull() ?: semesterStartDate?.let { start ->
        val daysFromStartMonday = (week - 1) * 7L - (start.dayOfWeek.value - 1L)
        start.plusDays(daysFromStartMonday)
    }

    // 月份或周次简写标签
    val monthOrWeekLabel = mondayDate?.let { "${it.monthValue}月" } ?: "${week}周"

    val weekdayNames = listOf("一", "二", "三", "四", "五", "六", "日")
    val accentColor = Color(QingyuTheme.primary(dark = dark))
    val textColor = Color(QingyuTheme.primaryText(dark))
    val subTextColor = Color(QingyuTheme.secondaryText(dark))
    val dividerColor = Color(QingyuTheme.dividerLine(dark))

    Column(modifier = modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .height(height),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            // ── 左侧时间轴对齐区（月份 / 周次切换） ──
            Box(
                modifier = Modifier
                    .width(timeColumnWidth)
                    .fillMaxHeight()
                    .clip(RoundedCornerShape(6.dp))
                    .clickable(onClick = onWeekTitleClick),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = monthOrWeekLabel,
                    style = MiuixTheme.textStyles.footnote2,
                    fontWeight = FontWeight.Bold,
                    color = accentColor,
                    textAlign = TextAlign.Center,
                )
            }

            // ── 星期与日期列 ──
            Row(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxHeight(),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                for (dayOfWeek in visibleDays) {
                    val dayIndex = dayOfWeek - 1
                    val dayLabel = weekdayNames.getOrElse(dayIndex) { "$dayOfWeek" }

                    val dayDate: LocalDate? = dates?.getOrNull(dayIndex)
                        ?: mondayDate?.plusDays(dayIndex.toLong())

                    val isToday = dayDate?.let { it == todayDate }
                        ?: (isCurrentBrowsingWeek && todayDate.dayOfWeek.value == dayOfWeek)

                    val isSelected = selectedDayOfWeek == dayOfWeek

                    val dateText = dayDate?.let { "${it.dayOfMonth}" } ?: ""

                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .fillMaxHeight()
                            .padding(horizontal = 1.dp, vertical = 2.dp)
                            .clip(RoundedCornerShape(8.dp))
                            .clickable { onDayClick(dayOfWeek) },
                        contentAlignment = Alignment.Center,
                    ) {
                        Column(
                            horizontalAlignment = Alignment.CenterHorizontally,
                            verticalArrangement = Arrangement.Center,
                        ) {
                            // 星期标签
                            Text(
                                text = dayLabel,
                                style = MiuixTheme.textStyles.footnote2,
                                fontWeight = if (isToday || isSelected) FontWeight.Bold else FontWeight.Medium,
                                color = if (isToday || isSelected) accentColor else subTextColor,
                            )

                            // 日期数字
                            if (dateText.isNotEmpty()) {
                                Spacer(modifier = Modifier.height(2.dp))
                                if (isToday) {
                                    Box(
                                        modifier = Modifier
                                            .clip(RoundedCornerShape(999.dp))
                                            .background(accentColor)
                                            .padding(horizontal = 5.dp, vertical = 1.dp),
                                        contentAlignment = Alignment.Center,
                                    ) {
                                        Text(
                                            text = dateText,
                                            style = MiuixTheme.textStyles.footnote2,
                                            fontWeight = FontWeight.Bold,
                                            color = Color.White,
                                            lineHeight = 12.sp,
                                        )
                                    }
                                } else {
                                    Text(
                                        text = dateText,
                                        style = MiuixTheme.textStyles.footnote2,
                                        fontWeight = FontWeight.Normal,
                                        color = if (isSelected) accentColor else textColor,
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }

        // 底部细微分割线
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(0.5.dp)
                .background(dividerColor),
        )
    }
}
