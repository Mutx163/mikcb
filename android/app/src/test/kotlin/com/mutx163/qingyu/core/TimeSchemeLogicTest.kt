package com.mutx163.qingyu.core

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * TimeSchemeLogic 移植测试。
 *
 * 期望值来源：
 * - [Dart抄录]：test/providers/time_scheme_logic_test.dart（断言逐条翻成 Kotlin）；
 * - [Dart推演]：对照 lib/domain/time_scheme_logic.dart 实现逐行推演
 *   （每个公开函数至少 1 条）；
 * - [人推]：空列表/越界/负数边界。
 */
class TimeSchemeLogicTest {

    private fun course(
        id: String,
        timeSchemeIdOverride: String? = null,
        startSection: Int = 1,
        endSection: Int = 4,
        dayOfWeek: Int = 1,
        location: String = "L",
    ): Course = Course(
        id = id,
        name = "Course $id",
        teacher = "T",
        location = location,
        dayOfWeek = dayOfWeek,
        startSection = startSection,
        endSection = endSection,
        startTime = "08:00",
        endTime = "09:40",
        color = "#FF0000",
        timeSchemeIdOverride = timeSchemeIdOverride,
    )

    private fun scheme(id: String, name: String = "Scheme"): TimeScheme {
        val now = DartTime.dateTime(2026, 1, 1)
        return TimeScheme(
            id = id,
            name = name,
            sections = TimetableSettings.DEFAULT_SECTIONS,
            createdAt = now,
            updatedAt = now,
        )
    }

    private fun profile(
        id: String,
        name: String,
        activeSchemeId: String,
        courses: List<Course> = emptyList(),
    ): TimetableProfile {
        val now = DartTime.dateTime(2026, 1, 1)
        return TimetableProfile(
            id = id,
            name = name,
            courses = courses,
            settings = TimetableSettings(activeTimeSchemeId = activeSchemeId),
            currentWeek = 1,
            createdAt = now,
            lastUsedAt = now,
        )
    }

    // ---------- getSchemeById [Dart抄录] ----------

    @Test
    fun getSchemeById_unknownReturnsNull() {
        assertNull(TimeSchemeLogic.getSchemeById(listOf(scheme("a")), "missing"))
        // null id → null（不抛）
        assertNull(TimeSchemeLogic.getSchemeById(listOf(scheme("a")), null))
        // 空列表 → null
        assertNull(TimeSchemeLogic.getSchemeById(emptyList(), "a"))
    }

    @Test
    fun getSchemeById_matchingScheme() { // [Dart抄录]
        val scheme = scheme("a")
        assertEquals(scheme, TimeSchemeLogic.getSchemeById(listOf(scheme), "a"))
    }

    // ---------- resolveCourseTimeScheme [Dart抄录] ----------

    @Test
    fun resolve_prefersCourseOverrideOverProfileScheme() { // [Dart抄录]
        val defaultScheme = scheme("default")
        val overrideScheme = scheme("override")
        val settings = TimetableSettings(activeTimeSchemeId = defaultScheme.id)
        val course = course("1", timeSchemeIdOverride = overrideScheme.id)
        assertEquals(
            overrideScheme,
            TimeSchemeLogic.resolveCourseTimeScheme(
                listOf(defaultScheme, overrideScheme),
                settings,
                course,
            ),
        )
    }

    @Test
    fun resolve_fallsBackToProfileActiveScheme() { // [Dart抄录]
        val scheme = scheme("active")
        val settings = TimetableSettings(activeTimeSchemeId = scheme.id)
        assertEquals(
            scheme,
            TimeSchemeLogic.resolveCourseTimeScheme(listOf(scheme), settings, course("1")),
        )
    }

    @Test
    fun resolve_usesLocationMatchWhenNoOverride() { // [Dart抄录]
        val defaultScheme = scheme("default")
        val otherScheme = scheme("other")
        val settings = TimetableSettings(activeTimeSchemeId = defaultScheme.id)
        val course = course("1", location = "A1062")
        val groups = listOf(
            LocationTimeGroup(id = "g1", name = "其他教学楼", timeSchemeId = otherScheme.id, keywords = listOf(LocationKeyword("A1"))),
        )
        assertEquals(
            otherScheme,
            TimeSchemeLogic.resolveCourseTimeScheme(
                listOf(defaultScheme, otherScheme),
                settings,
                course,
                locationTimeGroups = groups,
            ),
        )
    }

    @Test
    fun resolve_manualOverrideBeatsLocationMatch() { // [Dart抄录]
        val defaultScheme = scheme("default")
        val otherScheme = scheme("other")
        val overrideScheme = scheme("override")
        val settings = TimetableSettings(activeTimeSchemeId = defaultScheme.id)
        val course = course("1", timeSchemeIdOverride = overrideScheme.id, location = "A1062")
        val groups = listOf(
            LocationTimeGroup(id = "g1", name = "其他教学楼", timeSchemeId = otherScheme.id, keywords = listOf(LocationKeyword("A1"))),
        )
        assertEquals(
            overrideScheme,
            TimeSchemeLogic.resolveCourseTimeScheme(
                listOf(defaultScheme, otherScheme, overrideScheme),
                settings,
                course,
                locationTimeGroups = groups,
            ),
        )
    }

    @Test
    fun resolve_dateRulesDoNotSoftOverlay() { // [Dart抄录]
        val defaultScheme = scheme("default")
        val summerScheme = scheme("summer")
        val settings = TimetableSettings(activeTimeSchemeId = defaultScheme.id)
        val rules = listOf(
            ScheduleDateRule(id = "r1", name = "夏令时", timeSchemeId = summerScheme.id, startDate = "2026-05-01", endDate = "2026-09-30"),
        )
        // 传了 onDate 也不切（bulk apply 是 provider 的职责）
        assertEquals(
            defaultScheme,
            TimeSchemeLogic.resolveCourseTimeScheme(
                listOf(defaultScheme, summerScheme),
                settings,
                course("1"),
                scheduleDateRules = rules,
                onDate = DartTime.dateTime(2026, 7, 1),
            ),
        )
    }

    @Test
    fun resolve_locationMatchBeatsDateRule() { // [Dart抄录]
        val defaultScheme = scheme("default")
        val summerScheme = scheme("summer")
        val buildingScheme = scheme("building")
        val settings = TimetableSettings(activeTimeSchemeId = defaultScheme.id)
        val course = course("1", location = "A1062")
        val groups = listOf(
            LocationTimeGroup(id = "g1", name = "其他教学楼", timeSchemeId = buildingScheme.id, keywords = listOf(LocationKeyword("A1"))),
        )
        val rules = listOf(
            ScheduleDateRule(id = "r1", name = "夏令时", timeSchemeId = summerScheme.id, startDate = "2026-05-01", endDate = "2026-09-30"),
        )
        assertEquals(
            buildingScheme,
            TimeSchemeLogic.resolveCourseTimeScheme(
                listOf(defaultScheme, summerScheme, buildingScheme),
                settings,
                course,
                locationTimeGroups = groups,
                scheduleDateRules = rules,
                onDate = DartTime.dateTime(2026, 7, 1),
            ),
        )
    }

    @Test
    fun resolve_nothingMatchesReturnsNull() { // [人推]
        val settings = TimetableSettings(activeTimeSchemeId = "ghost")
        assertNull(
            TimeSchemeLogic.resolveCourseTimeScheme(listOf(scheme("a")), settings, course("1")),
        )
        // settingsOverride 优先于 settings（Dart 推演 :115）
        val overrideSettings = TimetableSettings(activeTimeSchemeId = "a")
        assertEquals(
            scheme("a"),
            TimeSchemeLogic.resolveCourseTimeScheme(
                listOf(scheme("a")),
                settings,
                course("1"),
                settingsOverride = overrideSettings,
            ),
        )
    }

    // ---------- getCourseUsages [Dart抄录] ----------

    @Test
    fun usages_collectsProfileLevelAndOverrideUsages() { // [Dart抄录]
        val schemeA = scheme("a", name = "A")
        val schemeB = scheme("b", name = "B")
        val profiles = listOf(
            profile(
                "p1", "Main", schemeA.id,
                courses = listOf(
                    course("c1", endSection = 2),
                    course("c2", timeSchemeIdOverride = schemeB.id, endSection = 6),
                ),
            ),
            profile("p2", "Other", schemeB.id, courses = listOf(course("c3"))),
        )
        val usagesA = TimeSchemeLogic.getCourseUsages(profiles, schemeA.id)
        assertEquals(1, usagesA.size)
        assertEquals("Main", usagesA.first().profileName)
        assertFalse(usagesA.first().usesOverride)

        val usagesB = TimeSchemeLogic.getCourseUsages(profiles, schemeB.id)
        assertEquals(2, usagesB.size)
        assertTrue(usagesB.any { it.usesOverride })
    }

    @Test
    fun usages_locationMatchCounted() { // [Dart推演 :160-183]
        val schemeA = scheme("a")
        val schemeB = scheme("b")
        val profiles = listOf(
            profile(
                "p1", "Main", schemeA.id,
                courses = listOf(course("c1", location = "实验楼 101")),
            ),
        )
        val groups = listOf(
            LocationTimeGroup(id = "g1", name = "实验楼", timeSchemeId = schemeB.id, keywords = listOf(LocationKeyword("实验楼"))),
        )
        val usages = TimeSchemeLogic.getCourseUsages(
            profiles, schemeB.id, schemes = listOf(schemeA, schemeB), locationTimeGroups = groups,
        )
        assertEquals(1, usages.size)
        assertFalse(usages.first().usesOverride)
        assertTrue(usages.first().usesLocationMatch)
        // 组指向的作息不存在 → 不算引用、也不吃掉默认路由
        val groupsGhost = listOf(
            LocationTimeGroup(id = "g1", name = "实验楼", timeSchemeId = "ghost", keywords = listOf(LocationKeyword("实验楼"))),
        )
        val fallback = TimeSchemeLogic.getCourseUsages(
            profiles, schemeA.id, locationTimeGroups = groupsGhost,
        )
        assertEquals(1, fallback.size)
        assertFalse(fallback.first().usesLocationMatch)
    }

    // ---------- maxUsedSection / maxSectionUsage [Dart抄录] ----------

    @Test
    fun maxUsedSection_highestEndSection() { // [Dart抄录]
        val scheme = scheme("a")
        val profiles = listOf(
            profile(
                "p1", "Main", scheme.id,
                courses = listOf(course("c1", endSection = 2), course("c2", endSection = 8)),
            ),
        )
        assertEquals(8, TimeSchemeLogic.maxUsedSection(profiles, scheme.id))
    }

    @Test
    fun maxUsedSection_unusedReturnsZero() { // [Dart抄录]
        assertEquals(0, TimeSchemeLogic.maxUsedSection(emptyList(), "missing"))
    }

    @Test
    fun maxSectionUsage_returnsHighestOrFirst() { // [Dart推演 :238-243]
        val scheme = scheme("a")
        val c2 = course("c2", endSection = 8)
        val profiles = listOf(
            profile(
                "p1", "Main", scheme.id,
                courses = listOf(course("c1", endSection = 2), c2),
            ),
        )
        assertEquals(c2, TimeSchemeLogic.maxSectionUsage(profiles, scheme.id)?.course)
        assertNull(TimeSchemeLogic.maxSectionUsage(emptyList(), scheme.id))
    }

    // ---------- validateCourseTimeSchemeOverride [Dart抄录] ----------

    @Test
    fun validate_rejectsSectionsOutsideSchemeCapacity() { // [Dart抄录]
        val shortSections = TimetableSettings.DEFAULT_SECTIONS.take(4)
        val scheme = TimeScheme(
            id = "a",
            name = "Short",
            sections = shortSections,
            createdAt = DartTime.dateTime(2026, 1, 1),
            updatedAt = DartTime.dateTime(2026, 1, 1),
        )
        val settings = TimetableSettings(activeTimeSchemeId = scheme.id)
        val msg = TimeSchemeLogic.validateCourseTimeSchemeOverride(
            schemes = listOf(scheme),
            settings = settings,
            timeSchemeId = scheme.id,
            startSection = 1,
            endSection = 5,
        )
        assertTrue(msg!!.contains("time_scheme_sections_insufficient"))
        assertTrue(msg.contains("startSection=1"))
        assertTrue(msg.contains("endSection=5"))
    }

    @Test
    fun validate_configUnavailableVsSchemeNotFound() { // [Dart推演 :280-285]
        val emptySettings = TimetableSettings(sections = emptyList())
        // timeSchemeId == null + settings.sections 空 → config_unavailable
        assertEquals(
            "time_scheme_config_unavailable",
            TimeSchemeLogic.validateCourseTimeSchemeOverride(
                schemes = emptyList(),
                settings = emptySettings,
                startSection = 1,
                endSection = 1,
            ),
        )
        // timeSchemeId != null 但找不到 + settings.sections 空 → not_found_selected
        assertEquals(
            "time_scheme_not_found_selected",
            TimeSchemeLogic.validateCourseTimeSchemeOverride(
                schemes = emptyList(),
                settings = emptySettings,
                timeSchemeId = "ghost",
                startSection = 1,
                endSection = 1,
            ),
        )
        // 合法：单节 1..10 在默认 10 节模板内 → null
        assertNull(
            TimeSchemeLogic.validateCourseTimeSchemeOverride(
                schemes = emptyList(),
                settings = TimetableSettings(),
                startSection = 1,
                endSection = 10,
            ),
        )
    }

    @Test
    fun validate_startBelowOneRejected() { // [人推] startSection < 1
        val msg = TimeSchemeLogic.validateCourseTimeSchemeOverride(
            schemes = emptyList(),
            settings = TimetableSettings(),
            startSection = 0,
            endSection = 2,
        )
        assertTrue(msg!!.contains("time_scheme_sections_insufficient"))
    }

    // ---------- countCoursesWithoutVisibleRow [Dart抄录] ----------

    @Test
    fun countVisibleRow_outOfRowCounted() { // [Dart抄录]
        val courses = listOf(course("fit", endSection = 2), course("over", endSection = 5))
        assertEquals(1, TimeSchemeLogic.countCoursesWithoutVisibleRow(courses, sectionCount = 4))
    }

    @Test
    fun countVisibleRow_reversedAndZeroStart() { // [Dart抄录]
        assertEquals(
            1,
            TimeSchemeLogic.countCoursesWithoutVisibleRow(
                listOf(course("reversed", startSection = 3, endSection = 2)),
                sectionCount = 4,
            ),
        )
        assertEquals(
            1,
            TimeSchemeLogic.countCoursesWithoutVisibleRow(
                listOf(course("zero", startSection = 0, endSection = 2)),
                sectionCount = 4,
            ),
        )
    }

    @Test
    fun countVisibleRow_zeroSectionCountReturnsZero() { // [Dart抄录]
        assertEquals(
            0,
            TimeSchemeLogic.countCoursesWithoutVisibleRow(listOf(course("over", endSection = 5)), sectionCount = 0),
        )
        assertEquals(0, TimeSchemeLogic.countCoursesWithoutVisibleRow(emptyList(), sectionCount = 4))
    }

    // ---------- isSchemeInUse / collectDeleteBlockers [Dart抄录] ----------

    @Test
    fun inUse_detectsActiveProfileAndOverrideReferences() { // [Dart抄录]
        val scheme = scheme("in-use")
        val other = scheme("free")
        val profiles = listOf(
            profile("p1", "Main", scheme.id),
            profile("p2", "Alt", other.id, courses = listOf(course("c1", timeSchemeIdOverride = scheme.id))),
        )
        assertTrue(TimeSchemeLogic.isSchemeInUse(profiles, scheme.id))
        assertTrue(TimeSchemeLogic.isSchemeInUse(profiles, other.id))
        assertFalse(TimeSchemeLogic.isSchemeInUse(profiles, "unused"))
    }

    @Test
    fun inUse_noBlockersForFreeScheme() { // [Dart抄录]
        val scheme = scheme("free")
        val profiles = listOf(
            profile("p1", "Main", "other", courses = listOf(course("c1"))),
        )
        val blockers = TimeSchemeLogic.collectDeleteBlockers(profiles, scheme.id)
        assertTrue(blockers.isEmpty)
        assertFalse(TimeSchemeLogic.isSchemeInUse(profiles, scheme.id))
    }

    @Test
    fun inUse_namesBlockingProfilesAndCountsOverrides() { // [Dart抄录]
        val scheme = scheme("in-use")
        val profiles = listOf(
            profile("p1", "Main", scheme.id),
            profile(
                "p2", "Alt", "other",
                courses = listOf(
                    course("c1", timeSchemeIdOverride = scheme.id),
                    course("c2", timeSchemeIdOverride = scheme.id),
                ),
            ),
        )
        val blockers = TimeSchemeLogic.collectDeleteBlockers(profiles, scheme.id)
        assertEquals(listOf("Main"), blockers.profileNames)
        assertEquals(2, blockers.overrideCourseCount)
        assertEquals(0, blockers.locationCourseCount)
        assertTrue(blockers.isNotEmpty)
        assertEquals(2, blockers.totalCourseCount)
    }

    @Test
    fun inUse_locationGroupAndDateRuleReferences() { // [Dart抄录]
        val scheme = scheme("in-use")
        val profiles = listOf(profile("p1", "Main", "other"))
        val blockers = TimeSchemeLogic.collectDeleteBlockers(
            profiles,
            scheme.id,
            schemes = listOf(scheme),
            locationTimeGroups = listOf(
                LocationTimeGroup(id = "g1", name = "实验楼", timeSchemeId = scheme.id),
            ),
            scheduleDateRules = listOf(
                ScheduleDateRule(id = "r1", name = "期末周", timeSchemeId = scheme.id, startDate = "2026-01-05", endDate = "2026-01-18"),
            ),
        )
        assertEquals(listOf("实验楼"), blockers.locationGroupNames)
        assertEquals(listOf("期末周"), blockers.dateRuleNames)
        assertTrue(blockers.isNotEmpty)
    }

    @Test
    fun inUse_countsLocationRoutedCourses() { // [Dart抄录]
        val scheme = scheme("lab")
        val profiles = listOf(
            profile(
                "p1", "Main", "other",
                courses = listOf(
                    course("c1", location = "实验楼 101"),
                    course("c2", location = "实验楼 202"),
                    course("c3", location = "主教学楼 301"),
                ),
            ),
        )
        val blockers = TimeSchemeLogic.collectDeleteBlockers(
            profiles,
            scheme.id,
            schemes = listOf(scheme),
            locationTimeGroups = listOf(
                LocationTimeGroup(id = "g1", name = "实验楼", timeSchemeId = scheme.id, keywords = listOf(LocationKeyword("实验楼"))),
            ),
        )
        assertEquals(2, blockers.locationCourseCount)
        assertEquals(0, blockers.overrideCourseCount)
        assertTrue(blockers.isNotEmpty)
    }

    @Test
    fun inUse_locationCourseCountRequiresSchemeToExist() { // [Dart推演 :378-381]
        val scheme = scheme("lab")
        val profiles = listOf(
            profile("p1", "Main", "other", courses = listOf(course("c1", location = "实验楼 101"))),
        )
        val groups = listOf(
            LocationTimeGroup(id = "g1", name = "实验楼", timeSchemeId = scheme.id, keywords = listOf(LocationKeyword("实验楼"))),
        )
        // schemes 里没有这个作息 → locationCourseCount 不计（但组引用仍阻塞删除）
        val blockers = TimeSchemeLogic.collectDeleteBlockers(
            profiles, scheme.id, schemes = emptyList(), locationTimeGroups = groups,
        )
        assertEquals(0, blockers.locationCourseCount)
        assertTrue(blockers.isNotEmpty) // locationGroupNames 仍非空
    }

    @Test
    fun inUse_disabledGroupStillBlocks() { // [Dart推演 :346-352] 停用的组也阻塞删除
        val scheme = scheme("lab")
        val blockers = TimeSchemeLogic.collectDeleteBlockers(
            emptyList(),
            scheme.id,
            locationTimeGroups = listOf(
                LocationTimeGroup(id = "g1", name = "停用组", timeSchemeId = scheme.id, enabled = false),
            ),
        )
        assertEquals(listOf("停用组"), blockers.locationGroupNames)
        assertTrue(blockers.isNotEmpty)
    }

    @Test
    fun inUse_overrideToOtherSchemeDoesNotBlock() { // [人推] :371-372
        val scheme = scheme("target")
        val other = scheme("other")
        val profiles = listOf(
            profile(
                "p1", "Main", "none",
                courses = listOf(course("c1", timeSchemeIdOverride = other.id)),
            ),
        )
        val blockers = TimeSchemeLogic.collectDeleteBlockers(profiles, scheme.id)
        assertTrue(blockers.isEmpty)
    }

    // ---------- sectionsSignature [Dart推演] ----------

    @Test
    fun signature_matchesValueEquality() { // [Dart推演 :94-95]
        val a = listOf(SectionTime("08:00", "08:45"), SectionTime("", ""))
        assertEquals(sectionsSignature(a), listOf(SectionTime("08:00", "08:45"), SectionTime("", "")).let { sectionsSignature(it) })
        assertFalse(sectionsSignature(a) == sectionsSignature(listOf(SectionTime("08:00", "08:45"))))
    }

    // ---------- syncCourseWithEffectiveTimeScheme [Dart抄录/推演 :429-507] ----------

    @Test
    fun sync_rewritesClockToSchemeSections() { // [Dart推演]
        val scheme = scheme("main")
        val settings = TimetableSettings(activeTimeSchemeId = scheme.id)
        val course = course("c1", startSection = 5, endSection = 6)
        val synced = TimeSchemeLogic.syncCourseWithEffectiveTimeScheme(course, schemes = listOf(scheme), settings = settings)
        // 默认模板第 5/6 节 = 14:00-14:45 / 14:55-15:40
        assertEquals("14:00", synced.startTime)
        assertEquals("15:40", synced.endTime)
    }

    @Test
    fun sync_outOfRangeSectionsKeepsOriginal() { // [Dart推演 :455-467]
        val scheme = scheme("main")
        val settings = TimetableSettings(activeTimeSchemeId = scheme.id)
        // 第 12 节超出默认 10 节模板
        val course = course("c1", startSection = 11, endSection = 12)
        val synced = TimeSchemeLogic.syncCourseWithEffectiveTimeScheme(course, schemes = listOf(scheme), settings = settings)
        assertEquals(course, synced) // 原样返回（引用语义）
        // startIndex < 0（startSection=0）
        val zero = course("c2", startSection = 0, endSection = 1)
        assertEquals(zero, TimeSchemeLogic.syncCourseWithEffectiveTimeScheme(zero, schemes = listOf(scheme), settings = settings))
        // 空 sections
        val emptySettings = TimetableSettings(sections = emptyList(), activeTimeSchemeId = null)
        val plain = course("c3")
        assertEquals(plain, TimeSchemeLogic.syncCourseWithEffectiveTimeScheme(plain, schemes = emptyList(), settings = emptySettings))
    }

    @Test
    fun sync_hasCustomTime_isAuthoritative() { // [Dart抄录 course_domain_edit_clock_test.dart 的语义：模板不得覆盖]
        val scheme = scheme("main")
        val settings = TimetableSettings(activeTimeSchemeId = scheme.id)
        val course = Course(
            id = "c1", name = "实验连堂", teacher = "T", location = "L",
            dayOfWeek = 1, startSection = 1, endSection = 2,
            startTime = "07:30", endTime = "10:00", // 适配脚本下发的真实钟点
            hasCustomTime = true,
        )
        val synced = TimeSchemeLogic.syncCourseWithEffectiveTimeScheme(course, schemes = listOf(scheme), settings = settings)
        assertEquals(course, synced)
    }

    @Test
    fun sync_sameClockReturnsSameInstance() { // [Dart推演 :479-490]
        val scheme = scheme("main")
        val settings = TimetableSettings(activeTimeSchemeId = scheme.id)
        // 第 1-2 节的默认钟点就是 08:00-09:40
        val course = course("c1", startSection = 1, endSection = 2)
        val synced = TimeSchemeLogic.syncCourseWithEffectiveTimeScheme(course, schemes = listOf(scheme), settings = settings)
        assertTrue(synced === course) // 引用相同（不改写）
    }

    @Test
    fun sync_noSchemeFallsBackToSettingsSections() { // [Dart推演 :451-452]
        val settings = TimetableSettings() // 无 activeTimeSchemeId
        val course = course("c1", startSection = 9, endSection = 9)
        val synced = TimeSchemeLogic.syncCourseWithEffectiveTimeScheme(course, schemes = emptyList(), settings = settings)
        assertEquals("19:00", synced.startTime)
        assertEquals("19:45", synced.endTime)
    }

    @Test
    fun syncCourses_mapsAllCourses() { // [Dart推演 :398-418]
        val scheme = scheme("main")
        val settings = TimetableSettings(activeTimeSchemeId = scheme.id)
        val courses = listOf(
            course("c1", startSection = 1, endSection = 1),
            course("c2", startSection = 5, endSection = 5),
        )
        val synced = TimeSchemeLogic.syncCoursesWithEffectiveTimeSchemes(courses, schemes = listOf(scheme), settings = settings)
        assertEquals(2, synced.size)
        assertEquals("08:00", synced[0].startTime)
        assertEquals("14:00", synced[1].startTime)
        // 原 list 未变（纯映射）
        assertEquals("08:00", courses[0].startTime)
    }
}
