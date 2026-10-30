package com.mutx163.qingyu.pages.statistics

import com.mutx163.qingyu.share.TransferShareContract
import java.io.File
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * F15（第二批·统计分享补图片导出）· 分享图纯逻辑测试。
 *
 * ## 期望值来源（独立于实现，别从实现里抄）
 *
 * - 文件名形状：Dart `statistics_share_service.dart:96`
 *   `'${tempDirectory.path}/statistics_export_$timestamp.png'`（前缀 + 毫秒时间戳 + `.png`）；
 * - 落盘目录：`res/xml/file_paths.xml` 里**真正生效的** `<cache-path>` 元素
 *   （不是那份文件注释里提到的字样——2026-10-30 对抗审核实测：只 `contains` 字符串时，
 *   把元素删掉、注释留着，本测试仍然全绿，等于没守）；
 * - 宽度区间：Dart `:88` `mediaQuery.size.width.clamp(320.0, 420.0)`；
 * - MIME：Dart `:104-108` `XFile(path, mimeType: 'image/png')`；
 * - 「空正文不许生成空图」「发不出图就退回纯文本」是清单 §一 1.2 的红线
 *   （假成功比没反应更糟），人推得出。
 */
class StatisticsShareImageModelTest {

    // ------------------------------------------------------------------ 文件与 Uri

    @Test
    fun `文件名与Dart同口径_前缀加毫秒时间戳加png后缀`() {
        val name = StatisticsShareImageModel.fileName(1_700_000_000_123L)
        assertEquals("statistics_export_1700000000123.png", name)
        assertTrue("必须以 .png 结尾：$name", name.endsWith(".png"))
        assertTrue("必须带导出前缀：$name", name.startsWith(StatisticsShareImageModel.FILE_PREFIX))
    }

    @Test
    fun `两次导出的文件名不同_不会互相覆盖`() {
        assertFalse(
            "不同毫秒必须不同名，否则上一张分享图被覆盖，接收方点开旧消息拿到新图",
            StatisticsShareImageModel.fileName(1L) == StatisticsShareImageModel.fileName(2L),
        )
    }

    @Test
    fun `落盘目录是file_paths点xml里登记过的那一个`() {
        val name = StatisticsShareImageModel.fileName(1_700_000_000_123L)
        val relative = StatisticsShareImageModel.cacheRelativePath(name)

        // ① 与共享契约逐字一致（那一层有单测把常量和 XML 对拍，本层不许再抄字符串）。
        assertEquals(TransferShareContract.providerCacheRelativePath(name), relative)
        assertEquals("transfer-share/$name", relative)

        // ② 再直接读一次真实的 file_paths.xml：目录**真在**白名单里。
        //    只看常量的话，两边一起改错（或 XML 那条被删）本测试会一起绿——那就成了摆设。
        //
        //    ⚠️ 这一条必须是**元素级**匹配：那份 XML 的注释里逐字写着
        //    `path="transfer-share/"`（在解释 name 与 path 的区别），
        //    字符串 contains 会被注释喂饱，元素真被删掉也不会红（2026-10-30 对抗审核实测）。
        val dirName = relative.substringBeforeLast('/')
        val elements = cachePathElements(filePathsXml())
        assertTrue(
            "file_paths.xml 里一个 <cache-path> 元素都没解析出来（解析坏了？这等于守卫空转）",
            elements.isNotEmpty(),
        )
        val registered = elements.any { element ->
            Regex("\\bname\\s*=\\s*\"${Regex.escape(TransferShareContract.PROVIDER_PATH_NAME)}\"")
                .containsMatchIn(element) &&
                Regex("\\bpath\\s*=\\s*\"${Regex.escape(dirName)}/\"")
                    .containsMatchIn(element)
        }
        assertTrue(
            "cacheDir/$dirName/ 没有对应的 <cache-path> 元素（注释里出现不算），" +
                "FileProvider.getUriForFile 会在运行期抛 IllegalArgumentException。\n" +
                "解析到的元素：$elements",
            registered,
        )
    }

    @Test
    fun `authority按运行期applicationId派生_空值拒绝`() {
        // dev 变体带 applicationIdSuffix（.debug），必须跟着变——写死正式包名只有正式包能分享出去。
        assertEquals(
            "com.mutx163.qingyu.debug.fileprovider",
            StatisticsShareImageModel.providerAuthority("com.mutx163.qingyu.debug"),
        )
        assertThrows(IllegalArgumentException::class.java) {
            StatisticsShareImageModel.providerAuthority("   ")
        }
    }

    @Test
    fun `MIME与ClipData标签都是契约的一部分`() {
        assertEquals("image/png", StatisticsShareImageModel.MIME_PNG)
        val label = StatisticsShareImageModel.CLIP_LABEL
        assertTrue("ClipData 标签不能为空", label.isNotBlank())
        assertTrue("ClipData 标签不该带空白字符：$label", label.none { it.isWhitespace() })
    }

    @Test
    fun `导出宽度收进320到420`() {
        assertEquals(320f, StatisticsShareImageModel.exportWidthDp(280f))
        assertEquals(420f, StatisticsShareImageModel.exportWidthDp(500f))
        assertEquals(375f, StatisticsShareImageModel.exportWidthDp(375f))
        // 0（非 Activity context 的 screenWidthDp 常见值）必须被抬到下限，而不是把图缩成 1px。
        assertEquals(320f, StatisticsShareImageModel.exportWidthDp(0f))
    }

    // ------------------------------------------------------------------ 卡片内容

    @Test
    fun `行序按标题_正文句_指标行拆开`() {
        val card = StatisticsShareImageModel.card(
            "统计\n来自轻屿课表的学期统计\n课程门数：12\n总节数：240",
        )!!
        assertEquals("统计", card.title)
        assertEquals("来自轻屿课表的学期统计", card.body)
        assertEquals(
            listOf(
                StatisticsShareImageModel.Row(label = "课程门数", value = "12"),
                StatisticsShareImageModel.Row(label = "总节数", value = "240"),
            ),
            card.rows,
        )
    }

    @Test
    fun `只有一行时没有正文句也没有指标行`() {
        val card = StatisticsShareImageModel.card("统计")!!
        assertEquals("统计", card.title)
        assertNull(card.body)
        assertTrue(card.rows.isEmpty())
    }

    @Test
    fun `切不出标签取值的行整行当正文_不造空标签`() {
        val card = StatisticsShareImageModel.card("统计\n正文\n第 3 周 · 12 节\n：取值缺标签\n标签缺取值：")!!
        assertEquals(
            listOf(
                StatisticsShareImageModel.Row("第 3 周 · 12 节", null),
                StatisticsShareImageModel.Row("：取值缺标签", null),
                StatisticsShareImageModel.Row("标签缺取值：", null),
            ),
            card.rows,
        )
    }

    @Test
    fun `取值里带冒号时只切第一处`() {
        val card = StatisticsShareImageModel.card("统计\n正文\n上课时间：08:00-09:40\n地点：A：B")!!
        assertEquals(
            listOf(
                StatisticsShareImageModel.Row("上课时间", "08:00-09:40"),
                StatisticsShareImageModel.Row("地点", "A：B"),
            ),
            card.rows,
        )
    }

    @Test
    fun `去空行但保序`() {
        assertEquals(listOf("A", "B", "C"), StatisticsShareImageModel.cardLines("A\n\nB\n   \nC\n"))
    }

    // ------------------------------------------------------------------ 诚实边界：不生成空图

    @Test
    fun `空正文不生成空图`() {
        assertNull("空串不该生成卡片", StatisticsShareImageModel.card(""))
        assertNull("只有空白的正文不该生成卡片", StatisticsShareImageModel.card("  \n\t\n "))
        assertNull(
            "payload 也必须回 null：调用方要据此降级成纯文本分享，而不是发一张只有底色的空图",
            StatisticsShareImageModel.payload(text = "", subject = "统计", epochMillis = 1L),
        )
        assertNull(
            StatisticsShareImageModel.payload(text = "\n\n", subject = "统计", epochMillis = 1L),
        )
    }

    @Test
    fun `payload把文件名_路径_MIME_正文_卡片串在一起`() {
        val text = "统计\n来自轻屿课表的学期统计\n课程门数：12"
        val payload = StatisticsShareImageModel.payload(text, subject = "学期统计", epochMillis = 42L)!!
        assertEquals("statistics_export_42.png", payload.fileName)
        assertTrue(payload.cacheRelativePath.endsWith(payload.fileName))
        assertEquals("image/png", payload.mimeType)
        assertEquals("学期统计", payload.subject)
        assertEquals("原文一字不改地放进 EXTRA_TEXT（接收方没有图时还能读到内容）", text, payload.text)
        // 图片画的就是这段正文的排版，不是另一份来源。
        assertEquals("统计", payload.card.title)
        assertEquals(listOf("课程门数" to "12"), payload.card.rows.map { it.label to it.value })
    }

    // ------------------------------------------------------------------ 发图还是降级：决策

    @Test
    fun `四步都成功时发图_载荷与Uri原样带走`() {
        val payload = payloadOf()
        val png = byteArrayOf(0x89.toByte(), 0x50, 0x4E, 0x47)
        val decision = StatisticsShareImageDecision.decide(
            payload = payload,
            png = png,
            writeSucceeded = true,
            uri = "content://com.mutx163.qingyu.fileprovider/transfer_share/x.png",
        )
        val image = decision as StatisticsShareImageDecision.Decision.ShareImage
        assertEquals(payload, image.payload)
        assertArrayEquals(png, image.png)
        assertEquals("content://com.mutx163.qingyu.fileprovider/transfer_share/x.png", image.uri)
    }

    @Test
    fun `空正文降级成纯文本_哪怕后面几步都成功`() {
        val decision = StatisticsShareImageDecision.decide(
            payload = null,
            png = byteArrayOf(1, 2, 3),
            writeSucceeded = true,
            uri = "content://x/y.png",
        )
        assertEquals(
            StatisticsShareImageDecision.FallbackReason.EMPTY_CONTENT,
            (decision as StatisticsShareImageDecision.Decision.FallbackToText).reason,
        )
    }

    @Test
    fun `光栅化失败降级成纯文本`() {
        val decision = StatisticsShareImageDecision.decide(
            payload = payloadOf(),
            png = null,
            writeSucceeded = true,
            uri = "content://x/y.png",
        )
        assertEquals(
            StatisticsShareImageDecision.FallbackReason.RASTERIZE_FAILED,
            (decision as StatisticsShareImageDecision.Decision.FallbackToText).reason,
        )
    }

    @Test
    fun `零字节PNG也算光栅化失败_不把空文件发出去`() {
        val decision = StatisticsShareImageDecision.decide(
            payload = payloadOf(),
            png = ByteArray(0),
            writeSucceeded = true,
            uri = "content://x/y.png",
        )
        assertEquals(
            StatisticsShareImageDecision.FallbackReason.RASTERIZE_FAILED,
            (decision as StatisticsShareImageDecision.Decision.FallbackToText).reason,
        )
    }

    @Test
    fun `写盘失败降级成纯文本`() {
        val decision = StatisticsShareImageDecision.decide(
            payload = payloadOf(),
            png = byteArrayOf(1),
            writeSucceeded = false,
            uri = "content://x/y.png",
        )
        assertEquals(
            StatisticsShareImageDecision.FallbackReason.WRITE_FAILED,
            (decision as StatisticsShareImageDecision.Decision.FallbackToText).reason,
        )
    }

    @Test
    fun `provider不可用时降级成纯文本`() {
        listOf(null, "", "   ").forEach { uri ->
            val decision = StatisticsShareImageDecision.decide(
                payload = payloadOf(),
                png = byteArrayOf(1),
                writeSucceeded = true,
                uri = uri,
            )
            assertEquals(
                "uri=$uri 时必须判成 provider 不可用（发不出图就退回纯文本）",
                StatisticsShareImageDecision.FallbackReason.PROVIDER_UNAVAILABLE,
                (decision as StatisticsShareImageDecision.Decision.FallbackToText).reason,
            )
        }
    }

    @Test
    fun `决策顺序与真实链路一致_空正文优先于后面所有失败`() {
        // 空正文 + 光栅化也失败：必须报「没有内容」，不是「画不出来」——
        // 否则排障时会被指去看渲染，而真正原因是没有内容。
        val decision = StatisticsShareImageDecision.decide(
            payload = null,
            png = null,
            writeSucceeded = false,
            uri = null,
        )
        assertEquals(
            StatisticsShareImageDecision.FallbackReason.EMPTY_CONTENT,
            (decision as StatisticsShareImageDecision.Decision.FallbackToText).reason,
        )
    }

    // ------------------------------------------------------------------ 工具

    private fun payloadOf(
        text: String = "统计\n来自轻屿课表的学期统计\n课程门数：12",
    ): StatisticsShareImageModel.Payload =
        StatisticsShareImageModel.payload(text, subject = "学期统计", epochMillis = 7L)!!

    /**
     * 读真实的 `res/xml/file_paths.xml`（从工作目录向上找仓库根，兼容 Gradle 与 IDE）。
     *
     * 找不到就**失败**而不是跳过——跳过等于这条断言不存在。
     */
    private fun filePathsXml(): String {
        val relative = "android/app/src/main/res/xml/file_paths.xml"
        var dir: File? = File("").absoluteFile
        repeat(8) {
            val candidate = File(dir, relative)
            if (candidate.isFile) return candidate.readText(Charsets.UTF_8)
            dir = dir?.parentFile
        }
        throw AssertionError("找不到 $relative（工作目录 ${File("").absolutePath}）")
    }

    /**
     * 取出**真正生效的** `<cache-path … />` 元素（先剥掉 XML 注释）。
     *
     * 为什么必须先剥注释：`file_paths.xml` 的注释里逐字写着
     * `name="transfer_share" path="transfer-share/"`（在解释 name 与 path 的区别），
     * 直接对全文 `contains` 会被注释喂饱——元素删掉也照样绿。
     */
    private fun cachePathElements(xml: String): List<String> =
        Regex("""<cache-path\b[^>]*/>""")
            .findAll(Regex("""<!--[\s\S]*?-->""").replace(xml, " "))
            .map { it.value }
            .toList()
}
