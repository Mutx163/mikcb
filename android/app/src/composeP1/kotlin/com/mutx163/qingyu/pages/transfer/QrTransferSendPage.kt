package com.mutx163.qingyu.pages.transfer

import androidx.compose.foundation.background
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuPageCardMargin
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.components.QingyuPageScaffold
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.shiftWeight
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.ButtonDefaults
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 二维码发送页 · Compose 渲染层（Phase 3）。
 *
 * 对应 Flutter `lib/screens/qr_transfer_send_screen.dart`（464 行）：
 * - 顶栏：返回 + 标题；
 * - 二维码显示区（由宿主传入 `qrContent` 渲染，本页只留位并给出提示）；
 * - 进度行（`已发送 {sent} 帧，约需 {total} 帧`）+ 进度条；
 * - 提示行（请对方打开扫码接收、保持不动）；
 * - 「停止发送」按钮；
 * - 超限 / 超时时换成对应提示，进度不再显示（避免用户以为还在传）。
 *
 * 二维码图形由宿主提供：官方 Miuix 没有二维码组件，本页不自己造一个（自绘二维码
 * 容易出现「看起来能扫、实际扫不出」的错误），只负责版面与文案。这一条写在认领文件
 * 「差异与风险」里。
 *
 * @param model 已算好的发送状态
 * @param onBack 返回
 * @param onStop 停止发送
 * @param qrSlot 二维码槽位（宿主把二维码 Composable 放进来）
 */
@Composable
fun QrTransferSendPage(
    model: QrTransferSendModel,
    onBack: () -> Unit,
    onStop: () -> Unit,
    qrSlot: @Composable () -> Unit,
    /**
     * 顶栏标题。Dart 是**按范围**传进来的
     * （`data_transfer_screen.dart:474-477` 传 `qrTransferSendCurrent`、
     * `:490-493` 传 `qrTransferSendAll`，`:517` 交给 `QrTransferSendScreen(title:)`，
     * 屏幕 `:264` 直接上顶栏）。
     *
     * 默认值 = 旧行为（分组标题），只是兜底：壳里必须传
     * `TransferShellBridge.outboundTitle`，否则两种发送范围看起来一模一样。
     */
    title: String = model.title,
) {
    val dark = isSystemInDarkTheme()

    // 共享骨架（2026-11-05 B 组迁移）：官方顶栏 + 标准返回键 + 顶栏毛玻璃。
    // 返回键显隐与玻璃圆底门控由骨架注入；`scrollBehavior` 由骨架下发给内容槽。
    // 附：原先返回键的读屏文案传的是**页面标题**（`contentDescription = title`），
    // 迁移后统一成骨架默认的「返回」。
    QingyuPageScaffold(
        title = title,
        onBack = onBack,
    ) {
        // 官方页面骨架：LazyColumn + 滚动条 + 末端触感（见 QingyuPageList 注释）
        QingyuPageList(
            innerPadding = innerPadding,
            scrollBehavior = scrollBehavior,
            horizontalPadding = QingyuPageCardMargin,
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            item {
                Column(
                    modifier = Modifier.fillMaxWidth(),
                    verticalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    // ── 二维码区 ──
                    QingyuCard(
                        modifier = Modifier
                            .fillMaxWidth()
                            .aspectRatio(1f),
                        insideMargin = PaddingValues(16.dp),
                    ) {
                        Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                            qrSlot()
                        }
                    }

                    // ── 拦截提示（超限优先于超时，见模型层注释）──
                    val blocking = model.blockingMessage
                    if (blocking != null) {
                        Text(
                            text = blocking,
                            style = MiuixTheme.textStyles.body2,
                            color = Color(QingyuTheme.error(dark)),
                            modifier = Modifier.fillMaxWidth(),
                        )
                    } else {
                        // ── 进度行 + 进度条（帧数没算好时整块不画）──
                        val progress = model.progressText
                        if (progress != null) {
                            Text(
                                text = progress,
                                style = MiuixTheme.textStyles.body2.shiftWeight(QingyuWeightDelta.MEDIUM),
                                color = Color(QingyuTheme.primaryText(dark)),
                            )
                            Spacer(Modifier.height(6.dp))
                            ProgressBar(fraction = model.progressFraction)
                        }
                        Text(
                            text = model.sendHint,
                            style = MiuixTheme.textStyles.footnote1,
                            color = Color(QingyuTheme.secondaryText(dark)),
                            modifier = Modifier.fillMaxWidth(),
                        )
                    }

                    // ── 停止按钮 ──
                    Button(
                        onClick = onStop,
                        modifier = Modifier.fillMaxWidth(),
                        colors = ButtonDefaults.buttonColors(
                            color = MiuixTheme.colorScheme.surfaceVariant,
                            contentColor = MiuixTheme.colorScheme.onSurfaceVariantActions,
                        ),
                        content = { Text(text = model.stopLabel) },
                    )

                }
            }
        }
    }
}

/** 细进度条：底条 + 前景按比例（与统计页覆盖行同款视觉）。 */
@Composable
private fun ProgressBar(fraction: Float) {
    val dark = isSystemInDarkTheme()
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(6.dp)
            .background(
                color = Color(QingyuTheme.surfaceContainerHighest(dark)),
                shape = androidx.compose.foundation.shape.RoundedCornerShape(3.dp),
            ),
    ) {
        val f = fraction.coerceIn(0f, 1f)
        if (f > 0f) {
            Box(
                modifier = Modifier
                    .fillMaxWidth(f)
                    .height(6.dp)
                    .background(
                        color = Color(QingyuTheme.primary(dark = dark)),
                        shape = androidx.compose.foundation.shape.RoundedCornerShape(3.dp),
                    ),
            )
        }
    }
}
