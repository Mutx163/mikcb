package com.mutx163.qingyu.app

import com.mutx163.qingyu.core.MiniJson
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 课程操作弹层文案逐字对照 ARB（`lib/l10n/app_zh.arb`）。
 *
 * 验收门槛 3：界面文案与 ARB 原文逐字一致，不自己改写、不省略占位符。
 */
class CourseActionStringsParityTest {

    private val arbMap: Map<String, String> by lazy { loadArbZh() }

    @Test
    fun `每一处屏上文案都与 app_zh_arb 逐字一致`() {
        val texts = CourseActionStrings.allTexts
        assertTrue("文案条数不应少于 10 条，当前 ${texts.size}", texts.size >= 10)

        for (item in texts) {
            val template = arbMap[item.key]
            assertTrue("ARB(app_zh.arb) 中缺少键 `${item.key}`", template != null)
            if (!template!!.contains('{')) {
                assertEquals("ARB 键 `${item.key}` 的屏上文案与 arb 不一致", template, item.zh)
            } else {
                // 占位符模板：逐段核对（与 LiveStringsParityTest 同口径）
                val segments = template.split(Regex("""\{[^}]*\}""")).filter { it.isNotEmpty() }
                var cursor = 0
                for (segment in segments) {
                    val index = item.zh.indexOf(segment, cursor)
                    assertTrue(
                        "键 `${item.key}` 的『${item.zh}』里找不到模板片段『$segment』",
                        index >= 0,
                    )
                    cursor = index + segment.length
                }
            }
        }
    }

    @Test
    fun `说明句填充周次 教师与地点空值兜底`() {
        assertEquals(
            "你正在查看第 7 周，如该时段突发考试或冲突，可立即在下方执行快速调课或停课",
            CourseActionStrings.notice(7),
        )
        assertEquals("未知教师", CourseActionStrings.teacherOrUnknown(""))
        assertEquals("未知教师", CourseActionStrings.teacherOrUnknown("   "))
        assertEquals("张老师", CourseActionStrings.teacherOrUnknown("张老师"))
        assertEquals("未知地点", CourseActionStrings.locationOrUnknown(""))
        assertEquals("三教-101", CourseActionStrings.locationOrUnknown("三教-101"))
    }

    @Test
    fun `停课按钮已停课时显示恢复`() {
        assertEquals("停课", CourseActionStrings.suspendButtonLabel(suspendedThisWeek = false))
        assertEquals("恢复", CourseActionStrings.suspendButtonLabel(suspendedThisWeek = true))
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
