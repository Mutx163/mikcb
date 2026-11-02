package com.mutx163.qingyu.pages.schedule

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.shiftWeight
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.ButtonDefaults
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 日程族共用的动作按钮（2026-11-02 合并三份私有 `MiuixActionButton`）。
 *
 * ## 为什么要合并
 *
 * 三个日程页面各自抄了一份 `private fun MiuixActionButton`，正文都写死
 * `color = MiuixTheme.colorScheme.onPrimary`，而 `Button` 默认配色是
 * `secondaryVariant`（浅灰底）——于是「白字落浅灰底」，按钮文字几乎看不见。
 * 根因是**颜色写在了字上**，而不是交给按钮的 `contentColor`。
 *
 * ## 变体口径
 *
 * - [primary]：强调色实心（`buttonColorsPrimary()`），保存 / 创建 / 确认 / 本次 / 全部；
 * - [destructive]：错误色实心（`colorScheme.error` + `onError`），删除 / 清空；
 * - 默认：次操作灰底（`buttonColors()`，`onSecondaryVariant` 深字），取消 / 次要入口。
 *
 * 文字颜色一律由按钮配色的 `contentColor` 决定，**不要**再在 `Text` 上写 `color`。
 */
@Composable
internal fun ScheduleActionButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    primary: Boolean = false,
    destructive: Boolean = false,
) {
    Button(
        onClick = onClick,
        modifier = modifier,
        enabled = enabled,
        colors = when {
            destructive -> ButtonDefaults.buttonColors(
                color = MiuixTheme.colorScheme.error,
                contentColor = MiuixTheme.colorScheme.onError,
            )
            primary -> ButtonDefaults.buttonColorsPrimary()
            else -> ButtonDefaults.buttonColors()
        },
    ) {
        Text(
            text = text,
            style = MiuixTheme.textStyles.body1.shiftWeight(QingyuWeightDelta.MEDIUM),
        )
    }
}
