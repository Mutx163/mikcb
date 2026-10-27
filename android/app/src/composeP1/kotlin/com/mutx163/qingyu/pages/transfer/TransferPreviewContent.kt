package com.mutx163.qingyu.pages.transfer

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Card
import top.yukonga.miuix.kmp.basic.ButtonDefaults
import top.yukonga.miuix.kmp.basic.HorizontalDivider
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TextButton

/**
 * 传输预览对话框内容 · Compose 渲染层（Phase 3）。
 *
 * 对应 Flutter `lib/screens/transfer_preview_dialog.dart`（56 行）：收到课表包后，
 * 在真正应用之前让用户亲口选「合并更改」还是「覆盖当前课表」。
 *
 * ## 为什么是一个 Composable 而不是弹层
 *
 * 官方 Miuix 的弹层有 `SuperDialog` / `OverlayDialog` 两种装配方式，选哪一种属壳层
 * 决策（台账 §6 里壳与主题都是 Lead 专属）。本页只提供**对话框内容**（正文 + 三个按钮），
 * 由宿主套进它选定的弹层里。这样无论宿主选哪种，文案与按钮顺序都是同一份。
 *
 * ## 正文是契约，不要"美化"
 *
 * 正文由 [TransferPreviewModel.body] 拼好：说明段 + 三个技术标识 + 每类实体的
 * `+a / ~b / -c` 计数。用户会拿它跟对方手机上的数字逐字符对比，所以这里原样显示、
 * 不重新排版、不加粗、不省略零值。
 *
 * @param body 已拼好的正文（[TransferPreviewModel.body] 的产物）
 * @param onAction 用户选了某一项；null = 取消
 */
@Composable
fun TransferPreviewContent(
    body: String,
    onAction: (TransferPreviewModel.ApplyMode?) -> Unit,
) {
    val dark = isSystemInDarkTheme()

    Card(modifier = Modifier.fillMaxWidth(), insideMargin = PaddingValues(horizontal = 20.dp, vertical = 18.dp)) {
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Text(
                text = TransferPreviewModel.title,
                fontSize = 17.sp,
                color = Color(QingyuTheme.primaryText(dark)),
            )
            // 正文：等宽感靠行结构与空行分段，不加粗不改写
            Text(
                text = body,
                fontSize = 13.sp,
                color = Color(QingyuTheme.secondaryText(dark)),
            )
            HorizontalDivider(color = Color(QingyuTheme.dividerLine(dark)))
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                for (action in TransferPreviewModel.actions()) {
                    // 官方 TextButton 是 text 参数式 API（不是内容 lambda）。
                    // 主按钮用主题色，其余用次级色 —— 与 Dart 的 isPrimary 一致。
                    TextButton(
                        text = action.label,
                        onClick = { onAction(action.mode) },
                        modifier = Modifier.weight(1f),
                        colors = if (action.primary) {
                            ButtonDefaults.textButtonColors(
                                color = Color(QingyuTheme.primary(dark = dark)),
                            )
                        } else {
                            ButtonDefaults.textButtonColors(
                                color = Color(QingyuTheme.secondaryText(dark)),
                            )
                        },
                    )
                }
            }
        }
    }
}
