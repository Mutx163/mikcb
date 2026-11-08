package com.mutx163.qingyu.pages.transfer

import com.mutx163.qingyu.core.MiniJson
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 数据备份与迁移 / 二维码传输文案逐字对照 ARB（`i18n/app_zh.arb`）。
 *
 * 验收门槛 3：界面文案与 ARB 原文逐字一致，不自己改写、不省略占位符。
 */
class TransferStringsParityTest {

    private val arbMap: Map<String, String> by lazy { loadArbZh() }

    @Test
    fun `每一处屏上文案都与 app_zh_arb 逐字一致`() {
        val texts = TransferStrings.allTexts
        assertTrue("文案条数不应少于 70 条，当前 ${texts.size}", texts.size >= 70)

        for (item in texts) {
            val template = arbMap[item.key]
            assertTrue("ARB(app_zh.arb) 中缺少键 `${item.key}`", template != null)
            assertMatchesArb(item.key, item.zh, template!!)
        }
    }

    @Test
    fun `占位符插值函数按预期生成文案`() {
        assertEquals("课程数量：12 门", TransferStrings.courseCountBullet.filled("count", "12"))
        assertEquals(
            "当前课表：2026 春",
            TransferStrings.currentTimetableBullet.filled("name", "2026 春"),
        )
        assertEquals(
            "当前周：第 5 周",
            TransferStrings.currentWeekBullet.filled("week", "5"),
        )
        assertEquals(
            "开学日期：2026-03-02",
            TransferStrings.semesterStartBullet.filled("date", "2026-03-02"),
        )
        assertEquals(
            "文件后缀：.mikcb",
            TransferStrings.fileExtensionBullet.filled("extension", "mikcb"),
        )
        assertEquals(
            "2026 春 - 轻屿课表备份",
            TransferStrings.dataTransferProfileShareSubjectNamed.filled("profileName", "2026 春"),
        )
        assertEquals(
            "已发送 12 帧，约需 40 帧",
            TransferStrings.qrTransferFrameProgress.filled("sent" to "12", "total" to "40"),
        )
        assertEquals(
            "已接收 12 帧 · 已解出 3/40",
            TransferStrings.qrTransferReceiveProgress
                .filled("received" to "12", "decoded" to "3", "total" to "40"),
        )
        assertEquals(
            "原始 1.2 MB · 压缩 340 KB",
            TransferStrings.qrTransferFileDataDetail
                .filled("rawSize" to "1.2 MB", "compressedSize" to "340 KB"),
        )
        assertEquals(
            "发送失败：未知错误",
            TransferStrings.sendFailedWithError.filled("error", "未知错误"),
        )
        // 「导入为新课表」新建模板名：`<课表名> 时间`（发布版硬编码 `'$nextName 时间'`，逐字照抄）。
        assertEquals(
            "我的课表 时间",
            TransferStrings.transferImportedTimeSchemeName.filled("name", "我的课表"),
        )
    }

    private fun assertMatchesArb(key: String, text: String, template: String) {
        if (!template.contains('{')) {
            assertEquals("ARB 键 `$key` 的屏上文案与 arb 不一致", template, text)
            return
        }
        val segments = template.split(Regex("""\{[^}]*\}""")).filter { it.isNotEmpty() }
        var cursor = 0
        for (segment in segments) {
            val idx = text.indexOf(segment, cursor)
            assertTrue(
                "键 `$key` 的渲染值『$text』里找不到模板片段『$segment』（模板：$template）",
                idx >= 0,
            )
            cursor = idx + segment.length
        }
    }

    private fun loadArbZh(): Map<String, String> {
        var dir: File? = File("").absoluteFile
        var arbFile: File? = null
        repeat(8) {
            val candidate = File(dir, "i18n/app_zh.arb")
            if (candidate.isFile) {
                arbFile = candidate
                return@repeat
            }
            dir = dir?.parentFile
        }
        val file = arbFile ?: error("找不到 i18n/app_zh.arb")
        val parsed = MiniJson.parse(file.readText(Charsets.UTF_8))
        check(parsed is Map<*, *>) { "app_zh.arb 顶层不是对象：${file.absolutePath}" }
        val map = LinkedHashMap<String, String>()
        parsed.forEach { (k, v) -> if (k is String && v is String) map[k] = v }
        return map
    }
}
