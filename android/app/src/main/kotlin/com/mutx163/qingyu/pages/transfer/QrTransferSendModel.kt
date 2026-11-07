package com.mutx163.qingyu.pages.transfer

import com.mutx163.qingyu.share.QrTransferLimits

/**
 * 二维码发送页（`lib/screens/qr_transfer_send_screen.dart`，464 行）模型层。
 *
 * ## 传输是怎么进行的
 *
 * 数据切成若干帧，屏幕按固定间隔轮播这些二维码；对方摄像头抓帧、凑齐后解码。
 * 所以发送端要回答的问题是：
 *
 * 1. **还要多久**：已发出多少帧、总共约需多少帧（`已发送 {sent} 帧，约需 {total} 帧`）；
 * 2. **能不能发**：超时 / 超资源上限必须提前拦，不然用户等三分钟才看到失败；
 * 3. **该不该停**：用户随时可以停（`停止发送`）。
 *
 * ## 为什么「进度文案」值得单测
 *
 * 这行字是用户唯一的进度感。三个坑：
 * - `total` 为 0 时不能显示「约需 0 帧」（数据还没准备好，应显示别的）；
 * - `sent > total` 时不能显示负数或超 100%（重复帧会让 sent 超过预期）；
 * - 超时之后仍显示进度会让人以为还在传。
 *
 * 这些判据都在这里，渲染层只管摆字。
 */
class QrTransferSendModel(
    /** 已发出的帧数。 */
    val sentFrames: Int = 0,
    /** 预计总帧数；0 = 还没算出来（数据没准备好）。 */
    val totalFrames: Int = 0,
    /** 会话开始至今的毫秒数。 */
    val elapsedMillis: Long = 0L,
    /** 会话是否已经超时。 */
    val expired: Boolean = false,
    /** 数据是否超过资源上限。 */
    val overResourceLimit: Boolean = false,
) {

    val title: String get() = TransferStrings.qrTransferSectionTitle.text
    val sendHint: String get() = TransferStrings.qrTransferSendHint.text
    val stopLabel: String get() = TransferStrings.qrTransferStop.text
    val limitMessage: String get() = TransferStrings.qrTransferResourceLimit.text
    val expiredMessage: String get() = TransferStrings.qrTransferSessionExpired.text

    /** 是否还能继续发（超时或超限都不能）。 */
    val canSend: Boolean get() = !expired && !overResourceLimit

    /**
     * 进度文案。
     *
     * `totalFrames <= 0` 时返回 null —— 数据还没算好帧数，这时候显示「约需 0 帧」
     * 是在撒谎。渲染层拿到 null 就不画这一行。
     */
    val progressText: String?
        get() {
            if (totalFrames <= 0) return null
            // sent 可能因重复帧超过 total，显示时夹住，避免「已发送 120 帧，约需 100 帧」这种自相矛盾
            val shownSent = sentFrames.coerceIn(0, totalFrames)
            return TransferStrings.qrTransferFrameProgress.filled(
                "sent" to shownSent.toString(),
                "total" to totalFrames.toString(),
            )
        }

    /** 进度比例 0f~1f（供渲染层画进度条）；未就绪时 0f。 */
    val progressFraction: Float
        get() = if (totalFrames <= 0) 0f else (sentFrames.toFloat() / totalFrames).coerceIn(0f, 1f)

    /** 是否已经发完（凑齐全部帧）。 */
    val isComplete: Boolean get() = totalFrames > 0 && sentFrames >= totalFrames

    /**
     * 该显示哪种提示：
     * - 超资源上限 → 上限文案（比超时更根本，先说这个）；
     * - 超时 → 超时文案；
     * - 否则没有提示。
     *
     * 顺序有讲究：超限时就算也超时了，用户该看到的是「备份太大」而不是「超时」，
     * 否则他会一直重试同一份过大的数据。
     */
    val blockingMessage: String?
        get() = when {
            overResourceLimit -> limitMessage
            expired -> expiredMessage
            else -> null
        }

    /** 已用时间文本（`m:ss`）；渲染层统计行用。 */
    val elapsedText: String
        get() {
            val totalSeconds = (elapsedMillis / 1000).coerceAtLeast(0)
            val minutes = totalSeconds / 60
            val seconds = totalSeconds % 60
            return "%d:%02d".format(minutes, seconds)
        }

    /** 帧间隔（毫秒）：屏幕轮播节奏由底层常量决定，不在这里另定一个数。 */
    val frameIntervalMillis: Long get() = QrTransferLimits.FRAME_INTERVAL_MILLIS
}
