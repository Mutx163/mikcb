package com.mutx163.qingyu.pages.timetable.day

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.shiftWeight
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 日视图「今日无课」极简空态卡片 · Compose 渲染层。
 *
 * 对应 Flutter `lib/widgets/timetable/day_view/day_view_empty_state.dart`：
 * - 居中两行展示：主标题「暂无课程」+ 副标题「第 N 周 · 周几」；
 * - 纯净排版，适配深色与浅色主题，契合 Miuix 极简视觉规范。
 */
@Composable
fun DayViewEmptyState(
    week: Int,
    dayOfWeek: Int? = null,
    modifier: Modifier = Modifier,
) {
    val dark = isSystemInDarkTheme()
    val titleColor = Color(QingyuTheme.primaryText(dark))
    val subtitleColor = Color(QingyuTheme.secondaryText(dark))

    // Dart `day_view_empty_state.dart:64-66`：副标题只有「第 N 周」一条。
    // 2026-10-31 审核：这里曾拼成「第 N 周 · 周X」，而上一行的摘要卡已经写着日期与星期，
    // 屏上等于同一句念两遍；`dayOfWeek` 参数保留只为调用方签名稳定。
    val subtitle = DayViewStrings.weekLabel(week)

    Box(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 32.dp, vertical = 48.dp),
        contentAlignment = Alignment.Center,
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text(
                text = DayViewStrings.dayViewEmptyTitle.zh,
                style = MiuixTheme.textStyles.main.shiftWeight(QingyuWeightDelta.MEDIUM),
                color = titleColor,
                textAlign = TextAlign.Center,
            )
            Spacer(modifier = Modifier.height(8.dp))
            Text(
                text = subtitle,
                style = MiuixTheme.textStyles.footnote1,
                color = subtitleColor,
                textAlign = TextAlign.Center,
            )
        }
    }
}
