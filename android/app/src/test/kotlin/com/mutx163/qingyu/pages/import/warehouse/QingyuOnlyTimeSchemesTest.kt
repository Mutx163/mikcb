package com.mutx163.qingyu.pages.import.warehouse

import com.mutx163.qingyu.app.InMemoryKeyValueStore
import com.mutx163.qingyu.app.TimetableRepository
import com.mutx163.qingyu.app.TimetableStore
import com.mutx163.qingyu.core.LocationKeyword
import com.mutx163.qingyu.core.LocationKeywordMatchMode
import com.mutx163.qingyu.core.LocationTimeGroup
import com.mutx163.qingyu.core.SectionTime
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 轻屿专属作息（`qingyu_only/<目录>/time_schemes.json`）的解析、校区反推与落盘。
 *
 * 钉住 Dart `QingyuOnlyTimeSchemesLogic` / `_applyQingyuOnlyLocationTimeSchemes` 的四条口径：
 * 1. 数据校验（版本、基线连续、每校区恰好一套兜底）；
 * 2. 校区用脚本下发的节次**逐节比对**反推，判不出来就退回脚本那套；
 * 3. 合并分组时同名替换 / 他校自动组清除 / 手建组保留；
 * 4. 写盘走既有仓储通道：同名模板更新、缺则新建，最后套用兜底那套。
 */
class QingyuOnlyTimeSchemesTest {

    private val baseline = mapOf(
        "1" to mapOf("startTime" to "08:00", "endTime" to "08:45"),
        "2" to mapOf("startTime" to "08:55", "endTime" to "09:40"),
        "3" to mapOf("startTime" to "09:50", "endTime" to "10:35"),
    )

    private fun sections(start: String, end: String) = SectionTime(startTime = start, endTime = end)

    private fun fixture(sectionsMap: Map<String, Any?> = baseline): Map<String, Any?> = mapOf(
        "version" to 1,
        "sections" to sectionsMap,
        "campuses" to listOf(
            mapOf(
                "id" to "yc",
                "name" to "永川校区",
                "schemes" to listOf(
                    mapOf("name" to "永川校区 · 其他教学楼"),
                    mapOf(
                        "name" to "永川校区 · A栋·主教学楼",
                        "keywords" to listOf(mapOf("pattern" to "A栋", "mode" to "contains")),
                        "overrides" to mapOf(
                            "3" to mapOf("startTime" to "10:30", "endTime" to "11:15"),
                        ),
                    ),
                ),
            ),
        ),
    )

    private fun repository(): TimetableRepository =
        TimetableRepository(TimetableStore(InMemoryKeyValueStore()))

    // ── 解析 ──────────────────────────────────────────────────────────

    @Test
    fun `解析把基线与覆盖合成每套作息，关键词模式按 fromValue 归一`() {
        val parsed = QingyuOnlyTimeSchemesLogic.parse(fixture())

        assertEquals(1, parsed.campuses.size)
        val campus = parsed.campuses.single()
        assertEquals("yc", campus.id)
        assertEquals(2, campus.schemes.size)

        val fallback = campus.schemes.first { it.isFallback }
        assertEquals(3, fallback.sections.size)
        assertEquals("08:00", fallback.sections[0].startTime)

        // 覆盖只写与基线不同的第 3 节，其余照抄基线。
        val building = campus.schemes.first { !it.isFallback }
        assertEquals("10:30", building.sections[2].startTime)
        assertEquals("11:15", building.sections[2].endTime)
        assertEquals(
            listOf(LocationKeyword("A栋", LocationKeywordMatchMode.CONTAINS)),
            building.keywords,
        )
    }

    @Test
    fun `版本不对或基线缺失时整份数据不可用`() {
        val wrongVersion = fixture().toMutableMap().apply { put("version", 2) }
        assertCode("qingyu_only_time_schemes_version") {
            QingyuOnlyTimeSchemesLogic.parse(wrongVersion)
        }

        val missingBaseline = fixture().toMutableMap().apply { remove("sections") }
        assertCode("qingyu_only_time_schemes_baseline_missing") {
            QingyuOnlyTimeSchemesLogic.parse(missingBaseline)
        }
    }

    @Test
    fun `基线缺节或时钟倒退时整份数据不可用`() {
        val gap = mapOf(
            "1" to mapOf("startTime" to "08:00", "endTime" to "08:45"),
            "3" to mapOf("startTime" to "09:50", "endTime" to "10:35"),
        )
        assertCode("qingyu_only_time_schemes_baseline_missing") {
            QingyuOnlyTimeSchemesLogic.parse(fixture(gap))
        }

        val backwards = mapOf(
            "1" to mapOf("startTime" to "08:00", "endTime" to "08:45"),
            "2" to mapOf("startTime" to "09:20", "endTime" to "09:00"),
        )
        assertCode("qingyu_only_time_schemes_baseline_missing") {
            QingyuOnlyTimeSchemesLogic.parse(fixture(backwards))
        }
    }

    @Test
    fun `每校区必须恰好一套兜底，多套的校区整块丢掉`() {
        val twoFallbacks = mapOf(
            "version" to 1,
            "sections" to baseline,
            "campuses" to listOf(
                mapOf(
                    "id" to "yc",
                    "name" to "永川校区",
                    "schemes" to listOf(
                        mapOf("name" to "永川校区 · 其他教学楼"),
                        mapOf("name" to "永川校区 · B栋", "keywords" to listOf(mapOf("pattern" to "B栋"))),
                    ),
                ),
                mapOf(
                    "id" to "bad",
                    "name" to "坏校区",
                    "schemes" to listOf(
                        mapOf("name" to "坏校区 · 兜底1"),
                        mapOf("name" to "坏校区 · 兜底2"),
                    ),
                ),
            ),
        )

        val parsed = QingyuOnlyTimeSchemesLogic.parse(twoFallbacks)

        assertEquals(listOf("yc"), parsed.campuses.map { it.id })
    }

    // ── 校区反推 ──────────────────────────────────────────────────────

    @Test
    fun `脚本选中的那套作息逐节比对命中对应校区`() {
        val parsed = QingyuOnlyTimeSchemesLogic.parse(fixture())
        val building = parsed.campuses.single().schemes.first { !it.isFallback }

        assertEquals("yc", parsed.campusForSections(building.sections)?.id)
        assertNull(parsed.campusForSections(emptyList()))
    }

    @Test
    fun `两套作息完全相同导致校区无解时返回 null 而不是猜`() {
        val ambiguous = mapOf(
            "version" to 1,
            "sections" to baseline,
            "campuses" to listOf(
                mapOf("id" to "a", "name" to "A校", "schemes" to listOf(mapOf("name" to "A兜底"))),
                mapOf("id" to "b", "name" to "B校", "schemes" to listOf(mapOf("name" to "B兜底"))),
            ),
        )
        val parsed = QingyuOnlyTimeSchemesLogic.parse(ambiguous)
        val probe = listOf(
            sections("08:00", "08:45"),
            sections("08:55", "09:40"),
            sections("09:50", "10:35"),
        )

        assertNull(parsed.campusForSections(probe))
    }

    // ── 分组合并 ──────────────────────────────────────────────────────

    @Test
    fun `同名替换 他校自动组清除 手建与本校旧组保留`() {
        val existing = listOf(
            LocationTimeGroup(id = "manual", name = "手建组", timeSchemeId = "s1"),
            LocationTimeGroup(id = "old", name = "本校旧组", timeSchemeId = "s2", sourceSchoolId = "yc"),
            LocationTimeGroup(id = "other", name = "他校组", timeSchemeId = "s3", sourceSchoolId = "zz"),
            LocationTimeGroup(id = "dup", name = "A栋", timeSchemeId = "s4", sourceSchoolId = "yc"),
        )
        val incoming = listOf(
            LocationTimeGroup(
                id = "new",
                name = "A栋",
                timeSchemeId = "s5",
                priority = 0,
                keywords = listOf(LocationKeyword("A栋", LocationKeywordMatchMode.CONTAINS)),
                sourceSchoolId = "yc",
            ),
        )

        val merged = mergeLocationTimeGroupsForImport(existing, incoming, schoolId = "yc")

        assertEquals(listOf("manual", "old", "new"), merged.map { it.id })
    }

    // ── 落盘 ──────────────────────────────────────────────────────────

    @Test
    fun `应用时同名模板更新、缺则新建、分组合并后套用兜底作息`() {
        val repository = repository()
        val parsed = QingyuOnlyTimeSchemesLogic.parse(fixture())
        val campus = parsed.campuses.single()
        val fallback = campus.schemes.first { it.isFallback }
        val building = campus.schemes.first { !it.isFallback }
        // 现有：同名兜底模板（值故意写错，验证会被更新成数据文件里的节次）
        val existing = repository.createTimeScheme(
            name = fallback.name,
            sections = listOf(sections("07:00", "07:45")),
        )
        val manual = LocationTimeGroup(id = "manual", name = "手建组", timeSchemeId = "s1")
        val otherSchool = LocationTimeGroup(
            id = "other",
            name = "他校组",
            timeSchemeId = "s2",
            sourceSchoolId = "zz",
        )
        repository.updateLocationTimeGroups(listOf(manual, otherSchool))

        var seq = 0
        val result = QingyuOnlyTimeSchemesApplier.apply(
            repository = repository,
            schemes = parsed,
            scriptSections = building.sections,
            schoolId = "yc",
            idFactory = { "g${seq++}" },
        )

        assertTrue(result is QingyuOnlyApplyResult.Applied)
        result as QingyuOnlyApplyResult.Applied
        assertEquals("yc", result.campusId)
        assertEquals(2, result.schemeCount)
        assertEquals(1, result.groupCount)

        val snapshot = repository.snapshot
        // 同名兜底被更新（不是又加一条重名模板），A栋 新建。
        assertEquals(2, snapshot.timeSchemes.size)
        assertEquals(
            fallback.sections,
            snapshot.timeSchemes.first { it.id == existing.id }.sections,
        )
        // 他校自动组清掉，手建组保留，新组带上来源校标记。
        assertEquals(listOf("manual", "g0"), snapshot.locationTimeGroups.map { it.id })
        assertEquals("yc", snapshot.locationTimeGroups.last().sourceSchoolId)
        // 兜底那套成为当前课表的作息。
        assertEquals(existing.id, snapshot.activeTimeSchemeId)
    }

    @Test
    fun `校区判不出来时什么都不改`() {
        val repository = repository()
        val ambiguous = mapOf(
            "version" to 1,
            "sections" to baseline,
            "campuses" to listOf(
                mapOf("id" to "a", "name" to "A校", "schemes" to listOf(mapOf("name" to "A兜底"))),
                mapOf("id" to "b", "name" to "B校", "schemes" to listOf(mapOf("name" to "B兜底"))),
            ),
        )
        val parsed = QingyuOnlyTimeSchemesLogic.parse(ambiguous)

        val result = QingyuOnlyTimeSchemesApplier.apply(
            repository = repository,
            schemes = parsed,
            scriptSections = listOf(sections("08:00", "08:45"), sections("09:00", "09:45")),
            schoolId = "yc",
        )

        assertEquals(
            QingyuOnlyApplyResult.Skipped("qingyu_only_campus_undetermined"),
            result,
        )
        assertTrue(repository.snapshot.timeSchemes.isEmpty())
        assertTrue(repository.snapshot.locationTimeGroups.isEmpty())
    }

    private fun assertCode(expected: String, block: () -> Unit) {
        val error = try {
            block()
            null
        } catch (caught: QingyuOnlyTimeSchemesException) {
            caught
        }
        assertEquals(expected, error?.code)
    }
}
