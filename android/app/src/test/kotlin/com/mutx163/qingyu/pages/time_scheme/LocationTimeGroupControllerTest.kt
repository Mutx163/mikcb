package com.mutx163.qingyu.pages.time_scheme

import com.mutx163.qingyu.app.TimetableStore
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.LocationKeyword
import com.mutx163.qingyu.core.LocationKeywordMatchMode
import com.mutx163.qingyu.core.LocationTimeGroup
import com.mutx163.qingyu.core.MiniJson
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 地点组控制器测试（纯逻辑，期望值从 Dart 源手推）。
 *
 * 出处：
 * - 新建/编辑/删除/开关：`lib/screens/location_time_match_screen.dart:1032-1100` 与
 *   `lib/services/timetable_location_rule_service.dart:174-285`；
 * - 匹配与「未知模板」兜底：`lib/domain/location_time_match_logic.dart:90-155`，
 *   卡片文案由 [LocationTimeMatchModel] 负责（已有独立测试，这里只钉控制器交给模型的数据）；
 * - 「重新匹配当前课表」：`location_time_match_screen.dart:162-326`（候选数、确认框、五分支结果）。
 *
 * 每条断言的期望值都写成字面量，能从上面几段 Dart 直接读出来，不从实现里反推。
 */
class LocationTimeGroupControllerTest {

    private fun group(
        id: String,
        name: String,
        schemeId: String = "s1",
        enabled: Boolean = true,
        priority: Int = 0,
        keywords: List<LocationKeyword> = listOf(LocationKeyword("A1")),
        sourceSchoolId: String? = null,
    ) = LocationTimeGroup(
        id = id,
        name = name,
        timeSchemeId = schemeId,
        enabled = enabled,
        priority = priority,
        keywords = keywords,
        sourceSchoolId = sourceSchoolId,
    )

    private fun buildController(
        groups: List<LocationTimeGroup>,
        schemes: List<LocationTimeSchemeOption> = listOf(LocationTimeSchemeOption("s1", "夏季作息")),
        locations: List<String> = emptyList(),
        newId: String = "new-group-id",
    ) = LocationTimeGroupController(
        groups = groups,
        schemes = schemes,
        availableLocations = locations,
        idFactory = { newId },
    )

    private fun course(location: String) = Course(
        id = "c-$location",
        name = "课",
        teacher = "",
        location = location,
        dayOfWeek = 1,
        startSection = 1,
        endSection = 2,
        startTime = "08:00",
        endTime = "09:40",
    )

    private fun assertJsonRoundTrip(groups: List<LocationTimeGroup>) {
        val encoded = MiniJson.encode(groups.map { it.toJsonMap() })
        val decoded = MiniJson.parse(encoded)
        assertTrue("顶层必须是数组，实际：$decoded", decoded is List<*>)
        @Suppress("UNCHECKED_CAST")
        val restored = (decoded as List<*>).map {
            @Suppress("UNCHECKED_CAST")
            LocationTimeGroup.fromJson(it as Map<String, Any?>)
        }
        assertEquals("toJsonMap()/fromJson() 往返必须逐字段相等", groups, restored)
    }

    // ── 1. 新建组 ──

    @Test
    fun `新建组追加到末尾且字段与表单一致`() {
        val existing = group(id = "g1", name = "主教学楼", priority = 3, sourceSchoolId = "school-1")
        val controller = buildController(groups = listOf(existing))

        val result = controller.save(
            controller.newDraft().copy(
                name = " 东区教学楼 ",
                timeSchemeId = "s1",
                enabled = false,
                keywords = listOf(
                    LocationKeyword(" 东区 ", LocationKeywordMatchMode.PREFIX),
                    LocationKeyword("   ", LocationKeywordMatchMode.CONTAINS),
                    LocationKeyword("B2", LocationKeywordMatchMode.EXACT),
                ),
                // 表单里没有的两个字段即使被脏数据带上，新建也必须归 0 / null。
                priority = 9,
                sourceSchoolId = "should-not-carry",
            ),
        )

        assertTrue("新建应被接受，实际 $result", result is LocationTimeGroupChange.Applied)
        val applied = result as LocationTimeGroupChange.Applied
        assertEquals(2, applied.groups.size)
        assertEquals("旧组必须原样留在原位", existing, applied.groups[0])
        val created = applied.groups[1]
        assertEquals("new-group-id", created.id)
        assertEquals("东区教学楼", created.name)
        assertEquals("s1", created.timeSchemeId)
        assertFalse(created.enabled)
        assertEquals("Dart createGroup 默认 priority = 0", 0, created.priority)
        assertNull("手建组没有学校来源", created.sourceSchoolId)
        assertEquals(
            listOf(
                LocationKeyword("东区", LocationKeywordMatchMode.PREFIX),
                LocationKeyword("B2", LocationKeywordMatchMode.EXACT),
            ),
            created.keywords,
        )
        assertEquals(created, applied.target)

        // 落盘格式：顶层列表 → JSON → fromJson 后必须逐字段回来。
        assertJsonRoundTrip(applied.groups)
        // 顶层 key 与 Dart 同名（`location_time_groups`，TimetableStore:368）。
        assertEquals("location_time_groups", TimetableStore.KEY_LOCATION_TIME_GROUPS)
        val keywordJson = created.toJsonMap()["keywords"] as List<*>
        assertEquals(
            linkedMapOf("pattern" to "东区", "mode" to "prefix"),
            keywordJson[0],
        )
    }

    @Test
    fun `新建表单默认值照 Dart 初始化`() {
        val controller = buildController(
            groups = emptyList(),
            schemes = listOf(
                LocationTimeSchemeOption("s1", "夏季作息"),
                LocationTimeSchemeOption("s2", "冬季作息"),
            ),
        )
        val draft = controller.newDraft()
        assertNull(draft.editingId)
        assertEquals("", draft.name)
        assertEquals("模板列表第一套（Dart build 里 schemes.first）", "s1", draft.timeSchemeId)
        assertTrue(draft.enabled)
        assertTrue(draft.keywords.isEmpty())
        assertEquals(0, draft.priority)
        assertNull(draft.sourceSchoolId)

        val noScheme = buildController(groups = emptyList(), schemes = emptyList()).newDraft()
        assertEquals("一套模板都没有时保持空串，保存报 needTimeScheme", "", noScheme.timeSchemeId)
    }

    @Test
    fun `编辑草稿照抄原组字段`() {
        val target = group(
            id = "g2",
            name = "东区",
            schemeId = "s1",
            enabled = false,
            priority = 7,
            keywords = listOf(LocationKeyword("B2", LocationKeywordMatchMode.CONTAINS)),
            sourceSchoolId = "school-2",
        )
        val draft = buildController(groups = listOf(target)).editDraft("g2")!!
        assertEquals("g2", draft.editingId)
        assertEquals("东区", draft.name)
        assertEquals("s1", draft.timeSchemeId)
        assertFalse(draft.enabled)
        assertEquals(listOf(LocationKeyword("B2", LocationKeywordMatchMode.CONTAINS)), draft.keywords)
        assertEquals(7, draft.priority)
        assertEquals("school-2", draft.sourceSchoolId)

        // Dart 只在 timeSchemeId 为空时回落到第一套模板（:648-650）。
        val noSchemeGroup = group(id = "g3", name = "无模板", schemeId = "")
        assertEquals(
            "s1",
            buildController(groups = listOf(noSchemeGroup)).editDraft("g3")!!.timeSchemeId,
        )
        assertNull(buildController(groups = emptyList()).editDraft("missing"))
    }

    // ── 2. 编辑组 ──

    @Test
    fun `编辑只改目标组其它组不动`() {
        val g1 = group(id = "g1", name = "主教学楼", keywords = listOf(LocationKeyword("A1")))
        val g2 = group(
            id = "g2",
            name = "东区",
            priority = 5,
            keywords = listOf(LocationKeyword("B1", LocationKeywordMatchMode.PREFIX)),
            sourceSchoolId = "school-2",
        )
        val g3 = group(id = "g3", name = "西区", keywords = listOf(LocationKeyword("C1")))
        val controller = buildController(groups = listOf(g1, g2, g3))

        val result = controller.save(
            controller.editDraft("g2")!!.copy(
                name = " 东区教学楼 ",
                timeSchemeId = "s1",
                enabled = false,
                keywords = listOf(LocationKeyword(" B2 ", LocationKeywordMatchMode.EXACT)),
            ),
        )

        assertTrue(result is LocationTimeGroupChange.Applied)
        val applied = result as LocationTimeGroupChange.Applied
        assertEquals(3, applied.groups.size)
        assertEquals("非目标组必须一模一样", g1, applied.groups[0])
        assertEquals("非目标组必须一模一样", g3, applied.groups[2])
        val edited = applied.groups[1]
        assertEquals("g2", edited.id)
        assertEquals("东区教学楼", edited.name)
        assertFalse(edited.enabled)
        assertEquals(listOf(LocationKeyword("B2", LocationKeywordMatchMode.EXACT)), edited.keywords)
        assertEquals("编辑保留 priority", 5, edited.priority)
        assertEquals("编辑保留 sourceSchoolId", "school-2", edited.sourceSchoolId)
        assertEquals("列表顺序不变", listOf("g1", "g2", "g3"), applied.groups.map { it.id })
        assertJsonRoundTrip(applied.groups)
    }

    @Test
    fun `编辑不存在的组返回 Missing 不伪造新列表`() {
        val controller = buildController(groups = listOf(group(id = "g1", name = "主楼")))
        val draft = controller.newDraft().copy(
            editingId = "gone",
            name = "东区",
            keywords = listOf(LocationKeyword("B2")),
        )
        assertTrue(controller.save(draft) is LocationTimeGroupChange.Missing)
    }

    // ── 3. 开关组 ──

    @Test
    fun `开关组翻 enabled 且落盘列表正确`() {
        val g1 = group(id = "g1", name = "主教学楼", enabled = true, priority = 2)
        val g2 = group(id = "g2", name = "东区", enabled = true)
        val controller = buildController(groups = listOf(g1, g2))

        val result = controller.setEnabled("g1", false)
        assertTrue(result is LocationTimeGroupChange.Applied)
        val applied = result as LocationTimeGroupChange.Applied
        assertEquals(2, applied.groups.size)
        assertEquals(g1.copy(enabled = false), applied.groups[0])
        assertEquals("开关不动别的组", g2, applied.groups[1])
        assertEquals("priority 原样保留", 2, applied.groups[0].priority)
        assertJsonRoundTrip(applied.groups)

        // 再拨回来：同一份数据反过来。
        val back = controller.setEnabled("g1", true) as LocationTimeGroupChange.Applied
        assertEquals(g1, back.groups[0])

        assertTrue(controller.setEnabled("missing", true) is LocationTimeGroupChange.Missing)
    }

    // ── 4. 删除组 ──

    @Test
    fun `删除组少一条且 JSON 往返`() {
        val g1 = group(id = "g1", name = "主教学楼")
        val g2 = group(id = "g2", name = "东区")
        val controller = buildController(groups = listOf(g1, g2))

        val result = controller.delete("g1")
        assertTrue(result is LocationTimeGroupChange.Applied)
        val applied = result as LocationTimeGroupChange.Applied
        assertNull("删除没有目标组", applied.target)
        assertEquals(listOf(g2), applied.groups)
        assertJsonRoundTrip(applied.groups)

        assertTrue(controller.delete("missing") is LocationTimeGroupChange.Missing)
    }

    // ── 5. 校验（与 LocationTimeGroupEditorValidation 同一口径）──

    @Test
    fun `空名称优先报名称必填`() {
        val controller = buildController(groups = emptyList())
        val draft = controller.newDraft().copy(name = "   ", keywords = listOf(LocationKeyword("B2")))
        val result = controller.save(draft)
        assertTrue(result is LocationTimeGroupChange.Rejected)
        assertEquals(LocationTimeMatchStrings.nameRequired.zh, (result as LocationTimeGroupChange.Rejected).message)
        // 与编辑页共用的校验器逐字一致，证明不是第二套口径。
        assertEquals(
            LocationTimeGroupEditorValidation.saveError(
                model = controller.model(),
                name = draft.name,
                timeSchemeId = draft.timeSchemeId,
                keywords = draft.keywords,
                editingGroupId = null,
            ),
            result.message,
        )
    }

    @Test
    fun `未选模板报需要先建模板`() {
        val controller = buildController(groups = emptyList(), schemes = emptyList())
        val draft = controller.newDraft().copy(
            name = "东区教学楼",
            keywords = listOf(LocationKeyword("B2")),
        )
        val result = controller.save(draft)
        assertTrue(result is LocationTimeGroupChange.Rejected)
        assertEquals(
            LocationTimeMatchStrings.needTimeScheme.zh,
            (result as LocationTimeGroupChange.Rejected).message,
        )
    }

    @Test
    fun `绑定的模板已被删时报模板不存在`() {
        // 页面校验只判「非空」；查表是 Dart service 层（time_scheme_not_found）。
        val controller = buildController(
            groups = emptyList(),
            schemes = listOf(LocationTimeSchemeOption("s2", "冬季作息")),
        )
        val result = controller.save(
            controller.newDraft().copy(
                timeSchemeId = "deleted-scheme",
                name = "东区教学楼",
                keywords = listOf(LocationKeyword("B2")),
            ),
        )
        assertTrue(result is LocationTimeGroupChange.Rejected)
        assertEquals(
            "时间模板不存在",
            (result as LocationTimeGroupChange.Rejected).message,
        )
    }

    @Test
    fun `空关键词报至少一个关键词`() {
        val controller = buildController(groups = emptyList())
        val empty = controller.save(
            controller.newDraft().copy(name = "东区教学楼", keywords = emptyList()),
        )
        assertTrue(empty is LocationTimeGroupChange.Rejected)
        assertEquals(
            LocationTimeMatchStrings.keywordRequired.zh,
            (empty as LocationTimeGroupChange.Rejected).message,
        )

        // 只有空白的关键词：trim 后等同没有（编辑页 _currentKeywords 的既有口径）。
        val blank = controller.save(
            controller.newDraft().copy(
                name = "东区教学楼",
                keywords = listOf(LocationKeyword("   ", LocationKeywordMatchMode.PREFIX)),
            ),
        )
        assertTrue(blank is LocationTimeGroupChange.Rejected)
        assertEquals(
            LocationTimeMatchStrings.keywordRequired.zh,
            (blank as LocationTimeGroupChange.Rejected).message,
        )
    }

    @Test
    fun `关键词被别的组占用时报占用组名`() {
        val owner = group(id = "g1", name = "主教学楼", keywords = listOf(LocationKeyword("A1")))
        val controller = buildController(groups = listOf(owner))
        val result = controller.save(
            controller.newDraft().copy(name = "东区", keywords = listOf(LocationKeyword(" A1 "))),
        )
        assertTrue(result is LocationTimeGroupChange.Rejected)
        assertEquals(
            "关键词已被 主教学楼 使用",
            (result as LocationTimeGroupChange.Rejected).message,
        )
    }

    @Test
    fun `校验失败不产生任何新列表`() {
        val controller = buildController(groups = emptyList())
        val result = controller.save(controller.newDraft())
        assertTrue(result is LocationTimeGroupChange.Rejected)
        // Rejected 里根本没有列表字段：调用方拿不到「一半已改」的数据。
    }

    // ── 6. 模板被删 → 未知时间模板 ──

    @Test
    fun `绑定模板被删卡片显示未知时间模板`() {
        val controller = buildController(
            groups = listOf(group(id = "g1", name = "主教学楼", schemeId = "deleted-scheme")),
            schemes = listOf(LocationTimeSchemeOption("s2", "冬季作息")),
        )
        val card = controller.model().card("g1")!!
        assertEquals(LocationTimeMatchStrings.unknownScheme.zh, card.boundSchemeName)
        assertEquals("未知时间模板", card.boundSchemeName)
        assertTrue("副标题也要带出未知模板：${card.subtitle}", card.subtitle.contains("未知时间模板"))
        assertEquals("时间模板：未知时间模板 · 关键词：A1", card.subtitle)
        assertFalse("exact 断言之外再钉一次：schemeNames 里不应有 deleted-scheme",
            controller.schemeNames.containsKey("deleted-scheme"))
    }

    // ── 7. 楼栋关键词建议（availableLocations 的用途） ──

    @Test
    fun `楼栋建议排除本组与其它组已有关键词`() {
        val owner = group(id = "g1", name = "主教学楼", keywords = listOf(LocationKeyword("A1")))
        val controller = buildController(
            groups = listOf(owner),
            locations = listOf("A1062", "B201"),
        )
        // 编辑 g1：本组已有关键词（A1）+ 其它组关键词都算已覆盖；g1 的关键词不重复计。
        // 地点里 A1062 聚成 A1（已覆盖）、B201 聚成 B2（未覆盖）⇒ 只剩 B2。
        assertEquals(
            listOf("B2"),
            controller.buildingSuggestions(
                currentKeywords = listOf(LocationKeyword("A1")),
                excludingGroupId = "g1",
            ).map { it.buildingKey },
        )
        // 新建（不排除任何组）：A1 已被 g1 占用，只剩 B2。
        assertEquals(
            listOf("B2"),
            controller.buildingSuggestions(emptyList(), excludingGroupId = null).map { it.buildingKey },
        )
    }

    // ── 8. 重新匹配当前课表：候选数与五分支文案 ──

    @Test
    fun `候选数按课程计数而不是地点去重`() {
        val controller = buildController(
            groups = listOf(
                group(id = "enabled", name = "启用组", keywords = listOf(LocationKeyword("A1"))),
                group(id = "disabled", name = "停用组", enabled = false, keywords = listOf(LocationKeyword("B1"))),
            ),
        )
        val courses = listOf(
            course("A1062"), // 命中启用组
            course("A1062"), // 同一地点第二门课：也算一门
            course("B201"), // 只命中停用组 → 不算
            course("Z999"), // 都不命中
        )
        assertEquals(2, controller.matchedCourseCount(courses))
    }

    @Test
    fun `没有候选不弹确认框`() {
        val controller = buildController(groups = listOf(group(id = "g1", name = "主楼")))
        assertEquals(LocationTimeApplyDecision.NoMatch, controller.applyDecision(0))
        assertEquals(LocationTimeApplyDecision.NoMatch, controller.applyDecision(-1))
    }

    @Test
    fun `有候选弹确认框且正文带门数`() {
        val controller = buildController(groups = listOf(group(id = "g1", name = "主楼")))
        val decision = controller.applyDecision(4)
        assertTrue(decision is LocationTimeApplyDecision.Confirm)
        val confirm = decision as LocationTimeApplyDecision.Confirm
        assertEquals("重新匹配当前课表？", confirm.title)
        assertTrue("正文应含门数：${confirm.message}", confirm.message.contains("4 门课程"))
        assertEquals("重新匹配", confirm.confirmLabel)
    }

    @Test
    fun `套用结果五分支文案`() {
        val controller = buildController(groups = emptyList())

        val partial = controller.applyToast(
            LocationTimeApplyOutcome(matched = 2, updated = 1, overflowCount = 1, overflowNames = listOf("体育")),
        )
        assertEquals(
            "已重新匹配 2 门，更新 1 门钟点；已匹配 2 门课程。另有 1 门超出模板节数，已取消套用",
            partial.message,
        )
        assertEquals("未套用示例：体育", partial.description)
        assertEquals(LocationTimeApplyToastKind.WARNING, partial.kind)

        val updated = controller.applyToast(LocationTimeApplyOutcome(matched = 3, updated = 2))
        assertEquals("已重新匹配 3 门，更新 2 门钟点", updated.message)
        assertNull(updated.description)
        assertEquals(LocationTimeApplyToastKind.SUCCESS, updated.kind)

        val aligned = controller.applyToast(LocationTimeApplyOutcome(matched = 3, updated = 0))
        assertEquals("已重新匹配 3 门，钟点无需改写", aligned.message)
        assertEquals(LocationTimeApplyToastKind.SUCCESS, aligned.kind)

        val overflowOnly = controller.applyToast(
            LocationTimeApplyOutcome(matched = 2, updated = 0, overflowCount = 2),
        )
        assertEquals("已匹配 2 门课程。另有 2 门超出模板节数，已取消套用", overflowOnly.message)
        assertNull(overflowOnly.description)
        assertEquals(LocationTimeApplyToastKind.WARNING, overflowOnly.kind)

        val none = controller.applyToast(LocationTimeApplyOutcome(matched = 0, updated = 0))
        assertEquals("没有匹配到可套用的课程", none.message)
        assertEquals(LocationTimeApplyToastKind.INFO, none.kind)
    }
}