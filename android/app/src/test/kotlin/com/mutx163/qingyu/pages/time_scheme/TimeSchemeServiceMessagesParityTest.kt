package com.mutx163.qingyu.pages.time_scheme

import com.mutx163.qingyu.core.MiniJson
import com.mutx163.qingyu.core.ServiceMessage
import com.mutx163.qingyu.core.buildQuickSectionTimes
import com.mutx163.qingyu.core.validateSectionTimes
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 服务消息本地化（[TimeSchemeServiceMessages]）的两件事：
 *
 * 1. **文案逐字对拍 ARB**（`serviceMsg*` 键）——屏上出现的每一句都必须能在
 *    `i18n/app_zh.arb` 里找到同名键，不许自造；
 * 2. **码 → 句子的映射**逐条走通，包括 `section_count_below_usage_detail` 里
 *    嵌套的 `usageType`（它本身也是一条 service message 码）。
 *
 * 这些码是仓储/校验函数真实的返回值，映射错一条就等于用户看到英文变量名，
 * 或者看到「第 0 节」这种把缺失参数当数据的假信息。
 */
class TimeSchemeServiceMessagesParityTest {

    private val arbMap: Map<String, String> by lazy { loadArbZh() }

    @Test
    fun `每一处服务消息文案都与 app_zh_arb 逐字一致`() {
        val texts = TimeSchemeServiceMessages.allTexts
        assertTrue("服务消息文案不应少于 15 条，当前 ${texts.size}", texts.size >= 15)
        for (item in texts) {
            val template = arbMap[item.key]
            assertNotNull("ARB(app_zh.arb) 中缺少键 `${item.key}`", template)
            assertEquals("ARB 键 `${item.key}` 与屏上文案不一致", template, item.zh)
        }
    }

    @Test
    fun `键名不重复`() {
        val duplicated = TimeSchemeServiceMessages.allTexts
            .groupBy { it.key }
            .filterValues { it.size > 1 }
            .keys
        assertTrue("ARB 键被登记了多次：$duplicated", duplicated.isEmpty())
    }

    // ───────────────────── 逐码映射 ─────────────────────

    @Test
    fun `无参数码直接给文案`() {
        assertEquals("时间模板不存在", TimeSchemeServiceMessages.localize("time_scheme_not_found"))
        assertEquals("至少需要保留一节课的时间", TimeSchemeServiceMessages.localize("at_least_one_section_required"))
        assertEquals("时间格式不正确", TimeSchemeServiceMessages.localize("invalid_time_format"))
        assertEquals("上课时长必须大于 0", TimeSchemeServiceMessages.localize("class_duration_must_positive"))
        assertEquals("课间时长不能小于 0", TimeSchemeServiceMessages.localize("break_duration_must_non_negative"))
        assertEquals("至少需要设置一个时段的节次数", TimeSchemeServiceMessages.localize("at_least_one_period_section"))
        assertEquals("请为有节次的时段设置第一节开始时间", TimeSchemeServiceMessages.localize("period_start_time_required"))
        assertEquals("副时间模板", TimeSchemeServiceMessages.localize("usage_type_override"))
        assertEquals("课表主时间模板", TimeSchemeServiceMessages.localize("usage_type_profile"))
    }

    @Test
    fun `带参数码按 payload 插值`() {
        assertEquals(
            "所选时间模板节次数不足，无法覆盖第 1～12 节",
            TimeSchemeServiceMessages.localize("time_scheme_sections_insufficient|startSection=1|endSection=12"),
        )
        assertEquals(
            "有课排到第 12 节",
            TimeSchemeServiceMessages.localize("section_count_below_usage|requiredMaxSection=12"),
        )
        assertEquals(
            "第 3 节结束时间必须晚于开始时间，暂不支持跨 0 点课程",
            TimeSchemeServiceMessages.localize("section_end_must_after_start|sectionNumber=3"),
        )
        assertEquals(
            "第 2 节开始时间不能早于上一节的结束时间",
            TimeSchemeServiceMessages.localize("section_start_before_previous_end|sectionNumber=2"),
        )
        assertEquals(
            "第 5 节会跨到次日，当前暂不支持跨 0 点课程",
            TimeSchemeServiceMessages.localize("section_crosses_midnight|sectionNumber=5"),
        )
    }

    @Test
    fun `明细码里的 usageType 必须递归本地化`() {
        val payload = ServiceMessage.encode(
            "section_count_below_usage_detail",
            linkedMapOf(
                "requiredMaxSection" to 12,
                "profileName" to "三年级",
                "courseName" to "高数",
                "dayOfWeek" to 3,
                "startSection" to 9,
                "endSection" to 12,
                "usageType" to "usage_type_override",
            ),
        )
        assertEquals(
            "节次数不能小于已用最大节次 第 12 节。正在使用：三年级 · 高数 周 3 第 9 至 12 节 副时间模板",
            TimeSchemeServiceMessages.localize(payload),
        )

        val profilePayload = ServiceMessage.encode(
            "section_count_below_usage_detail",
            linkedMapOf(
                "requiredMaxSection" to 10,
                "profileName" to "一年级",
                "courseName" to "英语",
                "dayOfWeek" to 1,
                "startSection" to 1,
                "endSection" to 10,
                "usageType" to "usage_type_profile",
            ),
        )
        assertTrue(TimeSchemeServiceMessages.localize(profilePayload).endsWith("课表主时间模板"))
    }

    @Test
    fun `认不出的码原样返回整个 payload`() {
        assertEquals("some_unknown_code", TimeSchemeServiceMessages.localize("some_unknown_code"))
        assertEquals(
            "some_unknown_code|x=1",
            TimeSchemeServiceMessages.localize("some_unknown_code|x=1"),
        )
    }

    @Test
    fun `空 payload 给空串`() {
        assertEquals("", TimeSchemeServiceMessages.localize(null))
        assertEquals("", TimeSchemeServiceMessages.localize(""))
    }

    @Test
    fun `参数缺失时数字补零而不是留空占位符`() {
        assertEquals(
            "第 0 节结束时间必须晚于开始时间，暂不支持跨 0 点课程",
            TimeSchemeServiceMessages.localize("section_end_must_after_start"),
        )
        // 字符串参数缺失补空串（Dart `?? ''` 同口径），不留 `{profileName}` 这种占位符。
        val localized = TimeSchemeServiceMessages.localize("section_count_below_usage_detail|requiredMaxSection=9")
        assertTrue("实际返回：$localized", localized.startsWith("节次数不能小于已用最大节次 第 9 节。正在使用："))
        assertTrue("实际返回：$localized", localized.contains("周 0 第 0 至 0 节"))
        assertTrue("实际返回：$localized", !localized.contains("{"))
    }

    @Test
    fun `校验函数真实产出的码都能本地化`() {
        // 校验函数的真实输出必须被本对象覆盖：拿 core 的返回值直接过 localize。
        val endBeforeStart = validateSectionTimes(
            listOf(com.mutx163.qingyu.core.SectionTime("10:00", "09:00")),
        )
        assertNotNull(endBeforeStart)
        assertEquals(
            "第 1 节结束时间必须晚于开始时间，暂不支持跨 0 点课程",
            TimeSchemeServiceMessages.localize(endBeforeStart),
        )

        val overlapping = validateSectionTimes(
            listOf(
                com.mutx163.qingyu.core.SectionTime("08:00", "08:45"),
                com.mutx163.qingyu.core.SectionTime("08:30", "09:20"),
            ),
        )
        assertEquals(
            "第 2 节开始时间不能早于上一节的结束时间",
            TimeSchemeServiceMessages.localize(overlapping),
        )

        assertEquals("至少需要保留一节课的时间", TimeSchemeServiceMessages.localize(validateSectionTimes(emptyList())))

        // 快捷生成的抛错消息（DartFormatException.message）也是同一种 payload。
        val quickError = runCatching {
            buildQuickSectionTimes(
                morningCount = 30,
                afternoonCount = 0,
                eveningCount = 0,
                morningStartTime = "08:00",
                afternoonStartTime = null,
                eveningStartTime = null,
                classDurationMinutes = 45,
                breakDurationMinutes = 10,
            )
        }.exceptionOrNull()!!.message
        assertEquals(
            "第 18 节会跨到次日，当前暂不支持跨 0 点课程",
            TimeSchemeServiceMessages.localize(quickError),
        )
    }

    // ───────────────────── ARB 读取（与既有对拍测试同一套） ─────────────────────

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
        for ((key, value) in parsed) {
            if (key is String && value is String) map[key] = value
        }
        return map
    }
}
