package com.mutx163.qingyu.pages.course

import com.mutx163.qingyu.core.MiniJson
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 四个后续弹层的文案逐字对照 ARB（`lib/l10n/app_zh.arb`）。
 *
 * 验收门槛 3：界面文案与 ARB 原文逐字一致，不自己改写、不省略占位符。
 * 写法与 `android/app/src/test/kotlin/com/mutx163/qingyu/app/CourseActionStringsParityTest.kt`
 * 同口径（MiniJson 读 ARB、逐键比对、占位符模板按片段核对）。
 */
class CourseFollowupStringsParityTest {

    private val arbMap: Map<String, String> by lazy { loadArbZh() }

    @Test
    fun `每一处屏上文案都与 app_zh_arb 逐字一致`() {
        val texts = CourseFollowupStrings.allTexts
        assertTrue(
            "文案条数不应少于 30 条（四个弹层的本族键），当前 ${texts.size}",
            texts.size >= 30,
        )

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
                // 占位符个数也要对上：模板有 1 个而屏上写 2 个同样算改写
                assertEquals(
                    "键 `${item.key}` 的占位符个数与 ARB 不一致",
                    Regex("""\{[^}]*\}""").findAll(template).count(),
                    Regex("""\{[^}]*\}""").findAll(item.zh).count(),
                )
            }
        }
    }

    @Test
    fun `七个星期文案依次是周一到周日`() {
        assertEquals(
            listOf("周一", "周二", "周三", "周四", "周五", "周六", "周日"),
            CourseFollowupStrings.weekdayLabels(),
        )
    }

    @Test
    fun `量纲占位符填充`() {
        assertEquals("第 3 周", CourseFollowupStrings.week(3))
        assertEquals("第 16 周", CourseFollowupStrings.week(16))
        assertEquals("第 1 节", CourseFollowupStrings.section(1))
        assertEquals("第 12 节", CourseFollowupStrings.section(12))
        assertEquals("地点：三教-101", CourseFollowupStrings.location("三教-101"))
        // 空地点也要能填（渲染层靠它判断要不要画那一行，由 model 决定不填）
        assertEquals("地点：", CourseFollowupStrings.location(""))
    }

    @Test
    fun `删除与停课的范围文案就是 ARB 里那两条短句`() {
        assertEquals("删这个课", CourseFollowupStrings.deleteCourseAction.zh)
        assertEquals("删这节课", CourseFollowupStrings.deleteOccurrenceAction.zh)
        assertEquals("停本周", CourseFollowupStrings.suspendThisWeek.zh)
        assertEquals("全部停", CourseFollowupStrings.suspendAllWeeks.zh)
        assertEquals("恢复全部", CourseFollowupStrings.unsuspendAllWeeks.zh)
        assertEquals("恢复", CourseFollowupStrings.courseActionUnsuspend.zh)
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
