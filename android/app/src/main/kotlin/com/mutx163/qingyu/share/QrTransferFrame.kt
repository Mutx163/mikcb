package com.mutx163.qingyu.share

import java.util.Base64

/**
 * 二维码帧文本协议（移植自 lib/services/qr_transfer/qr_transfer_codec.dart
 * 的 `QrTransferFrame`，只含拼包与校验，不含 LT 编解码）。
 *
 * ```text
 * QRV2|<k>|<t>|<payloadLen>|<rawLen>|<payloadSha256B64>|<seed>|<degree>|<symbolB64>
 * ```
 *
 * - `k` / `t`：LT 码源码符号数与符号字节大小；
 * - `payloadLen`：gzip 后载荷真实字节数；
 * - `rawLen`：原始（未压缩）数据字节数；
 * - `payloadSha256B64`：载荷 SHA-256（base64url），解码完成后校验；
 * - `seed`：本帧 LT 编码种子；`degree`：本帧度数（随帧传输，解码端不采样）；
 * - `symbolB64`：本帧符号的 base64url 文本。
 */
class QrTransferFrame(
    val info: QrTransferSessionInfo,
    val seed: Int,
    val degree: Int,
    val symbolBytes: ByteArray,
) {
    /** 将一帧编码为可放入二维码的纯文本。 */
    fun encode(): String = listOf(
        MAGIC,
        info.sourceSymbolCount.toString(),
        info.symbolSize.toString(),
        info.payloadLength.toString(),
        info.rawLength.toString(),
        info.payloadSha256,
        seed.toString(),
        degree.toString(),
        Base64.getUrlEncoder().encodeToString(symbolBytes),
    ).joinToString(FIELD_SEPARATOR)

    companion object {
        const val MAGIC = "QRV2"
        const val FIELD_SEPARATOR = "|"
        const val EXPECTED_FIELD_COUNT = 9

        /** 魔数 + 分隔符，即「看起来是本协议帧」的最短前缀（`QRV2|`）。 */
        const val MAGIC_PREFIX = "$MAGIC$FIELD_SEPARATOR"

        /**
         * 这段文本**看起来**是不是本协议的帧——只看前缀，不做任何内容校验。
         *
         * 用途只有一个：把「扫到别人屏幕/纸上/包装上的二维码」与「扫本协议的帧但没读清」
         * 分开。前者应当**静默忽略**（现场到处是这样的码），后者才是真帧坏。
         * 判据取 `trim()` 后的 `QRV2|` 前缀：只认完整魔数 + 分隔符，
         * 「QRV2xxx」这种不是本协议。
         */
        fun looksLikeFrame(text: String): Boolean =
            text.trim().startsWith(MAGIC_PREFIX)

        /** QRV2 来自摄像头输入，元信息不可信：上限与 Dart 侧一致，防 OOM/死循环。 */
        const val MAX_FRAME_TEXT_LENGTH = QrTransferLimits.MAX_FRAME_TEXT_LENGTH
        const val MAX_SOURCE_SYMBOL_COUNT = QrTransferLimits.MAX_SOURCE_SYMBOL_COUNT
        const val MAX_SYMBOL_SIZE = QrTransferLimits.MAX_SYMBOL_SIZE
        const val MAX_PAYLOAD_LENGTH = QrTransferLimits.MAX_COMPRESSED_PAYLOAD_BYTES
        const val MAX_RAW_LENGTH = QrTransferLimits.MAX_RAW_PAYLOAD_BYTES
        const val MAX_SEED = QrTransferLimits.MAX_SEED
        const val MAX_DEGREE = QrTransferLimits.MAX_DEGREE

        /** SHA-256 摘要字节数（Dart 按 `sha256.convert([]).bytes.length` 校验）。 */
        const val SHA256_BYTES = 32

        /**
         * 解析二维码识别出的文本；格式不合法时抛 [IllegalArgumentException]
         *（Dart `FormatException('invalid_qr_transfer_frame')` 对应用，
         * message 固定为同一判据串，便于对拍）。
         */
        fun parse(text: String): QrTransferFrame {
            val normalized = text.trim()
            if (normalized.isEmpty() || normalized.length > MAX_FRAME_TEXT_LENGTH) {
                throw IllegalArgumentException(INVALID_FRAME)
            }
            val fields = normalized.split(FIELD_SEPARATOR)
            if (fields.size != EXPECTED_FIELD_COUNT || fields.first() != MAGIC) {
                throw IllegalArgumentException(INVALID_FRAME)
            }
            val sourceSymbolCount = parseIntField(fields[1])
            val symbolSize = parseIntField(fields[2])
            val payloadLength = parseIntField(fields[3])
            val rawLength = parseIntField(fields[4])
            val seed = parseIntField(fields[6])
            val degree = parseIntField(fields[7])
            if (sourceSymbolCount <= 0 ||
                symbolSize <= 0 ||
                payloadLength <= 0 ||
                rawLength <= 0 ||
                seed < 0 ||
                seed > MAX_SEED ||
                degree <= 0
            ) {
                throw IllegalArgumentException(INVALID_FRAME)
            }
            // 上界校验：恶意帧会让解码器按超大 k 建表（OOM），或 degree > k
            // 导致邻居选取死循环（见 Dart 注释）。
            val maxPayloadBySymbols =
                if (sourceSymbolCount > MAX_PAYLOAD_LENGTH / symbolSize) {
                    MAX_PAYLOAD_LENGTH
                } else {
                    sourceSymbolCount * symbolSize
                }
            if (sourceSymbolCount > MAX_SOURCE_SYMBOL_COUNT ||
                symbolSize > MAX_SYMBOL_SIZE ||
                degree > sourceSymbolCount ||
                degree > MAX_DEGREE ||
                payloadLength > MAX_PAYLOAD_LENGTH ||
                rawLength > MAX_RAW_LENGTH ||
                payloadLength > maxPayloadBySymbols
            ) {
                throw IllegalArgumentException(INVALID_FRAME)
            }
            try {
                val hashBytes = Base64.getUrlDecoder().decode(fields[5])
                if (hashBytes.size != SHA256_BYTES) {
                    throw IllegalArgumentException(INVALID_FRAME)
                }
            } catch (_: Exception) {
                throw IllegalArgumentException(INVALID_FRAME)
            }
            val symbolBytes: ByteArray
            try {
                symbolBytes = Base64.getUrlDecoder().decode(fields[8])
            } catch (_: Exception) {
                throw IllegalArgumentException(INVALID_FRAME)
            }
            if (symbolBytes.size != symbolSize) {
                throw IllegalArgumentException(INVALID_FRAME)
            }
            return QrTransferFrame(
                info = QrTransferSessionInfo(
                    sourceSymbolCount = sourceSymbolCount,
                    symbolSize = symbolSize,
                    payloadLength = payloadLength,
                    rawLength = rawLength,
                    payloadSha256 = fields[5],
                ),
                seed = seed,
                degree = degree,
                symbolBytes = symbolBytes,
            )
        }

        const val INVALID_FRAME = "invalid_qr_transfer_frame"

        private fun parseIntField(text: String): Int =
            text.trim().toIntOrNull() ?: throw IllegalArgumentException(INVALID_FRAME)
    }

    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is QrTransferFrame) return false
        return info == other.info && seed == other.seed &&
            degree == other.degree && symbolBytes.contentEquals(other.symbolBytes)
    }

    override fun hashCode(): Int {
        var result = info.hashCode()
        result = 31 * result + seed
        result = 31 * result + degree
        result = 31 * result + symbolBytes.contentHashCode()
        return result
    }
}
