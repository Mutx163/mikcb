package com.mutx163.qingyu.transfer.lan

import com.mutx163.qingyu.app.InMemoryKeyValueStore
import com.mutx163.qingyu.app.TimetableRepository
import com.mutx163.qingyu.app.TimetableStore
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.CourseTask
import com.mutx163.qingyu.core.Exam
import com.mutx163.qingyu.core.FormatException
import com.mutx163.qingyu.core.LocationKeyword
import com.mutx163.qingyu.core.LocationKeywordMatchMode
import com.mutx163.qingyu.core.LocationTimeGroup
import com.mutx163.qingyu.core.ScheduleDateRule
import com.mutx163.qingyu.core.ScheduleItem
import com.mutx163.qingyu.core.SectionTime
import com.mutx163.qingyu.core.TimeScheme
import com.mutx163.qingyu.core.TimetableProfile
import com.mutx163.qingyu.core.TimetableSettings
import com.mutx163.qingyu.sync.validateTransferPackageJson
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDateTime

/**
 * `LanEditRepositoryHost` 的**真数据层**测试（L0）：内存 KV 存储 → `TimetableStore`
 * → `TimetableRepository` → 适配器，全程不 mock 存储。
 *
 * 这一组测的不是「协议」而是**数据**，所以断言落在两处：
 * - 仓储的对外视图（`repository.courses` 等）；
 * - **盘上的原始字节**（`InMemoryKeyValueStore.rawSnapshot()`）。
 *
 * 后者是本次的验收重点：导入类端点必须「先校验后落盘」，坏备份要能证明
 * **一个字节都没写**——只断言「抛了异常」不够，那只证明它没成功，不证明它没写坏。
 */
class LanEditRepositoryHostTest {

    // -----------------------------------------------------------------------
    // 导出
    // -----------------------------------------------------------------------

    @Test
    fun `导出的备份能被同一个校验器认下`() {
        val (repository, _) = repositoryWith(course("c1", "高等数学"), course("c2", "大学物理"))
        val host = LanEditRepositoryHost(repository)

        val exported = host.exportProfileBackupJson()
        val validation = validateTransferPackageJson(exported)
        assertTrue("导出的包必须自洽：${validation.errors}", validation.isValid)
        assertTrue(exported.contains("高等数学"))
        assertTrue(exported.contains("\"scope\":\"current_timetable\""))
        assertTrue(exported.contains("\"channel\":\"lan\""))
    }

    // -----------------------------------------------------------------------
    // 导入：正常路径
    // -----------------------------------------------------------------------

    @Test
    fun `导出再导入 课程真的落到盘上`() {
        val (source, _) = repositoryWith(course("c1", "高等数学"), course("c2", "大学物理"))
        val exported = LanEditRepositoryHost(source).exportProfileBackupJson()
        assertTrue("导出里必须有两门课：$exported", exported.contains("大学物理"))

        val store = InMemoryKeyValueStore()
        val target = repositoryOn(store)
        LanEditRepositoryHost(target).importProfileBackupJson(exported)

        assertEquals(2, target.courses.size)
        assertEquals(setOf("高等数学", "大学物理"), target.courses.map { it.name }.toSet())
        // 落盘证据：盘上的档案 JSON 里真的有这两门课（不是只改了内存）
        val raw = store.rawSnapshot().values.joinToString("\n")
        assertTrue("盘上必须写着这两门课", raw.contains("高等数学") && raw.contains("大学物理"))
    }

    /**
     * 2026-11-01 P0 回归：整份备份导出**缺三块**（日程 / 日期规则 / 地点作息分组），
     * 导入**只写课程 + 设置 + 当前周**，作业与考试也一起丢。
     *
     * 这条走「真仓储导出 → 空仓储导入 → 逐块断言」，任何一块没落盘都会红。
     */
    @Test
    fun `导出再导入 作业考试日程规则地点分组时间模板全部还在`() {
        val now = LocalDateTime.of(2026, 10, 28, 9, 0)
        val scheme = TimeScheme(
            id = "ts1",
            name = "默认作息",
            sections = listOf(SectionTime("08:00", "08:45")),
            createdAt = now,
            updatedAt = now,
        )
        val course = course("c1", "高等数学").copy(timeSchemeIdOverride = "ts1")
        val task = CourseTask(id = "t1", title = "作业一", courseId = "c1", createdAt = now, updatedAt = now)
        val exam = Exam(
            id = "e1",
            courseId = "c1",
            name = "期中考试",
            dateTime = LocalDateTime.of(2026, 11, 20, 9, 0),
            startTime = "09:00",
            endTime = "11:00",
            createdAt = now,
            updatedAt = now,
        )
        val item = ScheduleItem(
            id = "s1",
            title = "社团活动",
            startDate = LocalDateTime.of(2026, 11, 1, 0, 0),
            endDate = LocalDateTime.of(2026, 11, 1, 0, 0),
            startTime = "19:00",
            endTime = "21:00",
            createdAt = now,
            updatedAt = now,
        )
        val rule = ScheduleDateRule(
            id = "r1",
            name = "国庆调休",
            timeSchemeId = "ts1",
            startDate = "2026-10-01",
            endDate = "2026-10-07",
            enabled = true,
        )
        val group = LocationTimeGroup(
            id = "g1",
            name = "实验室作息",
            timeSchemeId = "ts1",
            enabled = true,
            priority = 3,
            keywords = listOf(LocationKeyword("实验楼", LocationKeywordMatchMode.PREFIX)),
        )

        val sourceStore = InMemoryKeyValueStore()
        val sourceTable = TimetableStore(sourceStore)
        sourceTable.saveProfiles(
            listOf(
                TimetableProfile(
                    id = "p1",
                    name = "默认课表",
                    courses = listOf(course),
                    tasks = listOf(task),
                    scheduleItems = listOf(item),
                    exams = listOf(exam),
                    currentWeek = 7L,
                    createdAt = now,
                    lastUsedAt = now,
                ),
            ),
        )
        sourceTable.saveActiveProfileId("p1")
        sourceTable.saveSettings(TimetableSettings.defaults().copy(activeTimeSchemeId = "ts1"))
        sourceTable.saveCurrentWeek(7)
        sourceTable.saveTimeSchemes(listOf(scheme))
        sourceTable.saveScheduleDateRules(listOf(rule))
        sourceTable.saveLocationTimeGroups(listOf(group))
        val source = TimetableRepository(sourceTable)

        val exported = LanEditRepositoryHost(source).exportProfileBackupJson()
        assertTrue("导出侧漏了日程条目：$exported", exported.contains("\"id\":\"s1\""))
        assertTrue("导出侧漏了日期规则：$exported", exported.contains("\"id\":\"r1\""))
        assertTrue("导出侧漏了地点分组：$exported", exported.contains("\"id\":\"g1\""))

        val target = repositoryOn(InMemoryKeyValueStore())
        LanEditRepositoryHost(target).importProfileBackupJson(exported)

        assertEquals("课程", listOf("高等数学"), target.courses.map { it.name })
        assertEquals("作业", listOf("t1"), target.tasks.map { it.id })
        assertEquals("考试", listOf("e1"), target.exams.map { it.id })
        assertEquals("日程条目", listOf("s1"), target.snapshot.scheduleItems.map { it.id })
        assertEquals("日期规则", listOf("r1"), target.snapshot.scheduleDateRules.map { it.id })
        assertEquals("地点分组", listOf("g1"), target.snapshot.locationTimeGroups.map { it.id })
        assertEquals("时间模板", 1, target.snapshot.timeSchemes.size)
        assertEquals("当前周", 7, target.snapshot.currentWeek)

        // 跨设备导入新建了模板：三处引用都必须指向本机新建的那套，不能悬空。
        val localSchemeId = target.snapshot.timeSchemes.single().id
        assertEquals("课程覆盖的模板 id", localSchemeId, target.courses.single().timeSchemeIdOverride)
        assertEquals("日期规则的模板 id", localSchemeId, target.snapshot.scheduleDateRules.single().timeSchemeId)
        assertEquals("地点分组的模板 id", localSchemeId, target.snapshot.locationTimeGroups.single().timeSchemeId)
    }

    // -----------------------------------------------------------------------
    // 导入：坏备份一个字节都不许写（本次验收重点）
    // -----------------------------------------------------------------------
    @Test
    fun `坏备份导入失败时盘上原文一字未变`() {
        val store = InMemoryKeyValueStore()
        val repository = repositoryOn(store)
        repository.addCourse(course("keep1", "原有课程"))
        val before = store.rawSnapshot()
        assertTrue("前置条件：盘上得先有东西", before.isNotEmpty())

        val host = LanEditRepositoryHost(repository)
        val badBackups = listOf(
            "not json at all" to "transfer_package_json_invalid",
            "[]" to "transfer_package_root_invalid",
            """{"app":"other","packageType":"transfer"}""" to "transfer_package_type_invalid",
            // 信封对、版本不对
            """{"app":"mikcb","packageType":"transfer","schemaVersion":9}""" to "transfer_package_schema_unsupported",
            // 信封对、版本对，但缺必填列表
            """{"app":"mikcb","packageType":"transfer","schemaVersion":1,"packageId":"p"}""" to
                "transfer_course_list_required",
            // 结构都对，但课程缺必填字段（校验能抓到）
            fullPackage(courses = """[{"id":"c9"}]""") to "transfer_course_name_required",
            // 结构都对，但课程 id 重复
            fullPackage(
                courses = """[${courseJson("dup", "A")},${courseJson("dup", "B")}]""",
            ) to "transfer_course_id_duplicate",
        )

        for ((content, expectedError) in badBackups) {
            val error = try {
                host.importProfileBackupJson(content)
                null
            } catch (e: FormatException) {
                e
            }
            assertNotNull("`$content` 必须被拒", error)
            assertEquals("`$content` 的错误码", expectedError, error!!.message)
            assertEquals(
                "校验失败时盘上必须一字未变（$expectedError）",
                before,
                store.rawSnapshot(),
            )
        }
    }

    @Test
    fun `多档案整份恢复明确拒绝而不是静默丢档案`() {
        val store = InMemoryKeyValueStore()
        val repository = repositoryOn(store)
        repository.addCourse(course("keep1", "原有课程"))
        val before = store.rawSnapshot()

        val withProfiles = fullPackage(
            courses = "[]",
            profiles = """[{"id":"p9","name":"另一份课表","courses":[],"tasks":[],"scheduleItems":[],"exams":[],"settings":{},"currentWeek":1,"createdAt":"2026-01-01T00:00:00","lastUsedAt":"2026-01-01T00:00:00"}]""",
        )
        val error = try {
            LanEditRepositoryHost(repository).importProfileBackupJson(withProfiles)
            null
        } catch (e: FormatException) {
            e
        }
        assertEquals("profile_backup_profiles_unsupported", error?.message)
        assertEquals("拒绝时不许动盘", before, store.rawSnapshot())
    }

    // -----------------------------------------------------------------------
    // 组替换
    // -----------------------------------------------------------------------

    @Test
    fun `组替换后组里消失的课真的没了`() {
        val store = InMemoryKeyValueStore()
        val repository = repositoryOn(store)
        // 同一门课的三条排课（同组）+ 一条别的课
        repository.addCourse(course("g1", "高等数学", dayOfWeek = 1))
        repository.addCourse(course("g2", "高等数学", dayOfWeek = 3))
        repository.addCourse(course("g3", "高等数学", dayOfWeek = 5))
        repository.addCourse(course("other", "大学物理"))
        assertEquals(4, repository.courses.size)

        val host = LanEditRepositoryHost(repository)
        val saved = host.replaceCourseGroup(
            originalName = "高等数学",
            slots = listOf(
                course("g1", "高等数学", dayOfWeek = 2),
                course("g2", "高等数学", dayOfWeek = 4),
            ),
        )

        // 返回的是替换后的整组
        assertEquals(2, saved.size)
        assertEquals(setOf(2, 4), saved.map { it.dayOfWeek }.toSet())
        // 原来那条周五的排课必须真的没了
        val names = repository.courses.map { it.id }
        assertFalse("g3 必须被删掉", names.contains("g3"))
        assertTrue("别的课不能受影响", names.contains("other"))
        assertEquals(3, repository.courses.size)
        // 盘上也要跟着变
        val raw = store.rawSnapshot().values.joinToString("\n")
        assertFalse("盘上不该再留着 g3", raw.contains("\"g3\""))
    }

    // -----------------------------------------------------------------------
    // 表格导入
    // -----------------------------------------------------------------------

    @Test
    fun `表格导入按 replaceExisting 决定追加还是替换`() {
        val store = InMemoryKeyValueStore()
        val repository = repositoryOn(store)
        repository.addCourse(course("old", "旧课"))
        val parsed = LanEditSpreadsheetParse(
            courses = listOf(course("n1", "新课一"), course("n2", "新课二")),
            warnings = listOf("w1"),
            format = "csv",
        )
        val host = LanEditRepositoryHost(repository) { _, _, _ -> parsed }

        val appended = host.importSpreadsheetBytes("a,b".toByteArray(), "x.csv", replaceExisting = false)
        assertEquals(2, appended.importedCount)
        assertEquals("csv", appended.format)
        assertEquals(listOf("w1"), appended.warnings)
        assertEquals(3, repository.courses.size)

        val replaced = host.importSpreadsheetBytes("a,b".toByteArray(), "x.csv", replaceExisting = true)
        assertEquals(2, replaced.importedCount)
        assertEquals(setOf("n1", "n2"), repository.courses.map { it.id }.toSet())
    }

    @Test
    fun `表格一门都没解析出来时不落盘`() {
        val store = InMemoryKeyValueStore()
        val repository = repositoryOn(store)
        repository.addCourse(course("old", "旧课"))
        val before = store.rawSnapshot()

        val host = LanEditRepositoryHost(repository) { _, _, _ ->
            LanEditSpreadsheetParse(emptyList(), listOf("no rows"), "csv")
        }
        val outcome = host.importSpreadsheetBytes("a,b".toByteArray(), "x.csv", replaceExisting = true)

        assertEquals(0, outcome.importedCount)
        assertEquals(listOf("no rows"), outcome.warnings)
        // replaceExisting=true 也不能因为「没解析出课」就把用户的课清空
        assertEquals("一门都没解析出来时不许动盘", before, store.rawSnapshot())
        assertEquals(1, repository.courses.size)
    }

    /**
     * 2026-11-02 修（P0）回归钉：旧实现 replaceExisting=true 时**先清空（立即落盘）
     * 再逐行写**，任一行非法时旧课表已经没了。新实现必须先验完全部行才允许碰盘——
     * 第 N 行非法 ⇒ 旧课表在内存与盘上都原样保留。
     */
    @Test
    fun `表格中间行非法时旧课表原样保留`() {
        val store = InMemoryKeyValueStore()
        val repository = repositoryOn(store)
        repository.addCourse(course("old", "旧课"))
        val before = store.rawSnapshot()
        assertTrue("前置条件：盘上得先有东西", before.isNotEmpty())

        val good1 = course("n1", "新课一")
        // 节次倒挂（endSection < startSection）：prepareForImport 的校验会拒。
        val bad = course("n2", "新课二").copy(startSection = 3, endSection = 1)
        val good3 = course("n3", "新课三")
        val host = LanEditRepositoryHost(repository) { _, _, _ ->
            LanEditSpreadsheetParse(listOf(good1, bad, good3), emptyList(), "csv")
        }

        val error = try {
            host.importSpreadsheetBytes("a,b".toByteArray(), "x.csv", replaceExisting = true)
            null
        } catch (e: IllegalArgumentException) {
            e
        }
        assertNotNull("非法行必须被拒", error)
        assertEquals("course_sections_invalid", error!!.message)
        // 旧课表在内存里原样（一行新课都没进、旧课也没被清）
        assertEquals(listOf("old"), repository.courses.map { it.id })
        // 盘上一字未变（旧实现这里课表已经被清空落盘了）
        assertEquals("第 2 行非法时盘上必须一字未变", before, store.rawSnapshot())

        // 追加模式同样不许写一半：同一批坏数据在 replaceExisting=false 下也整批拒绝。
        val errorAppend = try {
            host.importSpreadsheetBytes("a,b".toByteArray(), "x.csv", replaceExisting = false)
            null
        } catch (e: IllegalArgumentException) {
            e
        }
        assertNotNull("追加模式同样必须整批拒绝", errorAppend)
        assertEquals(listOf("old"), repository.courses.map { it.id })
        assertEquals("追加模式拒绝时盘上一字未变", before, store.rawSnapshot())
    }

    /** 覆盖导入成功的正路径：新课全量进、挂在旧课上的作业按 clear 口径一起清。 */
    @Test
    fun `表格覆盖导入成功后旧课与挂课作业一起换掉`() {
        val store = InMemoryKeyValueStore()
        val repository = repositoryOn(store)
        repository.addCourse(course("old", "旧课"))
        val host = LanEditRepositoryHost(repository) { _, _, _ ->
            LanEditSpreadsheetParse(
                listOf(course("n1", "新课一"), course("n2", "新课二")),
                emptyList(),
                "csv",
            )
        }

        val outcome = host.importSpreadsheetBytes("a,b".toByteArray(), "x.csv", replaceExisting = true)

        assertEquals(2, outcome.importedCount)
        assertEquals(setOf("n1", "n2"), repository.courses.map { it.id }.toSet())
        val raw = store.rawSnapshot().values.joinToString("\n")
        assertTrue("新课必须真的落到盘上", raw.contains("新课一") && raw.contains("新课二"))
        assertFalse("旧课必须从盘上消失", raw.contains("\"old\""))
    }

    /**
     * 2026-11-02 修回归钉：meta 原来只回 5 个键，Dart 版回 9 个；网页端
     * `app.js` 直接读 presetColors（选色块）/weekdayLabels/sectionCount/
     * profileId/profileName/profiles，缺了就各自退化（选色只剩默认蓝等）。
     * 这条逐字段钉齐，少一个键就红。
     */
    @Test
    fun `meta 接口字段与 Dart 版逐键对齐`() {
        val (repository, _) = repositoryWith(course("c1", "高等数学"))
        val host = LanEditRepositoryHost(repository)

        val meta = host.buildMetaJson()

        // Dart buildMetaJson 的全部 9 个键（缺一个网页端就退化一处）
        val dartKeys = listOf(
            "profileId", "profileName", "currentWeek", "semesterWeekCount",
            "sectionCount", "sections", "presetColors", "weekdayLabels", "profiles",
        )
        for (key in dartKeys) {
            assertTrue("meta 必须回 `$key`（网页端直接读它）", meta.containsKey(key))
        }
        assertEquals("p1", meta["profileId"])
        assertEquals("默认课表", meta["profileName"])
        assertEquals(7, meta["currentWeek"])
        assertEquals(20, meta["semesterWeekCount"])
        assertTrue("sectionCount 必须与 sections 同源", meta["sectionCount"] is Int)
        assertTrue(meta["sections"] is List<*>)
        // 色板必须来自下沉常量（不要新造色板），逐元素一致
        assertEquals(
            com.mutx163.qingyu.core.CourseColorPalette.PRESET_COURSE_COLOR_HEXES,
            meta["presetColors"],
        )
        assertEquals(
            listOf("周一", "周二", "周三", "周四", "周五", "周六", "周日"),
            meta["weekdayLabels"],
        )
        // profiles 是档案摘要列表（id/name/courseCount/currentWeek/isActive）
        val profiles = meta["profiles"] as List<*>
        assertEquals(1, profiles.size)
        val profile = profiles.single() as Map<*, *>
        assertEquals("p1", profile["id"])
        assertEquals("默认课表", profile["name"])
        assertEquals(1, profile["courseCount"])
        assertEquals(true, profile["isActive"])
    }

    // -----------------------------------------------------------------------
    // 其余写入口
    // -----------------------------------------------------------------------

    @Test
    fun `读写入口都走仓储 增删改与切周切档案`() {
        val (repository, store) = repositoryWith(course("c1", "高等数学"))
        val host = LanEditRepositoryHost(repository)

        val created = host.createCourse(course("c2", "大学物理"))
        assertEquals("c2", created.id)
        assertEquals(2, host.courses.size)

        val updated = created.copy(teacher = "张老师")
        assertTrue(host.updateCourse(updated))
        assertEquals("张老师", repository.getCourseById("c2")?.teacher)

        assertEquals(2, host.deleteCoursesBatch(listOf("c1", "c2", "nope")))
        assertTrue(host.courses.isEmpty())
        // 删不存在的返回 false / 0
        assertFalse(host.updateCourse(updated))
        assertFalse(host.deleteCourse("c2"))
        assertEquals(0, host.deleteCoursesBatch(listOf("c2")))

        host.setCurrentWeek(9)
        assertEquals(9, repository.snapshot.currentWeek)

        assertEquals("p1", host.activeProfileId)
        assertEquals(2, host.listProfilesSummary().size + 1) // 只有 p1 时是 1 条 → 这里钉住口径
        val meta = host.buildMetaJson()
        assertEquals(20, meta["semesterWeekCount"])
        assertTrue(meta["sections"] is List<*>)
        assertNotNull(store.rawSnapshot()["flutter.timetable_profiles"])
    }

    @Test
    fun `切档案走仓储 未知 id 抛 profile_not_found`() {
        val store = InMemoryKeyValueStore()
        val repository = repositoryOn(store)
        val host = LanEditRepositoryHost(repository)

        val error = try {
            host.switchProfile("nope")
            null
        } catch (e: IllegalArgumentException) {
            e
        }
        assertEquals("profile_not_found", error?.message)
        // 切到自己（当前档案）是幂等成功，不算错误
        host.switchProfile("p1")
        assertEquals("p1", host.activeProfileId)
    }

    @Test
    fun `传输包预览与应用已接线 返回真实结果而不是 501`() {
        val (repository, store) = repositoryWith(course("c1", "高等数学"))
        val host = LanEditRepositoryHost(repository)
        val content = fullPackage(courses = "[${courseJson("c9", "外来课程")}]")

        val before = store.rawSnapshot()
        val preview = host.previewTransferJson(content)
        assertNotNull("F17 之后预览必须回真实差异，而不是 null（→501）", preview)
        assertEquals("transfer-test-1", preview!!["transferId"])
        assertEquals("预览不许动盘", before, store.rawSnapshot())

        val applied = host.applyTransferJson(
            content,
            com.mutx163.qingyu.share.TransferApplyMode.MERGE,
        )
        assertEquals(true, applied["applied"])
        assertTrue("外来课必须真的进仓储", repository.courses.any { it.id == "c9" })
        assertTrue(
            "外来课必须真的落到盘上",
            store.rawSnapshot().values.joinToString("\n").contains("外来课程"),
        )
    }

    @Test
    fun `仓储宿主实现了 LanTransferHost 传输迁移能力`() {
        val (repository, _) = repositoryWith()
        val host = LanEditRepositoryHost(repository)
        assertTrue("LanEditRepositoryHost 必须具备传输包迁移能力", host is LanTransferHost)
    }

    // -----------------------------------------------------------------------
    // 工具
    // -----------------------------------------------------------------------

    private fun repositoryWith(vararg courses: Course): Pair<TimetableRepository, InMemoryKeyValueStore> {
        val store = InMemoryKeyValueStore()
        val repository = repositoryOn(store, courses.toList())
        return repository to store
    }

    private fun repositoryOn(
        store: InMemoryKeyValueStore,
        courses: List<Course> = emptyList(),
    ): TimetableRepository {
        val timetableStore = TimetableStore(store)
        val now = LocalDateTime.of(2026, 10, 28, 9, 0)
        timetableStore.saveProfiles(
            listOf(
                TimetableProfile(
                    id = "p1",
                    name = "默认课表",
                    courses = courses,
                    currentWeek = 7,
                    createdAt = now,
                    lastUsedAt = now,
                ),
            ),
        )
        timetableStore.saveActiveProfileId("p1")
        timetableStore.saveSettings(TimetableSettings.defaults())
        timetableStore.saveCurrentWeek(7)
        return TimetableRepository(timetableStore)
    }

    private fun course(
        id: String,
        name: String,
        dayOfWeek: Int = 1,
    ): Course = Course(
        id = id,
        name = name,
        teacher = "",
        location = "",
        dayOfWeek = dayOfWeek,
        startSection = 1,
        endSection = 2,
        startTime = "08:00",
        endTime = "09:40",
    )

    private fun courseJson(id: String, name: String): String =
        """{"id":"$id","name":"$name","teacher":"","location":"","dayOfWeek":1,""" +
            """"startSection":1,"endSection":2,"startTime":"08:00","endTime":"09:40"}"""

    /** 一份结构合法的 currentTimetable 包（可替换其中两块来造坏数据）。 */
    private fun fullPackage(
        courses: String = "[]",
        profiles: String = "[]",
    ): String = """
        {
          "app": "mikcb",
          "packageType": "transfer",
          "schemaVersion": 1,
          "packageId": "transfer-test-1",
          "scope": "current_timetable",
          "channel": "lan",
          "exportedAt": "2026-10-28T09:00:00.000",
          "currentWeek": 7,
          "settings": {"sections": [], "semesterWeekCount": 20},
          "courses": $courses,
          "tasks": [],
          "scheduleItems": [],
          "exams": [],
          "timeSchemes": [],
          "scheduleDateRules": [],
          "locationTimeGroups": [],
          "profiles": $profiles
        }
    """.trimIndent()
}
