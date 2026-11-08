package com.mutx163.qingyu.pages.course

import com.mutx163.qingyu.core.MiniJson
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 课程备注弹层文案逐字对照 ARB（`i18n/app_zh.arb`）。
 *
 * 验收门槛 3：界面文案与 ARB 原文逐字一致，不自己改写、不省略占位符。
 * 写法与 `AddCourseStringsParityTest` / `app/CourseActionStringsParityTest` 同一口径：
 * 无占位符的键比全串，带占位符的键按 `{…}` 切成片段**逐段核对**。
 *
 * `loadArbZh()` 从工作目录向上找仓库根定位 ARB，不写死绝对路径。
 */
class CourseNoteStringsParityTest {

    private val arbMap: Map<String, String> by lazy { loadArbZh() }

    @Test
    fun `每一处屏上文案都与 app_zh_arb 逐字一致`() {
        val texts = CourseNoteStrings.allTexts
        assertTrue("文案条数不应少于 20 条，当前 ${texts.size}", texts.size >= 20)

        for (item in texts) {
            val template = arbMap[item.key]
            assertTrue("ARB(app_zh.arb) 中缺少键 `${item.key}`", template != null)
            assertMatchesArb(item.key, item.zh, template!!)
        }
    }

    @Test
    fun `弹层本体用到的 12 条键一条不少`() {
        // 这一串是渲染层 `CourseNoteSheet.kt` 与 Dart `:214-330` 逐条对位的键，
        // 少一条就是「屏上少一句字」——单独钉一遍，防止有人把某条从 allTexts 里顺手删掉。
        val expectedKeys = listOf(
            "courseNoteSheetTitle",
            "courseNoteWholeCourseLabel",
            "courseNoteWholeCourseHint",
            "courseNoteWholeCoursePlaceholder",
            "courseNoteSessionLabel",
            "courseNoteSessionHint",
            "courseNoteSessionPlaceholder",
            "courseNoteReadOnlyNotice",
            "courseNoteSaveAction",
            "cancelAction",
            "weekLabel",
            "sectionRangeLabel",
        )
        val keysInUse = CourseNoteStrings.allTexts.map { it.key }.toSet()
        for (key in expectedKeys) {
            assertTrue("弹层用到的 ARB 键 `$key` 不在 CourseNoteStrings.allTexts 里", keysInUse.contains(key))
        }
    }

    @Test
    fun `周次与节次模板按 ARB 填充`() {
        assertEquals("第 3 周", CourseNoteStrings.weekText(3))
        assertEquals("第 18 周", CourseNoteStrings.weekText(18))
        assertEquals("第 1～2 节", CourseNoteStrings.sectionRangeText(1, 2))
        assertEquals("第 9～11 节", CourseNoteStrings.sectionRangeText(9, 11))
    }

    @Test
    fun `本节备注说明句把周次填进整句`() {
        assertEquals(
            "仅对第 5 周这一次课生效，适合记录携带物品或课堂提醒。",
            CourseNoteStrings.sessionHint(5),
        )
        assertEquals(
            "仅对第 16 周这一次课生效，适合记录携带物品或课堂提醒。",
            CourseNoteStrings.sessionHint(16),
        )
    }

    // ── 与 CourseActionStringsParityTest 同一口径的比对器 ──

    private fun assertMatchesArb(key: String, text: String, template: String) {
        if (!template.contains('{')) {
            assertEquals("ARB 键 `$key` 的屏上文案与 arb 不一致", template, text)
            return
        }
        // 占位符模板：逐段核对（占位符本身允许被填成任意值）
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
