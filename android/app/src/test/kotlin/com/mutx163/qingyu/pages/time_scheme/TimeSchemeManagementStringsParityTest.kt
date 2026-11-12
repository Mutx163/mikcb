package com.mutx163.qingyu.pages.time_scheme

import com.mutx163.qingyu.core.MiniJson
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 时间模板管理页文案逐字对照 ARB（`i18n/app_zh.arb`）。
 *
 * 与 `ExamStringsParityTest` / `TimetableStringsParityTest` 同一套机制：页面是 Kotlin
 * 重写，不读 Flutter 的 gen-l10n，所以每条屏上文案都必须能被机械证明与 ARB 原文一致，
 * 而不是靠人工肉眼比对。
 */
class TimeSchemeManagementStringsParityTest {

    private val arbMap: Map<String, String> by lazy { loadArbZh() }

    @Test
    fun `每一处屏上文案都与 app_zh_arb 逐字一致`() {
        val texts = TimeSchemeManagementStrings.allTexts
        assertTrue("文案条数不应少于 60 条，当前 ${texts.size}", texts.size >= 60)

        for (item in texts) {
            val template = arbMap[item.key]
            assertNotNull("ARB(app_zh.arb) 中缺少键 `${item.key}`", template)
            assertMatchesArb(item.key, item.zh, template!!)
        }
    }

    @Test
    fun `键名不重复`() {
        val texts = TimeSchemeManagementStrings.allTexts
        val duplicated = texts.groupBy { it.key }.filterValues { it.size > 1 }.keys
        assertTrue("ARB 键被登记了多次：$duplicated", duplicated.isEmpty())
    }

    @Test
    fun `占位符插值函数按预期生成文案`() {
        assertEquals("08:00 起", TimeSchemeManagementStrings.timeSchemeStartsAt.filled("start", "08:00"))
        assertEquals("已重命名为 夏季", TimeSchemeManagementStrings.renamedToMessage.filled("name", "夏季"))
        assertEquals(
            "确定删除作息 夏季？删除后无法恢复",
            TimeSchemeManagementStrings.deleteTimeSchemeMessage.filled("name", "夏季"),
        )
        assertEquals(
            "已删除时间模板：夏季",
            TimeSchemeManagementStrings.deletedTimeSchemeMessage.filled("name", "夏季"),
        )
        assertEquals(
            "已应用时间模板：夏季",
            TimeSchemeManagementStrings.appliedTimeSchemeMessage.filled("name", "夏季"),
        )
        assertEquals(
            "作为主时间模板的课表：甲、乙",
            TimeSchemeManagementStrings.timeSchemeBlockedByProfiles.filled("names", "甲、乙"),
        )
        assertEquals(
            "把它设为副时间模板的课程：2 门",
            TimeSchemeManagementStrings.timeSchemeBlockedByOverrideCourses.filled("count", "2"),
        )
        assertEquals(
            "按上课地点自动匹配到它的课程：2 门",
            TimeSchemeManagementStrings.timeSchemeBlockedByLocationCourses.filled("count", "2"),
        )
        assertEquals(
            "绑定了它的地点组：教学楼 A",
            TimeSchemeManagementStrings.timeSchemeBlockedByLocationGroups.filled("names", "教学楼 A"),
        )
        assertEquals(
            "绑定了它的日期作息规则：期中周",
            TimeSchemeManagementStrings.timeSchemeBlockedByDateRules.filled("names", "期中周"),
        )
        assertEquals(
            "轻屿课表时间模板 夏季，导入后即可使用",
            TimeSchemeManagementStrings.timeSchemeShareText.filled("name", "夏季"),
        )
        assertEquals(
            "发送失败：蓝牙未开启",
            TimeSchemeManagementStrings.sendFailedWithError.filled("error", "蓝牙未开启"),
        )
        assertEquals("夏季 的使用情况", TimeSchemeManagementStrings.timeSchemeUsageTitle.filled("name", "夏季"))
        assertEquals("3 个", TimeSchemeManagementStrings.profileCountValue.filled("count", "3"))
        assertEquals("3 节", TimeSchemeManagementStrings.courseSectionCountValue.filled("count", "3"))
        assertEquals("第 4 节", TimeSchemeManagementStrings.sectionLabel.filled("section", "4"))
        assertEquals(
            "三年级 · 高数 周 一 第 1 至 2 节 主时间模板",
            TimeSchemeManagementStrings.timeSchemeUsageReference.filled(
                "profileName" to "三年级",
                "courseName" to "高数",
                "weekday" to "一",
                "startSection" to "1",
                "endSection" to "2",
                "usageType" to "主时间模板",
            ),
        )
        assertEquals(
            "高数 等 3 节课程",
            TimeSchemeManagementStrings.timeSchemeBottomUsageMulti.filled("first" to "高数", "count" to "3"),
        )
        assertEquals(
            "周 三 3～4 节",
            TimeSchemeManagementStrings.weekdaySectionRange.filled(
                "weekday" to "三",
                "startSection" to "3",
                "endSection" to "4",
            ),
        )
        assertEquals(
            "3 节 · 2 个课表 · 4 节课程 · 1 节副时间模板",
            TimeSchemeManagementStrings.timeSchemeSummary.filled(
                "sections" to "3",
                "profiles" to "2",
                "courses" to "4",
                "overrideCourses" to "1",
            ),
        )
    }

    @Test
    fun `星期短名与 ARB 严格对齐`() {
        assertEquals("一", TimeSchemeManagementStrings.weekdayShort(1))
        assertEquals("二", TimeSchemeManagementStrings.weekdayShort(2))
        assertEquals("三", TimeSchemeManagementStrings.weekdayShort(3))
        assertEquals("四", TimeSchemeManagementStrings.weekdayShort(4))
        assertEquals("五", TimeSchemeManagementStrings.weekdayShort(5))
        assertEquals("六", TimeSchemeManagementStrings.weekdayShort(6))
        assertEquals("日", TimeSchemeManagementStrings.weekdayShort(7))
        assertEquals("", TimeSchemeManagementStrings.weekdayShort(0))
        assertEquals("", TimeSchemeManagementStrings.weekdayShort(8))
    }

    private fun assertMatchesArb(key: String, text: String, template: String) {
        if (!template.contains('{')) {
            assertEquals("ARB 键 `$key` 的屏上文案与 arb 不一致", template, text)
            return
        }
        val segments = template.split(Regex("""\{[^}]*\}""")).filter { it.isNotEmpty() }
        var from = 0
        for (segment in segments) {
            val idx = text.indexOf(segment, from)
            assertTrue(
                "键 `$key` 的渲染值『$text』里找不到模板片段『$segment』（模板：$template）",
                idx >= 0,
            )
            from = idx + segment.length
        }
    }

    /**
     * 从测试工作目录向上找 `i18n/app_zh.arb`，用 core 的 [MiniJson] 解析。
     *
     * 与 `TimetableStringsParityTest` 同一套加载方式：手写正则解析 ARB 会在
     * 值里出现转义引号或换行时静默读错，而读错的对拍测试比没有更危险。
     */
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
        val file = arbFile ?: error("找不到 i18n/app_zh.arb，当前工作目录 ${File("").absolutePath}")
        val parsed = MiniJson.parse(file.readText(Charsets.UTF_8))
        check(parsed is Map<*, *>) { "app_zh.arb 顶层不是对象：${file.absolutePath}" }
        val map = LinkedHashMap<String, String>()
        parsed.forEach { (k, v) -> if (k is String && v is String) map[k] = v }
        assertTrue("app_zh.arb 解析出的键过少（${map.size}）", map.size > 100)
        return map
    }
}
