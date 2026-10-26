package com.mutx163.qingyu.share

/**
 * 二维码传输资源预算（移植自 lib/services/qr_transfer/qr_transfer_session.dart
 * 的 QrTransferLimits / QrTransferLimitException / QrTransferDecompressionException
 * 与 lib/services/qr_transfer/qr_transfer_codec.dart 的 QrTransferEncoder
 * 容量规划部分）。
 *
 * 纯逻辑：只做阈值与预算算术，不做 gzip、不做 LT 编解码、不碰网络与落盘。
 * LT 编解码依赖 fountain_codes 包，Kotlin 侧无对应物，故发送端 prepare /
 * 接收端 submit 的状态机不在本泳道移植范围内；帧文本协议见 [QrTransferFrame]。
 */
object QrTransferLimits {
    const val MAX_FRAME_TEXT_LENGTH = 8192
    const val MAX_SOURCE_SYMBOL_COUNT = 8192
    const val MAX_SYMBOL_SIZE = 4096
    const val MAX_COMPRESSED_PAYLOAD_BYTES = 16 * 1024 * 1024
    const val MAX_RAW_PAYLOAD_BYTES = 64 * 1024 * 1024
    const val MAX_FRAME_COUNT = 32768
    const val MAX_UNIQUE_SEED_COUNT = 16384

    /** Dart `maxSeed = 0x7fffffff`。 */
    const val MAX_SEED = Int.MAX_VALUE

    const val MAX_SESSION_DURATION_MILLIS = 15 * 60 * 1000L
    const val FRAME_INTERVAL_MILLIS = 250L

    const val MAX_DEGREE = 100
    const val MAX_ADJACENCY_EDGES_PER_SOURCE_SYMBOL = 32
    const val MAX_ADJACENCY_EDGES = MAX_SOURCE_SYMBOL_COUNT * MAX_ADJACENCY_EDGES_PER_SOURCE_SYMBOL

    const val DECOMPRESSION_CHUNK_BYTES = 32 * 1024

    fun maxDegreeForSourceSymbolCount(sourceSymbolCount: Int): Int =
        if (sourceSymbolCount < MAX_DEGREE) sourceSymbolCount else MAX_DEGREE

    fun maxAdjacencyEdgesForSourceSymbolCount(sourceSymbolCount: Int): Int {
        val scaled = sourceSymbolCount * MAX_ADJACENCY_EDGES_PER_SOURCE_SYMBOL
        return if (scaled < MAX_ADJACENCY_EDGES) scaled else MAX_ADJACENCY_EDGES
    }

    /**
     * 发送端按 250ms 播放间隔，能塞进接收端 15 分钟会话上限的帧数。
     * Dart：`maxSessionDuration.inMilliseconds ~/ frameInterval.inMilliseconds` = 3600。
     */
    fun maxSessionFrameCount(): Long = MAX_SESSION_DURATION_MILLIS / FRAME_INTERVAL_MILLIS

    /**
     * 按 gzip 后载荷大小选符号尺寸（Dart `QrTransferEncoder.pickSymbolSize` 原样移植）。
     * 256B/512B 是面对面扫码的甜点区间（约 V12 / V20 版本）。
     */
    fun pickSymbolSize(payloadLength: Int): Int = when {
        payloadLength <= 2048 -> 256
        payloadLength <= 16384 -> 512
        payloadLength <= 65536 -> 1024
        else -> 2048
    }

    /**
     * 发送端预检的纯算术部分（Dart `_preparePayload` 去掉 gzip/LT 之后）。
     *
     * @param compressedLength gzip 后载荷字节数（调用方自行压缩后传入）。
     * @param rawLength 原始字节数（必须 > 0）。
     * @throws IllegalArgumentException raw 为空（Dart `ArgumentError` 对应用）。
     * @throws QrTransferLimitException 任一预算超限，code 与 Dart 一致。
     */
    fun planTransfer(compressedLength: Int, rawLength: Int): QrTransferCapacity {
        if (rawLength <= 0) {
            throw IllegalArgumentException("rawBytes must not be empty")
        }
        if (rawLength > MAX_RAW_PAYLOAD_BYTES) {
            throw QrTransferLimitException(
                code = "qr_transfer_raw_payload_too_large",
                actual = rawLength,
                limit = MAX_RAW_PAYLOAD_BYTES,
            )
        }
        if (compressedLength > MAX_COMPRESSED_PAYLOAD_BYTES) {
            throw QrTransferLimitException(
                code = "qr_transfer_compressed_payload_too_large",
                actual = compressedLength,
                limit = MAX_COMPRESSED_PAYLOAD_BYTES,
            )
        }
        val symbolSize = pickSymbolSize(compressedLength)
        val sourceSymbolCount = (compressedLength + symbolSize - 1) / symbolSize
        if (sourceSymbolCount > MAX_SOURCE_SYMBOL_COUNT) {
            throw QrTransferLimitException(
                code = "qr_transfer_source_symbol_limit",
                actual = sourceSymbolCount,
                limit = MAX_SOURCE_SYMBOL_COUNT,
            )
        }
        val estimatedFrameCount = (sourceSymbolCount * 12 + 9) / 10
        if (estimatedFrameCount > MAX_FRAME_COUNT) {
            throw QrTransferLimitException(
                code = "qr_transfer_frame_budget_exceeded",
                actual = estimatedFrameCount,
                limit = MAX_FRAME_COUNT,
            )
        }
        if (estimatedFrameCount > maxSessionFrameCount()) {
            throw QrTransferLimitException(
                code = "qr_transfer_session_duration_exceeded",
                actual = estimatedFrameCount.toInt(),
                limit = maxSessionFrameCount().toInt(),
            )
        }
        return QrTransferCapacity(
            rawLength = rawLength,
            compressedLength = compressedLength,
            sourceSymbolCount = sourceSymbolCount,
            estimatedFrameCount = estimatedFrameCount,
        )
    }
}

/** Dart `QrTransferCapacity`。 */
data class QrTransferCapacity(
    val rawLength: Int,
    val compressedLength: Int,
    val sourceSymbolCount: Int,
    val estimatedFrameCount: Int,
)

/** Dart `QrTransferLimitException`。 */
class QrTransferLimitException(
    val code: String,
    val actual: Int,
    val limit: Int,
) : Exception("$code (actual: $actual, limit: $limit)")

/** Dart `QrTransferDecompressionException`（默认 code 与 Dart 一致）。 */
class QrTransferDecompressionException(
    val code: String = "qr_transfer_decompression_failed",
) : Exception(code)

/** 一次二维码传输会话的固定元信息，随每一帧在头部传输。 */
data class QrTransferSessionInfo(
    /** LT 源码符号数。 */
    val sourceSymbolCount: Int,
    /** 单个符号字节大小。 */
    val symbolSize: Int,
    /** 压缩后载荷真实字节数。 */
    val payloadLength: Int,
    /** 原始（未压缩）数据字节数。 */
    val rawLength: Int,
    /** 压缩后载荷 SHA-256 摘要（base64url）。 */
    val payloadSha256: String,
)

/** 解码进度（Dart `QrTransferDecodeProgress`，只含纯算术的 fraction）。 */
data class QrTransferDecodeProgress(
    val detectedSymbols: Int = 0,
    val duplicateSymbols: Int = 0,
    val receivedSymbols: Int = 0,
    val innovativeSymbols: Int = 0,
    val sourceSymbolCount: Int = 0,
    val decodedSymbols: Int = 0,
    val isComplete: Boolean = false,
) {
    /** 已解出符号占源码符号比例，0.0 ~ 1.0；k = 0 时按 1.0（Dart 原样）。 */
    val fraction: Double
        get() = if (sourceSymbolCount == 0) {
            1.0
        } else {
            (decodedSymbols.toDouble() / sourceSymbolCount).coerceIn(0.0, 1.0)
        }
}

/**
 * 当前 QR 协议仍是可信近场明文传输：SHA-256 只防意外损坏，不提供
 * 机密性、发送端认证与重放保护（Dart `QrTransferProtocolPolicy` 原样）。
 */
object QrTransferProtocolPolicy {
    const val TRUST_MODEL = "trusted_proximity_plaintext"
    const val REQUIRES_EXPLICIT_IMPORT_CONFIRMATION = true
    const val IS_ENCRYPTED = false
    const val AUTHENTICATES_SENDER = false
}
