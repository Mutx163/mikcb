package com.mutx163.qingyu.pages.transfer

import com.mutx163.qingyu.app.TimetableSnapshot
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.CourseTask
import com.mutx163.qingyu.core.Exam
import com.mutx163.qingyu.core.MiniJson
import com.mutx163.qingyu.core.ScheduleDateRule
import com.mutx163.qingyu.core.ScheduleItem
import com.mutx163.qingyu.core.SectionTime
import com.mutx163.qingyu.core.TimeScheme
import com.mutx163.qingyu.core.TimetableProfile
import com.mutx163.qingyu.core.TimetableSettings
import com.mutx163.qingyu.share.TransferChannel
import com.mutx163.qingyu.share.TransferScope
import com.mutx163.qingyu.sync.validateTransferPackageJson
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDateTime

/**
 * 拼包模型层单测。
 *
 * ## 期望值从哪来
 *
 * 全部**人推**，不从实现里抄：
 * - 文件名按 `前缀-yyyyMMdd-HHmm.mikcb` 手算（`2026-03-02 08:30` → `20260302-0830`）；
 * - `exportedAt` 按 Dart `toIso8601String()` 手写（`2026-03-02T08:30:00.000`，无 `Z`）；
 * - 包体键序按 Dart `TransferPackage.toJson()` 手写；
 * - 「哪些课/作业/考试/日程/规则/作息进包」按 scope 语义手推（见每个用例前的注释）。
 *
 * ## 夹具的时间轴（手算基准）
 *
 * 学期起点 `2026-03-02`（周一），当前第 **3** 周 ⇒ 第 3 周是 `2026-03-16 ~ 03-22`。
 *
 * | 对象 | 周次/日期 | 第 3 周内？ |
 * | --- | --- | --- |
 * | 课 c1 高等数学 | 1-16 周 | 在 |
 * | 课 c2 大学英语 | 5-8 周 | 不在 |
 * | 日程 s1 | 2026-03-18 | 在 |
 * | 日程 s2 | 2026-06-10 | 不在 |
 * | 规则 r1（作息 ts2） | 2026-03-16 ~ 03-22 | 与第 3 周重叠 |
 * | 规则 r2（作息 ts3） | 2026-06-01 ~ 06-05 | 不重叠 |
 */
class DataTransferPackageLogicTest {

    // ---------- 夹具 ----------

    private val now: LocalDateTime = LocalDateTime.of(2026, 3, 2, 8, 30)

    private fun settings(): TimetableSettings = TimetableSettings(
        sections = listOf(SectionTime("08:00", "08:45"), SectionTime("08:55", "09:40")),
        activeTimeSchemeId = "ts1",
        semesterWeekCount = 16,
        semesterStartDate = LocalDateTime.of(2026, 3, 2, 0, 0),
    )

    private fun timeScheme(id: String, name: String, start: String = "08:00", end: String = "08:45") =
        TimeScheme(
            id = id,
            name = name,
            sections = listOf(SectionTime(start, end)),
            createdAt = LocalDateTime.of(2026, 2, 1, 0, 0),
            updatedAt = LocalDateTime.of(2026, 2, 1, 0, 0),
        )

    private fun course(
        id: String,
        name: String,
        dayOfWeek: Int,
        startWeek: Int,
        endWeek: Int,
    ) = Course(
        id = id,
        name = name,
        teacher = "张老师",
        location = "A101",
        dayOfWeek = dayOfWeek,
        startSection = 1,
        endSection = 2,
        startTime = "08:00",
        endTime = "09:40",
        startWeek = startWeek,
        endWeek = endWeek,
    )

    private fun task(id: String, courseId: String?) = CourseTask(
        id = id,
        title = "作业-$id",
        courseId = courseId,
        createdAt = LocalDateTime.of(2026, 2, 1, 0, 0),
        updatedAt = LocalDateTime.of(2026, 2, 1, 0, 0),
    )

    private fun exam(id: String, courseId: String) = Exam(
        id = id,
        courseId = courseId,
        name = "考试-$id",
        dateTime = LocalDateTime.of(2026, 6, 20, 9, 0),
        startTime = "09:00",
        endTime = "11:00",
        createdAt = LocalDateTime.of(2026, 2, 1, 0, 0),
        updatedAt = LocalDateTime.of(2026, 2, 1, 0, 0),
    )

    private fun scheduleItem(id: String, year: Int, month: Int, day: Int) = ScheduleItem(
        id = id,
        title = "日程-$id",
        startDate = LocalDateTime.of(year, month, day, 0, 0),
        endDate = LocalDateTime.of(year, month, day, 0, 0),
        startTime = "09:00",
        endTime = "10:00",
        createdAt = LocalDateTime.of(2026, 2, 1, 0, 0),
        updatedAt = LocalDateTime.of(2026, 2, 1, 0, 0),
    )

    private fun rule(
        id: String,
        schemeId: String,
        start: String,
        end: String,
    ) = ScheduleDateRule(
        id = id,
        name = "规则-$id",
        timeSchemeId = schemeId,
        enabled = true,
        startDate = start,
        endDate = end,
    )

    /** 完整夹具：一门在第 3 周内的课、一门不在的课，配套作业/考试/日程/规则/作息。 */
    private fun fullSnapshot(): TimetableSnapshot {
        val courses = listOf(
            course("c1", "高等数学", dayOfWeek = 1, startWeek = 1, endWeek = 16),
            course("c2", "大学英语", dayOfWeek = 2, startWeek = 5, endWeek = 8),
        )
        val tasks = listOf(task("t1", "c1"), task("t2", "c2"), task("t3", null))
        val exams = listOf(exam("e1", "c1"), exam("e2", "c2"))
        val items = listOf(
            scheduleItem("s1", 2026, 3, 18),
            scheduleItem("s2", 2026, 6, 10),
        )
        val rules = listOf(
            rule("r1", "ts2", "2026-03-16", "2026-03-22"),
            rule("r2", "ts3", "2026-06-01", "2026-06-05"),
        )
        val schemes = listOf(
            timeScheme("ts1", "默认作息"),
            timeScheme("ts2", "夏季作息"),
            timeScheme("ts3", "备用作息"),
        )
        val profile = TimetableProfile(
            id = "p1",
            name = "2026 春",
            courses = courses,
            tasks = tasks,
            scheduleItems = items,
            exams = exams,
            settings = settings(),
            currentWeek = 3L,
            createdAt = LocalDateTime.of(2026, 2, 1, 0, 0),
            lastUsedAt = LocalDateTime.of(2026, 2, 2, 0, 0),
        )
        return TimetableSnapshot(
            profiles = listOf(profile),
            activeProfileId = "p1",
            courses = courses,
            scheduleItems = items,
            scheduleDateRules = rules,
            settings = settings(),
            currentWeek = 3,
            semesterStartEpochDay = java.time.LocalDate.of(2026, 3, 2).toEpochDay(),
            timeSchemes = schemes,
            activeTimeSchemeId = "ts1",
        )
    }

    /** 只有一条作息、没有任何课表的夹具（时间模板导出用）。 */
    private fun timeTemplateOnlySnapshot(): TimetableSnapshot = TimetableSnapshot(
        profiles = emptyList(),
        activeProfileId = null,
        courses = emptyList(),
        scheduleItems = emptyList(),
        scheduleDateRules = emptyList(),
        settings = TimetableSettings.defaults(),
        currentWeek = 1,
        semesterStartEpochDay = null,
        timeSchemes = listOf(timeScheme("ts1", "默认作息")),
        activeTimeSchemeId = "ts1",
    )

    private fun request(scope: TransferScope, packageId: String = "pkg-1") =
        TransferPackageRequest(
            scope = scope,
            channel = TransferChannel.FILE,
            packageId = packageId,
            now = now,
        )

    private fun success(result: TransferPackageResult): TransferPackageResult.Success {
        assertTrue("期望 Success，实际 $result", result is TransferPackageResult.Success)
        return result as TransferPackageResult.Success
    }

    private fun failure(result: TransferPackageResult): String {
        assertTrue("期望 Failure，实际 $result", result is TransferPackageResult.Failure)
        return (result as TransferPackageResult.Failure).code
    }

    @Suppress("UNCHECKED_CAST")
    private fun root(json: String): Map<String, Any?> =
        MiniJson.parse(json) as Map<String, Any?>

    private fun listAt(root: Map<String, Any?>, key: String): List<Any?> =
        root[key] as? List<Any?> ?: error("键 $key 不是列表")

    // ---------- 时间模板：逐字整包对拍 ----------

    /**
     * `TIME_TEMPLATE` 的最小包：整段 JSON 手写对拍，一次钉住
     * ①键序 ②`exportedAt` 形状（`yyyy-MM-ddTHH:mm:ss.mmm`，**不带 Z**）
     * ③「不带 settings / currentWeek / profileName」④空列表也要写出来。
     */
    @Test
    fun `时间模板导出的整包逐字对齐 Dart toJson 键序`() {
        val result = success(
            DataTransferPackageLogic.build(
                timeTemplateOnlySnapshot(),
                request(TransferScope.TIME_TEMPLATE, "pkg-tt"),
            ),
        )
        val expected = """{"app":"mikcb","packageType":"transfer","schemaVersion":1,""" +
            """"packageId":"pkg-tt","scope":"time_template","channel":"file",""" +
            """"exportedAt":"2026-03-02T08:30:00.000","courses":[],"tasks":[],""" +
            """"scheduleItems":[],"exams":[],"timeSchemes":[{"id":"ts1","name":"默认作息",""" +
            """"sections":[{"startTime":"08:00","endTime":"08:45"}],""" +
            """"createdAt":"2026-02-01T00:00:00.000","updatedAt":"2026-02-01T00:00:00.000"}],""" +
            """"scheduleDateRules":[],"locationTimeGroups":[],"profiles":[]}"""
        assertEquals(expected, result.json)
        assertFalse("时间模板不是全量备份", result.isFullBackup)
        assertEquals(TransferScope.TIME_TEMPLATE, result.scope)
    }

    @Test
    fun `时间模板的文件名与分享文案按 Dart 口径拼`() {
        val result = success(
            DataTransferPackageLogic.build(
                timeTemplateOnlySnapshot(),
                request(TransferScope.TIME_TEMPLATE),
            ),
        )
        assertEquals("mikcb-timescheme-20260302-0830.mikcb", result.fileName)
        assertEquals("这是轻屿课表的时间模板分享文件，导入后即可恢复使用", result.shareText)
        assertEquals("轻屿课表 · 时间模板", result.shareSubject)
    }

    // ---------- 当前课表 ----------

    @Test
    fun `当前课表带全部课程作业考试日程规则与设置`() {
        val snapshot = fullSnapshot()
        val result = success(
            DataTransferPackageLogic.build(snapshot, request(TransferScope.CURRENT_TIMETABLE)),
        )
        val json = root(result.json)

        assertEquals("mikcb", json["app"])
        assertEquals("transfer", json["packageType"])
        assertEquals(1L, json["schemaVersion"])
        assertEquals("pkg-1", json["packageId"])
        assertEquals("current_timetable", json["scope"])
        assertEquals("file", json["channel"])
        assertEquals("2026-03-02T08:30:00.000", json["exportedAt"])
        assertEquals("2026 春", json["profileName"])
        assertEquals(3L, json["currentWeek"])
        assertTrue("当前课表不带 backupType", !json.containsKey("backupType"))
        assertTrue("当前课表不带 activeProfileId（非全量）", !json.containsKey("activeProfileId"))

        // 设置必须带（scope.carriesSettings），且是 core 子集五个键。
        val exportedSettings = json["settings"] as Map<*, *>
        assertEquals("ts1", exportedSettings["activeTimeSchemeId"])
        assertEquals(16L, exportedSettings["semesterWeekCount"])
        assertEquals("2026-03-02", exportedSettings["semesterStartDateText"])

        assertEquals(listOf("c1", "c2"), listAt(json, "courses").map { (it as Map<*, *>)["id"] })
        assertEquals(listOf("t1", "t2", "t3"), listAt(json, "tasks").map { (it as Map<*, *>)["id"] })
        assertEquals(listOf("e1", "e2"), listAt(json, "exams").map { (it as Map<*, *>)["id"] })
        assertEquals(
            listOf("s1", "s2"),
            listAt(json, "scheduleItems").map { (it as Map<*, *>)["id"] },
        )
        assertEquals(
            listOf("ts1", "ts2", "ts3"),
            listAt(json, "timeSchemes").map { (it as Map<*, *>)["id"] },
        )
        assertEquals(
            listOf("r1", "r2"),
            listAt(json, "scheduleDateRules").map { (it as Map<*, *>)["id"] },
        )
        assertTrue("单课表包不带 profiles", listAt(json, "profiles").isEmpty())

        assertTrue(validateTransferPackageJson(result.json).isValid)
        assertFalse(result.isFullBackup)
        assertEquals("mikcb-backup-20260302-0830.mikcb", result.fileName)
        assertEquals(
            "这是轻屿课表当前课表的完整备份文件，导入后可直接恢复课程和设置",
            result.shareText,
        )
        assertEquals("2026 春 - 轻屿课表备份", result.shareSubject)
    }

    // ---------- 全部数据 ----------

    @Test
    fun `全部数据是全量备份并整份带课表档案`() {
        val snapshot = fullSnapshot()
        val result = success(
            DataTransferPackageLogic.build(snapshot, request(TransferScope.ALL_DATA)),
        )
        val json = root(result.json)

        assertEquals("all_data", json["scope"])
        assertEquals("full", json["backupType"])
        assertEquals("p1", json["activeProfileId"])
        // 全量包不带顶层课表名、不带顶层设置与当前周（Dart buildFullPackage 不传）。
        assertTrue("全量包不带 profileName", !json.containsKey("profileName"))
        assertTrue("全量包不带 settings", !json.containsKey("settings"))
        assertTrue("全量包不带 currentWeek", !json.containsKey("currentWeek"))
        assertTrue("全量包不带顶层课程", listAt(json, "courses").isEmpty())
        assertTrue("全量包不带顶层作业", listAt(json, "tasks").isEmpty())
        assertTrue("全量包不带顶层考试", listAt(json, "exams").isEmpty())
        assertTrue("全量包不带顶层日程", listAt(json, "scheduleItems").isEmpty())

        val profiles = listAt(json, "profiles").map { it as Map<*, *> }
        assertEquals(1, profiles.size)
        assertEquals("p1", profiles[0]["id"])
        assertEquals("2026 春", profiles[0]["name"])
        assertEquals(2, (profiles[0]["courses"] as List<*>).size)
        assertEquals(3, (profiles[0]["tasks"] as List<*>).size)
        assertEquals(2, (profiles[0]["exams"] as List<*>).size)
        assertEquals(2, (profiles[0]["scheduleItems"] as List<*>).size)
        // 作息在档案的 settings.sections 里，档案本身没有顶层 sections 键。
        assertTrue("档案不该有顶层 sections 键", !profiles[0].containsKey("sections"))
        val profileSettings = profiles[0]["settings"] as Map<*, *>
        assertEquals(2, (profileSettings["sections"] as List<*>).size)
        assertEquals("ts1", profileSettings["activeTimeSchemeId"])
        assertEquals(3L, profiles[0]["currentWeek"])

        assertEquals(
            listOf("ts1", "ts2", "ts3"),
            listAt(json, "timeSchemes").map { (it as Map<*, *>)["id"] },
        )
        // 关键：全量包的跨档案 id 重复要放行，所以必须真的能过校验器。
        val validation = validateTransferPackageJson(result.json)
        assertTrue("全量包必须过校验：${validation.errors}", validation.isValid)
        assertTrue(result.isFullBackup)
        assertEquals("mikcb-full-backup-20260302-0830.mikcb", result.fileName)
        assertEquals(
            "这是轻屿课表的全部数据备份文件，包含所有课表、当前选中课表和时间模板",
            result.shareText,
        )
        assertEquals("轻屿课表 - 全部数据备份", result.shareSubject)
    }

    // ---------- 本周课表 ----------

    /**
     * `WEEK_TIMETABLE`：只留第 3 周仍有效的课（c1），附属数据一起收窄——
     * 作业只留 c1 的与无归属的（t1/t3），考试只留 e1，日程只留落在 03-16~03-22 的 s1，
     * 日期规则只留与第 3 周重叠的 r1，作息只留被引用到的 ts1（默认）+ ts2（r1 引用）。
     */
    @Test
    fun `本周课表按当前周筛课且附属数据跟着收窄`() {
        val snapshot = fullSnapshot()
        val result = success(
            DataTransferPackageLogic.build(snapshot, request(TransferScope.WEEK_TIMETABLE)),
        )
        val json = root(result.json)

        assertEquals("week_timetable", json["scope"])
        assertEquals(listOf("c1"), listAt(json, "courses").map { (it as Map<*, *>)["id"] })
        assertEquals(listOf("t1", "t3"), listAt(json, "tasks").map { (it as Map<*, *>)["id"] })
        assertEquals(listOf("e1"), listAt(json, "exams").map { (it as Map<*, *>)["id"] })
        assertEquals(listOf("s1"), listAt(json, "scheduleItems").map { (it as Map<*, *>)["id"] })
        assertEquals(
            listOf("r1"),
            listAt(json, "scheduleDateRules").map { (it as Map<*, *>)["id"] },
        )
        assertEquals(
            listOf("ts1", "ts2"),
            listAt(json, "timeSchemes").map { (it as Map<*, *>)["id"] },
        )
        // 局部范围不携带设备级设置；当前周照 Dart 带（校验器也要求）。
        assertTrue("局部范围不带 settings", !json.containsKey("settings"))
        assertEquals(3L, json["currentWeek"])
        assertTrue(validateTransferPackageJson(result.json).isValid)
    }

    // ---------- 选中课程 ----------

    /**
     * `SELECTED_COURSES` 选 c2（第 5-8 周）：窗口 = `2026-03-30 ~ 04-26`，
     * 两条日程（03-18 / 06-10）与两条日期规则都不落在窗口里 ⇒ 全是空列表；
     * 作息只留默认 ts1（c2 没有覆盖 id）。
     */
    @Test
    fun `选中课程按 id 筛课且窗口外的日程与规则被清掉`() {
        val snapshot = fullSnapshot()
        val result = success(
            DataTransferPackageLogic.build(
                snapshot,
                request(TransferScope.SELECTED_COURSES).copy(selectedCourseIds = setOf("c2")),
            ),
        )
        val json = root(result.json)

        assertEquals("selected_courses", json["scope"])
        assertEquals(listOf("c2"), listAt(json, "courses").map { (it as Map<*, *>)["id"] })
        assertEquals(listOf("t2", "t3"), listAt(json, "tasks").map { (it as Map<*, *>)["id"] })
        assertEquals(listOf("e2"), listAt(json, "exams").map { (it as Map<*, *>)["id"] })
        assertTrue(listAt(json, "scheduleItems").isEmpty())
        assertTrue(listAt(json, "scheduleDateRules").isEmpty())
        assertEquals(listOf("ts1"), listAt(json, "timeSchemes").map { (it as Map<*, *>)["id"] })
        assertTrue(validateTransferPackageJson(result.json).isValid)
    }

    // ---------- 失败路径 ----------

    @Test
    fun `没有时间模板时导出时间模板返回 no_time_schemes`() {
        val snapshot = timeTemplateOnlySnapshot().copy(timeSchemes = emptyList())
        assertEquals(
            "no_time_schemes",
            failure(DataTransferPackageLogic.build(snapshot, request(TransferScope.TIME_TEMPLATE))),
        )
    }

    @Test
    fun `没有活动课表时导出当前课表返回 no_active_profile`() {
        val snapshot = fullSnapshot().copy(profiles = emptyList(), activeProfileId = null)
        assertEquals(
            "no_active_profile",
            failure(DataTransferPackageLogic.build(snapshot, request(TransferScope.CURRENT_TIMETABLE))),
        )
    }

    @Test
    fun `选中课程但一门都没勾时拒绝打包`() {
        val snapshot = fullSnapshot()
        assertEquals(
            "no_selected_courses",
            failure(
                DataTransferPackageLogic.build(snapshot, request(TransferScope.SELECTED_COURSES)),
            ),
        )
    }

    // ---------- 文案与 ARB ----------

    @Test
    fun `本对象登记的七条文案与 TransferStrings 同源`() {
        assertEquals(7, DataTransferPackageLogic.allTexts.size)
        assertEquals(
            listOf(
                "dataTransferProfileShareText",
                "dataTransferProfileShareSubject",
                "dataTransferProfileShareSubjectNamed",
                "dataTransferFullBackupShareText",
                "dataTransferFullBackupShareSubject",
                "dataTransferTimeSchemeShareText",
                "timeSchemeShareSubject",
            ),
            DataTransferPackageLogic.allTexts.map { it.key },
        )
        // 同一批键已被 TransferStrings.kt 收过：两处必须逐字相等，防止漂开。
        for (arb in DataTransferPackageLogic.allTexts) {
            val known = TransferStrings.allTexts.firstOrNull { it.key == arb.key }
            assertTrue("TransferStrings 里应已有键 ${arb.key}", known != null)
            assertEquals("键 ${arb.key} 的文案与本对象不一致", known!!.zh, arb.zh)
        }
    }
}
