package com.mutx163.qingyu.pages.time_scheme

import com.mutx163.qingyu.core.SectionTime
import com.mutx163.qingyu.core.TimeScheme
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDateTime

/**
 * **编辑期允许乱序/重叠、保存时才硬拦**（2026-11-10 用户口径）。
 *
 * ## 它钉住的三件事
 *
 * 1. `withSectionTime` 改出重叠/乱序时**照常落地**（不再整表拒绝），并带一句非阻塞提示；
 * 2. `validateForSave()` 仍然硬拦（重叠的节次表存不下去）；
 * 3. 「单节结束必须晚于开始」这条**保留**——那是时间本身表达不了，不是排序口味问题。
 *
 * ## 为什么必须用单测而不是只靠守卫
 *
 * 旧口径是「不给保存 + 改不进去」，新口径是「改得进去、存不进去」。两者的差别只有在
 * 「改完的表长什么样」「保存返回什么」这两处才看得见，纯文本守卫抓不到。
 */
class TimeSchemeEditorOverlapPolicyTest {

    private val orderedSections = listOf(
        SectionTime("08:00", "08:45"),
        SectionTime("08:55", "09:40"),
    )

    private fun model(sections: List<SectionTime> = orderedSections): TimeSchemeEditorModel {
        val scheme = TimeScheme(
            id = "ts1",
            name = "默认作息",
            sections = sections,
            createdAt = LocalDateTime.of(2026, 2, 1, 0, 0),
            updatedAt = LocalDateTime.of(2026, 2, 1, 0, 0),
        )
        val built = TimeSchemeEditorModel.from(
            schemes = listOf(scheme),
            activeSchemeId = "ts1",
            usage = TimeSchemeUsageIndex.EMPTY,
            schemeId = "ts1",
        )
        assertNotNull("夹具必须能装配出编辑器模型", built)
        return built!!
    }

    @Test
    fun `把第二节改到上一节结束之前——编辑照常落地并给非阻塞提示`() {
        val outcome = model().withSectionTime(index = 1, start = "08:30", end = "09:15")

        assertEquals(
            "编辑期必须真的改进去（用户口径：允许乱序/重叠）",
            SectionTime("08:30", "09:15"),
            outcome.model.sections[1],
        )
        assertNotNull("重叠时必须给提示（不能静默）", outcome.message)
        assertTrue(
            "提示要指名是第几节：实际 ${outcome.message}",
            outcome.message!!.contains("2"),
        )
    }

    @Test
    fun `带重叠的节次表保存时仍被硬拦`() {
        val outcome = model().withSectionTime(index = 1, start = "08:30", end = "09:15")

        assertNotNull(
            "重叠的表必须存不下去（保存硬校验保留）",
            outcome.model.validateForSave(),
        )
    }

    @Test
    fun `单节结束早于开始仍被拒且原表不动`() {
        val before = model()
        val outcome = before.withSectionTime(index = 0, start = "09:00", end = "08:00")

        assertEquals(
            "这一条是时间本身表达不了（跨天），不是排序口味，必须继续硬拦",
            before.sections,
            outcome.model.sections,
        )
        assertNotNull(outcome.message)
    }

    @Test
    fun `顺序正常时没有任何提示`() {
        val outcome = model().withSectionTime(index = 1, start = "08:55", end = "09:40")

        assertNull("顺序正常不该出现提示", outcome.message)
        assertEquals(orderedSections, outcome.model.sections)
    }

    @Test
    fun `overlapHint 对顺序表返回 null、对乱序表指名到第几节`() {
        assertNull(model(orderedSections).overlapHint())
        val hint = model(
            listOf(
                SectionTime("08:00", "08:45"),
                SectionTime("08:20", "09:05"),
            ),
        ).overlapHint()
        assertNotNull(hint)
        assertTrue("提示应指名第 2 节：实际 $hint", hint!!.contains("2"))
    }

    @Test
    fun `两格全空的补位行不参与重叠判定`() {
        val sections = listOf(
            SectionTime("08:00", "08:45"),
            SectionTime("", ""),
            SectionTime("08:55", "09:40"),
        )
        assertNull("补位行是本仓认可的占位形状，不该被当成 00:00-00:00 的节次", model(sections).overlapHint())
    }
}
