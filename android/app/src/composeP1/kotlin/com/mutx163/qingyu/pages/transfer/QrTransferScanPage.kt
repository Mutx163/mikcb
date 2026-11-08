package com.mutx163.qingyu.pages.transfer

import androidx.compose.foundation.background
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuPageCardMargin
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.components.QingyuPageScaffold
import com.mutx163.qingyu.components.QingyuPageTheme
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.shiftWeight
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.ButtonDefaults
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 二维码扫码接收页 · Compose 渲染层（Phase 3）。
 *
 * 对应 Flutter `lib/screens/qr_transfer_scan_screen.dart`（728 行）：
 * - 顶栏：返回 + "扫码接收"；
 * - 相机预览槽位（宿主传入；本页不自持 CameraX 生命周期）；
 * - 进度行（`已接收 {received} 帧 · 已解出 {decoded}/{total}`）+ 进度条；
 * - 提示行（对准屏幕、保持稳定）；
 * - 明文传输提醒（`qrTransferPlaintextWarning`，这是安全提示，任何状态下都显示）；
 * - 错误态：对应错误文案 + 「重新开始」；收齐后：完成文案 + 完整备份提醒 + 导入按钮。
 *
 * ## 为什么明文提醒在任何状态都显示
 *
 * 它是**警告**而不是阶段文案：告诉用户「附近的摄像头可能读到你在传的东西」。
 * 只在正常态显示等于「出了错就不需要知道了」，与安全提示的目的相反。
 *
 * 相机预览同样由宿主提供：CameraX 的权限与生命周期属壳层，本页只留槽位。
 *
 * @param model 已算好的接收状态
 * @param onBack 返回
 * @param onRestart 失败了重来
 * @param onImportFullBackup 收齐后导入完整备份
 * @param cameraSlot 相机预览槽位
 */
@Composable
fun QrTransferScanPage(
    model: QrTransferScanModel,
    onBack: () -> Unit,
    onRestart: () -> Unit,
    onImportFullBackup: () -> Unit,
    cameraSlot: @Composable () -> Unit,
) {
    val dark = isSystemInDarkTheme()

    // 共享骨架（2026-11-05 B 组迁移）：官方顶栏 + 标准返回键 + 顶栏毛玻璃。
    // 返回键显隐与玻璃圆底门控由骨架注入；`scrollBehavior` 由骨架下发给内容槽。
    // 附：原先返回键的读屏文案传的是**页面标题**（`contentDescription = model.title`），
    // 迁移后统一成骨架默认的「返回」。
    QingyuPageScaffold(
        title = model.title,
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
                    // ── 相机预览槽位（收齐或出错后可以留着最后一帧，不强制黑屏）──
                    QingyuCard(
                        modifier = Modifier
                            .fillMaxWidth()
                            .aspectRatio(1f),
                        insideMargin = PaddingValues(0.dp),
                    ) {
                        Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                            cameraSlot()
                        }
                    }

                    // ── 错误态 ──
                    val errorMessage = model.errorMessage
                    if (errorMessage != null) {
                        Text(
                            text = errorMessage,
                            style = MiuixTheme.textStyles.body2.shiftWeight(QingyuWeightDelta.MEDIUM),
                            color = Color(QingyuTheme.error(dark)),
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = 4.dp),
                        )
                        Button(
                            onClick = onRestart,
                            modifier = Modifier.fillMaxWidth(),
                            content = { Text(text = model.restartLabel) },
                        )
                    } else if (model.isComplete) {
                        // ── 收齐 ──
                        Text(
                            text = model.completeMessage,
                            style = MiuixTheme.textStyles.body2.shiftWeight(QingyuWeightDelta.MEDIUM),
                            color = Color(QingyuTheme.primaryText(dark)),
                            modifier = Modifier.fillMaxWidth(),
                        )
                        // 完整备份会替换本机数据：这是「确认后才发生」的提示
                        Text(
                            text = model.fullBackupWarning,
                            style = MiuixTheme.textStyles.footnote1,
                            color = Color(QingyuTheme.secondaryText(dark)),
                            modifier = Modifier.fillMaxWidth(),
                        )
                        Button(
                            onClick = onImportFullBackup,
                            modifier = Modifier.fillMaxWidth(),
                            content = { Text(text = model.importFullBackupLabel) },
                        )
                    } else {
                        // ── 收集中 ──
                        val progress = model.progressText
                        if (progress != null) {
                            Text(
                                text = progress,
                                style = MiuixTheme.textStyles.body2.shiftWeight(QingyuWeightDelta.MEDIUM),
                                color = Color(QingyuTheme.primaryText(dark)),
                            )
                            ProgressBar(fraction = model.progressFraction)
                        }
                        Text(
                            text = model.scanHint,
                            style = MiuixTheme.textStyles.footnote1,
                            color = Color(QingyuTheme.secondaryText(dark)),
                            modifier = Modifier.fillMaxWidth(),
                        )
                    }

                    // ── 明文提醒：任何状态都显示（安全提示不是阶段文案）──
                    Text(
                        text = model.plaintextWarning,
                        style = MiuixTheme.textStyles.footnote1,
                        color = Color(QingyuTheme.secondaryText(dark)),
                        modifier = Modifier.fillMaxWidth(),
                    )

                }
            }
        }
    }
}

/** 细进度条（与发送页同款）。 */
@Composable
private fun ProgressBar(fraction: Float) {
    val dark = isSystemInDarkTheme()
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(6.dp)
            .background(
                color = Color(QingyuTheme.surfaceContainerHighest(dark)),
                shape = RoundedCornerShape(3.dp),
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
                        shape = RoundedCornerShape(3.dp),
                    ),
            )
        }
    }
}

// ── Android Studio 预览（@Preview）────────────────────────────────────────────
//
// 与 `ContributorsPage` 同一套口径：一个 `Preview<页面>` 承担「接收状态 + 外观档位」，
// 下面每个 `@Preview` 只选一档。预览不接宿主：回调一律空实现。
//
// 相机是宿主传进来的槽位（CameraX 的权限与生命周期在壳层），预览里换成一行占位说明，
// 页面自己的进度、错误与完成态才看得清。

/** 预览用的相机槽位：预览环境不起相机，只说明这里本来是什么。 */
@Composable
private fun PreviewCameraSlot() {
    Text(text = "相机预览（预览里不启动相机）", style = MiuixTheme.textStyles.body2)
}

/** 一档预览的公共身体：接收状态 + 外观档位。 */
@Composable
private fun PreviewQrTransferScanPage(
    model: QrTransferScanModel,
    dark: Boolean = false,
    textScale: Float = 1f,
) {
    QingyuPageTheme(isDark = dark, textScale = textScale) {
        QrTransferScanPage(
            model = model,
            onBack = {},
            onRestart = {},
            onImportFullBackup = {},
            cameraSlot = { PreviewCameraSlot() },
        )
    }
}

@Suppress("unused")
@Preview(name = "1 收集中", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun QrTransferScanPagePreviewScanning() {
    PreviewQrTransferScanPage(
        model = QrTransferScanModel(
            receivedFrames = 18,
            decodedSymbols = 12,
            totalSymbols = 40,
        ),
    )
}

@Suppress("unused")
@Preview(name = "2 已收齐", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun QrTransferScanPagePreviewComplete() {
    PreviewQrTransferScanPage(
        model = QrTransferScanModel(
            receivedFrames = 40,
            decodedSymbols = 40,
            totalSymbols = 40,
        ),
    )
}

@Suppress("unused")
@Preview(name = "3 校验失败", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun QrTransferScanPagePreviewFailed() {
    PreviewQrTransferScanPage(
        model = QrTransferScanModel(
            receivedFrames = 23,
            decodedSymbols = 20,
            totalSymbols = 40,
            error = QrTransferScanModel.Error.CHECKSUM_FAILED,
        ),
    )
}

@Suppress("unused")
@Preview(name = "4 暗色", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun QrTransferScanPagePreviewDark() {
    PreviewQrTransferScanPage(
        model = QrTransferScanModel(
            receivedFrames = 18,
            decodedSymbols = 12,
            totalSymbols = 40,
        ),
        dark = true,
    )
}

@Suppress("unused")
@Preview(name = "5 大字号 1.3", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun QrTransferScanPagePreviewLargeText() {
    PreviewQrTransferScanPage(
        model = QrTransferScanModel(
            receivedFrames = 18,
            decodedSymbols = 12,
            totalSymbols = 40,
        ),
        textScale = 1.3f,
    )
}
