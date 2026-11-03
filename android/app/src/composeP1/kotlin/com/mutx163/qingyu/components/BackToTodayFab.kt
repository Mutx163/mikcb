package com.mutx163.qingyu.components

import androidx.compose.foundation.border
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import top.yukonga.miuix.kmp.basic.FloatingActionButton
import top.yukonga.miuix.kmp.basic.FloatingActionButtonDefaults
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 「今」悬浮胶囊（日视图「回今日」/ 周视图「回本周」共用的唯一实现）。
 *
 * 形态（用户参考相册日历页的「今」钮拍板）：圆角胶囊——不是圆形/圆球；
 * 半透明主题主色底（能透出后面的卡片）；一圈浅色细描边读作玻璃亮棱；
 * 官方投影把钮从卡片上托起来。全部走官方件参数（FAB 的 shape /
 * containerColor / shadowElevation + 官方 border modifier），不自画形状。
 * 半透明底不依赖实时模糊/录像带——任何设备同一形态，无需降级分支。
 *
 * 两处调用的**可见字都是同一个单字「今」**（`label` 由调用方传，统一取
 * `DayViewStrings.backToTodayShort.zh`）；**读屏语义按各自行为给**：
 * 日视图念「回今日」、周视图念「回到本周」（调用方传各自域的既有完整语义键），
 * 不让读屏只听到一个字。
 *
 * 视觉高 [HEIGHT_DP]、宽 [WIDTH_DP]；命中区由外层垂直 padding 兜到 ≥48dp。
 *
 * @param onClick 点击回调（日视图回今天那一天；周视图回到本周）。
 * @param label 屏上可见文字（调用方传单字「今」的既有键）。
 * @param contentDescription 读屏完整语义（调用方传各自域的既有键）。
 * @param alpha 整钮透明度（周视图的「浮钮透明度」设置作用在这里；日视图恒 1）。
 */
@Composable
fun BackToTodayFab(
    onClick: () -> Unit,
    label: String,
    contentDescription: String,
    modifier: Modifier = Modifier,
    alpha: Float = 1f,
) {
    val shape = RoundedCornerShape(BACK_TO_TODAY_FAB_CORNER_DP.dp)
    FloatingActionButton(
        onClick = onClick,
        shape = shape,
        containerColor = MiuixTheme.colorScheme.primary.copy(alpha = 0.78f * alpha),
        shadowElevation = FloatingActionButtonDefaults.ShadowElevation,
        minWidth = BACK_TO_TODAY_FAB_WIDTH_DP.dp,
        minHeight = BACK_TO_TODAY_FAB_HEIGHT_DP.dp,
        modifier = modifier
            .semantics { this.contentDescription = contentDescription }
            // 视觉高 BACK_TO_TODAY_FAB_HEIGHT_DP，外层垂直各垫 4dp 把命中区兜到 ≥48dp。
            .padding(vertical = 4.dp)
            // 玻璃亮棱：一圈细描边（浅色半透明，深浅模式都读作「棱」）。
            .border(1.dp, MiuixTheme.colorScheme.onPrimary.copy(alpha = 0.35f), shape),
    ) {
        Text(
            text = label,
            style = MiuixTheme.textStyles.button,
            color = MiuixTheme.colorScheme.onPrimary.copy(alpha = alpha),
        )
    }
}

/** 胶囊视觉高（dp）；命中区靠外层 padding 兜到 ≥48。 */
const val BACK_TO_TODAY_FAB_HEIGHT_DP = 40f

/** 胶囊宽（dp）：单字「今」+ 左右呼吸。 */
const val BACK_TO_TODAY_FAB_WIDTH_DP = 64f

/**
 * 胶囊圆角（dp）。**必须小于高度的一半**（14 < 20）——一旦 ≥ 高/半就读成
 * 圆球/圆形，正是用户否掉的形态；守卫钉住这个关系。
 */
const val BACK_TO_TODAY_FAB_CORNER_DP = 14f
