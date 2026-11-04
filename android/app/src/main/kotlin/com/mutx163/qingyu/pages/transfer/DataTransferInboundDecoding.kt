package com.mutx163.qingyu.pages.transfer

import com.mutx163.qingyu.transfer.TransferTextDecoding

/**
 * 二维码接收通道的严格解码口径。
 *
 * Dart 侧扫码与文件通道都走 `utf8.decode`（默认 `allowMalformed: false`，
 * `data_transfer_screen.dart:415`）；畸形字节抛 `FormatException`，界面走「导入失败」。
 * 这里与文件通道共用 [TransferTextDecoding.decodeStrictUtf8]：失败返回 null，
 * **绝不**让 `U+FFFD` 替换字符进入后续 JSON 解析。
 *
 * 独立成对象只为给 Compose 入口留一个可单测的接缝（Host 里只剩一行调用）。
 */
object DataTransferInboundDecoding {

    fun decodeTransferText(bytes: ByteArray): String? =
        TransferTextDecoding.decodeStrictUtf8(bytes)
}
