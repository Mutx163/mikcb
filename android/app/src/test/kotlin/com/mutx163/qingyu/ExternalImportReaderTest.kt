package com.mutx163.qingyu

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import java.io.ByteArrayInputStream

class ExternalImportReaderTest {

    @Test
    fun readsAFileUnderTheCap() {
        val payload = ByteArray(1024) { (it % 251).toByte() }
        val out = ExternalImportReader.readCapped(
            ByteArrayInputStream(payload),
            maxBytes = 2048,
        )
        assertArrayEquals(payload, out)
    }

    @Test
    fun refusesAFileOverTheCap() {
        val out = ExternalImportReader.readCapped(
            ByteArrayInputStream(ByteArray(4096)),
            maxBytes = 2048,
        )
        assertNull(out)
    }

    @Test
    fun aFileExactlyAtTheCapIsAccepted() {
        // `>` not `>=`, matching the Dart-side `length > maxBytes` check: a
        // legitimate 20 MB import must not be refused.
        val out = ExternalImportReader.readCapped(
            ByteArrayInputStream(ByteArray(2048)),
            maxBytes = 2048,
        )
        assertEquals(2048, out?.size)
    }

    /**
     * 边读边判：provider 不报 SIZE（declaredBytes 为 -1）的那条路也必须拦住。
     * 这条是本次修复的核心——旧的 `stream.readBytes()` 先把整份读进内存再看，
     * 对超大文件已经来不及；而「先 readBytes 再判长度」的实现同样过不了这一关。
     */
    @Test
    fun refusesAFileThatOnlyRevealsItsSizeWhileStreaming() {
        val out = ExternalImportReader.readCapped(
            ByteArrayInputStream(ByteArray(5 * 1024 * 1024)),
            maxBytes = 1024,
        )
        assertNull(out)
    }

    @Test
    fun theCapMatchesTheDartSideBudget() {
        // 与 SpreadsheetImportService.maxFileBytes /
        // UnifiedTransferService.maxImportFileBytes 同为 20 MB。数值漂了就等于
        // 一侧拦下一侧放行，等于没拦。
        assertEquals(20L * 1024 * 1024, ExternalImportReader.MAX_IMPORT_BYTES)
    }
}
