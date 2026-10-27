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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.components.QingyuPageTheme
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.ButtonDefaults
import top.yukonga.miuix.kmp.basic.Card
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.IconButton
import top.yukonga.miuix.kmp.basic.Scaffold
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TopAppBar
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Back
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

    QingyuPageTheme {
        Scaffold(
            containerColor = Color(QingyuTheme.scaffoldBackground(dark)),
            topBar = {
                TopAppBar(
                    title = model.title,
                    navigationIcon = {
                        IconButton(onClick = onBack) {
                            Icon(
                                imageVector = MiuixIcons.Back,
                                contentDescription = model.title,
                                tint = Color(QingyuTheme.actionIcon(dark)),
                            )
                        }
                    },
                )
            },
        ) { innerPadding ->
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(innerPadding)
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = 16.dp, vertical = 8.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                // ── 相机预览槽位（收齐或出错后可以留着最后一帧，不强制黑屏）──
                Card(
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
                        fontSize = 15.sp,
                        fontWeight = FontWeight.Medium,
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
                        fontSize = 15.sp,
                        fontWeight = FontWeight.Medium,
                        color = Color(QingyuTheme.primaryText(dark)),
                        modifier = Modifier.fillMaxWidth(),
                    )
                    // 完整备份会替换本机数据：这是「确认后才发生」的提示
                    Text(
                        text = model.fullBackupWarning,
                        fontSize = 13.sp,
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
                            fontSize = 15.sp,
                            fontWeight = FontWeight.Medium,
                            color = Color(QingyuTheme.primaryText(dark)),
                        )
                        ProgressBar(fraction = model.progressFraction)
                    }
                    Text(
                        text = model.scanHint,
                        fontSize = 13.sp,
                        color = Color(QingyuTheme.secondaryText(dark)),
                        modifier = Modifier.fillMaxWidth(),
                    )
                }

                // ── 明文提醒：任何状态都显示（安全提示不是阶段文案）──
                Text(
                    text = model.plaintextWarning,
                    fontSize = 12.sp,
                    color = Color(QingyuTheme.secondaryText(dark)),
                    modifier = Modifier.fillMaxWidth(),
                )
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
