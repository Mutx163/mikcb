package com.mutx163.qingyu.pages.transfer

import com.mutx163.qingyu.app.AppGlobalSettingsStore
import com.mutx163.qingyu.app.TimetableSnapshot
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.LocationTimeGroup
import com.mutx163.qingyu.core.MiniJson
import com.mutx163.qingyu.core.SectionTime
import com.mutx163.qingyu.core.TimeScheme
import com.mutx163.qingyu.core.TimetableProfile
import com.mutx163.qingyu.core.TimetableSettings
import com.mutx163.qingyu.share.TransferApplyMode
import com.mutx163.qingyu.share.TransferChannel
import com.mutx163.qingyu.share.TransferScope
import java.time.LocalDateTime
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 传输包「设置与地点分组」的**黄金对拍**（2026-11-07）。
 *
 * ## 钉的是哪两条用户可见缺陷
 *
 * 1. 导出只写 `TimetableSettings.toJson()` 的 core 6 键，包里的 250+ 偏好键全部丢失；
 *    导入又只解 core 6 键，落盘时把整份设置写成默认 ⇒ 「恢复备份后外观/语言全变了」。
 * 2. 地点作息分组导入时恒整份替换，合并模式也一样 ⇒ 导入一份「本周课表」会删掉
 *    本机独有的分组，并让 `resync = true` 重排所有档案的课程钟点。
 *
 * ## 为什么用「规范化 JSON 文本」比对
 *
 * `MiniJson` 把整数解析成 `Long`，而 Kotlin 夹具里是 `Int`；直接比 Map 会因
 * `20 != 20L` 假红。统一过一遍 `MiniJson.encode` 再比，等价于比文档本身，
 * 也正好是「黄金文件」的语义（键序 + 值逐字）。
 */
class DataTransferSettingsGoldenTest {

    private val now = LocalDateTime.of(2026, 11, 7, 12, 0)

    // ── 1. 导出：完整 settings map 原样进包 ────────────────────────────

    @Test
    fun `单课表包导出时只带随课表走的偏好，不带整机级键`() {
        val golden = goldenSettings()
        val expected = AppGlobalSettingsStore.stripGlobalKeys(golden)
        val built = build(
            scope = TransferScope.CURRENT_TIMETABLE,
            settingsJson = golden,
        )

        val settings = rootOf(built)["settings"] as Map<*, *>
        assertEquals(
            "非整机级的偏好必须逐字保留（不能只剩 core 6 键）",
            MiniJson.encode(expected),
            MiniJson.encode(settings),
        )
        for (key in listOf("appLocaleTag", "enableHaptics", "pageTransitionSpeed")) {
            assertFalse(
                "整机级键 $key 不得进单课表包（否则会把对方的主题/语言写进本机全局）",
                settings.containsKey(key),
            )
        }
        assertEquals("compact", settings["courseCardDensity"])
    }

    @Test
    fun `全量备份每份档案都带自己的完整设置`() {
        val first = goldenSettings()
        val second = goldenSettings().toMutableMap().apply {
            put("appLocaleTag", "en")
            put("homeMaterialStyle", "solid")
        }
        val built = build(
            scope = TransferScope.ALL_DATA,
            profileSettingsById = mapOf("p1" to first, "p2" to second),
            profiles = listOf(profile("p1", "大一上"), profile("p2", "大一下")),
        )

        val profiles = rootOf(built)["profiles"] as List<*>
        assertEquals(2, profiles.size)
        val firstSettings = (profiles[0] as Map<*, *>)["settings"] as Map<*, *>
        val secondSettings = (profiles[1] as Map<*, *>)["settings"] as Map<*, *>
        assertEquals(MiniJson.encode(first), MiniJson.encode(firstSettings))
        assertEquals(MiniJson.encode(second), MiniJson.encode(secondSettings))
        assertEquals("en", secondSettings["appLocaleTag"])
    }

    // ── 2. 导入：原始键不丢，落盘计划原样携带 ─────────────────────────

    @Test
    fun `导出再导入只保留随课表走的设置原文`() {
        val golden = goldenSettings()
        val expected = AppGlobalSettingsStore.stripGlobalKeys(golden)
        val json = build(scope = TransferScope.CURRENT_TIMETABLE, settingsJson = golden).json
        val plan = parse(json)

        assertNotNull("包里的 settings 必须被保留为原文", plan.settingsJson)
        assertEquals(
            MiniJson.encode(expected),
            MiniJson.encode(plan.settingsJson),
        )
        // core 投影仍然可用（设置页/周次计算走它）。
        assertEquals("ts1", plan.settings?.activeTimeSchemeId)
        assertEquals(20, plan.settings?.semesterWeekCount)
    }

    @Test
    fun `落盘计划把 settings 原文交给宿主`() {
        val golden = goldenSettings()
        val plan = parse(
            build(scope = TransferScope.CURRENT_TIMETABLE, settingsJson = golden).json,
        )
        val writes = DataTransferApplyLogic.planWrites(
            plan = plan,
            mode = TransferApplyMode.OVERWRITE,
            current = DataTransferApplyLogic.TransferCurrentContent(),
            scope = TransferScope.CURRENT_TIMETABLE,
        )

        assertNotNull("writes 必须带原文，宿主才能按键合并写", writes.settingsJson)
        assertEquals(
            MiniJson.encode(AppGlobalSettingsStore.stripGlobalKeys(golden)),
            MiniJson.encode(writes.settingsJson),
        )
    }

    @Test
    fun `跨设备导入只改写 activeTimeSchemeId 其余键原样`() {
        val golden = goldenSettings()
        val plan = parse(
            build(scope = TransferScope.CURRENT_TIMETABLE, settingsJson = golden).json,
        )
        val writes = DataTransferApplyLogic.planWrites(
            plan = plan,
            mode = TransferApplyMode.OVERWRITE,
            current = DataTransferApplyLogic.TransferCurrentContent(),
            scope = TransferScope.CURRENT_TIMETABLE,
            schemeIdMap = mapOf("ts1" to "local-9"),
        )

        val written = writes.settingsJson!!
        val expected = AppGlobalSettingsStore.stripGlobalKeys(golden)
        assertEquals("local-9", written["activeTimeSchemeId"])
        assertEquals(
            "除 activeTimeSchemeId 外，其余键（含 Dart 侧独有键）必须逐字保留",
            expected.size,
            written.size,
        )
        for ((key, value) in expected) {
            if (key == "activeTimeSchemeId") continue
            assertEquals(
                "键 $key 被改写或丢失",
                MiniJson.encode(value),
                MiniJson.encode(written[key]),
            )
        }
    }

    @Test
    fun `全量备份导入保留每份档案的完整设置原文`() {
        val first = goldenSettings()
        val built = build(
            scope = TransferScope.ALL_DATA,
            profileSettingsById = mapOf("p1" to first),
            profiles = listOf(profile("p1", "大一上")),
        )
        val plan = parse(built.json)

        assertEquals(
            "解析层必须保留每份档案的 settings 原文",
            MiniJson.encode(first),
            MiniJson.encode(plan.profileSettingsById["p1"]),
        )

        val writes = DataTransferApplyLogic.planWrites(
            plan = plan,
            mode = TransferApplyMode.OVERWRITE,
            current = DataTransferApplyLogic.TransferCurrentContent(),
            scope = TransferScope.ALL_DATA,
        )
        assertEquals(
            "落盘计划必须把原文带进档案写入",
            MiniJson.encode(first),
            MiniJson.encode(writes.profileSettingsById["p1"]),
        )
    }

    // ── 3. 地点分组：合并模式按 id 合并，覆盖模式整份替换 ─────────────

    @Test
    fun `合并模式地点分组按 id 更新新增且保留本机独有`() {
        val plan = planWithGroups(
            group("g1", "教学楼", "ts1"),
            group("g3", "实验楼", "ts1"),
        )
        val writes = DataTransferApplyLogic.planWrites(
            plan = plan,
            mode = TransferApplyMode.MERGE,
            current = DataTransferApplyLogic.TransferCurrentContent(
                locationTimeGroups = listOf(
                    group("g1", "旧教学楼", "ts-old"),
                    group("g2", "本机独有", "ts-old"),
                ),
            ),
            scope = TransferScope.CURRENT_TIMETABLE,
        )

        assertEquals(
            "合并：同 id 更新、新 id 追加、本机独有保留",
            listOf("g1", "g2", "g3"),
            writes.locationTimeGroups.map { it.id },
        )
        assertEquals("同 id 用包里的名称", "教学楼", writes.locationTimeGroups.first().name)
    }

    @Test
    fun `局部 scope 的覆盖也按合并语义处理分组`() {
        // week_timetable 在 Dart 里 overwriteUsesMergeSemantics = true：
        // 「覆盖」不得删掉包边界外的本机分组。
        val plan = planWithGroups(group("g1", "教学楼", "ts1"))
        val writes = DataTransferApplyLogic.planWrites(
            plan = plan,
            mode = TransferApplyMode.OVERWRITE,
            current = DataTransferApplyLogic.TransferCurrentContent(
                locationTimeGroups = listOf(group("g2", "本机独有", "ts-old")),
            ),
            scope = TransferScope.WEEK_TIMETABLE,
        )

        assertEquals(
            listOf("g2", "g1"),
            writes.locationTimeGroups.map { it.id },
        )
    }

    @Test
    fun `普通覆盖仍然整份替换分组`() {
        val plan = planWithGroups(group("g1", "教学楼", "ts1"))
        val writes = DataTransferApplyLogic.planWrites(
            plan = plan,
            mode = TransferApplyMode.OVERWRITE,
            current = DataTransferApplyLogic.TransferCurrentContent(
                locationTimeGroups = listOf(group("g2", "本机独有", "ts-old")),
            ),
            scope = TransferScope.CURRENT_TIMETABLE,
        )

        assertEquals(listOf("g1"), writes.locationTimeGroups.map { it.id })
    }

    @Test
    fun `包没带分组时合并不动本机也不触发重排`() {
        val plan = planWithGroups()
        val writes = DataTransferApplyLogic.planWrites(
            plan = plan,
            mode = TransferApplyMode.MERGE,
            current = DataTransferApplyLogic.TransferCurrentContent(
                locationTimeGroups = listOf(group("g2", "本机独有", "ts-old")),
            ),
            scope = TransferScope.CURRENT_TIMETABLE,
        )

        assertTrue(
            "空列表 = 包没带这一块，宿主按现有判据跳过写入与 resync",
            writes.locationTimeGroups.isEmpty(),
        )
    }

    // ── 夹具 ─────────────────────────────────────────────────────────

    /** 黄金文档：core 6 键 + Dart 侧独有偏好键（含嵌套对象/数组）。 */
    private fun goldenSettings(): Map<String, Any?> {
        val out = LinkedHashMap<String, Any?>()
        out.putAll(
            TimetableSettings.defaults().copy(
                activeTimeSchemeId = "ts1",
                semesterWeekCount = 20,
            ).toJson(),
        )
        out["appLocaleTag"] = "zh-Hans"
        out["enableHaptics"] = true
        out["homeMaterialStyle"] = "glass"
        out["pageTransitionSpeed"] = "1.0"
        out["themeMode"] = "system"
        out["wallpaperBlurRadius"] = 18
        out["navBarStyle"] = "capsule"
        out["customAccentColor"] = "#FF3366"
        out["showWeekend"] = true
        out["widgetTheme"] = "auto"
        out["liveUpdateStyle"] = "island"
        out["courseCardDensity"] = "compact"
        out["timetableGridStyle"] = "grid"
        out["nested"] = linkedMapOf("a" to "b", "c" to true)
        out["listValue"] = listOf("x", "y")
        return out
    }

    private fun build(
        scope: TransferScope,
        settingsJson: Map<String, Any?>? = null,
        profileSettingsById: Map<String, Map<String, Any?>> = emptyMap(),
        profiles: List<TimetableProfile> = listOf(profile("p1", "大一上")),
    ): TransferPackageResult.Success {
        val snapshot = snapshot(profiles)
        val result = DataTransferPackageLogic.build(
            snapshot = snapshot,
            request = TransferPackageRequest(
                scope = scope,
                channel = TransferChannel.FILE,
                packageId = "pkg-golden",
                now = now,
            ),
            settingsJson = settingsJson,
            profileSettingsById = profileSettingsById,
        )
        return result as? TransferPackageResult.Success
            ?: error("拼包失败：$result")
    }

    private fun snapshot(profiles: List<TimetableProfile>): TimetableSnapshot {
        val course = Course(
            id = "c1",
            name = "高数",
            teacher = "张老师",
            location = "A101",
            dayOfWeek = 1,
            startSection = 1,
            endSection = 2,
            startTime = "08:00",
            endTime = "09:40",
        ).copy(timeSchemeIdOverride = "ts1")
        return TimetableSnapshot(
            profiles = profiles,
            activeProfileId = profiles.firstOrNull()?.id,
            courses = listOf(course),
            settings = TimetableSettings.defaults().copy(activeTimeSchemeId = "ts1"),
            currentWeek = 3,
            timeSchemes = listOf(
                TimeScheme(
                    id = "ts1",
                    name = "默认作息",
                    sections = listOf(
                        SectionTime("08:00", "08:45"),
                        SectionTime("08:55", "09:40"),
                    ),
                    createdAt = now,
                    updatedAt = now,
                ),
            ),
            activeTimeSchemeId = "ts1",
        )
    }

    private fun profile(id: String, name: String) = TimetableProfile(
        id = id,
        name = name,
        settings = TimetableSettings.defaults().copy(activeTimeSchemeId = "ts1"),
        currentWeek = 3L,
        createdAt = now,
        lastUsedAt = now,
    )

    private fun rootOf(result: TransferPackageResult.Success): Map<*, *> =
        MiniJson.parse(result.json) as Map<*, *>

    private fun parse(json: String): TransferImportPlan {
        val parsed = DataTransferImportLogic.parse(json)
        val valid = parsed as? TransferImportParseResult.Valid
        assertNotNull("导出的包必须能被自己解析回来：$parsed", valid)
        return valid!!.plan
    }

    private fun planWithGroups(vararg groups: LocationTimeGroup): TransferImportPlan =
        TransferImportPlan(
            profiles = emptyList(),
            activeProfileId = null,
            courses = listOf(
                Course(
                    id = "c1",
                    name = "高数",
                    teacher = "",
                    location = "A101",
                    dayOfWeek = 1,
                    startSection = 1,
                    endSection = 2,
                    startTime = "08:00",
                    endTime = "09:40",
                ),
            ),
            settings = TimetableSettings.defaults().copy(activeTimeSchemeId = "ts1"),
            currentWeek = 3,
            timeSchemes = emptyList(),
            tasks = emptyList(),
            exams = emptyList(),
            scheduleItems = emptyList(),
            scheduleDateRules = emptyList(),
            locationTimeGroups = groups.toList(),
        )

    private fun group(id: String, name: String, schemeId: String) = LocationTimeGroup(
        id = id,
        name = name,
        timeSchemeId = schemeId,
    )
}
