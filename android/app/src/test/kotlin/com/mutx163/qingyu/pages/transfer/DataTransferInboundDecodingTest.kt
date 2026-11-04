package com.mutx163.qingyu.pages.transfer

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * 二维码接收通道的编码口径（Dart `data_transfer_screen.dart:415` `utf8.decode`）。
 *
 * 要点：畸形字节必须得到 null（Host 走「导入失败」），不能产出 `U+FFFD` 文本。
 */
class DataTransferInboundDecodingTest {

    @Test
    fun `畸形字节返回 null 且不产出 U+FFFD 文本`() {
        val malformed = listOf(
            byteArrayOf(0xC3.toByte(), 0x28),
            byteArrayOf(0xED.toByte(), 0xA0.toByte(), 0x80.toByte()), // UTF-8 编码的代理区
            byteArrayOf(0xEF.toByte(), 0xBF.toByte(), 0xBD.toByte(), 0xC3.toByte()), // U+FFFD + 断尾
            byteArrayOf(0xFF.toByte()),
        )
        for (bytes in malformed) {
            assertNull(
                "畸形字节必须失败，否则会把替换字符带进 JSON",
                DataTransferInboundDecoding.decodeTransferText(bytes),
            )
        }
    }

    @Test
    fun `合法 UTF-8 原样返回`() {
        val text = DataTransferInboundDecoding.decodeTransferText("{\"a\":\"课表\"}".toByteArray(Charsets.UTF_8))
        assertNotNull(text)
        assertEquals("{\"a\":\"课表\"}", text)
    }
}
