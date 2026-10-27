package com.mutx163.qingyu.components

import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.theme.QingyuShapes
import top.yukonga.miuix.kmp.basic.Card
import top.yukonga.miuix.kmp.basic.CardColors
import top.yukonga.miuix.kmp.basic.CardDefaults
import top.yukonga.miuix.kmp.utils.PressFeedbackType

/**
 * 全站卡片入口：官方 [Card] + **默认打开按压反馈** + 语义圆角。
 *
 * ## 为什么需要它（2026-10-27 对照官方 demo 的结论）
 *
 * 官方 `Card` 的交互参数**默认全是关的**（`Card.kt:87-95`）：
 *
 * ```kotlin
 * pressFeedbackType: PressFeedbackType = PressFeedbackType.None,   // 按下零视觉反应
 * showIndication: Boolean = false,                                  // 无点击指示
 * ```
 *
 * 官方 `card.md` 的「Interactive Card」一节要求**两个都显式打开**。我们迁移时按默认值抄了，
 * 于是全仓 230 处 `Card(` 调用里，凡是可点的（约 32 处传了 `onClick`）**按下去什么也不发生**——
 * 这就是「点击效果不好」的全部原因。
 *
 * 旧版 Flutter 本来是有手感的（`lib/ui/hyperos/widgets/tiles.dart:45` 起 921 行按压状态机：
 * 25ms 出压痕、纵向滑动 2dp 取消、翻页期间保持高亮），迁移时这一层没搬。
 *
 * ## 为什么用「默认开」而不是让每个调用点自己传
 *
 * 靠人记着传参数一定会漏——**已经漏了 230 次**。把正确行为设成默认值，
 * 忘记传参数时得到的是对的，而不是没手感的。
 *
 * ## 圆角为什么有默认值
 *
 * 官方 `Card` 默认 `cornerRadius = 16.dp`（`CardDefaults.CornerRadius`），
 * 而 Dart 侧设置组是 **24**（`hyperos_miuix_spec.dart:69` 的 `settingsGroupRadius`）。
 * 迁移时没人传圆角，230 处里只有 9 处显式指定 → 设置组卡片全部被压成 16，
 * 半径小一圈是「变廉价」的直观来源之一。
 * 这里给语义默认值：[QingyuCardDefaults.Corner]（16，普通卡片）与
 * [QingyuCardDefaults.SettingsGroupCorner]（24，设置组）。
 *
 * ## 内边距：**包 Preference 行时不要传**
 *
 * 官方 `CardDefaults.InsideMargin` 是 `PaddingValues(0.dp)`，而所有 `*Preference`
 * 组件**自带 16dp 内边距**。所以：
 *
 * - 包一组 `ArrowPreference` / `SwitchPreference` → **不传** `insideMargin`（保持 0）；
 * - 包普通内容（`Text` / `Row` 等）→ 自己传 [QingyuCardDefaults.ContentInsideMargin]（16dp），
 *   否则内容会贴着卡片边缘。
 *
 * 官方骨架的横向刻度是：页面 0 → Card 外边距 12 → Preference 自带 16 = **文字左缘 28**，
 * 与 `SmallTitle` 自带的 28 对齐。传错 `insideMargin` 会让这一列错开，看起来就是「行不齐」。
 *
 * @param pressFeedbackType 传 `null`（默认）表示按可点与否自动选：
 *   可点 → [PressFeedbackType.Sink]（下沉缩放，官方推荐），不可点 → `None`。
 *   想要倾斜效果传 [PressFeedbackType.Tilt]，想要完全无反馈传 `None`。
 * @param showIndication 默认 `true`；仅在可点时生效。
 *   `MiuixTheme` 已内置 `LocalIndication`（`MiuixTheme.kt:36`），无需自备 ripple。
 * @param holdDownState 长按弹出弹窗期间传 `true`，可让卡片保持「按下态」外观，
 *   避免弹窗出现的瞬间卡片「一闪」。弹窗的 `onDismissFinished` 里要复位为 `false`。
 */
@Composable
fun QingyuCard(
    modifier: Modifier = Modifier,
    cornerRadius: Dp = QingyuCardDefaults.Corner,
    insideMargin: PaddingValues = PaddingValues(0.dp),
    colors: CardColors = CardDefaults.defaultColors(),
    pressFeedbackType: PressFeedbackType? = null,
    showIndication: Boolean = true,
    holdDownState: Boolean = false,
    onClick: (() -> Unit)? = null,
    onLongPress: (() -> Unit)? = null,
    content: @Composable ColumnScope.() -> Unit,
) {
    val clickable = onClick != null || onLongPress != null
    Card(
        modifier = modifier,
        cornerRadius = cornerRadius,
        insideMargin = insideMargin,
        colors = colors,
        pressFeedbackType = pressFeedbackType
            ?: if (clickable) PressFeedbackType.Sink else PressFeedbackType.None,
        showIndication = showIndication && clickable,
        holdDownState = holdDownState,
        onClick = onClick,
        onLongPress = onLongPress,
        content = content,
    )
}

/** [QingyuCard] 的语义默认值。数值全部来自 [QingyuShapes]，不在此处发明新值。 */
object QingyuCardDefaults {

    /** 普通卡片圆角（= `QingyuShapes.CARD_CORNER`，16dp，与官方 `CardDefaults.CornerRadius` 一致）。 */
    val Corner: Dp = QingyuShapes.CARD_CORNER.dp

    /** 设置组卡片圆角（= `QingyuShapes.SETTINGS_GROUP_RADIUS`，24dp，Dart 侧 `settingsGroupRadius`）。 */
    val SettingsGroupCorner: Dp = QingyuShapes.SETTINGS_GROUP_RADIUS.dp

    /**
     * 包**普通内容**时的内边距（16dp）。
     *
     * 包 `*Preference` 行时**不要**用这个值——那些组件自带 16dp，再给会变成 32dp。
     */
    val ContentInsideMargin: PaddingValues = PaddingValues(16.dp)
}
