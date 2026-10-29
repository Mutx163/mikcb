package com.mutx163.qingyu.pages.time_scheme

import com.mutx163.qingyu.core.DartFormatException
import com.mutx163.qingyu.core.SectionTime
import com.mutx163.qingyu.core.TimeScheme
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test
import java.time.LocalDateTime

/**
 * 编辑器状态机（[TimeSchemeEditorModel]）与三个「与 Dart 同源」判据的单测。
 *
 * 这里钉的全是**反向验证过**的事故点：
 * 1. [canAppendSection] 的时间余量必须与 [nextSection] 的实际跨度同源（55 分钟），
 *    否则 23:06 的末节会追加出 23:16-00:01 这种结束早于开始的畸形节次；
 * 2. 畸形末节与 `24:00` 末节都必须拒绝追加（两者都会造出 00:10 的幽灵课）；
 * 3. [resolveSectionEndTimeEdit] 必须把「原本 24:00、选回 00:00」认回来，
 *    否则「只想改开始时间」的编辑会把末节改坏；
 * 4. [TimeSchemeEditorModel.withSectionTime] 的两道校验顺序与 Dart 一致，
 *    且失败时**整表拒绝**（不留下半套生效）。
 */
class TimeSchemeEditorModelTest {

    // ───────────────────── canAppendSection：数量与时间余量 ─────────────────────

    @Test
    fun `空表不能追加`() {
        assertFalse(canAppendSection(emptyList()))
    }

    @Test
    fun `已满二十节不能追加`() {
        val twenty = (1..20).map { minutes -> SectionTime(mm(minutes), mm(minutes + 45)) }
        assertFalse(canAppendSection(twenty))
        assertTrue(canAppendSection(twenty.dropLast(1)))
    }

    /**
     * 余量边界：`nextSection` 需要「末节结束 +10 分钟开始、+45 分钟结束」，
     * 即 55 分钟余量。
     */
    @Test
    fun `末节结束时间必须留出五十五分钟余量`() {
        // 23:05 = 1385 分钟；1385 + 55 = 1440 = 24:00，刚好放行。
        assertTrue(canAppendSection(listOf(SectionTime("22:20", "23:05"))))
        // 23:06 = 1386；+55 = 1441 > 1440，必须置灰（Dart 注释里的 23:06~23:59 事故段）。
        assertFalse(canAppendSection(listOf(SectionTime("22:21", "23:06"))))
        assertFalse(canAppendSection(listOf(SectionTime("23:00", "23:59"))))
    }

    @Test
    fun `末节是二十四点不能追加`() {
        // 快速生成会把末节写成 24:00；nextSection 的宽松解析会把它兜底成 00:00，
        // 从而造出 00:10-00:55 的幽灵课 —— 必须拒绝。
        assertFalse(canAppendSection(listOf(SectionTime("23:15", "24:00"))))
    }

    @Test
    fun `畸形末节结束时间同样置灰`() {
        assertFalse(canAppendSection(listOf(SectionTime("08:00", "08.45"))))
        assertFalse(canAppendSection(listOf(SectionTime("08:00", "8"))))
        assertFalse(canAppendSection(listOf(SectionTime("08:00", ""))))
        assertFalse(canAppendSection(listOf(SectionTime("08:00", "25:00"))))
        assertFalse(canAppendSection(listOf(SectionTime("08:00", "24:30"))))
    }

    // ───────────────────── nextSection：与 canAppendSection 同源 ─────────────────────

    @Test
    fun `追加出来的下一节是末节结束后十分钟起的四十五分钟`() {
        assertEquals(SectionTime("08:55", "09:40"), nextSection(SectionTime("08:00", "08:45")))
        // 23:05 + 10 = 23:15 起、+45 = 24:00；Dart 这里用的是 `%1440` 回绕版本
        // （不是 minutesToClock 的 24:00 特例），所以落成 00:00 —— 正是
        // canAppendSection 必须把「余量不足」拦在外面的原因。
        assertEquals(SectionTime("23:15", "00:00"), nextSection(SectionTime("22:20", "23:05")))
    }

    // ───────────────────── resolveSectionEndTimeEdit ─────────────────────

    @Test
    fun `原本是二十四点且选回零点时保留二十四点`() {
        assertEquals("24:00", resolveSectionEndTimeEdit("24:00", "00:00"))
        assertEquals("24:00", TimeSchemeSectionEdit.resolveEndTimeEdit("24:00", "00:00"))
    }

    @Test
    fun `原本不是二十四点时零点照常生效`() {
        assertEquals("00:00", resolveSectionEndTimeEdit("08:45", "00:00"))
        assertEquals("23:30", resolveSectionEndTimeEdit("24:00", "23:30"))
    }

    // ───────────────────── withSectionTime：两道校验 ─────────────────────

    @Test
    fun `合法修改直接生效`() {
        val model = editor(listOf(SectionTime("08:00", "08:45"), SectionTime("08:55", "09:40")))
        val outcome = model.withSectionTime(0, "08:05", "08:50")
        assertNull(outcome.message)
        assertEquals(SectionTime("08:05", "08:50"), outcome.model.sections[0])
        assertEquals(SectionTime("08:55", "09:40"), outcome.model.sections[1])
    }

    @Test
    fun `结束早于开始被拦住且状态不变`() {
        val model = editor(listOf(SectionTime("08:00", "08:45")))
        val outcome = model.withSectionTime(0, "09:00", "08:30")
        assertEquals("结束时间必须晚于开始时间", outcome.message)
        assertSame(model, outcome.model)
    }

    @Test
    fun `与上一节重叠时整表拒绝并弹服务消息`() {
        val model = editor(listOf(SectionTime("08:00", "08:45"), SectionTime("08:55", "09:40")))
        val outcome = model.withSectionTime(1, "08:30", "09:40")
        assertEquals("第 2 节开始时间不能早于上一节的结束时间", outcome.message)
        assertSame(model, outcome.model)
        // 整表拒绝：第一节没有被顺手改掉，也没有留下半套生效的节次。
        assertEquals(SectionTime("08:00", "08:45"), outcome.model.sections[0])
        assertEquals(SectionTime("08:55", "09:40"), outcome.model.sections[1])
    }

    @Test
    fun `末节原本二十四点时只改开始时间不会把它改坏`() {
        val model = editor(listOf(SectionTime("22:00", "24:00")))
        val outcome = model.withSectionTime(0, "21:30", "00:00")
        assertNull(outcome.message)
        assertEquals(SectionTime("21:30", "24:00"), outcome.model.sections[0])
    }

    @Test
    fun `越界下标原样返回且不报错`() {
        val model = editor(listOf(SectionTime("08:00", "08:45")))
        val outcome = model.withSectionTime(3, "09:00", "09:45")
        assertNull(outcome.message)
        assertSame(model, outcome.model)
    }

    // ───────────────────── 增删改与恢复默认 ─────────────────────

    @Test
    fun `追加一节后与按钮置灰条件同步`() {
        val model = editor(listOf(SectionTime("08:00", "08:45")))
        assertTrue(model.canAdd)
        val next = model.addSection()
        assertEquals(listOf(SectionTime("08:00", "08:45"), SectionTime("08:55", "09:40")), next.sections)

        val locked = editor(listOf(SectionTime("23:20", "23:59")))
        assertFalse(locked.canAdd)
        assertSame(locked, locked.addSection())
    }

    @Test
    fun `只剩一节时删不掉`() {
        val single = editor(listOf(SectionTime("08:00", "08:45")))
        assertFalse(single.canRemove)
        assertSame(single, single.removeLastSection())

        val two = editor(listOf(SectionTime("08:00", "08:45"), SectionTime("08:55", "09:40")))
        assertTrue(two.canRemove)
        assertEquals(listOf(SectionTime("08:00", "08:45")), two.removeLastSection().sections)
    }

    @Test
    fun `恢复默认用内置十节模板`() {
        val model = editor(listOf(SectionTime("07:00", "07:45")))
        val reset = model.resetSections()
        assertEquals(10, reset.sections.size)
        assertEquals(SectionTime("08:00", "08:45"), reset.sections.first())
        assertTrue(model.canReset)
    }

    @Test
    fun `整表替换不做校验`() {
        val model = editor(listOf(SectionTime("08:00", "08:45")))
        val broken = listOf(SectionTime("10:00", "09:00"))
        assertEquals(broken, model.withSections(broken).sections)
    }

    // ───────────────────── 保存前校验与装配 ─────────────────────

    @Test
    fun `保存前校验名称必填与节次表合法性`() {
        val model = editor(listOf(SectionTime("08:00", "08:45")))
        assertNull(model.validateForSave())

        assertEquals("请填写名称", model.withName("  ").validateForSave())

        val broken = editor(listOf(SectionTime("10:00", "09:00")))
        assertEquals("第 1 节结束时间必须晚于开始时间，暂不支持跨 0 点课程", broken.validateForSave())
    }

    @Test
    fun `from 只读 schemes 里的那一套且找不到返回 null`() {
        val schemes = listOf(scheme("s1", "夏季"))
        assertNull(TimeSchemeEditorModel.from(schemes, null, TimeSchemeUsageIndex.EMPTY, "nope"))

        val model = TimeSchemeEditorModel.from(schemes, "s1", TimeSchemeUsageIndex.EMPTY, "s1")!!
        assertEquals("s1", model.schemeId)
        assertEquals("夏季", model.name)
        assertEquals(2, model.sections.size)
        assertTrue(model.isActive)
    }

    @Test
    fun `withUsage 刷新派生输入但不动正在编辑的节次与名字`() {
        val model = editor(listOf(SectionTime("08:00", "08:45"))).withName("改到一半")
        val refreshed = model.withUsage(
            usage = TimeSchemeUsageIndex(overrideCourses = mapOf("s1" to listOf(course("物理")))),
            schemes = listOf(scheme("s1", "夏季", listOf(SectionTime("07:00", "07:45")))),
            activeSchemeId = "s1",
        )
        assertEquals("改到一半", refreshed.name)
        assertEquals(listOf(SectionTime("08:00", "08:45")), refreshed.sections)
        assertTrue(refreshed.isActive)
        assertEquals(1, refreshed.header.chips[2].value.filter { it.isDigit() }.toInt())
    }

    @Test
    fun `withQuickGeneratePreset 记住上次参数`() {
        val preset = TimeSchemeQuickGeneratePreset.DEFAULT.copy(morningCount = 3)
        assertEquals(3, editor(emptyList()).withQuickGeneratePreset(preset).lastQuickGeneratePreset.morningCount)
    }

    // ───────────────────── 头部信息区 ─────────────────────

    @Test
    fun `头部徽标与三个计数`() {
        val usage = TimeSchemeUsageIndex(
            directProfiles = mapOf("s1" to listOf(TimeSchemeProfileRef("p1", "三年级"))),
            followMainCourses = mapOf("s1" to listOf(course("高数"))),
            overrideCourses = mapOf("s1" to listOf(course("物理"), course("化学"))),
        )
        val model = editor(listOf(SectionTime("08:00", "08:45")), usage = usage, isActive = true)
        val header = model.header
        assertTrue(header.showInUseBadge)
        assertEquals("当前使用", header.inUseBadgeText)
        assertEquals(listOf("课表", "课程", "副时间模板"), header.chips.map { it.label })
        assertEquals(listOf("1 个", "3 节", "2 节"), header.chips.map { it.value })
        assertEquals(
            "当前课表和部分课程正在使用这套时间模板，保存后会同步更新所有相关课表和课程",
            header.impactHint,
        )
    }

    @Test
    fun `无引用时不摆徽标也不摆提示`() {
        val header = editor(listOf(SectionTime("08:00", "08:45"))).header
        assertFalse(header.showInUseBadge)
        assertEquals("", header.inUseBadgeText)
        assertEquals("", header.impactHint)
        assertNull(header.previewText)
    }

    @Test
    fun `引用预览用 Dart 的遍历顺序取第一条`() {
        val first = course("高数", courseId = "c1")
        val second = course("物理", courseId = "c2")
        val usage = TimeSchemeUsageIndex(
            followMainCourses = mapOf("s1" to listOf(first)),
            overrideCourses = mapOf("s1" to listOf(second)),
            // 顺序与分类表不同：预览必须跟 Dart 的「档案 → 课程」原序走。
            orderedCourseRefs = mapOf("s1" to listOf(second, first)),
        )
        val model = editor(listOf(SectionTime("08:00", "08:45")), usage = usage)
        // 多条时是「<第一条引用整句> 等 N 节课程」（Dart timeSchemeBottomUsageMulti 同形）。
        assertEquals(
            "三年级 · 物理 周 一 第 1 至 2 节 副时间模板 等 2 节课程",
            model.header.previewText,
        )

        val single = editor(
            listOf(SectionTime("08:00", "08:45")),
            usage = TimeSchemeUsageIndex(
                followMainCourses = mapOf("s1" to listOf(first)),
                orderedCourseRefs = mapOf("s1" to listOf(first)),
            ),
        )
        assertEquals("三年级 · 高数 周 一 第 1 至 2 节 主时间模板", single.header.previewText)
    }

    // ───────────────────── 快捷生成 ─────────────────────

    @Test
    fun `默认参数与 Dart 逐字一致`() {
        val preset = TimeSchemeQuickGeneratePreset.DEFAULT
        assertEquals(4, preset.morningCount)
        assertEquals(4, preset.afternoonCount)
        assertEquals(2, preset.eveningCount)
        assertEquals("08:00", preset.morningStartTime)
        assertEquals("14:00", preset.afternoonStartTime)
        assertEquals("19:00", preset.eveningStartTime)
        assertEquals(45, preset.classDurationMinutes)
        assertEquals(10, preset.breakDurationMinutes)
        assertEquals(1, preset.breakOverrideRules.size)
        assertEquals(2, preset.breakOverrideRules.first().afterSection)
        assertEquals(20, preset.breakOverrideRules.first().breakDurationMinutes)

        val sections = preset.toSections()
        assertEquals(10, sections.size)
        assertEquals(SectionTime("08:00", "08:45"), sections.first())
        // 第 2 节后的 20 分钟大课间：09:40 → 10:00
        assertEquals(SectionTime("10:00", "10:45"), sections[2])
        assertEquals(SectionTime("19:55", "20:40"), sections.last())
    }

    @Test
    fun `非法参数原样上抛 DartFormatException`() {
        try {
            TimeSchemeQuickGeneratePreset.DEFAULT.copy(classDurationMinutes = 0).toSections()
            fail("上课时长为 0 时必须抛错")
        } catch (error: DartFormatException) {
            assertEquals("class_duration_must_positive", error.message)
        }
        try {
            TimeSchemeQuickGeneratePreset.DEFAULT.copy(
                morningCount = 0,
                afternoonCount = 0,
                eveningCount = 0,
            ).toSections()
            fail("一个时段都没有时必须抛错")
        } catch (error: DartFormatException) {
            assertEquals("at_least_one_period_section", error.message)
        }
    }

    // ───────────────────── 测试夹具 ─────────────────────

    private fun editor(
        sections: List<SectionTime>,
        usage: TimeSchemeUsageIndex = TimeSchemeUsageIndex.EMPTY,
        isActive: Boolean = false,
    ) = TimeSchemeEditorModel(
        schemeId = "s1",
        name = "夏季",
        sections = sections,
        isActive = isActive,
        schemes = listOf(scheme("s1", "夏季", sections)),
        activeSchemeId = if (isActive) "s1" else null,
        usage = usage,
    )

    private fun scheme(id: String, name: String, sections: List<SectionTime> = DEFAULT_SECTIONS): TimeScheme {
        val now = LocalDateTime.of(2026, 10, 26, 8, 0)
        return TimeScheme(id = id, name = name, sections = sections, createdAt = now, updatedAt = now)
    }

    private fun course(name: String, courseId: String = "c-$name") = TimeSchemeCourseRef(
        profileId = "p1",
        profileName = "三年级",
        courseId = courseId,
        courseName = name,
        dayOfWeek = 1,
        startSection = 1,
        endSection = 2,
    )

    private fun mm(totalMinutes: Int): String =
        "%02d:%02d".format(totalMinutes / 60, totalMinutes % 60)

    private companion object {
        val DEFAULT_SECTIONS = listOf(
            SectionTime("08:00", "08:45"),
            SectionTime("08:55", "09:40"),
        )
    }
}
