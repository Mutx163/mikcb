package com.mutx163.qingyu.platform

import com.google.zxing.BarcodeFormat
import com.google.zxing.EncodeHintType
import com.google.zxing.qrcode.QRCodeWriter
import com.google.zxing.qrcode.decoder.ErrorCorrectionLevel
import com.mutx163.qingyu.pages.statistics.charts.QrEncodeModel
import com.mutx163.qingyu.pages.statistics.charts.QrEncoder
import com.mutx163.qingyu.pages.statistics.charts.QrMatrix

/**
 * 二维码编码的 ZXing 实现（2026-11-14 用户决定：自研编码换成熟库）。
 *
 * ## 为什么在 `platform/`
 *
 * `pages/statistics` 是 L0 共享面，classpath 没有 `com.google.zxing:core`；把 `QRCodeWriter`
 * 写进去会让 24 个模块的 L0 一起红。所以接口 `QrEncoder` 留在域内，实现放这里，与
 * `OkHttpHolidayHttp` / `OkHttpAboutHttp` 同一套切法。L1 证明它能编过，
 * `src/test/kotlin/.../platform/ZxingQrEncoderTest` 证明它真能扫回来。
 *
 * ## 三个编码提示是刻意写死的
 *
 * - `QR_VERSION = 2`：品牌条按固定 25×25 排版；让 ZXing 自动挑版本会让短内容变成 21×21，
 *   版式跟着抖。
 * - `ERROR_CORRECTION = L`：与 Dart `qr_flutter` 给这个网址挑的规格一致
 *   （19 字节已放不进版本 1-L）。
 * - `MARGIN = 0`：白边由渲染层自己画（`StatisticsShareImageRender` 有背景与留白），
 *   编码器再塞 4 模块静区会多出一圈白框。
 */
object ZxingQrEncoder : QrEncoder {

    override fun encode(text: String): QrMatrix {
        val bitMatrix = QRCodeWriter().encode(
            text,
            BarcodeFormat.QR_CODE,
            QrEncodeModel.SIZE,
            QrEncodeModel.SIZE,
            mapOf(
                EncodeHintType.CHARACTER_SET to "UTF-8",
                EncodeHintType.ERROR_CORRECTION to ErrorCorrectionLevel.L,
                EncodeHintType.QR_VERSION to QrEncodeModel.VERSION,
                EncodeHintType.MARGIN to 0,
            ),
        )
        // 尺寸提示是 25×25 且静区 0，ZXing 按 1:1 输出；仍校验一次，
        // 免得将来有人把 MARGIN 改回默认 4 之后版式悄悄变宽。
        // 提示语用英文：CJK 字面量棘轮只降不升，屏上文案一律走 ArbText。
        check(bitMatrix.width == QrEncodeModel.SIZE && bitMatrix.height == QrEncodeModel.SIZE) {
            "unexpected qr size: ${bitMatrix.width}x${bitMatrix.height}, expected ${QrEncodeModel.SIZE}"
        }
        val dark = Array(QrEncodeModel.SIZE) { y ->
            BooleanArray(QrEncodeModel.SIZE) { x -> bitMatrix[x, y] }
        }
        return QrMatrix(QrEncodeModel.SIZE, dark)
    }
}
