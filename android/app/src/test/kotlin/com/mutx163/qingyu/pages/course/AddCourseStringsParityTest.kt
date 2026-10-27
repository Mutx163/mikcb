package com.mutx163.qingyu.pages.course

import com.mutx163.qingyu.core.MiniJson
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 加课表单模块文案逐字对照 ARB（`lib/l10n/app_zh.arb`）。
 *
 * 验收门槛 3：界面文案与 ARB 原文逐字一致，不自己改写、不省略占位符。
 * `loadArbZh()` 从工作目录向上找仓库根定位 ARB，不写死绝对路径。
 */
class AddCourseStringsParityTest {

    private val arbMap: Map<String, String> by lazy { loadArbZh() }

    @Test
    fun `每一处屏上文案都与 app_zh_arb 逐字一致`() {
        val texts = AddCourseStrings.allTexts
        assertTrue("文案条数不应少于 85 条，当前 ${texts.size}", texts.size >= 85)

        for (item in texts) {
            val template = arbMap[item.key]
            assertTrue("ARB(app_zh.arb) 中缺少键 `${item.key}`", template != null)
            assertMatchesArb(item.key, item.zh, template!!)
        }
    }

    @Test
    fun `星期名称与 ARB 严格对齐`() {
        assertEquals("周一", AddCourseStrings.weekdayName(1))
        assertEquals("周二", AddCourseStrings.weekdayName(2))
        assertEquals("周三", AddCourseStrings.weekdayName(3))
        assertEquals("周四", AddCourseStrings.weekdayName(4))
        assertEquals("周五", AddCourseStrings.weekdayName(5))
        assertEquals("周六", AddCourseStrings.weekdayName(6))
        assertEquals("周日", AddCourseStrings.weekdayName(7))
        assertEquals("", AddCourseStrings.weekdayName(0))
        assertEquals("", AddCourseStrings.weekdayName(8))
    }

    @Test
    fun `星期短名称与 ARB 严格对齐`() {
        assertEquals("一", AddCourseStrings.weekdayShortName(1))
        assertEquals("二", AddCourseStrings.weekdayShortName(2))
        assertEquals("三", AddCourseStrings.weekdayShortName(3))
        assertEquals("四", AddCourseStrings.weekdayShortName(4))
        assertEquals("五", AddCourseStrings.weekdayShortName(5))
        assertEquals("六", AddCourseStrings.weekdayShortName(6))
        assertEquals("日", AddCourseStrings.weekdayShortName(7))
    }

    @Test
    fun `占位符插值函数按预期生成文案`() {
        // 手推期望值（对照 Dart 调用点），不读实现
        assertEquals("第 4 周", AddCourseStrings.weekLabel.filled("week", "4"))
        assertEquals(
            "已选 3 周：第 1-3 周",
            AddCourseStrings.selectedWeeksSummary.filled("count", "3").filled("weeks", "1-3"),
        )
        assertEquals(
            "确定删除课程 高等数学？",
            AddCourseStrings.confirmDeleteCourseMessage.filled("name", "高等数学"),
        )
        assertEquals(
            "周 三 3～4 节",
            AddCourseStrings.weekdaySectionSummary
                .filled("weekday", "三")
                .filled("startSection", "3")
                .filled("endSection", "4"),
        )
        assertEquals(
            "跟随当前课表 轻屿课表",
            AddCourseStrings.followCurrentTimetableWithName.filled("name", AddCourseStrings.timetableAppName.zh),
        )
        assertEquals(
            "地点组 A101 → 晚作息",
            AddCourseStrings.locationTimeAutoResolvedByGroup
                .filled("group", "A101")
                .filled("scheme", "晚作息"),
        )
        assertEquals(
            "课表默认 → 标准作息",
            AddCourseStrings.locationTimeAutoResolvedByTimetable.filled("scheme", "标准作息"),
        )
        assertEquals(
            "地点匹配 · 标准作息",
            AddCourseStrings.locationTimeMatchedSchemeHint.filled("scheme", "标准作息"),
        )
    }

    @Test
    fun `性质选项与 ARB 严格对齐`() {
        assertEquals("必修", AddCourseStrings.courseNatureRequired.zh)
        assertEquals("选修", AddCourseStrings.courseNatureElective.zh)
        assertEquals("必修", AddCourseStrings.courseNatureName(com.mutx163.qingyu.core.CourseNature.REQUIRED))
        assertEquals("选修", AddCourseStrings.courseNatureName(com.mutx163.qingyu.core.CourseNature.ELECTIVE))
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
