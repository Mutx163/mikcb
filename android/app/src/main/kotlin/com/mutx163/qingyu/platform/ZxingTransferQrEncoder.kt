package com.mutx163.qingyu.platform

import com.google.zxing.BarcodeFormat
import com.google.zxing.EncodeHintType
import com.google.zxing.WriterException
import com.google.zxing.qrcode.QRCodeWriter
import com.google.zxing.qrcode.decoder.ErrorCorrectionLevel
import com.mutx163.qingyu.share.qr.QrErrorCorrectionLevel
import com.mutx163.qingyu.share.qr.QrMatrix
import com.mutx163.qingyu.share.qr.ShareQrEncoderPort

/**
 * 局域网页二维码的 ZXing 实现（2026-11-14 用户决定：自研编码换成熟库）。
 *
 * 原实现（687 行）是把 Dart `qr` 3.0.2 逐行移植过来的手写编码器，立项理由是「与 Dart
 * 逐位对拍」。Dart 层（P4-C）已经删除，那个理由不再成立；而版本选择 / 掩码 / 纠错码字
 * 属于「典型别手写」的一类，所以和品牌条二维码一起换 ZXing。
 *
 * ## 为什么在 `platform/`
 *
 * `share` 是 L0 共享面，classpath 没有 `com.google.zxing:core`。接口 `ShareQrEncoderPort`
 * 留在 `share/qr`（纯 Kotlin），实现放这里——与 `ZxingQrEncoder` / `OkHttpAboutHttp` 同构。
 *
 * ## 与旧实现的差异（唯一允许的差异）
 *
 * **掩码选择**改用 ZXing 的罚分实现，所以同一内容的矩阵不再与 Dart 版逐位相同。
 * 这不影响用途：两端各扫自己的码，编码结果只需是**规范合法**的二维码；`QrMatrix`
 * 的尺寸、自动版本选择与显式版本语义都保持不变。
 */
object ZxingTransferQrEncoder : ShareQrEncoderPort {

    override fun encode(
        text: String,
        ec: QrErrorCorrectionLevel,
        version: Int?,
    ): QrMatrix {
        val hints = mutableMapOf<EncodeHintType, Any>(
            EncodeHintType.CHARACTER_SET to "UTF-8",
            EncodeHintType.ERROR_CORRECTION to zxingLevel(ec),
            // 白边由 QrMatrixCanvas 画（它有背景与 padding），编码器再塞静区会多一圈白框。
            EncodeHintType.MARGIN to 0,
        )
        if (version != null) hints[EncodeHintType.QR_VERSION] = version
        val bitMatrix = try {
            // 宽高传 0：ZXing 按「1 模块 = 1 像素」输出，尺寸正好等于模块数。
            QRCodeWriter().encode(text, BarcodeFormat.QR_CODE, 0, 0, hints)
        } catch (error: WriterException) {
            // 提示语用英文：CJK 字面量棘轮只降不升，屏上文案一律走 ArbText。
            throw IllegalArgumentException(
                "qr content does not fit " +
                    (version?.let { "version $it" } ?: "version 40") +
                    ": " + error.message,
                error,
            )
        }
        val size = bitMatrix.width
        check(size == bitMatrix.height) { "qr output is not square: ${size}x${bitMatrix.height}" }
        val dark = Array(size) { y -> BooleanArray(size) { x -> bitMatrix[x, y] } }
        return QrMatrix(size, dark)
    }

    private fun zxingLevel(ec: QrErrorCorrectionLevel): ErrorCorrectionLevel = when (ec) {
        QrErrorCorrectionLevel.L -> ErrorCorrectionLevel.L
        QrErrorCorrectionLevel.M -> ErrorCorrectionLevel.M
        QrErrorCorrectionLevel.Q -> ErrorCorrectionLevel.Q
        QrErrorCorrectionLevel.H -> ErrorCorrectionLevel.H
    }
}
