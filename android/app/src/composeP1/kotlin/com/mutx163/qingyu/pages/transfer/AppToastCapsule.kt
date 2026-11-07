package com.mutx163.qingyu.pages.transfer

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.theme.QingyuTheme
import kotlinx.coroutines.delay
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TextButton
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 应用内提示胶囊（Dart `HyperosToastCapsule` / `showAppToast` 的对位件）。
 *
 * ## 为什么要有这个共享件
 *
 * 「数据备份与迁移」页 2026-10-29 自己画了一颗胶囊（撤销动作要挂在提示尾部，
 * 系统 Toast 挂不了动作），而「情侣课表设置」页还在用 `android.widget.Toast`
 * ⇒ 同族两页的提示长得不一样、位置不一样（系统 Toast 在屏幕下方偏上、还带
 * 应用图标）。Dart 侧两页都用同一颗 `showAppToast`，所以这里抽成一份共用。
 *
 * ## 口径（照抄 Dart，不是自己拍的）
 *
 * - 底部浮层、圆角 16、内边距 16/12/12/12、动作在文字右侧；
 * - 2 秒自动消失（`HyperosMiuixSnackbar.durationShortMs = 2000`，`app_toast.dart:6-8`）；
 * - 动作按钮点一下先关掉提示再执行回调（Dart 同款顺序，避免回调里又弹一条时
 *   两条叠在一起）。
 *
 * @param description 第二行说明（比正文小一号、次要色）；null = 只有一行。
 *   对应 Dart `showAppToast(description:)`，失败提示的「试试直接打开 App」放这里。
 * @param isError true = 错误样式（正文用 error 色，Dart `AppToastKind.error` 的对位）；
 *   默认 false = 常规样式，既有调用点零变化。
 * @param autoDismissMillis ≤ 0 表示不自动消失（需要用户点一下才走）。
 */
@Composable
fun AppToastCapsule(
    message: String,
    dark: Boolean,
    modifier: Modifier = Modifier,
    description: String? = null,
    isError: Boolean = false,
    actionLabel: String? = null,
    onAction: (() -> Unit)? = null,
    onDismiss: () -> Unit = {},
    autoDismissMillis: Long = TOAST_DURATION_MILLIS,
) {
    LaunchedEffect(message, description, actionLabel) {
        if (autoDismissMillis > 0L) {
            delay(autoDismissMillis)
            onDismiss()
        }
    }
    val secondaryText = Color(QingyuTheme.secondaryText(dark))
    QingyuCard(
        modifier = modifier
            .fillMaxWidth()
            // 自绘胶囊不会像系统 Toast 那样被读屏自动播报；合并成一个节点标成 polite
            // live region，让 TalkBack 在提示出现时补念整句（不抢焦点）。
            .semantics(mergeDescendants = true) { liveRegion = LiveRegionMode.Polite },
        cornerRadius = 16.dp,
        insideMargin = PaddingValues(start = 16.dp, top = 12.dp, end = 12.dp, bottom = 12.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = message,
                    style = MiuixTheme.textStyles.body2,
                    color = if (isError) {
                        Color(QingyuTheme.error(dark))
                    } else {
                        Color(QingyuTheme.primaryText(dark))
                    },
                )
                if (!description.isNullOrBlank()) {
                    Text(
                        text = description,
                        style = MiuixTheme.textStyles.footnote1,
                        color = secondaryText,
                        modifier = Modifier.padding(top = 2.dp),
                    )
                }
            }
            if (actionLabel != null) {
                TextButton(
                    text = actionLabel,
                    onClick = {
                        onDismiss()
                        onAction?.invoke()
                    },
                )
            }
        }
    }
}

/** Dart `HyperosMiuixSnackbar.durationShortMs` = 2000（`app_toast.dart:6-8`）。 */
const val TOAST_DURATION_MILLIS: Long = 2000L
