package com.mutx163.qingyu.pages.course

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 「哪些周上」弹层的三个纯构建小件（`lib/screens/add_course_week_picker_tiles.dart`
 * 的 Compose 移植，**页面域内私有**——Dart 侧同款文件也是弹层专供）：
 * - [AddCourseWeekGridTile]：周网格里的单周按钮；
 * - [AddCourseWeekModeTileGroup]：模式选择组（连续周 / 自定义周）；
 * - [AddCourseWeekParityTileGroup]：单双周过滤组（全部 / 单周 / 双周）。
 *
 * 弹层本体与判据（`weeksFromRangeSelection` / 草稿状态机）在模型层
 * [AddCourseWeekDraftLogic]，这里只画。
 */

/** 周网格里的单周按钮（Dart `buildCourseWeekGridTile`：选中=primary，未选=secondary）。 */
@Composable
internal fun AddCourseWeekGridTile(
    week: Int,
    isSelected: Boolean,
    dark: Boolean,
    onPress: () -> Unit,
) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .background(
                if (isSelected) Color(QingyuTheme.primary(dark = dark)) else Color(QingyuTheme.card(dark)),
            )
            .border(
                1.dp,
                if (isSelected) Color.Transparent else Color(QingyuTheme.dividerLine(dark)),
                RoundedCornerShape(8.dp),
            )
            .clickable(onClick = onPress)
            .padding(vertical = 10.dp),
        contentAlignment = Alignment.Center,
    ) {
        // Dart 侧按钮文案是纯数字 `'$week'`，不带「第 N 周」整词。
        Text(
            text = week.toString(),
            style = MiuixTheme.textStyles.footnote1,
            fontWeight = FontWeight.Medium,
            color = if (isSelected) Color.White else Color(QingyuTheme.primaryText(dark)),
        )
    }
}

/** 模式选择组：按范围（起止周 + 单双周）/ 逐周勾选（Dart `buildCourseWeekModeTileGroup`）。 */
@Composable
internal fun AddCourseWeekModeTileGroup(
    tempMode: AddCourseWeekSelectionMode,
    dark: Boolean,
    onSelect: (AddCourseWeekSelectionMode) -> Unit,
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        AddCourseChoiceChip(
            label = AddCourseStrings.rangeWeeksLabel.zh,
            isSelected = tempMode == AddCourseWeekSelectionMode.RANGE,
            dark = dark,
            modifier = Modifier.weight(1f),
            onClick = { onSelect(AddCourseWeekSelectionMode.RANGE) },
        )
        AddCourseChoiceChip(
            label = AddCourseStrings.customWeeksLabel.zh,
            isSelected = tempMode == AddCourseWeekSelectionMode.CUSTOM,
            dark = dark,
            modifier = Modifier.weight(1f),
            onClick = { onSelect(AddCourseWeekSelectionMode.CUSTOM) },
        )
    }
}

/**
 * 单双周过滤组（Dart `buildCourseWeekParityTileGroup`，只出现在范围模式）。
 * 「全部」= 单双周都不勾；三个互斥。
 */
@Composable
internal fun AddCourseWeekParityTileGroup(
    isAllWeeks: Boolean,
    isOddWeek: Boolean,
    isEvenWeek: Boolean,
    dark: Boolean,
    onSelectAll: () -> Unit,
    onSelectOdd: () -> Unit,
    onSelectEven: () -> Unit,
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        AddCourseChoiceChip(
            label = AddCourseStrings.allWeeksFilter.zh,
            isSelected = isAllWeeks,
            dark = dark,
            modifier = Modifier.weight(1f),
            onClick = onSelectAll,
        )
        AddCourseChoiceChip(
            label = AddCourseStrings.oddWeeksFilter.zh,
            isSelected = isOddWeek,
            dark = dark,
            modifier = Modifier.weight(1f),
            onClick = onSelectOdd,
        )
        AddCourseChoiceChip(
            label = AddCourseStrings.evenWeeksFilter.zh,
            isSelected = isEvenWeek,
            dark = dark,
            modifier = Modifier.weight(1f),
            onClick = onSelectEven,
        )
    }
}

/** 弹层里的可选中胶囊（与 AddScheduleItemPage 的选择 chip 同一套视觉语言）。 */
@Composable
internal fun AddCourseChoiceChip(
    label: String,
    isSelected: Boolean,
    dark: Boolean,
    modifier: Modifier = Modifier,
    onClick: () -> Unit,
) {
    Box(
        modifier = modifier
            .background(
                if (isSelected) Color(QingyuTheme.primary(dark = dark)) else Color(QingyuTheme.card(dark)),
            )
            .border(
                1.dp,
                if (isSelected) Color.Transparent else Color(QingyuTheme.dividerLine(dark)),
                RoundedCornerShape(8.dp),
            )
            .clickable(onClick = onClick)
            .padding(horizontal = 12.dp, vertical = 10.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = label,
            style = MiuixTheme.textStyles.footnote1,
            fontWeight = FontWeight.Medium,
            color = if (isSelected) Color.White else Color(QingyuTheme.primaryText(dark)),
        )
    }
}
