package com.mutx163.qingyu.pages.transfer

import com.mutx163.qingyu.core.MiniJson
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 导出与传输族「余量三件」文案逐字对照 ARB（`i18n/app_zh.arb`）。
 *
 * `TransferExtStrings.kt` 的类注释一直声称「每条都在 `TransferExtStringsParityTest`
 * 里与 ARB 机械比对」，但在此之前**这个测试并不存在**：取件码的标题、分组名、七个入口、
 * 失败原因与无障碍标签共 50 余条文案没有任何对拍。本类把这句话补成真的。
 *
 * 判据：文案没有占位符时逐字相等；有占位符时把模板按 `{…}` 切开，
 * 要求渲染值里按顺序出现每一段（占位符的取值由调用方决定，不能拿它做字面比较）。
 */
class TransferExtStringsParityTest {

    private val arbMap: Map<String, String> by lazy { loadArbZh() }

    @Test
    fun `每一处屏上文案都与 app_zh_arb 逐字一致`() {
        val texts = TransferExtStrings.allTexts
        assertTrue("文案条数不应少于 45 条，当前 ${texts.size}", texts.size >= 45)

        for (item in texts) {
            val template = arbMap[item.key]
            assertTrue("ARB(app_zh.arb) 中缺少键 `${item.key}`", template != null)
            assertMatchesArb(item.key, item.zh, template!!)
        }
    }

    @Test
    fun `取件码的标题与分组名取自 ARB 原文`() {
        assertEquals("取件码", PickupCodesModel.title)
        assertEquals("出示身份码", PickupCodesModel.groupTitle(PickupCodesModel.Group.IDENTITY))
        assertEquals("查待取快递", PickupCodesModel.groupTitle(PickupCodesModel.Group.PARCELS))
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
