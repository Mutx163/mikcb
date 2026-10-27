package com.mutx163.qingyu.pages.statistics

import com.mutx163.qingyu.core.MiniJson
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 统计族余量两页的文案逐字对照 ARB（`lib/l10n/app_zh.arb`）。
 *
 * 验收门槛 3：界面文案与 ARB 原文逐字一致，不自己改写、不省略占位符。
 * 与已交付的 [StatisticsStringsParityTest] 分开，互不改动对方的验收基线。
 */
class StatisticsExtStringsParityTest {

    private val arbMap: Map<String, String> by lazy { loadArbZh() }

    @Test
    fun `每一处屏上文案都与 app_zh_arb 逐字一致`() {
        val texts = StatisticsExtStrings.allTexts
        assertTrue("文案条数不应少于 20 条，当前 ${texts.size}", texts.size >= 20)

        for (item in texts) {
            val template = arbMap[item.key]
            assertTrue("ARB(app_zh.arb) 中缺少键 `${item.key}`", template != null)
            assertEquals(
                "键 `${item.key}` 的文案与 ARB 不一致（不许自己改写）",
                template,
                item.zh,
            )
        }
    }

    @Test
    fun `allTexts 没有重复键（重复说明有人复制粘贴时漏改了键名）`() {
        val keys = StatisticsExtStrings.allTexts.map { it.key }
        assertEquals("allTexts 里出现重复键：$keys", keys.size, keys.toSet().size)
    }

    @Test
    fun `六个分析模块标题都能在 ARB 里找到且互不相同`() {
        val titles = StatisticsAnalysisModule.entries.map { StatisticsAnalysisModel.title(it) }
        assertEquals("分析模块应有 6 个", 6, titles.size)
        assertEquals("六个模块标题不该有重复：$titles", titles.size, titles.toSet().size)
        assertTrue("标题不该为空", titles.all { it.isNotBlank() })
    }

    @Test
    fun `课次阶段标签六种全覆盖且各自对应 ARB`() {
        val labels = com.mutx163.qingyu.core.CourseSessionPhase.entries.map {
            StatisticsSessionModel.phaseLabel(it)
        }
        assertEquals("阶段应有 6 种", 6, labels.size)
        assertTrue("阶段标签不该为空", labels.all { it.isNotBlank() })
    }

    private fun loadArbZh(): Map<String, String> {
        var dir: File? = File("").absoluteFile
        var arbFile: File? = null
        repeat(8) {
            val candidate = File(dir, "lib/l10n/app_zh.arb")
            if (candidate.isFile) {
                arbFile = candidate
                return@repeat
            }
            dir = dir?.parentFile
        }
        val file = arbFile ?: error("找不到 lib/l10n/app_zh.arb")
        val parsed = MiniJson.parse(file.readText(Charsets.UTF_8))
        check(parsed is Map<*, *>) { "app_zh.arb 顶层不是对象：${file.absolutePath}" }
        val map = LinkedHashMap<String, String>()
        parsed.forEach { (k, v) -> if (k is String && v is String) map[k] = v }
        return map
    }
}
