package com.mutx163.qingyu.share

import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.util.zip.GZIPInputStream

/**
 * 从已解出的 gzip 载荷还原原始字节（移植自 qr_transfer_codec.dart
 * 的 `qrTransferDecompress` + `_BoundedByteSink`）。
 *
 * 输出 sink 在超过 [maxOutputBytes] 时立即拒绝，避免 gzip 炸弹把无界
 * 缓冲区打满；分块读取的块大小与 Dart
 * （`decompressionChunkBytes = 32 * 1024`）一致。
 *
 * @throws QrTransferLimitException 压缩体超限 / 预算非法 / 输出超预算
 *  （code 与 Dart 一致：`qr_transfer_compressed_payload_too_large`、
 *   `qr_transfer_raw_payload_too_large`、
 *   `qr_transfer_decompression_output_too_large`）。
 * @throws QrTransferDecompressionException 输入不是合法 gzip
 *  （code `qr_transfer_decompression_failed`）。
 */
fun qrTransferDecompress(
    compressedPayload: ByteArray,
    maxOutputBytes: Int = QrTransferLimits.MAX_RAW_PAYLOAD_BYTES,
): ByteArray {
    if (compressedPayload.size > QrTransferLimits.MAX_COMPRESSED_PAYLOAD_BYTES) {
        throw QrTransferLimitException(
            code = "qr_transfer_compressed_payload_too_large",
            actual = compressedPayload.size,
            limit = QrTransferLimits.MAX_COMPRESSED_PAYLOAD_BYTES,
        )
    }
    if (maxOutputBytes <= 0 || maxOutputBytes > QrTransferLimits.MAX_RAW_PAYLOAD_BYTES) {
        throw QrTransferLimitException(
            code = "qr_transfer_raw_payload_too_large",
            actual = maxOutputBytes,
            limit = QrTransferLimits.MAX_RAW_PAYLOAD_BYTES,
        )
    }
    val output = ByteArrayOutputStream()
    try {
        GZIPInputStream(ByteArrayInputStream(compressedPayload)).use { gzip ->
            val chunk = ByteArray(QrTransferLimits.DECOMPRESSION_CHUNK_BYTES)
            while (true) {
                val read = gzip.read(chunk)
                if (read < 0) break
                if (output.size() + read > maxOutputBytes) {
                    throw QrTransferLimitException(
                        code = "qr_transfer_decompression_output_too_large",
                        actual = output.size() + read,
                        limit = maxOutputBytes,
                    )
                }
                output.write(chunk, 0, read)
            }
        }
    } catch (e: QrTransferLimitException) {
        throw e
    } catch (_: Exception) {
        throw QrTransferDecompressionException()
    }
    return output.toByteArray()
}
