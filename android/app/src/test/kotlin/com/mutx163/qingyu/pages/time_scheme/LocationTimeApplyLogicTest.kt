package com.mutx163.qingyu.pages.time_scheme

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.LocationKeyword
import com.mutx163.qingyu.core.LocationKeywordMatchMode
import com.mutx163.qingyu.core.LocationTimeGroup
import com.mutx163.qingyu.core.SectionTime
import com.mutx163.qingyu.core.TimeScheme
import com.mutx163.qingyu.core.TimetableSettings
import java.time.LocalDateTime
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 「重新匹配当前课表」纯逻辑层（[LocationTimeApplyLogic]）与编辑页同名模板显示名
 * （[LocationTimeMatchModel.schemeSelectLabels]）的测试。
 *
 * 期望值来源全部是 Dart `TimetableLocationRuleService.applyToActiveProfile`
 * （`lib/services/timetable_location_rule_service.dart:286-585`），逐分支对照：
 *
 * | Dart 分支 | 行 | 本文件用例 |
 * |---|---|---|
 * | `hasCustomTime` 原样跳过、不计匹配 | :384-389 | [hasCustomTime_courseIsUntouched] |
 * | 没命中地点组 → 原样 + noMatch | :391-410 | [noLocationMatch_countsAndLeavesCourse] |
 * | 命中但模板不存在 → 原样 + missingScheme | :412-430 | [missingScheme_countsAndLeavesCourse] |
 * | 节次坐不进模板 → 原样（连 override 都不释放）+ overflow | :432-472 | [sectionOverflow_keepsOverrideAndCounts] |
 * | 释放 override + 重算钟点 | :474-497 | [releaseOverride_rewritesClock] |
 * | 钟点本来就一致 → sameClock，不计 updated | :484-490 | [alreadyAligned_countsSameClockWithoutUpdate] |
 * | 越界课名只收前 5 个 | :440-442 | [overflowNames_cappedAtFive] |
 * | 停用组不参与 | `LocationTimeMatchLogic` | [disabledGroup_isIgnored] |
 *
 * 这些用例是「分组改了课表时间到底变不变」那条断点（S1）的**回归钉子**：逻辑层不写盘，
 * 所以这里只能钉「算出来的课确实变了」；「变完落不落盘」由 `TimeSchemeWiringGuardTest`
 * 钉壳里的 `resync = true` / `replaceActiveProfileContent(`。
 */
class LocationTimeApplyLogicTest {

    // ------------------------------------------------------------------ 夹具

    private fun fmt(minutes: Int): String =
        String.format("%02d:%02d", minutes / 60, minutes % 60)

    /** 第 1 节从 `08:00 + offsetMinutes` 开始，每节 45 分钟、间隔 15 分钟。 */
    private fun sectionsOf(offsetMinutes: Int, count: Int = 12): List<SectionTime> =
        (1..count).map { index ->
            val start = 8 * 60 + offsetMinutes + (index - 1) * 60
            SectionTime(fmt(start), fmt(start + 45))
        }

    private fun scheme(id: String, name: String = "模板$id", sections: List<SectionTime> = sectionsOf(0)): TimeScheme {
        val now = LocalDateTime.of(2026, 1, 1, 0, 0)
        return TimeScheme(id = id, name = name, sections = sections, createdAt = now, updatedAt = now)
    }

    private fun course(
        id: String,
        location: String = "教一 101",
        startSection: Int = 1,
        endSection: Int = 2,
        startTime: String = "08:00",
        endTime: String = "09:45",
        timeSchemeIdOverride: String? = null,
        hasCustomTime: Boolean = false,
        name: String = "课程$id",
    ): Course = Course(
        id = id,
        name = name,
        teacher = "T",
        location = location,
        dayOfWeek = 1,
        startSection = startSection,
        endSection = endSection,
        startTime = startTime,
        endTime = endTime,
        timeSchemeIdOverride = timeSchemeIdOverride,
        hasCustomTime = hasCustomTime,
    )

    private fun group(
        id: String,
        schemeId: String,
        pattern: String = "教一",
        enabled: Boolean = true,
    ): LocationTimeGroup = LocationTimeGroup(
        id = id,
        name = "组$id",
        timeSchemeId = schemeId,
        enabled = enabled,
        keywords = listOf(LocationKeyword(pattern, LocationKeywordMatchMode.PREFIX)),
    )

    private fun settings(activeSchemeId: String = "a"): TimetableSettings =
        TimetableSettings(activeTimeSchemeId = activeSchemeId)

    // ------------------------------------------------------------------ 分支

    @Test
    fun releaseOverride_rewritesClock() {
        // 课程手动绑了模板 a（08:00 起），地点组把它指到 b（11:00 起）→ 释放 override 并改成 b 的钟点。
        val a = scheme("a", sections = sectionsOf(0))
        val b = scheme("b", sections = sectionsOf(180))
        val target = course("c1", startSection = 1, endSection = 2, timeSchemeIdOverride = "a")

        val plan = LocationTimeApplyLogic.plan(
            courses = listOf(target),
            schemes = listOf(a, b),
            settings = settings("a"),
            locationTimeGroups = listOf(group("g1", "b")),
        )

        val synced = plan.courses.single()
        assertNull("手动绑定必须被释放，否则以后改规则又变成一次性手动覆盖", synced.timeSchemeIdOverride)
        assertEquals(b.sections[0].startTime, synced.startTime)
        assertEquals(b.sections[1].endTime, synced.endTime)
        assertEquals(1, plan.stats.matched)
        assertEquals(1, plan.stats.updated)
        assertEquals(1, plan.stats.releasedOverrides)
        assertEquals(0, plan.stats.sameClock)
        assertTrue(plan.stats.hasChanges)
    }

    @Test
    fun alreadyAligned_countsSameClockWithoutUpdate() {
        // 钟点本来就和命中模板一致 → 计 sameClock，不计 updated，不需要落盘。
        val a = scheme("a", sections = sectionsOf(0))
        val target = course(
            "c1",
            startSection = 1,
            endSection = 2,
            startTime = a.sections[0].startTime,
            endTime = a.sections[1].endTime,
        )

        val plan = LocationTimeApplyLogic.plan(
            courses = listOf(target),
            schemes = listOf(a),
            settings = settings("a"),
            locationTimeGroups = listOf(group("g1", "a")),
        )

        assertEquals(1, plan.stats.sameClock)
        assertEquals(1, plan.stats.matched)
        assertEquals(0, plan.stats.updated)
        assertFalse("没有变化就不该写盘（Dart `if (updatedCount > 0)`）", plan.stats.hasChanges)
        assertEquals(target, plan.courses.single())
    }

    @Test
    fun sectionOverflow_keepsOverrideAndCounts() {
        // 课程的 20 节坐不进 12 节的模板：整门课不动，连 override 都不释放。
        val short = scheme("a", sections = sectionsOf(0, count = 12))
        val target = course(
            "c1",
            startSection = 1,
            endSection = 20,
            timeSchemeIdOverride = "a",
        )

        val plan = LocationTimeApplyLogic.plan(
            courses = listOf(target),
            schemes = listOf(short),
            settings = settings("a"),
            locationTimeGroups = listOf(group("g1", "a")),
        )

        assertEquals(1, plan.stats.sectionOverflow)
        assertEquals("越界不算 matched（只有完整坐得进模板的课才算）", 0, plan.stats.matched)
        assertEquals(0, plan.stats.updated)
        assertEquals(listOf(target.name), plan.stats.sectionOverflowCourseNames)
        assertEquals("越界时 override 必须原样保留", "a", plan.courses.single().timeSchemeIdOverride)
        assertEquals(target, plan.courses.single())
    }

    @Test
    fun overflowNames_cappedAtFive() {
        // Dart 只收前 5 个越界课名（:440-442），多写只会把提示变成长篇。
        val short = scheme("a", sections = sectionsOf(0, count = 4))
        val courses = (1..7).map { course("c$it", startSection = 1, endSection = 8, name = "越界$it") }

        val plan = LocationTimeApplyLogic.plan(
            courses = courses,
            schemes = listOf(short),
            settings = settings("a"),
            locationTimeGroups = listOf(group("g1", "a")),
        )

        assertEquals(7, plan.stats.sectionOverflow)
        assertEquals(LocationTimeApplyLogic.OVERFLOW_NAME_LIMIT, plan.stats.sectionOverflowCourseNames.size)
        assertEquals(listOf("越界1", "越界2", "越界3", "越界4", "越界5"), plan.stats.sectionOverflowCourseNames)
    }

    @Test
    fun noLocationMatch_countsAndLeavesCourse() {
        val a = scheme("a")
        val target = course("c1", location = "文科楼 305")

        val plan = LocationTimeApplyLogic.plan(
            courses = listOf(target),
            schemes = listOf(a),
            settings = settings("a"),
            locationTimeGroups = listOf(group("g1", "a", pattern = "教一")),
        )

        assertEquals(1, plan.stats.noMatch)
        assertEquals(0, plan.stats.matched)
        assertEquals(target, plan.courses.single())
    }

    @Test
    fun missingScheme_countsAndLeavesCourse() {
        // 组绑的模板已被删：命中但拿不到模板，原样不动、计入 missingScheme。
        val a = scheme("a")
        val target = course("c1")

        val plan = LocationTimeApplyLogic.plan(
            courses = listOf(target),
            schemes = listOf(a),
            settings = settings("a"),
            locationTimeGroups = listOf(group("g1", "ghost")),
        )

        assertEquals(1, plan.stats.missingScheme)
        assertEquals(0, plan.stats.matched)
        assertEquals(target, plan.courses.single())
    }

    @Test
    fun disabledGroup_isIgnored() {
        val a = scheme("a", sections = sectionsOf(0))
        val b = scheme("b", sections = sectionsOf(300))
        val target = course(
            "c1",
            startTime = a.sections[0].startTime,
            endTime = a.sections[1].endTime,
        )

        val plan = LocationTimeApplyLogic.plan(
            courses = listOf(target),
            schemes = listOf(a, b),
            settings = settings("a"),
            locationTimeGroups = listOf(group("g1", "b", enabled = false)),
        )

        assertEquals("停用的组不参与匹配", 1, plan.stats.noMatch)
        assertEquals(target, plan.courses.single())
    }

    @Test
    fun hasCustomTime_courseIsUntouched() {
        // 适配脚本下发的真实钟点（早读/连堂）是权威值：连 examined 都不算。
        val a = scheme("a", sections = sectionsOf(0))
        val b = scheme("b", sections = sectionsOf(300))
        val target = course(
            "c1",
            startTime = "07:20",
            endTime = "08:05",
            hasCustomTime = true,
        )

        val plan = LocationTimeApplyLogic.plan(
            courses = listOf(target),
            schemes = listOf(a, b),
            settings = settings("a"),
            locationTimeGroups = listOf(group("g1", "b")),
        )

        assertSame(target, plan.courses.single())
        assertEquals(0, plan.stats.examined)
        assertEquals(0, plan.stats.matched)
        assertEquals(0, plan.stats.updated)
        assertFalse(plan.stats.hasChanges)
    }

    @Test
    fun mixedCourses_keepOrderAndStats() {
        // 一门课一个分支：顺序必须原样保留，四类计数各归各。
        val a = scheme("a", sections = sectionsOf(0))
        val b = scheme("b", sections = sectionsOf(300))
        val courses = listOf(
            course("c1", startSection = 1, endSection = 2), // 命中 b、钟点要改写
            course("c2", location = "文科楼"), // 未命中
            course("c3", startSection = 1, endSection = 20), // 越界
            course("c4", hasCustomTime = true), // 脚本时刻
        )

        val plan = LocationTimeApplyLogic.plan(
            courses = courses,
            schemes = listOf(a, b),
            settings = settings("a"),
            locationTimeGroups = listOf(group("g1", "b")),
        )

        assertEquals(listOf("c1", "c2", "c3", "c4"), plan.courses.map { it.id })
        assertEquals(3, plan.stats.examined)
        assertEquals(1, plan.stats.matched)
        assertEquals(1, plan.stats.updated)
        assertEquals(1, plan.stats.noMatch)
        assertEquals(1, plan.stats.sectionOverflow)
    }

    // ------------------------------------------------ 编辑页同名模板显示名

    @Test
    fun schemeSelectLabels_keepsUniqueNames() {
        val labels = LocationTimeMatchModel.schemeSelectLabels(
            listOf("a1b2c3d4e5" to "默认作息", "ffff0000" to "夏季作息"),
        )
        assertEquals(listOf("默认作息", "夏季作息"), labels)
    }

    @Test
    fun schemeSelectLabels_appendsShortIdOnDuplicates() {
        // Dart `_timeSchemeSelectLabel`：同名 → 「name · id 前 8 位」。
        val labels = LocationTimeMatchModel.schemeSelectLabels(
            listOf(
                "a1b2c3d4e5f6" to "默认作息",
                "000011112222" to "默认作息",
                "3333" to "默认作息",
            ),
        )
        assertEquals(
            listOf("默认作息 · a1b2c3d4", "默认作息 · 00001111", "默认作息 · 3333"),
            labels,
        )
    }

    @Test
    fun schemeSelectLabels_emptyInput() {
        assertEquals(emptyList<String>(), LocationTimeMatchModel.schemeSelectLabels(emptyList()))
    }
}
