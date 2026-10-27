package com.mutx163.qingyu.pages.transfer

/**
 * 二维码扫码接收页（`lib/screens/qr_transfer_scan_screen.dart`，728 行）模型层。
 *
 * ## 接收端比发送端复杂在哪
 *
 * 发送端只需要轮播；接收端要处理**所有出错方式**，而每一种错对用户说的话都不一样：
 *
 * | 情况 | 用户该看到什么 |
 * |---|---|
 * | 扫到了另一份数据（会话不匹配） | 「检测到不同传输内容，请确认只对准一份数据」 |
 * | 校验和对不上 | 「传输校验失败，请重新开始」 |
 * | 解压后长度不对 | 「接收数据长度校验失败，请重新开始」 |
 * | 解压失败 | 「数据解压失败，请重新开始」 |
 * | 超过资源上限 | 「接收数据超过二维码传输资源上限…」 |
 * | 超时 | 「二维码传输已超时…」 |
 * | 解码失败（帧坏） | 「二维码数据解码失败，请重新开始」 |
 *
 * 搞混任何一种都会误导用户去重试错的方向（例如把「超限」说成「超时」，
 * 用户会一遍遍重试同一份过大备份）。所以这一层把「错误种类 → 一句准确的话」
 * 钉成映射，并在单测里逐条对拍。
 *
 * ## 阶段
 *
 * `SCANNING`（还在收）→ `COMPLETE`（收齐，正在导入）→ 或任一 `FAILED_*`。
 * 「重新开始」只在失败态出现；收齐后不该再让人重来，否则会和导入流程抢时序。
 */
class QrTransferScanModel(
    val receivedFrames: Int = 0,
    /** 已解出的源符号数。 */
    val decodedSymbols: Int = 0,
    /** 需要的源符号总数；0 = 头帧还没到，还不知道总量。 */
    val totalSymbols: Int = 0,
    /** 当前错误种类；null = 没错。 */
    val error: Error? = null,
) {

    /**
     * 错误种类（与 ARB 文案一一对应）。
     *
     * 每条自带一个 `message` 取值：枚举里直接指向对应 ARB 键，读代码时一眼能看出
     * 「这个错误说什么」，不必去 `when` 里翻。
     */
    enum class Error {
        SESSION_MISMATCH { override fun messageOf() = TransferStrings.qrTransferSessionMismatch.zh },
        CHECKSUM_FAILED { override fun messageOf() = TransferStrings.qrTransferChecksumFailed.zh },
        RAW_LENGTH_MISMATCH { override fun messageOf() = TransferStrings.qrTransferRawLengthMismatch.zh },
        DECOMPRESSION_FAILED { override fun messageOf() = TransferStrings.qrTransferDecompressionFailed.zh },
        RESOURCE_LIMIT { override fun messageOf() = TransferStrings.qrTransferResourceLimit.zh },
        SESSION_EXPIRED { override fun messageOf() = TransferStrings.qrTransferSessionExpired.zh },
        DECODE_FAILED { override fun messageOf() = TransferStrings.qrTransferDecodeFailed.zh };

        abstract fun messageOf(): String
    }

    val title: String get() = TransferStrings.qrTransferScanTitle.zh
    val scanHint: String get() = TransferStrings.qrTransferScanHint.zh
    val completeMessage: String get() = TransferStrings.qrTransferReceiveComplete.zh
    val restartLabel: String get() = TransferStrings.qrTransferRestart.zh
    val plaintextWarning: String get() = TransferStrings.qrTransferPlaintextWarning.zh

    /** 是否在收集中。 */
    val isScanning: Boolean get() = error == null && !isComplete

    /** 是否已经收齐（全部源符号到手）。 */
    val isComplete: Boolean get() = totalSymbols > 0 && decodedSymbols >= totalSymbols

    /** 错误提示文本；没错时 null。 */
    val errorMessage: String? get() = error?.messageOf()

    /**
     * 是否显示「重新开始」。
     *
     * 只在失败时出现：收齐之后重来会和导入流程抢时序；正常收集中也不该出现，
     * 免得用户误触丢掉已收到的帧。
     */
    val showRestart: Boolean get() = error != null

    /**
     * 进度文案：`已接收 {received} 帧 · 已解出 {decoded}/{total}`。
     *
     * `totalSymbols <= 0` 时返回 null：头帧还没到，`0/0` 只会让人困惑。
     */
    val progressText: String?
        get() {
            if (totalSymbols <= 0) return null
            val decoded = decodedSymbols.coerceIn(0, totalSymbols)
            return TransferStrings.qrTransferReceiveProgress.filled(
                "received" to receivedFrames.toString(),
                "decoded" to decoded.toString(),
                "total" to totalSymbols.toString(),
            )
        }

    /** 进度比例 0f~1f；未就绪时 0f。 */
    val progressFraction: Float
        get() = if (totalSymbols <= 0) 0f else (decodedSymbols.toFloat() / totalSymbols).coerceIn(0f, 1f)

    /**
     * 收齐后必须提醒的事：完整备份会替换本机数据。
     *
     * 这是「确认后才会发生」的提示，不是错误，所以单独一个字段而不是塞进 error。
     */
    val fullBackupWarning: String get() = TransferStrings.qrTransferFullBackupWarning.zh
    val importFullBackupLabel: String get() = TransferStrings.qrTransferImportFullBackup.zh
}
