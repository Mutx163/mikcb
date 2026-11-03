package com.mutx163.qingyu.transfer

import com.mutx163.qingyu.pages.transfer.DataTransferImportLogic
import com.mutx163.qingyu.pages.transfer.TransferImportParseResult
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 文件通道读取的严格 UTF-8 解码（[TransferTextDecoding]）+ 接回导入模型层的判据。
 *
 * Dart 真值：`data_transfer_screen.dart` 里 `utf8.decode(bytes)` 默认
 * `allowMalformed: false`，畸形字节抛 `FormatException`，不会带着替换字符继续解析。
 * Android 胶水层（`platform/AndroidTransferDocumentAdapter`）在 JVM 单测里跑不起来
 * （引 `android.*`），所以判据抽到 [TransferTextDecoding]，这四例钉住它的行为：
 *
 * 1. `\xC3`（截断的 2 字节序列，缺后续字节）
 * 2. `\xFF`（UTF-8 里从不出现的字节）
 * 3. 合法 4 字节 emoji（U+1F600）必须照常解出并成功导入
 * 4. BOM（`EF BB BF`）**是合法 UTF-8**，解码不拒；拦截点仍是 JSON 门，报
 *    `transfer_package_json_invalid`（与 Dart `jsonDecode` 同口径）
 */
class TransferTextDecodingTest {

    /** 合法单课表包（与 `DataTransferImportLogicTest` 同构，手敲 JSON）。 */
    private val validPackage = """{""" +
        """"app":"mikcb","packageType":"transfer","schemaVersion":1,""" +
        """"packageId":"pkg-utf8","scope":"current_timetable","channel":"file",""" +
        """"exportedAt":"2026-03-02T08:30:00.000","profileName":"2026 春","currentWeek":3,""" +
        """"settings":{"sections":[{"startTime":"08:00","endTime":"08:45"}],""" +
        """"activeTimeSchemeId":"ts1","semesterWeekCount":16,""" +
        """"semesterStartDateText":"2026-03-02"},""" +
        """"courses":[{"id":"c1","name":"高等数学","teacher":"张老师","location":"A101",""" +
        """"dayOfWeek":1,"startSection":1,"endSection":2,"startTime":"08:00","endTime":"09:40"}],""" +
        """"tasks":[],"scheduleItems":[],"exams":[],""" +
        """"timeSchemes":[{"id":"ts1","name":"默认作息","sections":[{"startTime":"08:00",""" +
        """"endTime":"08:45"}],"createdAt":"2026-02-01T00:00:00.000",""" +
        """"updatedAt":"2026-02-01T00:00:00.000"}],""" +
        """"scheduleDateRules":[{"id":"r1","name":"规则一","timeSchemeId":"ts1","enabled":true,""" +
        """"startDate":"2026-03-02","endDate":"2026-03-08"}],""" +
        """"locationTimeGroups":[],"profiles":[]}"""

    // ---------- 畸形字节 ----------

    @Test
    fun `截断的 C3 序列被拒绝`() {
        // 0xC3 是 2 字节序列的首字节，后面没有 continuation byte：
        // Dart `utf8.decode` 抛 FormatException；这里返回 null（映射为 InvalidEncoding）。
        assertNull(TransferTextDecoding.decodeStrictUtf8(byteArrayOf(0xC3.toByte())))
    }

    @Test
    fun `FF 非法字节被拒绝`() {
        // 0xFF 不在任何合法 UTF-8 序列的首字节集合里。
        assertNull(TransferTextDecoding.decodeStrictUtf8(byteArrayOf(0xFF.toByte())))
    }

    // ---------- 合法字节：4 字节 emoji ----------

    @Test
    fun `含 4 字节 emoji 的包能正常导入`() {
        val emoji = "\uD83D\uDE00" // 😀 U+1F600
        assertEquals("emoji 必须真是 4 字节", 4, emoji.toByteArray(Charsets.UTF_8).size)

        val content = validPackage.replace(""""name":"高等数学"""", """"name":"高等数学$emoji"""")
        val text = TransferTextDecoding.decodeStrictUtf8(content.toByteArray(Charsets.UTF_8))
        assertNotNull("合法 UTF-8 不该被拒", text)
        assertEquals(content, text)

        val parsed = DataTransferImportLogic.parse(text!!)
        assertTrue("期望 Valid，实际 $parsed", parsed is TransferImportParseResult.Valid)
        val plan = (parsed as TransferImportParseResult.Valid).plan
        assertEquals("高等数学$emoji", plan.courses[0].name)
    }

    // ---------- 导入入口：错误分类 → 文案键（Lead 裁决） ----------

    @Test
    fun `畸形字节走解码入口报 InvalidEncoding 并复用 importFailedInvalidFile`() {
        for (bytes in listOf(byteArrayOf(0xC3.toByte()), byteArrayOf(0xFF.toByte()))) {
            val decoded = TransferTextDecoding.decodeImportText(bytes)
            assertTrue("期望 InvalidEncoding，实际 $decoded", decoded is TransferTextDecoding.DecodedImportText.InvalidEncoding)
        }
        // 不新增 `transfer_package_utf8_invalid` 那套键；复用既有 ARB 键。
        assertEquals(
            "importFailedInvalidFile",
            com.mutx163.qingyu.pages.transfer.TransferStrings.importFailedInvalidFile.key,
        )
    }

    @Test
    fun `空内容与仅空白内容判失败并复用 importFileReadFailed`() {
        val blanks = listOf(
            ByteArray(0),
            "   ".toByteArray(Charsets.UTF_8),
            " \n\t".toByteArray(Charsets.UTF_8),
        )
        for (bytes in blanks) {
            val decoded = TransferTextDecoding.decodeImportText(bytes)
            assertTrue("期望 EmptyContent，实际 $decoded", decoded is TransferTextDecoding.DecodedImportText.EmptyContent)
        }
        assertEquals(
            "importFileReadFailed",
            com.mutx163.qingyu.pages.transfer.TransferStrings.importFileReadFailed.key,
        )
    }

    // ---------- BOM：合法编码，交给 JSON 门 ----------

    @Test
    fun `BOM 前缀仍是合法 UTF-8 但导入报 transfer_package_json_invalid`() {
        val content = "\uFEFF" + validPackage
        val text = TransferTextDecoding.decodeStrictUtf8(content.toByteArray(Charsets.UTF_8))
        assertNotNull("BOM 是合法 UTF-8，解码层不该拒", text)
        assertTrue("BOM 应解出 U+FEFF", text!!.startsWith("\uFEFF"))

        val parsed = DataTransferImportLogic.parse(text)
        assertTrue("期望 Invalid，实际 $parsed", parsed is TransferImportParseResult.Invalid)
        assertEquals(
            "transfer_package_json_invalid",
            (parsed as TransferImportParseResult.Invalid).code,
        )
    }
}
