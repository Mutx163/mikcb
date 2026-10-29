package com.mutx163.qingyu.pages.time_scheme

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.LocationKeyword
import com.mutx163.qingyu.core.LocationTimeGroup
import com.mutx163.qingyu.core.ScheduleDateRule
import com.mutx163.qingyu.core.SectionTime
import com.mutx163.qingyu.core.TimeScheme
import com.mutx163.qingyu.core.TimetableProfile
import com.mutx163.qingyu.core.TimetableSettings
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDateTime

/**
 * 引用关系索引工厂（[TimeSchemeUsageIndexFactory]）的单测。
 *
 * 这一层最怕的是「漏一类占用」：漏掉的后果不是显示不准，而是**删除拦截失效**
 * （模板被删 → 课表取不到节次时间 → 周视图直接画不出来）。所以三类课程占用、
 * 停用地点分组、日期规则逐条钉住，并且钉住「键只填非空」的约定。
 */
class TimeSchemeUsageIndexFactoryTest {

    @Test
    fun `课表级绑定按 activeTimeSchemeId 归组`() {
        val index = TimeSchemeUsageIndexFactory.build(
            schemes = listOf(scheme("s1"), scheme("s2")),
            profiles = listOf(
                profile("p1", "一年级", activeSchemeId = "s1"),
                profile("p2", "二年级", activeSchemeId = "s1"),
                profile("p3", "三年级", activeSchemeId = "s2"),
                profile("p4", "四年级", activeSchemeId = null),
            ),
            locationGroups = emptyList(),
            dateRules = emptyList(),
        )
        assertEquals(listOf("一年级", "二年级"), index.directProfiles["s1"]!!.map { it.name })
        assertEquals(listOf("三年级"), index.directProfiles["s2"]!!.map { it.name })
        assertNull(index.directProfiles["p4"])
        // 缺键与空表等价：第 4 份档案没绑模板，不该出现任何键。
        assertFalse(index.directProfiles.containsKey("p4"))
    }

    @Test
    fun `三类课程占用各归一段`() {
        val groups = listOf(
            locationGroup("g1", "教学楼", timeSchemeId = "s1", keywords = listOf("教学楼")),
        )
        val index = TimeSchemeUsageIndexFactory.build(
            schemes = listOf(scheme("s1")),
            profiles = listOf(
                profile(
                    "p1",
                    "一年级",
                    activeSchemeId = "s1",
                    courses = listOf(
                        course("c1", "高数", location = ""),
                        course("c2", "英语", location = "教学楼 A101"),
                        course("c3", "物理", location = "", override = "s1"),
                    ),
                ),
            ),
            locationGroups = groups,
            dateRules = emptyList(),
        )
        assertEquals(listOf("物理"), index.overrideCourses["s1"]!!.map { it.courseName })
        assertEquals(listOf("英语"), index.locationCourses["s1"]!!.map { it.courseName })
        assertEquals(listOf("高数"), index.followMainCourses["s1"]!!.map { it.courseName })
        // 三条引用都要出现在有序全表里（编辑器预览取第一条用）。
        assertEquals(3, index.courseReferences("s1").size)
        // 档案 id 必须能反查出来（按课程 id，不按档案名）。
        assertTrue(index.courseReferences("s1").all { it.profileId == "p1" })
    }

    @Test
    fun `停用的地点分组也算占用`() {
        val index = TimeSchemeUsageIndexFactory.build(
            schemes = listOf(scheme("s1")),
            profiles = emptyList(),
            locationGroups = listOf(
                locationGroup("g1", "曾用组", timeSchemeId = "s1", enabled = false),
            ),
            dateRules = emptyList(),
        )
        // 与 TimeSchemeLogic 同口径：停用的组重新启用就会复活这条模板，删了就回来不了。
        assertEquals(listOf("曾用组"), index.locationGroups["s1"]!!.map { it.name })
    }

    @Test
    fun `日期规则按 timeSchemeId 归组`() {
        val index = TimeSchemeUsageIndexFactory.build(
            schemes = listOf(scheme("s1")),
            profiles = emptyList(),
            locationGroups = emptyList(),
            dateRules = listOf(
                dateRule("d1", "期中周", "s1"),
                dateRule("d2", "期末周", "s2"),
            ),
        )
        assertEquals(listOf("期中周"), index.dateRules["s1"]!!.map { it.name })
        assertEquals(listOf("期末周"), index.dateRules["s2"]!!.map { it.name })
    }

    @Test
    fun `空输入得到空索引且每个键都缺省`() {
        val index = TimeSchemeUsageIndexFactory.build(emptyList(), emptyList(), emptyList(), emptyList())
        assertTrue(index.directProfiles.isEmpty())
        assertTrue(index.followMainCourses.isEmpty())
        assertTrue(index.overrideCourses.isEmpty())
        assertTrue(index.locationCourses.isEmpty())
        assertTrue(index.locationGroups.isEmpty())
        assertTrue(index.dateRules.isEmpty())
        assertTrue(index.courseReferences("s1").isEmpty())
    }

    @Test
    fun `没有引用的模板不出现键`() {
        val index = TimeSchemeUsageIndexFactory.build(
            schemes = listOf(scheme("s1"), scheme("s2")),
            profiles = listOf(profile("p1", "一年级", activeSchemeId = "s1")),
            locationGroups = emptyList(),
            dateRules = emptyList(),
        )
        assertTrue(index.directProfiles.containsKey("s1"))
        assertFalse(index.directProfiles.containsKey("s2"))
        assertFalse(index.courseReferences("s2").isNotEmpty())
    }

    @Test
    fun `有序全表按 Dart 的档案到课程顺序`() {
        val index = TimeSchemeUsageIndexFactory.build(
            schemes = listOf(scheme("s1")),
            profiles = listOf(
                profile(
                    "p1",
                    "一年级",
                    activeSchemeId = "s1",
                    courses = listOf(course("c1", "高数"), course("c2", "英语")),
                ),
                profile(
                    "p2",
                    "二年级",
                    activeSchemeId = "s1",
                    courses = listOf(course("c3", "物理")),
                ),
            ),
            locationGroups = emptyList(),
            dateRules = emptyList(),
        )
        assertEquals(
            listOf("高数", "英语", "物理"),
            index.courseReferences("s1").map { it.courseName },
        )
    }

    // ───────────────────── 测试夹具 ─────────────────────

    private fun scheme(id: String): TimeScheme {
        val now = LocalDateTime.of(2026, 10, 26, 8, 0)
        return TimeScheme(
            id = id,
            name = "模板-$id",
            sections = listOf(SectionTime("08:00", "08:45"), SectionTime("08:55", "09:40")),
            createdAt = now,
            updatedAt = now,
        )
    }

    private fun profile(
        id: String,
        name: String,
        activeSchemeId: String?,
        courses: List<Course> = emptyList(),
    ): TimetableProfile {
        val now = LocalDateTime.of(2026, 10, 26, 8, 0)
        return TimetableProfile(
            id = id,
            name = name,
            courses = courses,
            settings = TimetableSettings.defaults().copy(activeTimeSchemeId = activeSchemeId),
            currentWeek = 1,
            createdAt = now,
            lastUsedAt = now,
        )
    }

    private fun course(
        id: String,
        name: String,
        location: String = "",
        override: String? = null,
    ) = Course(
        id = id,
        name = name,
        teacher = "",
        location = location,
        dayOfWeek = 1,
        startSection = 1,
        endSection = 2,
        startTime = "08:00",
        endTime = "09:40",
        timeSchemeIdOverride = override,
    )

    private fun locationGroup(
        id: String,
        name: String,
        timeSchemeId: String,
        enabled: Boolean = true,
        keywords: List<String> = emptyList(),
    ) = LocationTimeGroup(
        id = id,
        name = name,
        timeSchemeId = timeSchemeId,
        enabled = enabled,
        keywords = keywords.map { LocationKeyword(it) },
    )

    private fun dateRule(id: String, name: String, timeSchemeId: String) = ScheduleDateRule(
        id = id,
        name = name,
        timeSchemeId = timeSchemeId,
        startDate = "2026-10-01",
        endDate = "2026-10-31",
    )
}
