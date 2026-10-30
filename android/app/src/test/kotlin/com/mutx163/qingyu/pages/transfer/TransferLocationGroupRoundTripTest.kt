package com.mutx163.qingyu.pages.transfer

import com.mutx163.qingyu.app.TimetableSnapshot
import com.mutx163.qingyu.core.LocationKeyword
import com.mutx163.qingyu.core.LocationKeywordMatchMode
import com.mutx163.qingyu.core.LocationTimeGroup
import com.mutx163.qingyu.core.MiniJson
import com.mutx163.qingyu.core.SectionTime
import com.mutx163.qingyu.core.TimeScheme
import com.mutx163.qingyu.core.TimetableProfile
import com.mutx163.qingyu.core.TimetableSettings
import com.mutx163.qingyu.share.TransferApplyMode
import com.mutx163.qingyu.share.TransferChannel
import com.mutx163.qingyu.share.TransferScope
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDateTime

/**
 * 地点作息分组的**往返**测试（导出 → 解析 → 落盘计划）。
 *
 * ## 为什么单独建这一条
 *
 * 2026-10-30 二轮审核 P0-3：这块数据**双向全丢**且没有任何测试会红——
 *
 * - 导出侧 `DataTransferPackageLogic` 恒写 `locationTimeGroupsJson = emptyList()`，
 *   理由写成「TimetableSnapshot 没有该字段」，但 `TimetableRepository.kt:45` 早就有；
 * - 导入侧 `DataTransferImportLogic` 根本不解析这个键；
 * - 于是「按地点匹配作息」跨设备迁移后静默失效，包里连痕迹都没有。
 *
 * 旧测试抓不到它，因为它们只断言「包里有哪些课程/作业/考试」，
 * **没有一条断言「地点分组进包了、且能读回来」**。
 *
 * ## 期望值从哪来
 *
 * 人推，不从实现里抄：
 * - 分组自己造的 `g1` 必须**原样**出现在包 JSON 的 `locationTimeGroups` 里（id/name/timeSchemeId/keywords）；
 * - 解析回来后的模型字段必须与写进去的逐字段相等；
 * - 落盘计划必须把同一批分组带到 `writes.locationTimeGroups`（宿主据此调 `updateLocationTimeGroups`）；
 * - 包**没带**该键时计划必须是空（约定：空 = 不动本机，绝不能顺手清空用户分组）。
 */
class TransferLocationGroupRoundTripTest {

    private val now: LocalDateTime = LocalDateTime.of(2026, 3, 2, 8, 30)

    private fun settings() = TimetableSettings(
        sections = listOf(SectionTime("08:00", "08:45")),
        activeTimeSchemeId = "ts1",
        semesterWeekCount = 16,
        semesterStartDate = LocalDateTime.of(2026, 3, 2, 0, 0),
    )

    private fun scheme(id: String, name: String) = TimeScheme(
        id = id,
        name = name,
        sections = listOf(SectionTime("08:00", "08:45")),
        createdAt = LocalDateTime.of(2026, 2, 1, 0, 0),
        updatedAt = LocalDateTime.of(2026, 2, 1, 0, 0),
    )

    /** 一条「按地点匹配作息」的分组：地点含「实验楼」，命中就走实验室作息 `ts2`。 */
    private fun group(id: String = "g1") = LocationTimeGroup(
        id = id,
        name = "实验室作息",
        timeSchemeId = "ts2",
        enabled = true,
        priority = 5,
        keywords = listOf(
            LocationKeyword("实验楼", LocationKeywordMatchMode.PREFIX),
            LocationKeyword("A101", LocationKeywordMatchMode.EXACT),
        ),
        sourceSchoolId = "school-1",
    )

    private fun snapshot(groups: List<LocationTimeGroup>) = TimetableSnapshot(
        profiles = listOf(
            TimetableProfile(
                id = "p1",
                name = "2026 春",
                courses = emptyList(),
                settings = settings(),
                currentWeek = 1L,
                createdAt = LocalDateTime.of(2026, 2, 1, 0, 0),
                lastUsedAt = LocalDateTime.of(2026, 2, 2, 0, 0),
            ),
        ),
        activeProfileId = "p1",
        settings = settings(),
        currentWeek = 1,
        semesterStartEpochDay = java.time.LocalDate.of(2026, 3, 2).toEpochDay(),
        timeSchemes = listOf(scheme("ts1", "默认作息"), scheme("ts2", "实验室作息")),
        activeTimeSchemeId = "ts1",
        locationTimeGroups = groups,
    )

    private fun exportedJson(groups: List<LocationTimeGroup>): String {
        val result = DataTransferPackageLogic.build(
            snapshot = snapshot(groups),
            request = TransferPackageRequest(
                scope = TransferScope.CURRENT_TIMETABLE,
                channel = TransferChannel.FILE,
                packageId = "pkg-loc",
                now = now,
            ),
        )
        assertTrue("期望打包成功，实际 $result", result is TransferPackageResult.Success)
        return (result as TransferPackageResult.Success).json
    }

    @Suppress("UNCHECKED_CAST")
    private fun rootOf(json: String): Map<String, Any?> = MiniJson.parse(json) as Map<String, Any?>

    // ---------- ① 导出 ----------

    @Test
    fun `导出必须把地点作息分组写进包`() {
        val json = exportedJson(listOf(group()))
        val raw = rootOf(json)["locationTimeGroups"] as? List<Any?>
        assertTrue(
            "包 JSON 的 locationTimeGroups 不是列表（实际 ${rootOf(json)["locationTimeGroups"]}）——" +
                "这正是审核 P0-3 的形态：导出侧恒写空列表。整包：$json",
            raw != null,
        )
        assertEquals("地点分组导出条数不对：$json", 1, raw!!.size)

        @Suppress("UNCHECKED_CAST")
        val first = raw[0] as Map<String, Any?>
        // 逐字段人推：与 group() 里写进去的值一致。
        assertEquals("g1", first["id"])
        assertEquals("实验室作息", first["name"])
        assertEquals("ts2", first["timeSchemeId"])
        assertEquals(true, first["enabled"])
        assertEquals(5, (first["priority"] as Number).toInt())
        assertEquals("school-1", first["sourceSchoolId"])

        val keywords = first["keywords"] as? List<Any?>
        assertEquals("关键词条数不对", 2, keywords?.size)
        @Suppress("UNCHECKED_CAST")
        val kw0 = keywords!![0] as Map<String, Any?>
        assertEquals("实验楼", kw0["pattern"])
        assertEquals("prefix", kw0["mode"])
    }

    @Test
    fun `没有分组时不写空对象进去`() {
        val json = exportedJson(emptyList())
        val raw = rootOf(json)["locationTimeGroups"] as? List<Any?>
        assertEquals("没有分组就该是空列表", 0, raw?.size)
    }

    // ---------- ② 解析（导入侧） ----------

    @Test
    fun `导入必须把地点作息分组解析回模型`() {
        val json = exportedJson(listOf(group()))
        val parsed = DataTransferImportLogic.parse(json)
        assertTrue("期望解析成功，实际 $parsed", parsed is TransferImportParseResult.Valid)
        val plan = (parsed as TransferImportParseResult.Valid).plan

        assertEquals("导入侧没解析地点分组（审核 P0-3 的导入半边）", 1, plan.locationTimeGroups.size)
        val g = plan.locationTimeGroups[0]
        assertEquals("g1", g.id)
        assertEquals("实验室作息", g.name)
        assertEquals("ts2", g.timeSchemeId)
        assertEquals(true, g.enabled)
        assertEquals(5, g.priority)
        assertEquals("school-1", g.sourceSchoolId)
        assertEquals("关键词条数不对", 2, g.keywords.size)
        assertEquals("实验楼", g.keywords[0].pattern)
        assertEquals(LocationKeywordMatchMode.PREFIX, g.keywords[0].mode)
        assertEquals(LocationKeywordMatchMode.EXACT, g.keywords[1].mode)
    }

    // ---------- ③ 落盘计划 ----------

    @Test
    fun `落盘计划必须携带地点作息分组`() {
        val json = exportedJson(listOf(group()))
        val plan = (DataTransferImportLogic.parse(json) as TransferImportParseResult.Valid).plan
        val writes = DataTransferApplyLogic.planWrites(
            plan = plan,
            mode = TransferApplyMode.OVERWRITE,
            current = DataTransferApplyLogic.TransferCurrentContent(),
            scope = TransferScope.CURRENT_TIMETABLE,
        )
        assertEquals(
            "计划里没有地点分组 ⇒ 宿主永远不会调 updateLocationTimeGroups，数据还是不落地",
            1,
            writes.locationTimeGroups.size,
        )
        assertEquals("g1", writes.locationTimeGroups[0].id)
    }

    @Test
    fun `包没带分组时计划必须是空表示不动本机`() {
        val json = exportedJson(emptyList())
        val plan = (DataTransferImportLogic.parse(json) as TransferImportParseResult.Valid).plan
        val writes = DataTransferApplyLogic.planWrites(
            plan = plan,
            mode = TransferApplyMode.OVERWRITE,
            current = DataTransferApplyLogic.TransferCurrentContent(),
            scope = TransferScope.CURRENT_TIMETABLE,
        )
        assertEquals(
            "包没带该键时必须留空（空 = 不覆盖），否则一次不含分组的导入会清空用户已有分组",
            0,
            writes.locationTimeGroups.size,
        )
    }
}
