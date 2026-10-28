package com.mutx163.qingyu.pages.transfer

import android.os.SystemClock
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import com.mutx163.qingyu.share.QrTransferLimits
import com.mutx163.qingyu.share.camera.BarcodeScanResult
import com.mutx163.qingyu.share.qr.QrEncoder
import kotlinx.coroutines.delay

/**
 * 二维码传输两头的**宿主接线**（Phase 3.5 · TQ1）。
 *
 * 两个页面（`QrTransferSendPage` / `QrTransferScanPage`）在 Phase 3 交付时都只留了槽位
 * （`qrSlot` / `cameraSlot`），槽位里该放什么一直空着，所以这两个页面在真机上点进去
 * 是「一张空白卡片」。本文件就是填槽位，并把槽位与纯逻辑层接起来：
 *
 * ```
 * 发送：QrTransferSendSession（纯逻辑：LT 编码 + 轮播节奏）
 *         └─ QrSendQrSlot（Compose：QrEncoder 编矩阵 → QrMatrixCanvas 画）
 * 接收：QrCameraSlot（B6：CameraX + MLKit + 权限 + 去重）
 *         └─ QrTransferReceiveSession（纯逻辑：拼帧 + 削皮解码 + 校验 + 错误映射）
 *              └─ QrTransferScanPage（Phase 3：只负责摆字）
 * ```
 *
 * ## 为什么宿主自己持有「经过了多少毫秒」
 *
 * 页面的模型是**时间的函数**（`已发送 N 帧，约需 M 帧`、超时、超限）。如果把计时器放在
 * 页面里，页面就得知道自己有状态，Phase 3 的「纯渲染」契约就破了。所以计时、取帧、
 * 算模型这三件事全在宿主，页面继续吃一个不可变的 `QrTransferSendModel`。
 */

// ─────────────────────────────────────────────────────────────
// 发送端
// ─────────────────────────────────────────────────────────────

/**
 * 发送页的 `qrSlot`：把「第几拍该显示哪一帧」渲染成二维码。
 *
 * @param session 发送会话；null 表示没有数据可发（槽位保持空白，页面照常显示提示行）
 * @param elapsedMillis 会话已用毫秒数（由 [QrTransferSendHost] 提供）
 */
@Composable
fun QrSendQrSlot(
    session: QrTransferSendSession?,
    elapsedMillis: Long,
    modifier: Modifier = Modifier,
) {
    if (session == null || !session.hasFrames) {
        Box(modifier = modifier)
        return
    }
    // 一拍 = 一个帧间隔；tick 就是「第几拍」。
    val frameText = remember(session, elapsedMillis) {
        val tick = (elapsedMillis / session.frameIntervalMillis)
            .coerceAtMost(Int.MAX_VALUE.toLong())
            .toInt()
        session.frameTextForTick(tick)
    }
    // QrEncoder 是纯 CPU 活（选版本 + 试 8 个掩码）；文本一变才重算。
    // 编不出来（例如极端长度）就退化成空槽位，不把整页带崩。
    val matrix = remember(frameText) {
        frameText?.let { text -> runCatching { QrEncoder.encode(text) }.getOrNull() }
    }
    if (matrix == null) {
        Box(modifier = modifier)
    } else {
        QrMatrixCanvas(matrix = matrix, modifier = modifier)
    }
}

/**
 * 发送页 + 二维码渲染（一行接线给壳用）。
 *
 * 计时器在这里，不在页面里：页面继续是「给什么画什么」的纯渲染层。
 *
 * @param session 由 `QrTransferSendSession.prepare(要发的字节)` 准备好
 * @param active 页面是否在前台（后台时停止计时，免得把「已发送帧数」白白刷上去）
 */
@Composable
fun QrTransferSendHost(
    session: QrTransferSendSession?,
    onBack: () -> Unit,
    onStop: () -> Unit,
    active: Boolean = true,
) {
    var elapsedMillis by remember(session) { mutableStateOf(0L) }

    LaunchedEffect(session, active) {
        if (!active) return@LaunchedEffect
        val interval = session?.frameIntervalMillis ?: QrTransferLimits.FRAME_INTERVAL_MILLIS
        val start = SystemClock.elapsedRealtime()
        while (true) {
            elapsedMillis = SystemClock.elapsedRealtime() - start
            delay(interval)
        }
    }

    val model = remember(session, elapsedMillis) {
        session?.modelAt(elapsedMillis) ?: QrTransferSendModel()
    }

    QrTransferSendPage(
        model = model,
        onBack = onBack,
        onStop = onStop,
        qrSlot = { QrSendQrSlot(session = session, elapsedMillis = elapsedMillis, modifier = Modifier.fillMaxSize()) },
    )
}

// ─────────────────────────────────────────────────────────────
// 接收端
// ─────────────────────────────────────────────────────────────

/**
 * 扫码接收页 + 相机 + 分帧接收会话（一行接线给壳用）。
 *
 * 这是 B6 诚实清单第 ③ 条的正解：「扫码结果没有接业务，扫到码也只是回调空实现」。
 * 现在每一条放行的识别结果都会进 [QrTransferReceiveSession]，页面上的进度/错误全部来自它。
 *
 * @param onImportFullBackup 收齐且校验通过后的原始字节（导入动作由壳/数据层执行，
 *   本文件**不碰仓储**——「完整备份会覆盖本机数据」要用户确认后才发生）
 */
@Composable
fun QrTransferScanHost(
    onBack: () -> Unit,
    onImportFullBackup: (ByteArray) -> Unit,
    active: Boolean = true,
) {
    val session = remember { QrTransferReceiveSession() }
    var model by remember { mutableStateOf(session.model()) }
    // 「重新开始」要连相机侧的去重/节流状态一起重置，所以换 key 让槽位整个重建。
    var cameraGeneration by remember { mutableStateOf(0) }

    QrTransferScanPage(
        model = model,
        onBack = onBack,
        onRestart = {
            session.reset()
            model = session.model()
            cameraGeneration++
        },
        onImportFullBackup = {
            val raw = session.consumeRawPayload()
            model = session.model()
            if (raw != null) onImportFullBackup(raw)
        },
        cameraSlot = {
            key(cameraGeneration) {
                QrCameraSlot(
                    onBarcode = { barcode: BarcodeScanResult ->
                        session.onBarcode(barcode)
                        // 收齐的那一刻就把「压缩载荷 → 原始字节」这一步做完：
                        // 解压失败必须变成页面上一条准确的错误，而不是留个静默的「完成」。
                        if (session.isVerified && session.rawData == null) {
                            session.consumeRawPayload()
                        }
                        model = session.model()
                    },
                    active = active,
                )
            }
        },
    )
}
